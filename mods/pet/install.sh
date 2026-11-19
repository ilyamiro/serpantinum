#!/usr/bin/env bash
# Installs (or re-installs) the serpantinum desktop pet. Safe to run any number of times:
# after a shell update or reinstall, just run it again.
#
#   mods/pet/install.sh            install / repair everything
#   mods/pet/install.sh --no-bed   don't place the bed module in the bar
#   mods/pet/install.sh --key J    use SUPER+J / SUPER+SHIFT+J instead of K
#   mods/pet/install.sh --no-keybind
set -euo pipefail

PET_HOME="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
SERP_SRC="${SERPANTINUM_DIR:-$HOME/.local/share/serpantinum/src}"
QS="$SERP_SRC/quickshell"
HYPR_DIR="${HYPR_CONFIG_DIR:-$HOME/.config/hypr}"
SETTINGS="${QS_SETTINGS:-$HOME/.config/serpantinum/settings.json}"
KEY="K"
DO_BIND=1
DO_BED=1
QUIET=0

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --key) KEY="${2:-K}"; shift 2 ;;
        --no-keybind) DO_BIND=0; shift ;;
        --no-bed) DO_BED=0; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

KEY="$(printf '%s' "$KEY" | tr '[:lower:]' '[:upper:]')"

ok()   { [ "$QUIET" = 1 ] || printf '\033[32m✓\033[0m %s\n' "$*"; }
info() { [ "$QUIET" = 1 ] || printf '  %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$QS/Shell.qml" ] || die "serpantinum not found at $QS (set SERPANTINUM_DIR=/path/to/serpantinum/src)"
[ -d "$PET_HOME/src/pet" ] || die "pet sources missing at $PET_HOME/src/pet"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

# 1. files -----------------------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
tmp="$QS/.pet.installing"
old="$QS/.pet.old"
rm -rf "$tmp" "$old"
cp -r "$PET_HOME/src/pet" "$tmp"
printf '.pragma library\n\nvar STAMP = "%s";\nvar KEY = "%s";\n' "$STAMP" "$KEY" > "$tmp/PetVersion.js"
printf 'source=%s\ninstalled=%s\n' "$PET_HOME" "$(date -Iseconds)" > "$tmp/.installed-from"
[ -d "$QS/pet" ] && mv "$QS/pet" "$old"
mv "$tmp" "$QS/pet"
rm -rf "$old"
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/pet"
ok "pet files → $QS/pet"

# 2. Shell.qml hook --------------------------------------------------------
shell_result="$(python3 -I - "$QS/Shell.qml" <<'PY'
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    src = f.read()
block = (
    "    // >>> serpantinum-pet (managed by mods/pet/install.sh, re-run it after shell updates)\n"
    "    Loader {\n"
    "        active: !Config.getSetting(\"general\", {}).performance\n"
    "        source: \"pet/PetRoot.qml\"\n"
    "    }\n"
    "    // <<< serpantinum-pet\n"
)
clean = re.sub(r"\n*[ \t]*// >>> serpantinum-pet.*?// <<< serpantinum-pet[^\n]*\n", "\n", src, flags=re.S)
end = clean.rstrip().rfind("}")
if end < 0 or "ShellRoot" not in clean:
    print("error: could not find ShellRoot in Shell.qml")
    sys.exit(1)
new = clean[:end].rstrip("\n") + "\n\n" + block + clean[end:]
if new == src:
    print("unchanged")
else:
    with open(path, "r+", encoding="utf-8") as f:
        f.seek(0)
        f.write(new)
        f.truncate()
    print("patched")
PY
)" || die "could not patch Shell.qml: $shell_result"
ok "Shell.qml hook ($shell_result)"

# 3. keybinds: SUPER+KEY summon/send home, SUPER+SHIFT+KEY on/off ------------
if [ "$DO_BIND" = 1 ]; then
    bind_result="$(python3 -I - "$HYPR_DIR" "$KEY" <<'PY'
import os, re, sys
hypr, key = sys.argv[1], sys.argv[2]
cands = [os.path.join(hypr, "config", "keybinds.lua"), os.path.join(hypr, "hyprland.lua"),
         os.path.join(hypr, "config", "keybindings.conf"), os.path.join(hypr, "hyprland.conf")]
target = next((p for p in cands if os.path.isfile(p)), None)
if not target:
    print("missing|no Hyprland config found in " + hypr)
    sys.exit(0)
lua = target.endswith(".lua")
with open(target, encoding="utf-8") as f:
    src = f.read()
mark = "--" if lua else "#"
pat = re.escape(mark) + r" >>> serpantinum-pet.*?" + re.escape(mark) + r" <<< serpantinum-pet[^\n]*\n"
clean = re.sub(r"\n*" + pat, "\n", src, flags=re.S)
k = re.escape(key)
if lua:
    plain = re.search(r'(?:(?:mainMod|"SUPER")\s*\.\.\s*"\s*\+\s*|"SUPER\s*\+\s*)' + k + r'"', clean)
    shifted = re.search(r'(?:(?:mainMod|"SUPER")\s*\.\.\s*"\s*\+\s*SHIFT\s*\+\s*|"SUPER\s*\+\s*SHIFT\s*\+\s*)' + k + r'"', clean)
    toggle = 'hl.bind((_G.mainMod or "SUPER") .. " + %s", hl.dsp.exec_cmd("serpantinum ipc call pet toggle"))' % key
    power = 'hl.bind((_G.mainMod or "SUPER") .. " + SHIFT + %s", hl.dsp.exec_cmd("serpantinum ipc call pet power"))' % key
else:
    plain = re.search(r'^\s*bind\w*\s*=\s*(\$mainMod|SUPER)\s*,\s*' + k + r'\s*,', clean, re.M | re.I)
    shifted = re.search(r'^\s*bind\w*\s*=\s*(\$mainMod|SUPER)\s+SHIFT\s*,\s*' + k + r'\s*,', clean, re.M | re.I)
    toggle = "bind = SUPER, %s, exec, serpantinum ipc call pet toggle" % key
    power = "bind = SUPER SHIFT, %s, exec, serpantinum ipc call pet power" % key
lines, skipped = [], []
if plain:
    skipped.append("SUPER+" + key)
else:
    lines.append(toggle)
if shifted:
    skipped.append("SUPER+SHIFT+" + key)
else:
    lines.append(power)
new = clean
if lines:
    block = "%s >>> serpantinum-pet (managed by mods/pet/install.sh)\n%s\n%s <<< serpantinum-pet\n" % (mark, "\n".join(lines), mark)
    new = clean.rstrip("\n") + "\n\n" + block
if new != src:
    with open(target, "r+", encoding="utf-8") as f:
        f.seek(0)
        f.write(new)
        f.truncate()
state = "patched" if new != src else "unchanged"
print("%s|%s|%s" % (state, target, ",".join(skipped)))
PY
)"
    IFS='|' read -r bind_state bind_target bind_skipped <<< "$bind_result"
    case "$bind_state" in
        patched|unchanged)
            ok "keybinds ($bind_state, $bind_target)"
            [ -n "$bind_skipped" ] && warn "already bound elsewhere, skipped: $bind_skipped (use --key)"
            if [ "$bind_state" = patched ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
                has_bind() {
                    hyprctl binds -j 2>/dev/null | python3 -I -c '
import json, sys
key = sys.argv[1]
try:
    binds = json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if any(b.get("key") == key and b.get("modmask") in (64, 65) for b in binds) else 1)
' "$KEY"
                }
                sleep 0.5
                has_bind || { hyprctl reload >/dev/null 2>&1 || true; sleep 0.5; }
                has_bind || warn "Hyprland didn't load the new binds; run: hyprctl reload"
            fi
            ;;
        missing) warn "$bind_target; add binds for: serpantinum ipc call pet toggle / pet power" ;;
        *) warn "keybinds: $bind_result" ;;
    esac
fi

# 4. bar bed ---------------------------------------------------------------
if [ "$DO_BED" = 1 ] && [ -f "$QS/pet/PetBedFace.qml" ]; then
    if [ -f "$SETTINGS" ]; then
        bed_result="$(python3 -I - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
pet = data.get("pet") if isinstance(data.get("pet"), dict) else {}
bar = data.get("bar") if isinstance(data.get("bar"), dict) else {}
mods = bar.get("modules") if isinstance(bar.get("modules"), dict) else None

def has(x):
    if isinstance(x, list):
        return any(has(i) for i in x)
    return x == "pet"

if mods is not None and any(has(v) for v in mods.values()):
    print("present")
elif pet.get("bedPlaced"):
    print("removed-by-user")
elif mods is None:
    print("no-layout")
else:
    center = mods.get("center")
    if not isinstance(center, list):
        center = []
    center.append("pet")
    mods["center"] = center
    pet["bedPlaced"] = True
    data["pet"] = pet
    tmp = path + ".pet-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print("placed")
PY
)" || bed_result="error"
        case "$bed_result" in
            placed) ok "bed added to the bar (center group, move it in Settings → Bar)" ;;
            present) ok "bed already in the bar" ;;
            removed-by-user) info "bed not in the bar (you removed it; add it back in Settings → Bar → modules)" ;;
            no-layout) info "bar layout not customised yet: add the 'Pet bed' module in Settings → Bar" ;;
            *) warn "could not update $SETTINGS" ;;
        esac
    else
        info "settings.json not found yet; start serpantinum once and re-run this to place the bed"
    fi
fi

# 5. reload + verify -------------------------------------------------------
if pgrep -f "quickshell.*$QS/Shell.qml" >/dev/null 2>&1; then
    sleep 0.3
    quickshell -p "$QS/Shell.qml" ipc call main forceReload >/dev/null 2>&1 || touch "$QS/Shell.qml"
    live=0
    for _ in $(seq 1 40); do
        if [ "$(quickshell -p "$QS/Shell.qml" ipc call pet version 2>/dev/null)" = "$STAMP" ]; then
            live=1
            break
        fi
        sleep 0.5
    done
    if [ "$live" = 1 ]; then
        ok "pet is live (serpantinum reloaded)"
    else
        warn "the shell didn't load the new pet. Check: quickshell log -p $QS/Shell.qml -t 60"
    fi
else
    info "serpantinum isn't running; the pet will appear next time it starts"
fi

if [ "$QUIET" = 0 ]; then
    cat <<EOF

  SUPER+$KEY          summon / send home        SUPER+SHIFT+$KEY   turn the pet on / off
  drag & throw     pick it up anywhere       scroll on it    pet it
  click            meow                      double-click    chase your cursor
  right-click      send it home              bed right-click menu (treats, sounds, off)
EOF
fi
