#!/usr/bin/env bash
# Switch the window layout mode for the running compositor.
#
# Usage: layout.sh [tiling|mixed|floating]
#
# With no argument the mode stored in Serpantinum settings is applied, which
# makes the script safe to call from autostart. The mode is persisted in
# settings and mirrored into the Hyprland config so it survives a reload. On
# Hyprland the change is applied to already-open windows immediately through
# apply_layout_mode().

set -u

while [ $# -gt 0 ]; do
    case "$1" in
        --verbose|-v)
            shift
            ;;
        *)
            break
            ;;
    esac
done

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
settings_file="$config_home/serpantinum/settings.json"
variables_file="$config_home/hypr/config/variables.lua"

mode="${1:-}"
if [ -z "$mode" ] && [ -f "$settings_file" ] && command -v jq >/dev/null 2>&1; then
    mode="$(jq -r '.windowLayout.mode // "mixed"' "$settings_file" 2>/dev/null)"
fi
mode="${mode:-mixed}"

case "$mode" in
    tiling|mixed|floating) ;;
    *)
        echo "usage: layout.sh [tiling|mixed|floating]" >&2
        exit 2
        ;;
esac

if [ -f "$settings_file" ] && command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp "${settings_file}.XXXXXX")" || exit 1
    if jq --arg m "$mode" \
        '. + {windowLayout: ((.windowLayout // {}) + {mode: $m})}' \
        "$settings_file" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$settings_file"
    else
        rm -f "$tmp"
    fi
fi

if [ -f "$variables_file" ] && [ -w "$variables_file" ]; then
    tmp="$(mktemp "${variables_file}.XXXXXX")" || exit 1
    if awk -v mode="$mode" '
        /^[[:space:]]*layoutMode[[:space:]]*=/ {
            print "layoutMode = \"" mode "\""
            seen = 1
            next
        }
        { print }
        END { if (!seen) print "layoutMode = \"" mode "\"" }
    ' "$variables_file" > "$tmp"; then
        mv "$tmp" "$variables_file"
    else
        rm -f "$tmp"
    fi
fi

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    hyprctl eval "apply_layout_mode(\"$mode\")" >/dev/null 2>&1 || true
fi

exit 0
