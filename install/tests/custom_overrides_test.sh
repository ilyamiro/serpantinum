#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"

# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/migrate.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/custom_overrides.sh"

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

starters_match() {
    local comp="$1" dir topic
    dir="$HOME/.config/$(get_compositor_config_dir_name "$comp")"
    custom_spec "$comp" || return 1
    for topic in $CS_TOPICS; do
        cmp -s "$REPO_ROOT/install/templates/custom/$comp/$topic$CS_EXT" "$dir/custom/$topic$CS_EXT" || return 1
    done
}

for comp in hyprland niri sway mango; do
    mkdir -p "$HOME/.config/$(get_compositor_config_dir_name "$comp")"
    ensure_custom_starters "$REPO_ROOT" "$comp"
    check "starters_created_$comp" "starters_match $comp"
done

# existing custom file untouched
mkdir -p "$HOME/.config/hypr/custom"
rm -rf "$HOME/.config/hypr/custom"
mkdir -p "$HOME/.config/hypr/custom"
printf 'my user content\n' > "$HOME/.config/hypr/custom/keybinds.lua"
touch -d '2001-02-03 04:05:06' "$HOME/.config/hypr/custom/keybinds.lua"
before_sum="$(cksum < "$HOME/.config/hypr/custom/keybinds.lua")"
before_mtime="$(stat -c %Y "$HOME/.config/hypr/custom/keybinds.lua")"
ensure_custom_starters "$REPO_ROOT" hyprland
check "existing_custom_untouched" '[ "$(cksum < "$HOME/.config/hypr/custom/keybinds.lua")" = "$before_sum" ] && [ "$(stat -c %Y "$HOME/.config/hypr/custom/keybinds.lua")" = "$before_mtime" ] && [ -f "$HOME/.config/hypr/custom/env.lua" ]'

# no config dir -> nothing created
rm -rf "$HOME/.config/niri"
ensure_custom_starters "$REPO_ROOT" niri
check "no_config_dir_no_starters" '[ ! -e "$HOME/.config/niri" ]'

# dangling symlink kept
rm -rf "$HOME/.config/hypr/custom"
mkdir -p "$HOME/.config/hypr/custom"
ln -s "$SANDBOX/nowhere" "$HOME/.config/hypr/custom/env.lua"
ensure_custom_starters "$REPO_ROOT" hyprland
check "dangling_symlink_kept" '[ -L "$HOME/.config/hypr/custom/env.lua" ] && [ ! -e "$SANDBOX/nowhere" ]'

check "custom_spec_unknown_fails" '! custom_spec bogus'
check "custom_spec_mango_before" 'custom_spec mango && [ "$CS_BEFORE_TOPICS" = keybinds ]'

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
