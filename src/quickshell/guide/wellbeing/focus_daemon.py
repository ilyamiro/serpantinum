#!/usr/bin/env python3
import subprocess
import sqlite3
import time
import os
import socket
import json
import threading
import calendar
import re
import signal
import sys
import shutil
import glob
import fcntl
from datetime import date, datetime, timedelta
from collections import defaultdict

RUN_DIR = os.environ.get("QS_RUN_FOCUSTIME", "/tmp/quickshell/focustime")
os.makedirs(RUN_DIR, exist_ok=True)

LOCK_PATH = os.path.join(RUN_DIR, "focus_daemon.lock")
lock_fd = open(LOCK_PATH, "w")
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except (IOError, BlockingIOError):
    sys.exit(0)

current_app_class = "Desktop"
current_app_title = "Desktop"

DB_DIR = os.environ.get("QS_STATE_FOCUSTIME", os.path.expanduser("~/.local/state/quickshell/focustime"))
os.makedirs(DB_DIR, exist_ok=True)
DB_PATH = os.path.join(DB_DIR, "focustime.db")

OLD_DB_DIR = os.path.expanduser("~/.local/share/focustime")
OLD_DB_BASE = os.path.join(OLD_DB_DIR, "focustime.db")

if not os.path.exists(DB_PATH) and os.path.exists(OLD_DB_BASE):
    try:
        for old_file in glob.glob(OLD_DB_BASE + "*"):
            shutil.move(old_file, DB_DIR)
    except Exception:
        pass

STATE_FILE = os.path.join(RUN_DIR, "focustime_state.json")
CONFIG_PATH = os.environ.get("QS_SETTINGS", os.path.expanduser("~/.config/serpantinum/settings.json"))

SYSTEM_STATES = {"Desktop", "Locked", "Quickshell", "Unknown"}

def detect_compositor():
    if os.environ.get("MANGO_INSTANCE_SIGNATURE"):
        return "mango"
    if os.environ.get("NIRI_SOCKET"):
        return "niri"
    if os.environ.get("SWAYSOCK"):
        return "sway"
    try:
        if subprocess.run(['pgrep', '-x', 'niri'], capture_output=True).returncode == 0:
            return "niri"
    except Exception:
        pass
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "hyprland"
    try:
        if subprocess.run(['pgrep', '-x', 'Hyprland'], capture_output=True).returncode == 0:
            return "hyprland"
    except Exception:
        pass
    try:
        if subprocess.run(['pgrep', '-x', 'sway'], capture_output=True).returncode == 0:
            return "sway"
    except Exception:
        pass
    try:
        if subprocess.run(['pgrep', '-x', 'mango'], capture_output=True).returncode == 0:
            return "mango"
    except Exception:
        pass
    return "unknown"

def resolve_app_name(app_class, raw_title):
    if not app_class or app_class in SYSTEM_STATES:
        return app_class if app_class else "Unknown"
        
    clean_title = re.sub(r'^\(\d+\)\s*|^\[\d+\]\s*', '', raw_title)
    clean_title = re.sub(r'\s*\(\d+\)$', '', clean_title)
    parts = re.split(r'\s+[-—|]\s+', clean_title)
    name = parts[-1].strip() if len(parts) > 1 else clean_title.strip()

    return app_class.capitalize() if len(name) > 25 else name

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS focus_log (log_date TEXT, app_class TEXT, seconds INTEGER, app_title TEXT, PRIMARY KEY (log_date, app_class))''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date)')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_hourly (log_date TEXT, hour INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, hour, app_class))''')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_intervals (log_date TEXT, interval_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, interval_idx, app_class))''')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_minutes (log_date TEXT, minute_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, minute_idx, app_class))''')
    
    c.execute("PRAGMA table_info(focus_log)")
    if 'app_title' not in [row[1] for row in c.fetchall()]:
        c.execute('ALTER TABLE focus_log ADD COLUMN app_title TEXT')
        
    conn.commit()
    return conn

def get_active_window_hyprctl():
    try:
        output = subprocess.check_output(['hyprctl', 'activewindow', '-j'], text=True)
        if output.strip() == "{}": return "Desktop", "Desktop"
        data = json.loads(output)
        
        app_cls = (data.get('initialClass') or data.get('class') or '').strip()
        raw_title = (data.get('initialTitle') or data.get('title') or '').strip()

        if "quickshell" in app_cls.lower() or "qs-master" in raw_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"
            
        app_cls = app_cls if app_cls else "Unknown"
        raw_title = raw_title if raw_title else app_cls
        clean_name = resolve_app_name(app_cls, raw_title)
        return app_cls, clean_name
    except Exception:
        return "Unknown", "Unknown"

def get_active_window_niri():
    try:
        output = subprocess.check_output(['niri', 'msg', '-j', 'focused-window'], text=True)
        if not output.strip() or output.strip() == "null": return "Desktop", "Desktop"
        data = json.loads(output)
        
        app_cls = (data.get('app_id') or '').strip()
        raw_title = (data.get('title') or '').strip()

        if "quickshell" in app_cls.lower() or "qs-master" in raw_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"
            
        app_cls = app_cls if app_cls else "Unknown"
        raw_title = raw_title if raw_title else app_cls
        clean_name = resolve_app_name(app_cls, raw_title)
        return app_cls, clean_name
    except Exception:
        return "Desktop", "Desktop"

def find_focused_sway_node(node):
    if node.get('focused') and node.get('type') in ('con', 'floating_con'):
        return node
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        found = find_focused_sway_node(child)
        if found:
            return found
    return None

def get_active_window_sway():
    try:
        output = subprocess.check_output(['swaymsg', '-t', 'get_tree'], text=True)
        node = find_focused_sway_node(json.loads(output))
        if not node: return "Desktop", "Desktop"

        props = node.get('window_properties') or {}
        app_cls = (node.get('app_id') or props.get('class') or '').strip()
        raw_title = (node.get('name') or '').strip()

        if "quickshell" in app_cls.lower() or "qs-master" in raw_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"

        app_cls = app_cls if app_cls else "Unknown"
        raw_title = raw_title if raw_title else app_cls
        clean_name = resolve_app_name(app_cls, raw_title)
        return app_cls, clean_name
    except Exception:
        return "Desktop", "Desktop"

def get_active_window_mango():
    try:
        output = subprocess.check_output(['mmsg', 'get', 'focusing-client'], text=True)
        data = json.loads(output)
        if not output.strip() or data.get('error'): return "Desktop", "Desktop"

        app_cls = (data.get('appid') or '').strip()
        raw_title = (data.get('title') or '').strip()

        if "quickshell" in app_cls.lower() or "qs-master" in raw_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"

        app_cls = app_cls if app_cls else "Unknown"
        raw_title = raw_title if raw_title else app_cls
        clean_name = resolve_app_name(app_cls, raw_title)
        return app_cls, clean_name
    except Exception:
        return "Desktop", "Desktop"

LOCK_RUN_DIR = os.environ.get("QS_RUN_LOCK", os.path.join(os.environ.get("QS_RUN_DIR", f"{os.environ.get('XDG_RUNTIME_DIR', '/tmp')}/serpantinum"), "lock"))
LOCK_STATE_PATH = os.path.join(LOCK_RUN_DIR, "locked")

def is_locked():
    if os.path.exists(LOCK_STATE_PATH):
        return True
    return False

def listen_hyprland_ipc():
    global current_app_class, current_app_title
    hypr_sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not hypr_sig: return

    sock_path = f"{os.environ.get('XDG_RUNTIME_DIR', '/tmp')}/hypr/{hypr_sig}/.socket2.sock"
    if not os.path.exists(sock_path):
        sock_path = f"/tmp/hypr/{hypr_sig}/.socket2.sock"

    while True:
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(sock_path)
            buffer = ""
            while True:
                data = client.recv(4096).decode('utf-8')
                if not data: break
                buffer += data
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.startswith('activewindow>>') or line.startswith('activewindowv2>>'):
                        cls, clean_title = get_active_window_hyprctl()
                        if is_locked() or cls == "hyprlock":
                            current_app_class, current_app_title = "Locked", "Locked"
                        else:
                            current_app_class, current_app_title = cls, clean_title
        except Exception:
            time.sleep(2) 

def listen_niri_ipc():
    global current_app_class, current_app_title
    while True:
        try:
            process = subprocess.Popen(['niri', 'msg', 'event-stream'], stdout=subprocess.PIPE, text=True)
            for line in process.stdout:
                if not line.strip(): continue
                cls, clean_title = get_active_window_niri()
                if is_locked():
                    current_app_class, current_app_title = "Locked", "Locked"
                else:
                    current_app_class, current_app_title = cls, clean_title
            process.wait()
        except Exception:
            pass
        time.sleep(2)

def listen_sway_ipc():
    global current_app_class, current_app_title
    while True:
        try:
            process = subprocess.Popen(['swaymsg', '-t', 'subscribe', '-m', '["window", "workspace"]'], stdout=subprocess.PIPE, text=True)
            for line in process.stdout:
                if not line.strip(): continue
                cls, clean_title = get_active_window_sway()
                if is_locked():
                    current_app_class, current_app_title = "Locked", "Locked"
                else:
                    current_app_class, current_app_title = cls, clean_title
            process.wait()
        except Exception:
            pass
        time.sleep(2)

def listen_mango_ipc():
    global current_app_class, current_app_title
    while True:
        try:
            process = subprocess.Popen(['mmsg', 'watch', 'focusing-client'], stdout=subprocess.PIPE, text=True)
            for line in process.stdout:
                if not line.strip(): continue
                cls, clean_title = get_active_window_mango()
                if is_locked():
                    current_app_class, current_app_title = "Locked", "Locked"
                else:
                    current_app_class, current_app_title = cls, clean_title
            process.wait()
        except Exception:
            pass
        time.sleep(2)

class DaemonTracker:
    def __init__(self):
        self.conn = init_db()
        self.buffer = []
        self.cached_json = None
        self.last_sync = 0
        self.last_date = date.today()
        
    def full_sync(self, target_date):
        c = self.conn.cursor()
        
        yesterday = target_date - timedelta(days=1)
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (yesterday.isoformat(),))
        yesterday_seconds = c.fetchone()[0] or 0

        monday = target_date - timedelta(days=target_date.weekday())
        sunday = monday + timedelta(days=6)
        week_range_str = f"{monday.strftime('%b')} {monday.day} - {sunday.strftime('%b')} {sunday.day}"

        c.execute('''SELECT COUNT(DISTINCT log_date), SUM(seconds) FROM focus_log 
                     WHERE log_date >= ? AND log_date <= ? AND seconds > 0''', (monday.isoformat(), sunday.isoformat()))
        row = c.fetchone()
        days_count = row[0] or 0
        total_week = row[1] or 0
        average_seconds = total_week // days_count if days_count > 0 else 0
        
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (target_date.isoformat(),))
        total_seconds = c.fetchone()[0] or 0

        c.execute('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs 
                     FROM focus_log WHERE log_date = ? GROUP BY app_class ORDER BY secs DESC''', (target_date.isoformat(),))
        all_apps = []
        for row in c.fetchall():
            app_class, app_title, secs = row
            all_apps.append({
                "class": app_class, "name": app_title,
                "seconds": secs, "percent": round((secs / total_seconds) * 100, 1) if total_seconds > 0 else 0
            })

        c.execute('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log 
                     WHERE log_date >= ? AND log_date <= ? GROUP BY app_class ORDER BY secs DESC LIMIT 50''', 
                  (monday.isoformat(), sunday.isoformat()))
        week_apps_rows = c.fetchall()
        week_apps_total = sum([r[2] for r in week_apps_rows])
        week_apps = []
        for r in week_apps_rows:
            cls, title, secs = r
            week_apps.append({
                "class": cls, "name": title,
                "seconds": secs, "percent": round((secs / week_apps_total) * 100, 1) if week_apps_total > 0 else 0
            })

        c.execute('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date', 
                 (monday.isoformat(), sunday.isoformat()))
        week_map = {r[0]: r[1] for r in c.fetchall()}
        days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        week_data = []
        for i in range(7):
            d_str = (monday + timedelta(days=i)).isoformat()
            week_data.append({"date": d_str, "day": days_str[i], "total": week_map.get(d_str, 0), "is_target": d_str == target_date.isoformat()})

        first_day = target_date.replace(day=1)
        _, num_days = calendar.monthrange(target_date.year, target_date.month)
        last_day = target_date.replace(day=num_days)
        c.execute('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date', 
                 (first_day.isoformat(), last_day.isoformat()))
        month_map = {r[0]: r[1] for r in c.fetchall()}
        
        month_data = [{"date": "", "total": -1, "is_target": False} for _ in range(first_day.weekday())]
        for i in range(1, num_days + 1):
            d_str = target_date.replace(day=i).isoformat()
            month_data.append({"date": d_str, "total": month_map.get(d_str, 0), "is_target": d_str == target_date.isoformat()})

        hourly_data = [0] * 48
        try:
            c.execute('SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ? GROUP BY hour', (target_date.isoformat(),))
            for hr, secs in c.fetchall():
                if 0 <= hr <= 23: hourly_data[hr * 2] += secs
            c.execute('SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ? GROUP BY interval_idx', (target_date.isoformat(),))
            for idx, secs in c.fetchall():
                if 0 <= idx < 96: hourly_data[idx // 2] += secs
        except sqlite3.OperationalError:
            pass 

        week_heatmap = [[0]*24 for _ in range(7)]
        try:
            c.execute('''SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ? GROUP BY log_date, hour''', 
                      (monday.isoformat(), sunday.isoformat()))
            for ldate, hr, secs in c.fetchall():
                day_idx = date.fromisoformat(ldate).weekday()
                if 0 <= hr <= 23: week_heatmap[day_idx][hr] += secs
        except sqlite3.OperationalError:
            pass

        minute_data = [0] * 1440
        try:
            c.execute('''SELECT minute_idx, SUM(seconds) FROM focus_minutes WHERE log_date >= ? AND log_date <= ? GROUP BY minute_idx''', 
                      (monday.isoformat(), sunday.isoformat()))
            for idx, secs in c.fetchall():
                if 0 <= idx < 1440: minute_data[idx] += secs
        except sqlite3.OperationalError:
            pass

        peak_str = "N/A"
        max_sum = 0
        best_window = None
        for i in range(1440 - 60):
            w_sum = sum(minute_data[i:i+60])
            if w_sum > max_sum and w_sum > 0:
                max_sum = w_sum
                best_window = (i, i+60)

        if best_window:
            start_idx, end_idx = best_window
            while start_idx < end_idx and minute_data[start_idx] == 0: start_idx += 1
            actual_end = end_idx - 1
            while actual_end > start_idx and minute_data[actual_end] == 0: actual_end -= 1
            s_h, s_m = divmod(start_idx, 60)
            e_h, e_m = divmod(actual_end, 60)
            peak_str = f"{s_h:02d}:{s_m:02d} - {e_h:02d}:{e_m:02d}"

        try:
            c.execute('SELECT app_class, MAX(COALESCE(app_title, app_class)), SUM(seconds) FROM focus_log GROUP BY app_class ORDER BY SUM(seconds) DESC')
            all_known_apps = [{"class": row[0], "name": row[1]} for row in c.fetchall()]
        except sqlite3.OperationalError:
            all_known_apps = []

        self.cached_json = {
            "selected_date": target_date.isoformat(), "total": total_seconds, "average": average_seconds,
            "week_range": week_range_str, "yesterday": yesterday_seconds, "current": current_app_title,
            "apps": all_apps, "week_apps": week_apps, "week": week_data, "month": month_data,
            "hourly": hourly_data, "week_heatmap": week_heatmap, "peak_usage_str": peak_str, "all_known_apps": all_known_apps
        }
        self.last_sync = time.time()
        self.last_date = target_date
        
    def fast_tick(self, app_class, app_title, secs=1, write_to_disk=True):
        now = datetime.now()
        target_date = now.date()

        if not app_class or app_class in SYSTEM_STATES:
            if self.cached_json is not None:
                self.cached_json["current"] = app_title
                if write_to_disk:
                    temp_file = STATE_FILE + ".tmp"
                    try:
                        with open(temp_file, "w") as f:
                            json.dump(self.cached_json, f)
                        os.rename(temp_file, STATE_FILE)
                    except Exception:
                        pass
            return

        self.buffer.append((target_date.isoformat(), app_class, app_title, now, secs))
        
        if self.cached_json is None or target_date != self.last_date or (time.time() - self.last_sync > 60):
            self.flush()
            self.full_sync(target_date)
        else:
            d = self.cached_json
            d["total"] += secs
            d["current"] = app_title
            
            found = False
            for app in d["apps"]:
                if app["class"] == app_class:
                    app["seconds"] += secs
                    app["name"] = app_title
                    found = True
                    break
            if not found:
                d["apps"].append({
                    "class": app_class, "name": app_title, 
                    "seconds": secs, "percent": 0
                })
                
            for app in d["apps"]:
                app["percent"] = round((app["seconds"] / d["total"]) * 100, 1) if d["total"] > 0 else 0
            d["apps"].sort(key=lambda x: x["seconds"], reverse=True)
            
            for w in d["week"]:
                if w["is_target"]: w["total"] += secs
            for m in d["month"]:
                if m["is_target"]: m["total"] += secs
                
            hr = now.hour
            idx = hr * 2 + (1 if now.minute >= 30 else 0)
            if 0 <= idx < 48: d["hourly"][idx] += secs
                
            day_idx = now.weekday()
            if 0 <= hr < 24: d["week_heatmap"][day_idx][hr] += secs
                
        if write_to_disk and self.cached_json:
            temp_file = STATE_FILE + ".tmp"
            try:
                with open(temp_file, "w") as f:
                    json.dump(self.cached_json, f)
                os.rename(temp_file, STATE_FILE)
            except Exception:
                pass
            
        if len(self.buffer) >= 15:
            self.flush()
            
    def flush(self):
        if not self.buffer: return
        c = self.conn.cursor()
        
        logs = defaultdict(int)
        titles = {}
        hours = defaultdict(int)
        intervals = defaultdict(int)
        minutes = defaultdict(int)
        
        for d_str, cls, title, dt, secs in self.buffer:
            logs[(d_str, cls)] += secs
            titles[cls] = title
            hr = dt.hour
            hours[(d_str, hr, cls)] += secs
            minute = hr * 60 + dt.minute
            intervals[(d_str, minute // 15, cls)] += secs
            minutes[(d_str, minute, cls)] += secs
            
        for (d_str, cls), secs in logs.items():
            c.execute('''INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?, app_title = ?''',
                      (d_str, cls, secs, titles[cls], secs, titles[cls]))
                      
        for (d_str, hr, cls), secs in hours.items():
            c.execute('''INSERT INTO focus_hourly (log_date, hour, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, hr, cls, secs, secs))
                      
        for (d_str, itv, cls), secs in intervals.items():
            c.execute('''INSERT INTO focus_intervals (log_date, interval_idx, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, interval_idx, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, itv, cls, secs, secs))
                      
        for (d_str, min_idx, cls), secs in minutes.items():
            c.execute('''INSERT INTO focus_minutes (log_date, minute_idx, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, minute_idx, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, min_idx, cls, secs, secs))
                      
        self.conn.commit()
        self.buffer.clear()

tracker = DaemonTracker()

def exit_handler(sig, frame):
    tracker.flush()
    sys.exit(0)

def main():
    global current_app_class, current_app_title
    signal.signal(signal.SIGINT, exit_handler)
    signal.signal(signal.SIGTERM, exit_handler)

    compositor = detect_compositor()
    
    if compositor == "mango":
        current_app_class, current_app_title = get_active_window_mango()
        ipc_thread = threading.Thread(target=listen_mango_ipc, daemon=True)
    elif compositor == "sway":
        current_app_class, current_app_title = get_active_window_sway()
        ipc_thread = threading.Thread(target=listen_sway_ipc, daemon=True)
    elif compositor == "niri":
        current_app_class, current_app_title = get_active_window_niri()
        ipc_thread = threading.Thread(target=listen_niri_ipc, daemon=True)
    else:
        current_app_class, current_app_title = get_active_window_hyprctl()
        ipc_thread = threading.Thread(target=listen_hyprland_ipc, daemon=True)
        
    ipc_thread.start()

    notified_overall = False
    notified_apps = set()
    last_notification_date = datetime.now().date()

    last_monotonic = time.monotonic()
    accumulated_time = 0.0
    tick_counter = 0

    cached_settings = {}
    last_settings_mtime = 0

    while True:
        time.sleep(1)
        now_monotonic = time.monotonic()
        delta = now_monotonic - last_monotonic
        last_monotonic = now_monotonic

        if delta < 0 or delta > 3.0:
            delta = 1.0

        accumulated_time += delta
        secs_to_record = int(accumulated_time)
        if secs_to_record < 1:
            continue
        accumulated_time -= secs_to_record
        tick_counter += 1
        
        today = datetime.now().date()
        if today != last_notification_date:
            notified_overall = False
            notified_apps = set()
            last_notification_date = today

        if tick_counter % 5 == 1:
            try:
                if os.path.exists(CONFIG_PATH):
                    mtime = os.path.getmtime(CONFIG_PATH)
                    if mtime != last_settings_mtime:
                        last_settings_mtime = mtime
                        with open(CONFIG_PATH, "r") as f:
                            cached_settings = json.load(f)
            except Exception:
                pass
                
        wellbeing = cached_settings.get("wellbeing", {})
        excluded_apps = wellbeing.get("excludedApps", [])
        overall_limit = wellbeing.get("overallDailyLimit", 0)
        app_limits = wellbeing.get("appLimits", {})

        if is_locked():
            current_app_class, current_app_title = "Locked", "Locked"

        if current_app_class and current_app_class not in SYSTEM_STATES and current_app_class not in excluded_apps:
            tracker.fast_tick(current_app_class, current_app_title, secs=secs_to_record, write_to_disk=(tick_counter % 5 == 0))
            
            if tracker.cached_json:
                total_seconds = tracker.cached_json.get("total", 0)
                if overall_limit > 0 and total_seconds >= overall_limit and not notified_overall:
                    subprocess.Popen(["notify-send", "-u", "critical", "Digital Wellbeing", "Overall daily limit reached!"])
                    notified_overall = True

                app_seconds = 0
                for app in tracker.cached_json.get("apps", []):
                    if app["class"] == current_app_class:
                        app_seconds = app["seconds"]
                        break
                
                app_limit = app_limits.get(current_app_class, 0)
                if app_limit > 0 and app_seconds >= app_limit and current_app_class not in notified_apps:
                    subprocess.Popen(["notify-send", "-u", "critical", "Digital Wellbeing", f"{current_app_title} daily limit reached!"])
                    notified_apps.add(current_app_class)
        else:
            tracker.fast_tick(current_app_class, current_app_title, secs=0, write_to_disk=(tick_counter % 5 == 0))

if __name__ == "__main__":
    main()
