#!/usr/bin/env python3
"""End-to-end run of display_txn.py against a TEST compositor. Run it ONLY through
tests/display/sandbox.sh (it refuses otherwise):

    tests/display/sandbox.sh sway "$SWAYSOCK" wayland-2 -- python3 tests/display/e2e_run.py

Scenarios: move (confirm), scale (manual revert), unconfirmed timeout, rescue from a broken
layout, power off/on (only with two enabled outputs), persisted file. Prints PASS/FAIL lines;
exit 1 on any FAIL."""
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


def state():
    return txn("state")["monitors"]


def plan(**changes):
    mons = []
    for m in state():
        p = {k: m[k] for k in ("name", "description", "enabled", "width", "height", "refresh", "x", "y", "scale", "transform")}
        p.update(changes.get(m["name"], {}))
        mons.append(p)
    return json.dumps({"monitors": mons})


def check(name, cond, detail=""):
    print("%s %s %s" % ("PASS" if cond else "FAIL", name, detail))
    if not cond:
        FAILS.append(name)


def mon(name):
    return next(m for m in state() if m["name"] == name)


def same(a, b):
    return all(a[k] == b[k] for k in ("x", "y", "scale", "transform", "width", "height", "enabled"))


enabled = [m for m in state() if m["enabled"]]
last = enabled[-1]["name"]
base = mon(last)

# 1. move + confirm
r = txn("apply", plan(**{last: {"y": base["y"] + 60}}), "--timeout", "8")
check("move applies", r.get("ok") is True, str(r)[:100])
check("move landed", mon(last)["y"] == base["y"] + 60)
check("move confirmed", txn("confirm").get("outcome") == "confirmed")

# 2. scale + manual revert
cur = mon(last)
scales = txn("state")["monitors"]
scale = next((s for s in next(m for m in scales if m["name"] == last)["validScales"] if s > cur["scale"]), cur["scale"] + 0.5)
r = txn("apply", plan(**{last: {"scale": scale}}), "--timeout", "8")
check("scale applies", r.get("ok") is True, str(r)[:100])
check("scale landed", abs(mon(last)["scale"] - scale) < 1e-3)
txn("revert")
time.sleep(3)
check("manual revert restores", same(mon(last), cur), str(mon(last)))

# 3. unconfirmed -> timeout restores
r = txn("apply", plan(**{last: {"x": cur["x"] + 40}}), "--timeout", "5")
check("timeout txn applies", r.get("ok") is True)
time.sleep(9)
check("timeout restores", same(mon(last), cur), str(mon(last)))

# 4. rescue from a broken layout (works through the engine; changes the layout by hand first)
txn("apply", plan(**{last: {"x": cur["x"] + 25}}), "--timeout", "5")
txn("confirm")
last_good_before = mon(last)["x"]
res = txn("rescue")
check("rescue ok", res.get("ok") is True, str(res)[:100])
check("rescue lands on last-good", mon(last)["x"] == last_good_before)

# 5. power off/on, only with two enabled outputs
if len(enabled) >= 2:
    other = enabled[0]["name"]
    keep = mon(other)
    r = txn("apply", plan(**{other: {"enabled": False}}), "--timeout", "8")
    check("power off applies", r.get("ok") is True, str(r)[:100])
    check("power off landed", mon(other)["enabled"] is False)
    txn("confirm")
    r = txn("apply", plan(**{other: {"enabled": True, "x": keep["x"], "y": keep["y"]}}), "--timeout", "8")
    check("power on applies", r.get("ok") is True, str(r)[:100])
    check("power on landed", mon(other)["enabled"] is True)
    txn("confirm")
else:
    print("SKIP power off/on: needs two enabled outputs")

# 6. the last enabled output can't be turned off
only = txn("validate", plan(**{m["name"]: {"enabled": False} for m in enabled}))
check("turning every output off is refused", only.get("ok") is False and "no_enabled_monitor" in only.get("errors", []))

# 7. persisted file
info = txn("state")["persistence"]
check("persisted file exists", info.get("exists") is True, info.get("path", ""))

print("RESULT:", "FAIL (%s)" % ", ".join(FAILS) if FAILS else "all passed")
sys.exit(1 if FAILS else 0)
