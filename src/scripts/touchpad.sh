#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/config/settings.lua"
ACTION="${1:-}"
VAL="${2:-}"

save_and_reload() {
    local val="$1"
    if grep -q "sensitivity *=" "$CONF" 2>/dev/null; then
        sed -i "s/\(sensitivity *= *\)[-0-9.]*/\1$val/" "$CONF"
    elif [[ -f "$CONF" ]]; then
        sed -i "/accel_profile *=/a \    sensitivity = $val," "$CONF"
    fi
    hyprctl eval "hl.config({ input = { sensitivity = $val } })" 2>/dev/null || true
    hyprctl reload 2>/dev/null || true
}

case "$ACTION" in
    set-speed|sensitivity)
        [[ -n "$VAL" ]] && save_and_reload "$VAL"
        ;;
    live-speed)
        [[ -n "$VAL" ]] && hyprctl eval "hl.config({ input = { sensitivity = $VAL } })" 2>/dev/null || true
        ;;
    reload)
        hyprctl reload 2>/dev/null || true
        ;;
    get)
        hyprctl getoption input:sensitivity -j 2>/dev/null || echo '{"float": 0.5}'
        ;;
    *)
        echo "Usage: $0 {set-speed <val>|live-speed <val>|reload|get}" >&2
        exit 1
        ;;
esac
