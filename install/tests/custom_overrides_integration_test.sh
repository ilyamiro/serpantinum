#!/usr/bin/env bash
# Update flow end to end, under set -e like the installer: refresh the defaults,
# set up custom overrides, print the notice. Each case runs in its own subshell
# so a crash is reported instead of ending the test.

set -eu

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SANDBOX="$(mktemp -d)"
cleanup_sandbox() { chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"; }
trap cleanup_sandbox EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"
case "$HOME" in "$SANDBOX"/*) ;; *) echo "HOME is not in the sandbox" >&2; exit 2 ;; esac

# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/migrate.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/compositor_sync.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/custom_overrides.sh"
t() { echo "$*"; }

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

# hypr_verify <hyprland.lua>: 0 when Hyprland is not installed or says "config ok".
hypr_verify() {
    command -v Hyprland >/dev/null 2>&1 || return 0
    local run
    run="$(mktemp -d "$SANDBOX/run.XXXXXX")" && chmod 700 "$run" || return 1
    env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$run" \
        timeout 60 Hyprland --verify-config -c "$1" 2>&1 | grep -q '^config ok'
}
command -v Hyprland >/dev/null 2>&1 || echo "skip  Hyprland not installed: --verify-config checks are skipped"

# Throwaway repo. A: the release before custom overrides (no helper, no custom
# lines, an older keybinds.lua). B: this tree, with the starter templates.
REPO="$SANDBOX/repo"
g() { git -C "$REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
mkdir -p "$REPO/compositors" "$REPO/install/templates"
git -C "$REPO" init -q
for comp in hyprland niri; do
    cp -r "$REPO_ROOT/compositors/$comp" "$REPO/compositors/"
done
rm "$REPO/compositors/hyprland/config/custom.lua"
cp "$REPO_ROOT/install/tests/fixtures/custom_overrides/hyprland.main" "$REPO/compositors/hyprland/hyprland.lua"
cp "$REPO_ROOT/install/tests/fixtures/custom_overrides/niri.main" "$REPO/compositors/niri/config.kdl"
printf -- '-- older default\n' >> "$REPO/compositors/hyprland/config/keybinds.lua"
g add -A; g commit -q -m A
OLD=$(g rev-parse HEAD)
for comp in hyprland niri; do
    rm -rf "$REPO/compositors/$comp"
    cp -r "$REPO_ROOT/compositors/$comp" "$REPO/compositors/"
done
cp -r "$REPO_ROOT/install/templates/custom" "$REPO/install/templates/"
g add -A; g commit -q -m B
NEW=$(g rev-parse HEAD)

HCFG="$HOME/.config/hypr"
OLD_MAIN="$SANDBOX/old-hyprland.lua"
git -C "$REPO" show "$OLD:compositors/hyprland/hyprland.lua" > "$OLD_MAIN"
NEW_MAIN="$REPO_ROOT/compositors/hyprland/hyprland.lua"

# reset_hypr: ~/.config/hypr as release A deployed it.
reset_hypr() {
    chmod -R u+w "$HOME" 2>/dev/null || true
    rm -rf "$HOME/.config"
    mkdir -p "$HCFG"
    git -C "$REPO" archive "$OLD" compositors/hyprland | tar -x -C "$HCFG" --strip-components=2
}

# sums <path>...: checksums of the given files (following symlinks).
sums() { local p; for p in "$@"; do printf '%s ' "$p"; sha256sum < "$p"; done; }

# run_update: the installer's update steps for hyprland, under set -e, in a
# subshell. Output (the notice) goes to $OUT; RC is the exit code.
OUT="$SANDBOX/out"
run_update() {
    set +e
    (
        set -e
        COMPOSITOR_EDITED_FILES=() CUSTOM_OVERRIDES_MANUAL=()
        ensure_custom_starters "$REPO" hyprland
        refresh_compositor_defaults "$REPO" "$OLD" "$NEW" hyprland
        setup_custom_overrides "$REPO" hyprland
        print_custom_overrides_notice
        echo "__survived__"
    ) > "$OUT" 2>&1
    RC=$?
    set -e
    sed -i "s/\x1b\[[0-9;]*m//g" "$OUT"
}
survived() { [ "$RC" = 0 ] && grep -qx "__survived__" "$OUT"; }
notice_lists() { grep -q "installer.custom.edited_header" "$OUT" && grep -qF "    ~${1#"$HOME"}" "$OUT"; }
manual_lines() { grep -c 'require("config/custom").load(' "$OUT" || true; }
# user_content_kept <file> <original>: the file, minus the lines the installer
# adds, is the original.
user_content_kept() {
    diff <(grep -vxF -e '-- serpantinum: custom overrides' "$1" | grep -v '^require("config/custom").load(') "$2" >/dev/null
}

# 1. unedited
reset_hypr
run_update
check "unedited_survives" 'survived'
check "unedited_main_refreshed" 'cmp -s "$HCFG/hyprland.lua" "$NEW_MAIN" && cmp -s "$HCFG/config/custom.lua" "$REPO_ROOT/compositors/hyprland/config/custom.lua"'
check "unedited_starters_created" '[ -f "$HCFG/custom/keybinds.lua" ] && [ -f "$HCFG/custom/env.lua" ]'
check "unedited_no_notice" '! grep -q "installer.custom" "$OUT"'
check "unedited_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# 2. edited hyprland.lua: kept (load lines added, backup saved)
reset_hypr
printf -- '-- my own line\n' >> "$HCFG/hyprland.lua"
cp "$HCFG/hyprland.lua" "$SANDBOX/edited-main"
run_update
check "edited_main_survives" 'survived'
check "edited_main_content_kept" 'user_content_kept "$HCFG/hyprland.lua" "$SANDBOX/edited-main" && cmp -s "$HCFG/hyprland.lua.pre-custom-overrides.bak" "$SANDBOX/edited-main"'
check "edited_main_gets_load_lines" '[ "$(grep -c "^require(\"config/custom\").load(" "$HCFG/hyprland.lua")" = 6 ]'
check "edited_main_listed" 'notice_lists "$HCFG/hyprland.lua" && [ "$(manual_lines)" = 0 ]'
check "edited_main_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# 3. symlinked config/
reset_hypr
mv "$HCFG/config" "$SANDBOX/hconf"; ln -s "$SANDBOX/hconf" "$HCFG/config"
before="$(sums "$SANDBOX"/hconf/*)"
run_update
check "symlinked_config_survives" 'survived'
check "symlinked_config_untouched" '[ "$(sums "$SANDBOX"/hconf/*)" = "$before" ] && [ ! -e "$SANDBOX/hconf/custom.lua" ]'
check "symlinked_config_main_kept" 'cmp -s "$HCFG/hyprland.lua" "$OLD_MAIN" && notice_lists "$HCFG/hyprland.lua" && [ "$(manual_lines)" = 6 ]'
check "symlinked_config_verifies" 'hypr_verify "$HCFG/hyprland.lua"'
rm -f "$HCFG/config"; rm -rf "$SANDBOX/hconf"

# 4. the user's own config/custom.lua
reset_hypr
printf 'return true\n' > "$HCFG/config/custom.lua"
run_update
check "user_helper_survives" 'survived'
check "user_helper_untouched" '[ "$(cat "$HCFG/config/custom.lua")" = "return true" ] && cmp -s "$HCFG/hyprland.lua" "$OLD_MAIN"'
check "user_helper_listed" 'notice_lists "$HCFG/hyprland.lua" && notice_lists "$HCFG/config/custom.lua" && [ "$(manual_lines)" = 6 ]'
check "user_helper_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# 5. unwritable unedited file
if [ "$(id -u)" != 0 ]; then
    reset_hypr
    cp "$HCFG/config/keybinds.lua" "$SANDBOX/old-keybinds"
    chmod 444 "$HCFG/config/keybinds.lua"
    run_update
    check "readonly_file_survives" 'survived'
    check "readonly_file_kept_and_listed" 'cmp -s "$HCFG/config/keybinds.lua" "$SANDBOX/old-keybinds" && notice_lists "$HCFG/config/keybinds.lua"'
    check "readonly_file_rest_updated" 'cmp -s "$HCFG/hyprland.lua" "$NEW_MAIN" && [ -f "$HCFG/config/custom.lua" ]'
    check "readonly_file_verifies" 'hypr_verify "$HCFG/hyprland.lua"'
else
    echo "skip  read-only case (running as root)"
fi

# 6. dangling custom/ symlink
reset_hypr
ln -s "$SANDBOX/nowhere/custom" "$HCFG/custom"
run_update
check "dangling_custom_survives" 'survived'
check "dangling_custom_nothing_created" '[ -L "$HCFG/custom" ] && [ ! -e "$SANDBOX/nowhere" ]'
check "dangling_custom_main_refreshed" 'cmp -s "$HCFG/hyprland.lua" "$NEW_MAIN"'
check "dangling_custom_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# ---- deploy_package: niri starters exist before the refreshed config.kdl includes them ----
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/deploy.sh"
sudo() { :; }
setup_pam_service() { :; }
remove_settings_desktop_entry() { :; }
reset_hypr
rm -rf "$HOME/.config/hypr"
mkdir -p "$HOME/.config/niri"
git -C "$REPO" archive "$OLD" compositors/niri | tar -x -C "$HOME/.config/niri" --strip-components=2
set +e
( set -e; COMPOSITOR_EDITED_FILES=(); deploy_package "$REPO" "$OLD" "$NEW" false current niri ) > "$OUT" 2>&1
RC=$?
set -e
missing_includes() {
    local inc
    sed -n 's/^[[:space:]]*include "\(custom\/[^"]*\)".*/\1/p' "$HOME/.config/niri/config.kdl" | while IFS= read -r inc; do
        [ -f "$HOME/.config/niri/$inc" ] || echo "$inc"
    done
}
check "deploy_survives" '[ "$RC" = 0 ]'
check "deploy_refreshes_niri_main" 'cmp -s "$HOME/.config/niri/config.kdl" "$REPO_ROOT/compositors/niri/config.kdl"'
check "deploy_creates_starters_before_include" '[ -z "$(missing_includes)" ]'

# ---- the notice is shown on the completion screen, after clear ----
set +u
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/ui.sh"
set -u
# ui.sh sets its own EXIT trap (terminal cleanup); keep ours instead.
trap cleanup_sandbox EXIT
trap - INT TERM
t() { echo "$*"; }
cleanup_terminal() { :; }
clear() { echo "__clear__"; }
read() { if [ "${1:-}" = -r ] && [ "${2:-}" = -p ]; then return 0; fi; builtin read "$@"; }
FAILED_PKGS=()
COMPOSITOR_EDITED_FILES=("$HOME/.config/hypr/config/keybinds.lua") CUSTOM_OVERRIDES_MANUAL=()
screen="$(draw_completion_screen 9.9.9 abc < /dev/null 2>&1 | sed "s/\x1b\[[0-9;]*m//g")"
check "completion_screen_shows_notice_after_clear" 'printf "%s\n" "$screen" | sed -n "/__clear__/,\$p" | sed -n "/installer.ui.installed_success/,/installer.ui.restart_prompt/p" | grep -q "installer.custom.edited_header"'
COMPOSITOR_EDITED_FILES=()
screen="$(draw_completion_screen 9.9.9 abc < /dev/null 2>&1)"
check "completion_screen_silent_without_notice" '! grep -q "installer.custom" <<<"$screen"'
unset -f read clear

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
