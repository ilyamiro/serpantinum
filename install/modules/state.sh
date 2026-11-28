#!/usr/bin/env bash

detect_install_state() {
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local legacy_marker="$state_home/imperative-dots-version"
    local legacy_watcher="$config_home/hypr/scripts/settings_watcher.sh"
    local new_marker="${QS_STATE_DIR:-$state_home/serpantinum}/version"

    if [[ -f "$new_marker" ]]; then
        echo "current"
    elif [[ -f "$legacy_marker" || -f "$legacy_watcher" ]]; then
        echo "legacy"
    else
        echo "fresh"
    fi
}
