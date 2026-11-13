#!/usr/bin/env bash
# Custom override support: user-owned ~/.config/<comp>/custom/ folders.
# Functions only; safe to source. Needs get_compositor_config_dir_name (migrate.sh)
# and config_path_is_real (compositor_sync.sh).

# Entries "<main file path>|<line to add>" for main configs that were not edited.
CUSTOM_OVERRIDES_MANUAL=()

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

# _custom_has_line <file> <line>: 0 when some line of <file>, trimmed, equals <line> exactly.
_custom_has_line() {
    [ -r "$1" ] || return 1
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -qxF -- "$2"
}

# insert_custom_lines <comp>: add the missing custom load lines to the compositor's
# main config, each right after its default line (right before, for CS_BEFORE_TOPICS).
# Symlinked configs are not edited; their missing lines go to CUSTOM_OVERRIDES_MANUAL.
insert_custom_lines() {
    local comp="$1"
    custom_spec "$comp" || return 1

    local name base main
    name="$(get_compositor_config_dir_name "$comp")"
    base="$HOME/.config/$name"
    main="$base/$CS_MAIN"
    [ -d "$base" ] || return 0

    local marker="$CS_COMMENT serpantinum: custom overrides"
    local topic custom_line
    local -a missing=()
    local unsafe=false
    if [ -L "$base" ] || ! config_path_is_real "$base" "$CS_MAIN"; then
        unsafe=true
    elif [ ! -f "$main" ]; then
        return 0
    fi

    for topic in $CS_TOPICS; do
        # shellcheck disable=SC2059
        custom_line="$(printf "$CS_CUSTOM_FMT" "$topic")"
        _custom_has_line "$main" "$custom_line" || missing+=("$topic")
    done
    [ "${#missing[@]}" -gt 0 ] || return 0

    if [ "$unsafe" = true ]; then
        for topic in "${missing[@]}"; do
            # shellcheck disable=SC2059
            CUSTOM_OVERRIDES_MANUAL+=("$main|$(printf "$CS_CUSTOM_FMT" "$topic")")
        done
        return 0
    fi

    [ -e "$main.pre-custom-overrides.bak" ] || [ -L "$main.pre-custom-overrides.bak" ] \
        || cp -p "$main" "$main.pre-custom-overrides.bak" || return 0

    local default_line before tmp
    for topic in "${missing[@]}"; do
        # shellcheck disable=SC2059
        default_line="$(printf "$CS_DEFAULT_FMT" "$topic")"
        # shellcheck disable=SC2059
        custom_line="$(printf "$CS_CUSTOM_FMT" "$topic")"
        before=0
        case " $CS_BEFORE_TOPICS " in *" $topic "*) before=1 ;; esac
        tmp="$(mktemp "$base/.${CS_MAIN}.XXXXXX")" || return 0
        if _custom_has_line "$main" "$default_line"; then
            CS_D="$default_line" CS_C="$custom_line" CS_M="$marker" CS_B="$before" \
            awk '
                BEGIN { d = ENVIRON["CS_D"]; c = ENVIRON["CS_C"]; m = ENVIRON["CS_M"]; b = ENVIRON["CS_B"]; done = 0 }
                {
                    t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t)
                    if (!done && t == d) {
                        done = 1
                        if (b == "1") { print m; print c; print $0 }
                        else { print $0; print m; print c }
                    } else print $0
                }' "$main" > "$tmp"
        elif [ "$before" = 1 ]; then
            { printf '%s\n%s\n' "$marker" "$custom_line"; cat "$main"; } > "$tmp"
        else
            { cat "$main"; [ -z "$(tail -c1 "$main")" ] || printf '\n'; printf '%s\n%s\n' "$marker" "$custom_line"; } > "$tmp"
        fi
        chmod --reference="$main" "$tmp" 2>/dev/null
        mv -f "$tmp" "$main" || { rm -f "$tmp"; return 0; }
    done
    return 0
}

# setup_custom_overrides <repo_root> <comp>...: starters, then load lines, for each
# compositor whose config dir exists.
setup_custom_overrides() {
    local repo_root="$1" comp base
    shift
    for comp in "$@"; do
        custom_spec "$comp" || continue
        base="$HOME/.config/$(get_compositor_config_dir_name "$comp")"
        [ -d "$base" ] || continue
        # Never create starters through a symlinked config dir.
        [ -L "$base" ] || ensure_custom_starters "$repo_root" "$comp"
        insert_custom_lines "$comp"
    done
    return 0
}
