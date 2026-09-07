#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SERPANTINUM_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

STATE_DIR="${QS_STATE_DIR:-$HOME/.local/state/serpantinum}"
FLAG_FILE="$STATE_DIR/first_launch.done"

check_status() {
    mkdir -p "$STATE_DIR"
    if [ -f "$FLAG_FILE" ]; then
        echo "SKIP"
        exit 0
    fi

    touch "$FLAG_FILE"

    WP_DIR=""
    if type get_setting >/dev/null 2>&1; then
        WP_DIR="$(get_setting "wallpaperDir" "")"
        [ -z "$WP_DIR" ] && WP_DIR="$(get_setting "wallpaper_dir" "")"
    fi

    RANDOM_WP=""
    if [ -n "$WP_DIR" ] && [ -d "$WP_DIR" ]; then
        RANDOM_WP="$(find "$WP_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) 2>/dev/null | shuf -n 1)"
    fi

    START_QML=""
    if [ -f "$SERPANTINUM_DIR/quickshell/serp/Start.qml" ]; then
        START_QML="$SERPANTINUM_DIR/quickshell/serp/Start.qml"
    elif [ -f "$SERPANTINUM_DIR/quickshell/Start.qml" ]; then
        START_QML="$SERPANTINUM_DIR/quickshell/Start.qml"
    else
        START_QML="$(find "$SERPANTINUM_DIR/quickshell" -type f -name "Start.qml" 2>/dev/null | head -n 1)"
    fi

    echo "FIRST|$RANDOM_WP|$START_QML"
}

open_guide() {
    local script_path="$SERPANTINUM_DIR/scripts/qs_manager.sh"
    if [ -f "$script_path" ]; then
        bash "$script_path" open guide
    fi
}

reset_state() {
    rm -f "$FLAG_FILE"
}

case "$1" in
    --check)
        check_status
        ;;
    --open-guide)
        open_guide
        ;;
    --reset)
        reset_state
        ;;
    *)
        exit 1
        ;;
esac
