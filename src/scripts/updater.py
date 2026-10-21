import json
import os
import re
import sys
import time
import urllib.request

REPO = "timl000/serpantinum"
BRANCH = "minecraft"
DEFAULT_VER = "2.0.0"

state_dir = os.path.expanduser("~/.local/state/serpantinum")
if "--state-dir" in sys.argv:
    try:
        idx = sys.argv.index("--state-dir")
        if idx + 1 < len(sys.argv):
            state_dir = sys.argv[idx + 1]
    except Exception:
        pass

state_file = os.path.join(state_dir, "version")
last_check_file = os.path.join(state_dir, "last_check")
notified_file = os.path.join(state_dir, "last_notified")

if "--save-notified" in sys.argv:
    try:
        idx = sys.argv.index("--save-notified")
        if idx + 1 < len(sys.argv):
            ver_to_save = sys.argv[idx + 1]
            os.makedirs(state_dir, exist_ok=True)
            with open(notified_file, "w") as f:
                f.write(ver_to_save)
    except Exception:
        pass
    sys.exit(0)

if "--delay" in sys.argv:
    if os.path.isfile(last_check_file):
        try:
            with open(last_check_file, "r") as f:
                last_ts = float(f.read().strip())
            elapsed = time.time() - last_ts
            remaining = int(max(0, 3600 - elapsed) * 1000)
            print(remaining)
            sys.exit(0)
        except Exception:
            pass
    print(0)
    sys.exit(0)

def get_local_ver():
    if os.path.isfile(state_file):
        try:
            with open(state_file, "r") as f:
                for line in f:
                    if line.startswith("SERPANTINUM_VERSION="):
                        v = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if v:
                            return v
        except Exception:
            pass
    return DEFAULT_VER

def get_last_notified():
    if os.path.isfile(notified_file):
        try:
            with open(notified_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return ""

def parse_v(v):
    nums = re.findall(r"\d+", v)
    return [int(x) for x in nums] if nums else [0]

try:
    os.makedirs(state_dir, exist_ok=True)
    with open(last_check_file, "w") as f:
        f.write(str(time.time()))
except Exception:
    pass

local_ver = get_local_ver()
remote_ver = ""

try:
    req = urllib.request.Request(
        f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/version.txt",
        headers={"User-Agent": "updater-script"}
    )
    res = urllib.request.urlopen(req, timeout=5)
    remote_ver = res.read().decode("utf-8").strip()
except Exception:
    remote_ver = local_ver

has_update = parse_v(remote_ver) > parse_v(local_ver)

print(json.dumps({
    "local": local_ver,
    "remote": remote_ver,
    "has_update": has_update,
    "last_notified": get_last_notified()
}))
