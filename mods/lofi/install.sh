#!/usr/bin/env bash
# Installs (or re-installs) the SUPER+- lofi toggle. Safe to re-run: after an update or reinstall,
# just run it again.
#
#   mods/lofi/install.sh
#   mods/lofi/install.sh --uninstall
set -euo pipefail

HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
BIN="$HOME/.local/bin"
KEYBINDS="${HYPR_CONFIG_DIR:-$HOME/.config/hypr}/config/keybinds.lua"
BEGIN="-- >>> lofi (managed by mods/lofi/install.sh)"
END="-- <<< lofi"

command -v mpv >/dev/null || { echo "mpv is required (sudo pacman -S mpv)" >&2; exit 1; }
[ -f "$KEYBINDS" ] || { echo "no $KEYBINDS" >&2; exit 1; }

# drop any previous managed block
python3 -I - "$KEYBINDS" "$BEGIN" "$END" <<'PY'
import re, sys
path, begin, end = sys.argv[1:4]
src = open(path, encoding="utf-8").read()
new = re.sub(r"\n*" + re.escape(begin) + r".*?" + re.escape(end) + r"\n", "\n", src, flags=re.S)
if new != src:
    open(path, "w", encoding="utf-8").write(new)
PY

if [ "${1:-}" = "--uninstall" ]; then
    rm -f "$BIN/lofi-toggle"
    pkill -f 'mpv.*lofi radio' 2>/dev/null || true
    echo "uninstalled"
else
    mkdir -p "$BIN"
    install -m755 "$HERE/lofi-toggle" "$BIN/lofi-toggle"
    printf '\n%s\nhl.bind((_G.mainMod or "SUPER") .. " + minus", hl.dsp.exec_cmd("%s/lofi-toggle"))\n%s\n' \
        "$BEGIN" "$BIN" "$END" >> "$KEYBINDS"
    echo "✓ lofi installed: SUPER + - toggles it"
fi
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && hyprctl reload >/dev/null 2>&1 || true
