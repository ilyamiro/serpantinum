#!/usr/bin/env python3
"""Mango only: what a CONFIRMED change does once Mango reloads its own config. Writing
monitors.conf makes Mango reload and re-apply every monitor_rule (a user rule that wins, or an
output we turned off and therefore did not write), so the engine puts the confirmed layout back
(MangoBackend.after_persist). Run through tests/display/mango_reload_e2e.sh, which starts a
headless mango with a config in a throw-away HOME and calls the sandbox."""
import json
import os
import subprocess
import sys
import time

if os.environ.get("SANDBOX") != "1" or os.environ.get("SERPANTINUM_DISPLAY_VIRTUAL_ONLY") != "1":
    sys.exit("refusing to run outside tests/display/sandbox.sh")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TXN = os.path.join(ROOT, "src", "quickshell", "guide", "display", "display_txn.py")
FAILS = []


def txn(*args):
    p = subprocess.run([sys.executable, TXN, *args], capture_output=True, text=True, timeout=60)
    try:
        return json.loads(p.stdout)
    except ValueError:
        return {"ok": False, "raw": p.stdout, "err": p.stderr}


def mons():
    return {m["name"]: m for m in txn("state")["monitors"]}


def plan(**changes):
    out = []
    for name, m in mons().items():
        p = {k: m[k] for k in ("name", "description", "enabled", "width", "height", "refresh", "x", "y", "scale", "transform")}
        p.update(changes.get(name, {}))
        out.append(p)
    return json.dumps({"monitors": out})


def check(name, cond, detail=""):
    print("%s %s %s" % ("PASS" if cond else "FAIL", name, detail))
    if not cond:
        FAILS.append(name)


ms = mons()
assert len(ms) >= 2, "needs two outputs"
a, b = sorted(ms)[:2]
home_conf = os.path.join(os.path.expanduser("~"), ".config", "mango", "config.conf")
check("mango reads the config of the throw-away HOME", os.path.exists(home_conf), home_conf)
print("config.conf:\n" + open(home_conf).read())
start_y = ms[b]["y"]

# 1. move, confirm, wait out the reload: the confirmed layout must still be there
r = txn("apply", plan(**{b: {"y": start_y + 100}}), "--timeout", "8")
check("move applies", r.get("ok") is True, str(r)[:100])
check("move confirmed", txn("confirm").get("outcome") == "confirmed")
time.sleep(1.5)
check("move survives mango's reload", mons()[b]["y"] == start_y + 100, "y=%s" % mons()[b]["y"])
rules = open(os.path.join(os.path.dirname(home_conf), "serpantinum", "monitors.conf")).read()
check("monitors.conf was written", "y:%d" % (start_y + 100) in rules)

# 2. power off, confirm: mango's reload (which never saw the disabled output) must not bring it back
r = txn("apply", plan(**{b: {"enabled": False}}), "--timeout", "8")
check("power off applies", r.get("ok") is True, str(r)[:100])
check("power off confirmed", txn("confirm").get("outcome") == "confirmed")
time.sleep(1.5)
check("power off survives mango's reload", mons()[b]["enabled"] is False)

# 3. power on again at its old place
r = txn("apply", plan(**{b: {"enabled": True, "x": ms[b]["x"], "y": start_y}}), "--timeout", "8")
check("power on applies", r.get("ok") is True, str(r)[:100])
check("power on confirmed", txn("confirm").get("outcome") == "confirmed")
time.sleep(1.5)
now = mons()[b]
check("power on survives mango's reload", now["enabled"] and (now["x"], now["y"]) == (ms[b]["x"], start_y), str(now)[:120])

print("RESULT: %s" % ("FAIL (%s)" % ", ".join(FAILS) if FAILS else "all passed"))
sys.exit(1 if FAILS else 0)
