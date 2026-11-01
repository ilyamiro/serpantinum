#!/usr/bin/env python3
"""Prints today's focused seconds in "coding" apps, read from serpantinum's wellbeing database.

usage: pet_stats.py <focustime.db> '<json list of app-class patterns>'
"""
import datetime
import fnmatch
import json
import sqlite3
import sys


def main():
    db = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        patterns = [str(p).lower() for p in json.loads(sys.argv[2])] if len(sys.argv) > 2 else []
    except ValueError:
        patterns = []
    today = datetime.date.today().isoformat()
    total = 0
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)
        try:
            rows = con.execute(
                "SELECT app_class, SUM(seconds) FROM focus_log WHERE log_date = ? GROUP BY app_class",
                (today,),
            ).fetchall()
        finally:
            con.close()
        for cls, secs in rows:
            name = (cls or "").lower()
            if any(fnmatch.fnmatchcase(name, p) for p in patterns):
                total += int(secs or 0)
    except Exception as exc:
        print(json.dumps({"date": today, "coding_seconds": 0, "error": str(exc)}))
        return
    print(json.dumps({"date": today, "coding_seconds": total}))


if __name__ == "__main__":
    main()
