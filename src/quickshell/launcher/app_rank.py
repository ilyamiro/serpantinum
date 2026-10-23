#!/usr/bin/env python3
import os
import json
import fcntl
import sqlite3
import argparse
from datetime import date, timedelta, datetime

HALF_LIFE_DAYS = 7
LAUNCH_SECONDS_PER_EVENT = 90
RETENTION_DAYS = 60

def get_stats_dir():
    stats_dir = os.environ.get("QS_STATE_APPLAUNCHER", os.path.expanduser("~/.local/state/quickshell/applauncher"))
    os.makedirs(stats_dir, exist_ok=True)
    return stats_dir

def get_launcher_stats():
    stats_path = os.path.join(get_stats_dir(), "launch_stats.json")
    if os.path.exists(stats_path):
        try:
            with open(stats_path, 'r') as f:
                raw = json.load(f)
            three_days_ago = (date.today() - timedelta(days=3)).isoformat()
            migrated = {}
            for name, val in raw.items():
                if isinstance(val, dict):
                    migrated[name] = val
                elif isinstance(val, (int, float)):
                    migrated[name] = {three_days_ago: int(val)}
            return migrated
        except Exception:
            pass
    return {}

def log_launch(app_name):
    if not app_name:
        return
    stats_path = os.path.join(get_stats_dir(), "launch_stats.json")
    with open(stats_path + ".lock", 'w') as lock_fd:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        stats = get_launcher_stats()
        today_str = date.today().isoformat()
        app_stats = stats.get(app_name, {})
        app_stats[today_str] = app_stats.get(today_str, 0) + 1

        cutoff = date.today() - timedelta(days=RETENTION_DAYS)
        app_stats = {d: c for d, c in app_stats.items() if date.fromisoformat(d) >= cutoff}
        stats[app_name] = app_stats

        try:
            tmp_path = stats_path + ".tmp"
            with open(tmp_path, 'w') as f:
                json.dump(stats, f)
            os.replace(tmp_path, stats_path)
        except Exception:
            pass

def get_target_db():
    db_dir = os.environ.get("QS_STATE_FOCUSTIME", os.path.expanduser("~/.local/state/quickshell/focustime"))
    db_path = os.path.join(db_dir, "focustime.db")
    old_db_path = os.path.expanduser("~/.local/share/focustime/focustime.db")
    if os.path.exists(db_path):
        return db_path
    if os.path.exists(old_db_path):
        return old_db_path
    return None

def get_usage_stats():
    stats = {}
    target_db = get_target_db()
    if target_db:
        try:
            conn = sqlite3.connect(target_db)
            c = conn.cursor()
            today = date.today()
            cutoff = (today - timedelta(days=RETENTION_DAYS)).isoformat()
            c.execute("SELECT app_class, log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? GROUP BY app_class, log_date", (cutoff,))
            
            app_data = {}
            for row in c.fetchall():
                app_class = row[0]
                log_date_str = row[1]
                secs = row[2]
                if not app_class:
                    continue
                
                cls = app_class.lower()
                if cls not in app_data:
                    app_data[cls] = {'days': set(), 'decayed_secs': 0.0}
                
                try:
                    age_days = (today - date.fromisoformat(log_date_str)).days
                except ValueError:
                    continue
                
                age_days = max(0, age_days)
                weight = 0.5 ** (age_days / HALF_LIFE_DAYS)
                app_data[cls]['decayed_secs'] += secs * weight
                app_data[cls]['days'].add(log_date_str)
                
            for cls, data in app_data.items():
                distinct_days = len(data['days'])
                consistency_bonus = distinct_days * 300
                stats[cls] = data['decayed_secs'] + consistency_bonus
                
            conn.close()
        except Exception:
            pass
    return stats

def get_contextual_scores():
    stats = {}
    target_db = get_target_db()
    if target_db:
        try:
            now = datetime.now()
            hr = now.hour
            conn = sqlite3.connect(target_db)
            c = conn.cursor()
            two_weeks_ago = (date.today() - timedelta(days=14)).isoformat()
            
            c.execute("""SELECT app_class, SUM(seconds) FROM focus_hourly
                         WHERE log_date >= ? AND hour IN (?, ?, ?)
                         GROUP BY app_class""", (two_weeks_ago, (hr-1)%24, hr, (hr+1)%24))
            
            for row in c.fetchall():
                app_class = row[0]
                secs = row[1]
                if app_class:
                    stats[app_class.lower()] = secs
                    
            conn.close()
        except Exception:
            pass
    return stats

def get_launch_scores():
    today = date.today()
    raw = get_launcher_stats()
    scores = {}
    for name, day_counts in raw.items():
        total_weight = 0.0
        for d_str, count in day_counts.items():
            try:
                age_days = (today - date.fromisoformat(d_str)).days
            except ValueError:
                continue
            age_days = max(0, age_days)
            weight = 0.5 ** (age_days / HALF_LIFE_DAYS)
            total_weight += count * weight
        scores[name] = total_weight * LAUNCH_SECONDS_PER_EVENT
    return scores

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--rank', action='store_true')
    parser.add_argument('--log-launch', action='store_true')
    parser.add_argument('--name', type=str, default='')
    args = parser.parse_args()

    if args.log_launch:
        log_launch(args.name)
    elif args.rank:
        output = {
            "focus": get_usage_stats(),
            "launch": get_launch_scores(),
            "context": get_contextual_scores()
        }
        print(json.dumps(output))
