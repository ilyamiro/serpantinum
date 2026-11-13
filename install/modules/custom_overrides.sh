#!/usr/bin/env bash
# Custom override support: user-owned ~/.config/<comp>/custom/ folders.
# Functions only; safe to source. Needs get_compositor_config_dir_name (migrate.sh).

# custom_spec <comp>: sets the CS_* globals describing how <comp>'s main config
# loads its custom files. Returns 1 for an unknown compositor.
custom_spec() {
    CS_MAIN="" CS_EXT="" CS_TOPICS="" CS_COMMENT="" CS_DEFAULT_FMT="" CS_CUSTOM_FMT="" CS_BEFORE_TOPICS=""
    case "$1" in
        hyprland)
            CS_MAIN="hyprland.lua"
            CS_EXT=".lua"
            CS_TOPICS="variables env autostart monitors settings keybinds"
            CS_COMMENT="--"
            CS_DEFAULT_FMT='require("config/%s")'
            CS_CUSTOM_FMT='require("config/custom").load("%s")'
            ;;
        niri)
            CS_MAIN="config.kdl"
            CS_EXT=".kdl"
            CS_TOPICS="env input output layout autostart keybinds"
            CS_COMMENT="//"
            CS_DEFAULT_FMT='include "config/%s.kdl"'
            CS_CUSTOM_FMT='include "custom/%s.kdl"'
            ;;
        sway)
            CS_MAIN="config"
            CS_EXT=""
            CS_TOPICS="variables input output layout autostart keybinds"
            CS_COMMENT="#"
            CS_DEFAULT_FMT='include config/%s'
            CS_CUSTOM_FMT='include custom/%s'
            ;;
        mango)
            CS_MAIN="config.conf"
            CS_EXT=".conf"
            CS_TOPICS="input layout autostart keybinds"
            CS_COMMENT="#"
            CS_DEFAULT_FMT='source=./config/%s.conf'
            CS_CUSTOM_FMT='source_optional=./custom/%s.conf'
            CS_BEFORE_TOPICS="keybinds"
            ;;
        *) return 1 ;;
    esac
    return 0
}

# ensure_custom_starters <repo_root> <comp>: create missing starter files in
# ~/.config/<dir>/custom/. Never touches an existing file or symlink.
ensure_custom_starters() {
    local repo_root="$1" comp="$2"
    custom_spec "$comp" || return 1

    local dir
    dir="$HOME/.config/$(get_compositor_config_dir_name "$comp")"
    [ -d "$dir" ] || return 0

    local custom="$dir/custom" topic target template
    if [ ! -e "$custom" ] && [ ! -L "$custom" ]; then
        mkdir -p "$custom" || return 0
    fi

    for topic in $CS_TOPICS; do
        target="$custom/$topic$CS_EXT"
        template="$repo_root/install/templates/custom/$comp/$topic$CS_EXT"
        if [ -e "$target" ] || [ -L "$target" ]; then
            continue
        fi
        [ -f "$template" ] && cp "$template" "$target"
    done
    return 0
}
