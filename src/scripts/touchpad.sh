#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/config/settings.lua"
ACTION="${1:-}"
VAL="${2:-}"

update_conf() {
    local key="$1"
    local val="$2"
    [[ -f "$CONF" ]] || return 0
    case "$key" in
        sensitivity)
            if grep -q "sensitivity *=" "$CONF" 2>/dev/null; then
                sed -i "s/\(sensitivity *= *\)[-0-9.]*/\1$val/" "$CONF"
            else
                sed -i "/accel_profile *=/a \    sensitivity = $val," "$CONF"
            fi
            ;;
        natural_scroll)
            if grep -q "natural_scroll *=" "$CONF" 2>/dev/null; then
                sed -i "s/\(natural_scroll *= *\)[a-z]*/\1$val/" "$CONF"
            fi
            ;;
        disable_while_typing)
            if grep -q "disable_while_typing *=" "$CONF" 2>/dev/null; then
                sed -i "s/\(disable_while_typing *= *\)[a-z]*/\1$val/" "$CONF"
            fi
            ;;
        accel_profile)
            if grep -q "accel_profile *=" "$CONF" 2>/dev/null; then
                sed -i "s/\(accel_profile *= *\)\"[^\"]*\"/\1\"$val\"/" "$CONF"
            fi
            ;;
    esac
}

case "$ACTION" in
    set-speed|sensitivity)
        [[ -n "$VAL" ]] || exit 1
        update_conf "sensitivity" "$VAL"
        hyprctl eval "hl.config({ input = { sensitivity = $VAL } })" 2>/dev/null || true
        hyprctl reload 2>/dev/null || true
        ;;
    live-speed)
        [[ -n "$VAL" ]] || exit 1
        hyprctl eval "hl.config({ input = { sensitivity = $VAL } })" 2>/dev/null || true
        ;;
    set-natural-scroll)
        [[ -n "$VAL" ]] || exit 1
        update_conf "natural_scroll" "$VAL"
        hyprctl eval "hl.config({ input = { touchpad = { natural_scroll = $VAL } } })" 2>/dev/null || true
        hyprctl reload 2>/dev/null || true
        ;;
    set-disable-while-typing)
        [[ -n "$VAL" ]] || exit 1
        update_conf "disable_while_typing" "$VAL"
        hyprctl eval "hl.config({ input = { touchpad = { disable_while_typing = $VAL } } })" 2>/dev/null || true
        hyprctl reload 2>/dev/null || true
        ;;
    set-accel-profile)
        [[ -n "$VAL" ]] || exit 1
        update_conf "accel_profile" "$VAL"
        hyprctl eval "hl.config({ input = { accel_profile = \"$VAL\" } })" 2>/dev/null || true
        hyprctl reload 2>/dev/null || true
        ;;
    reset)
        update_conf "sensitivity" "0.0"
        update_conf "natural_scroll" "true"
        update_conf "disable_while_typing" "false"
        update_conf "accel_profile" "flat"
        hyprctl eval "hl.config({ input = { sensitivity = 0.0, accel_profile = \"flat\", touchpad = { natural_scroll = true, disable_while_typing = false } } })" 2>/dev/null || true
        hyprctl reload 2>/dev/null || true
        ;;
    get)
        hyprctl getoption input:sensitivity -j 2>/dev/null || echo '{"float": 0.0}'
        ;;
    *)
        echo "Usage: $0 {set-speed <val>|live-speed <val>|set-natural-scroll <bool>|set-disable-while-typing <bool>|set-accel-profile <profile>|reset|get}" >&2
        exit 1
        ;;
esac
