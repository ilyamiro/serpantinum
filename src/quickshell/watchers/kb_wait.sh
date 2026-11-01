#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"

COMPOSITOR="$1"
PIPE="$QS_RUN_DIR/qs_kb_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null
trap 'rm -f "$PIPE"; kill $(jobs -p) 2>/dev/null; exit 0' EXIT INT TERM

case "$COMPOSITOR" in
    niri)
        niri msg -j event-stream 2>/dev/null | jq --unbuffered -c 'select(has("KeyboardLayoutSwitched"))' > "$PIPE" &
        ;;
    mango)
        mmsg watch keyboardlayout 2>/dev/null | { read -r _; cat; } > "$PIPE" &
        ;;
    sway)
        swaymsg -t subscribe -m '["input"]' 2>/dev/null | jq --unbuffered -c 'select(.change == "xkb_layout" or .change == "xkb_keymap")' > "$PIPE" &
        ;;
    *)
        if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
            LC_ALL=C socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | grep --line-buffered "activelayout>>" > "$PIPE" &
        else
            sleep 10 > "$PIPE" &
        fi
        ;;
esac

read -r _ < "$PIPE"
sleep 0.05
