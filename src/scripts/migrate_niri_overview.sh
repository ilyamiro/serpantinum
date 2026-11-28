#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"

MARKER="$QS_STATE_DIR/niri-overview-migrated"
[ -f "$MARKER" ] && exit 0
command -v niri >/dev/null 2>&1 || exit 0

NIRI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
CONFIG="$NIRI_DIR/config.kdl"
[ -f "$CONFIG" ] || exit 0

finish() {
    : > "$MARKER"
    exit 0
}

grep -rqs --include='*.kdl' 'wallpaper-overview' "$NIRI_DIR" && finish
[ -L "$CONFIG" ] && finish
[ -w "$CONFIG" ] && [ -w "$NIRI_DIR" ] || finish

TMP="$NIRI_DIR/.config.kdl.serpantinum-migrate"
cp -p "$CONFIG" "$TMP" || finish
cat >> "$TMP" <<'EOF'

layer-rule {
    match namespace="^wallpaper-overview$"
    place-within-backdrop true
}
EOF

if niri validate -c "$TMP" >/dev/null 2>&1; then
    mv -f "$TMP" "$CONFIG"
else
    rm -f "$TMP"
fi
finish
