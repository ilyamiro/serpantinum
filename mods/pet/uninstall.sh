#!/usr/bin/env bash
# Removes the desktop pet from serpantinum (files, Shell.qml hook, keybind, bar bed).
# Your pet's state (treats, stats) is kept unless you pass --purge.
set -euo pipefail

SERP_SRC="${SERPANTINUM_DIR:-$HOME/.local/share/serpantinum/src}"
QS="$SERP_SRC/quickshell"
HYPR_DIR="${HYPR_CONFIG_DIR:-$HOME/.config/hypr}"
SETTINGS="${QS_SETTINGS:-$HOME/.config/serpantinum/settings.json}"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

python3 -I - "$QS/Shell.qml" "$HYPR_DIR" <<'PY'
import os, re, sys
shell, hypr = sys.argv[1], sys.argv[2]
files = [shell] + [os.path.join(hypr, p) for p in ("config/keybinds.lua", "hyprland.lua", "config/keybindings.conf", "hyprland.conf")]
for path in files:
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as f:
        src = f.read()
    new = re.sub(r"\n*[ \t]*(//|--|#) >>> serpantinum-pet.*?(//|--|#) <<< serpantinum-pet[^\n]*\n", "\n", src, flags=re.S)
    if new != src:
        with open(path, "r+", encoding="utf-8") as f:
            f.seek(0)
            f.write(new)
            f.truncate()
        print("cleaned " + path)
PY

if [ -f "$SETTINGS" ]; then
    python3 -I - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
mods = (data.get("bar") or {}).get("modules")
changed = False
def strip(x):
    global changed
    if isinstance(x, list):
        out = []
        for i in x:
            if i == "pet":
                changed = True
                continue
            out.append(strip(i))
        return [i for i in out if i != []]
    return x
if isinstance(mods, dict):
    for k in list(mods.keys()):
        mods[k] = strip(mods[k])
if isinstance(data.get("pet"), dict) and data["pet"].pop("bedPlaced", None) is not None:
    changed = True
if changed:
    tmp = path + ".pet-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print("removed the bed from the bar layout")
PY
fi

rm -rf "$QS/pet"
echo "removed $QS/pet"

if [ "$PURGE" = 1 ]; then
    rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/pet"
    echo "purged pet state"
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi
echo "done (sources kept in $(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd))"
