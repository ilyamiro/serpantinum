#!/usr/bin/env python3
import sqlite3
import json
import os
import argparse
import calendar
import shutil
import glob
from datetime import date, timedelta
from collections import defaultdict

def build_query(base_query, date_params, app_filter):
    if app_filter: return base_query + " AND app_class = ?", date_params + (app_filter,)
    return base_query, date_params

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("date", nargs="?", default=date.today().isoformat())
    parser.add_argument("--app", type=str, default=None)
    parser.add_argument("--db-dir", type=str, default=None)
    args = parser.parse_args()

    target_date_str = args.date
    app_filter = args.app
    
    db_dir = args.db_dir if args.db_dir else os.environ.get("QS_STATE_FOCUSTIME", os.path.expanduser("~/.local/state/quickshell/focustime"))
    db_path = os.path.join(db_dir, "focustime.db")

    old_db_dir = os.path.expanduser("~/.local/share/focustime")
    old_db_base = os.path.join(old_db_dir, "focustime.db")
    
    if not os.path.exists(db_path) and os.path.exists(old_db_base):
        os.makedirs(db_dir, exist_ok=True)
        try:
            for old_file in glob.glob(old_db_base + "*"):
                shutil.move(old_file, db_dir)
        except Exception:
            pass

    try:
        target_date = date.fromisoformat(target_date_str)
    except ValueError:
        target_date = date.today()

    if not os.path.exists(db_path):
        print(json.dumps({
            "total": 0, "average": 0, "week_range": "", "yesterday": 0, "current": "History", 
            "apps": [], "week_apps": [], "week": [], "month": [], "hourly": [0]*48, "week_heatmap": [[0]*24 for _ in range(7)], "peak_usage_str": "N/A", "all_known_apps": []
        }))
        return

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    yesterday = target_date - timedelta(days=1)
    q, p = build_query('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (yesterday.isoformat(),), app_filter)
    c.execute(q, p)
    yesterday_seconds = c.fetchone()[0] or 0

    monday = target_date - timedelta(days=target_date.weekday())
    sunday = monday + timedelta(days=6)
    week_range_str = f"{monday.strftime('%b')} {monday.day} - {sunday.strftime('%b')} {sunday.day}"

    q, p = build_query('''SELECT COUNT(DISTINCT log_date), SUM(seconds) FROM focus_log 
                          WHERE log_date >= ? AND log_date <= ? AND seconds > 0''', (monday.isoformat(), sunday.isoformat()), app_filter)
    c.execute(q, p)
    row = c.fetchone()
    days_count = row[0] or 0
    total_week = row[1] or 0
    average_seconds = total_week // days_count if days_count > 0 else 0

    q, p = build_query('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (target_date.isoformat(),), app_filter)
    c.execute(q, p)
    total_seconds = c.fetchone()[0] or 0

    q, p = build_query('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs 
                          FROM focus_log WHERE log_date = ?''', (target_date.isoformat(),), app_filter)
    c.execute(q + " GROUP BY app_class ORDER BY secs DESC", p)
    
    all_apps = []
    for row in c.fetchall():
        app_class, app_title, secs = row
        all_apps.append({
            "class": app_class, "name": app_title,
            "seconds": secs, "percent": round((secs / total_seconds) * 100, 1) if total_seconds > 0 else 0
        })

    q, p = build_query('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs 
                          FROM focus_log WHERE log_date >= ? AND log_date <= ?''', (monday.isoformat(), sunday.isoformat()), app_filter)
    c.execute(q + " GROUP BY app_class ORDER BY secs DESC LIMIT 50", p)
    week_apps_rows = c.fetchall()
    week_apps_total = sum([r[2] for r in week_apps_rows])
    week_apps = []
    for r in week_apps_rows:
        cls, title, secs = r
        week_apps.append({
            "class": cls, "name": title,
            "seconds": secs, "percent": round((secs / week_apps_total) * 100, 1) if week_apps_total > 0 else 0
        })

    q, p = build_query('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ?', 
                       (monday.isoformat(), sunday.isoformat()), app_filter)
    c.execute(q + " GROUP BY log_date", p)
    week_map = {r[0]: r[1] for r in c.fetchall()}
    
    week_data = []
    days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i in range(7):
        d_str = (monday + timedelta(days=i)).isoformat()
        week_data.append({"date": d_str, "day": days_str[i], "total": week_map.get(d_str, 0), "is_target": d_str == target_date_str})

    first_day = target_date.replace(day=1)
    _, num_days = calendar.monthrange(target_date.year, target_date.month)
    last_day = target_date.replace(day=num_days)

    q, p = build_query('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ?', 
                       (first_day.isoformat(), last_day.isoformat()), app_filter)
    c.execute(q + " GROUP BY log_date", p)
    month_map = {r[0]: r[1] for r in c.fetchall()}
    
    month_data = [{"date": "", "total": -1, "is_target": False} for _ in range(first_day.weekday())]
    for i in range(1, num_days + 1):
        d_str = target_date.replace(day=i).isoformat()
        month_data.append({"date": d_str, "total": month_map.get(d_str, 0), "is_target": d_str == target_date_str})

    hourly_data = [0] * 48
    try:
        q, p = build_query('SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ?', (target_date.isoformat(),), app_filter)
        c.execute(q + " GROUP BY hour", p)
        for hr, secs in c.fetchall():
            if 0 <= hr <= 23: hourly_data[hr * 2] += secs
            
        q, p = build_query('SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ?', (target_date.isoformat(),), app_filter)
        c.execute(q + " GROUP BY interval_idx", p)
        for idx, secs in c.fetchall():
            if 0 <= idx < 96: hourly_data[idx // 2] += secs
    except sqlite3.OperationalError:
        pass

    week_heatmap = [[0]*24 for _ in range(7)]
    try:
        q, p = build_query('''SELECT log_date, hour, SUM(seconds) FROM focus_hourly 
                              WHERE log_date >= ? AND log_date <= ?''', (monday.isoformat(), sunday.isoformat()), app_filter)
        c.execute(q + " GROUP BY log_date, hour", p)
        for ldate, hr, secs in c.fetchall():
            day_idx = date.fromisoformat(ldate).weekday()
            if 0 <= hr <= 23: week_heatmap[day_idx][hr] += secs
    except sqlite3.OperationalError:
        pass

    minute_data = [0] * 1440
    try:
        q, p = build_query('''SELECT minute_idx, SUM(seconds) FROM focus_minutes 
                              WHERE log_date >= ? AND log_date <= ?''', (monday.isoformat(), sunday.isoformat()), app_filter)
        c.execute(q + " GROUP BY minute_idx", p)
        for idx, secs in c.fetchall():
            if 0 <= idx < 1440: minute_data[idx] += secs
    except sqlite3.OperationalError:
        pass

    peak_str = "N/A"
    max_sum = 0
    best_window = None
    w_sum = sum(minute_data[:60])
    for i in range(1440 - 60):
        if i: w_sum += minute_data[i + 59] - minute_data[i - 1]
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
        c.execute('SELECT app_class, MAX(COALESCE(app_title, app_class)) FROM focus_log GROUP BY app_class')
        all_known_apps = [{"class": row[0], "name": row[1]} for row in c.fetchall()]
    except sqlite3.OperationalError:
        all_known_apps = []

    result = {
        "selected_date": target_date.isoformat(), "total": total_seconds, "average": average_seconds,
        "week_range": week_range_str, "yesterday": yesterday_seconds, "current": app_filter if app_filter else "History",
        "apps": all_apps, "week_apps": week_apps, "week": week_data, "month": month_data,
        "hourly": hourly_data, "week_heatmap": week_heatmap, "peak_usage_str": peak_str, "all_known_apps": all_known_apps
    }
    
    print(json.dumps(result))

if __name__ == "__main__":
    main()
