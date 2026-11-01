#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"

MARKER="$QS_STATE_DIR/easyeffects-migrated"
[ -f "$MARKER" ] && exit 0
command -v serpantinum-audio >/dev/null 2>&1 || exit 0

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PRESET_DIR="$DATA_HOME/easyeffects/output"
SHIPPED_AUTOSTART_FILES=(
    hypr/config/autostart.lua
    niri/config/autostart.kdl
    sway/configDir/autostart
    mango/config/autostart.conf
)
AUTOSTART_LINE='^[[:space:]]*(exec systemctl --user enable --now easyeffects|exec_once=systemctl --user enable --now easyeffects|hl\.exec_cmd\("systemctl --user enable --now easyeffects"\)|spawn-at-startup "systemctl" "--user" "enable" "--now" "easyeffects")[[:space:]]*$'
OWN_INSTANCE='(^|/)easyeffects .*-l live_eq( |$)'
ANY_INSTANCE='(^|/)easyeffects( |$)'
SELF_UID="$(id -u)"

stop_own_instance() {
    local pids pid alive waited=0
    pids="$(pgrep -u "$SELF_UID" -f "$OWN_INSTANCE" 2>/dev/null)" || return 1
    kill -TERM $pids 2>/dev/null
    while [ "$waited" -lt 20 ]; do
        alive=false
        for pid in $pids; do
            kill -0 "$pid" 2>/dev/null && alive=true
        done
        [ "$alive" = true ] || return 0
        sleep 0.1
        waited=$((waited + 1))
    done
    kill -KILL $pids 2>/dev/null
    return 0
}

stop_ee_eq_unit() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl --user is-active --quiet ee-eq.service 2>/dev/null || return 1
    systemctl --user stop ee-eq.service >/dev/null 2>&1
    return 0
}

remove_generated_preset() {
    local found=1
    if [ -f "$PRESET_DIR/live_eq.json" ]; then
        rm -f "$PRESET_DIR/live_eq.json"
        found=0
    fi
    rmdir "$PRESET_DIR" "$DATA_HOME/easyeffects" 2>/dev/null
    return "$found"
}

clean_shipped_autostart() {
    local real_config rel file cleaned=1
    real_config="$(realpath "$CONFIG_HOME" 2>/dev/null)" || return 1
    for rel in "${SHIPPED_AUTOSTART_FILES[@]}"; do
        file="$CONFIG_HOME/$rel"
        [ -f "$file" ] && [ -w "$file" ] && [ -w "$(dirname "$file")" ] || continue
        [ "$(realpath "$file" 2>/dev/null)" = "$real_config/$rel" ] || continue
        grep -qE "$AUTOSTART_LINE" "$file" 2>/dev/null || continue
        [ -e "$file.pre-audio-engine.bak" ] || cp -p "$file" "$file.pre-audio-engine.bak" || continue
        sed -i -E "\\#$AUTOSTART_LINE#d" "$file" && cleaned=0
    done
    return "$cleaned"
}

unit_starts_at_login() {
    case "$(systemctl --user is-enabled "$1" 2>/dev/null)" in
        enabled|enabled-runtime|linked|linked-runtime|indirect|alias|generated) return 0 ;;
    esac
    return 1
}

easyeffects_still_set_up() {
    pgrep -u "$SELF_UID" -f "$ANY_INSTANCE" >/dev/null 2>&1 && return 0
    [ -e "$CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop" ] && return 0
    command -v systemctl >/dev/null 2>&1 || return 1
    unit_starts_at_login easyeffects.service || unit_starts_at_login ee-eq.service
}

notifications_ready() {
    {
        busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications ||
            dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner string:org.freedesktop.Notifications
    } 2>/dev/null | grep -qw true
}

announce() {
    local title body app
    source "$SCRIPT_DIR/i18n.sh"
    title="$(t "daemon.easyeffects.title")"
    body="$(t "daemon.easyeffects.body")"

    if [ -n "${SERPANTINUM_INSTALLER:-}" ]; then
        echo -e "\n\e[33m[ WARN ]\e[0m $title"
        echo "  $body"
        return
    fi

    command -v notify-send >/dev/null 2>&1 || return
    app="$(t "daemon.app_name")"
    (
        waited=0
        while [ "$waited" -lt 60 ] && ! notifications_ready; do
            sleep 1
            waited=$((waited + 1))
        done
        notify-send -a "$app" "$title" "$body"
    ) >/dev/null 2>&1 &
}

drove_easyeffects=false
stop_own_instance && drove_easyeffects=true
stop_ee_eq_unit && drove_easyeffects=true
remove_generated_preset && drove_easyeffects=true
clean_shipped_autostart && drove_easyeffects=true

: > "$MARKER"

if [ "$drove_easyeffects" = true ] && easyeffects_still_set_up; then
    announce
fi
