#!/usr/bin/env bash
#
# Game mode: disable costly eye-candy (animations, blur, shadows) on Hyprland
# for maximum performance while gaming. Previous values are saved and
# restored when game mode is turned off.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/i18n.sh"

STATE_FILE="$QS_RUN_DIR/gamemode.state"

# option -> performance value applied while game mode is on
GAME_OPTS=(
    "animations:enabled=false"
    "decoration:blur:enabled=false"
    "decoration:shadow:enabled=false"
)

GAME_PARSER=""

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Serpantinum" "$1" "$2" 2>/dev/null || true
}

need_hyprland() {
    if ! command -v hyprctl >/dev/null 2>&1 || [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        echo "$(t "gamemode.error_hyprland_only")" >&2
        exit 1
    fi
}

# Hyprland >= 0.56 uses the Lua config parser where `hyprctl keyword`
# no longer works and `hyprctl eval 'hl.config({...})'` is required.
use_eval() {
    if [[ "$GAME_PARSER" == "eval" ]]; then return 0; fi
    if [[ "$GAME_PARSER" == "keyword" ]]; then return 1; fi
    if hyprctl eval 'hl.config({})' >/dev/null 2>&1; then
        GAME_PARSER="eval"
        return 0
    fi
    GAME_PARSER="keyword"
    return 1
}

get_opt() {
    hyprctl getoption "$1" 2>/dev/null | awk '/^(int|float|str|bool|vec):/ {print $2; exit}'
}

# "a:b:c" + value -> Lua fragment: a = { b = { c = value } }
lua_set() {
    local name="$1" value="$2"
    local IFS=':'
    local -a parts=($name)
    local out="$value" i
    for (( i=${#parts[@]}-1; i>=0; i-- )); do
        if (( i == ${#parts[@]}-1 )); then
            out="${parts[$i]} = $out"
        else
            out="${parts[$i]} = { $out }"
        fi
    done
    printf '%s' "$out"
}

apply_opt() {
    local name="$1" value="$2"
    if use_eval; then
        hyprctl eval "hl.config({ $(lua_set "$name" "$value") })" >/dev/null 2>&1 || true
    else
        hyprctl keyword "$name" "$value" >/dev/null 2>&1 || true
    fi
}

is_active() { [[ -f "$STATE_FILE" ]]; }

game_on() {
    need_hyprland
    if is_active; then echo "$(t "gamemode.already_on")"; return 0; fi

    mkdir -p "$QS_RUN_DIR" 2>/dev/null || true
    : > "$STATE_FILE"
    local entry name value
    for entry in "${GAME_OPTS[@]}"; do
        name="${entry%%=*}"
        value="$(get_opt "$name")"
        printf '%s=%s\n' "$name" "$value" >> "$STATE_FILE"
        apply_opt "$name" "${entry#*=}"
    done
    notify "$(t "gamemode.on_title")" "$(t "gamemode.on_body")"
    echo "$(t "gamemode.on_title")"
}

game_off() {
    need_hyprland
    if ! is_active; then echo "$(t "gamemode.already_off")"; return 0; fi

    local line name value
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name="${line%%=*}"
        value="${line#*=}"
        if [[ -n "$name" && -n "$value" ]]; then
            apply_opt "$name" "$value"
        fi
    done < "$STATE_FILE"
    rm -f "$STATE_FILE"
    notify "$(t "gamemode.off_title")" "$(t "gamemode.off_body")"
    echo "$(t "gamemode.off_title")"
}

case "${1:-toggle}" in
    on) game_on ;;
    off) game_off ;;
    status)
        if is_active; then echo "$(t "gamemode.status_on")"; else echo "$(t "gamemode.status_off")"; fi
        ;;
    toggle)
        if is_active; then game_off; else game_on; fi
        ;;
    -h|--help|help) echo "$(t "gamemode.help")" ;;
    *)
        echo "$(t "gamemode.error_unknown_arg" "ARG=$1")" >&2
        exit 1
        ;;
esac
