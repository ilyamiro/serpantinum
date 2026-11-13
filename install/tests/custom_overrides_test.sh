#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SANDBOX="$(mktemp -d)"
trap 'chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"

# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/migrate.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/install/modules/compositor_sync.sh"
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

# ---- insert_custom_lines / setup_custom_overrides ----
FIX="$REPO_ROOT/install/tests/fixtures/custom_overrides"
SHIPPED_REL_hyprland=compositors/hyprland/hyprland.lua
SHIPPED_REL_niri=compositors/niri/config.kdl
SHIPPED_REL_sway=compositors/sway/config
SHIPPED_REL_mango=compositors/mango/config.conf

# fresh_main <comp>: reset the comp dir with the old shipped main config.
fresh_main() {
    local comp="$1" dir
    custom_spec "$comp" || return 1
    dir="$HOME/.config/$(get_compositor_config_dir_name "$comp")"
    rm -rf "$dir"
    mkdir -p "$dir"
    cp "$FIX/$comp.main" "$dir/$CS_MAIN"
    if [ "$comp" = hyprland ] && [ "${NO_LOADER:-}" != 1 ]; then
        mkdir -p "$dir/config"
        cp "$REPO_ROOT/compositors/hyprland/config/custom.lua" "$dir/config/custom.lua"
    fi
}
main_of() { custom_spec "$1"; echo "$HOME/.config/$(get_compositor_config_dir_name "$1")/$CS_MAIN"; }
# non_comment <file> <comment-prefix>: trimmed lines that are neither comments nor blank.
non_comment() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v -e "^$2" -e '^$'; }

# placement_ok <comp>: each custom line sits right after its marker, which sits right after
# its default line (before it, for CS_BEFORE_TOPICS).
placement_ok() {
    local comp="$1" f topic d c mk prev
    custom_spec "$comp"; f="$(main_of "$comp")"
    mk="$CS_COMMENT serpantinum: custom overrides"
    for topic in $CS_TOPICS; do
        # shellcheck disable=SC2059
        d="$(printf "$CS_DEFAULT_FMT" "$topic")"; c="$(printf "$CS_CUSTOM_FMT" "$topic")"
        case " $CS_BEFORE_TOPICS " in
            *" $topic "*) grep -x -B2 -F -- "$d" "$f" | head -2 | paste -sd'|' | grep -qxF -- "$mk|$c" || return 1 ;;
            *) grep -x -A2 -F -- "$d" "$f" | tail -2 | paste -sd'|' | grep -qxF -- "$mk|$c" || return 1 ;;
        esac
    done
}

for comp in hyprland niri sway mango; do
    fresh_main "$comp"
    insert_custom_lines "$comp"
    check "inserts_after_default_$comp" "placement_ok $comp"
    eval "rel=\$SHIPPED_REL_$comp"
    custom_spec "$comp"
    check "result_matches_shipped_$comp" 'diff <(non_comment "$(main_of $comp)" "$CS_COMMENT") <(non_comment "$REPO_ROOT/$rel" "$CS_COMMENT") >/dev/null'

    f="$(main_of "$comp")"
    sum1="$(cksum < "$f")"
    insert_custom_lines "$comp"
    check "second_run_is_noop_$comp" '[ "$(cksum < "$f")" = "$sum1" ] && [ "$(ls "$f".pre-custom-overrides.bak* | wc -l)" = 1 ]'
    check "backup_created_once_$comp" 'cmp -s "$f.pre-custom-overrides.bak" "$FIX/$comp.main"'
    check "trailing_newline_$comp" '[ -z "$(tail -c1 "$f")" ]'
done

# permissions preserved
fresh_main sway; f="$(main_of sway)"; chmod 640 "$f"
insert_custom_lines sway
check "mode_preserved" '[ "$(stat -c %a "$f")" = 640 ]'

# missing default line appends / prepends
fresh_main niri; f="$(main_of niri)"
grep -vF 'include "config/layout.kdl"' "$FIX/niri.main" > "$f"
insert_custom_lines niri
check "missing_default_line_appends_niri_at_end" 'grep -nF "custom/layout.kdl" "$f" | cut -d: -f1 | { read -r n; [ "$n" -gt "$(grep -nF "config/keybinds.kdl" "$f" | cut -d: -f1)" ]; }'
fresh_main mango; f="$(main_of mango)"
grep -vF 'source=./config/keybinds.conf' "$FIX/mango.main" > "$f"
insert_custom_lines mango
check "missing_default_line_prepends_mango" '[ "$(sed -n 1,2p "$f" | paste -sd"|")" = "# serpantinum: custom overrides|source_optional=./custom/keybinds.conf" ]'

# commented default / commented custom lines are ignored
fresh_main hyprland; f="$(main_of hyprland)"
sed 's|^require("config/env")|-- require("config/env")|' "$FIX/hyprland.main" > "$f"
insert_custom_lines hyprland
check "commented_default_line_is_ignored" '[ "$(grep -c "load(\"env\")" "$f")" = 1 ] && grep -nF "load(\"env\")" "$f" | cut -d: -f1 | { read -r n; [ "$n" -gt "$(grep -nF "config/keybinds" "$f" | head -1 | cut -d: -f1)" ]; }'
fresh_main niri; f="$(main_of niri)"
{ echo '// include "custom/env.kdl"'; cat "$FIX/niri.main"; } > "$f"
insert_custom_lines niri
check "commented_custom_line_not_present" '[ "$(grep -cx "include \"custom/env.kdl\"" "$f")" = 1 ]'

# symlinked main skipped
fresh_main sway; f="$(main_of sway)"; real="$SANDBOX/real-sway-config"
mv "$f" "$real"; ln -s "$real" "$f"
CUSTOM_OVERRIDES_MANUAL=()
insert_custom_lines sway
check "symlinked_main_skipped" '[ -L "$f" ] && cmp -s "$real" "$FIX/sway.main" && [ ! -e "$f.pre-custom-overrides.bak" ] && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ] && [ "${CUSTOM_OVERRIDES_MANUAL[0]}" = "$f|include custom/variables" ]'

# symlinked base skipped
fresh_main niri; basedir="$HOME/.config/niri"; realdir="$SANDBOX/real-niri"
rm -rf "$realdir"; mv "$basedir" "$realdir"; ln -s "$realdir" "$basedir"
CUSTOM_OVERRIDES_MANUAL=()
setup_custom_overrides "$REPO_ROOT" niri
check "symlinked_base_main_skipped" 'cmp -s "$realdir/config.kdl" "$FIX/niri.main" && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ] && [ ! -e "$realdir/custom" ]'
rm -f "$basedir"

# hyprland without config/custom.lua: not edited, listed for the user
NO_LOADER=1 fresh_main hyprland; f="$(main_of hyprland)"; CUSTOM_OVERRIDES_MANUAL=()
insert_custom_lines hyprland
check "hypr_without_loader_skipped" 'cmp -s "$f" "$FIX/hyprland.main" && [ ! -e "$f.pre-custom-overrides.bak" ] && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ]'

# CRLF main config
fresh_main niri; f="$(main_of niri)"; sed 's/$/\r/' "$FIX/niri.main" > "$f"
insert_custom_lines niri
check "crlf_main_gets_lines" '[ "$(grep -c "custom/" "$f")" = 6 ]'

# no-op run does not rewrite the file
fresh_main sway; f="$(main_of sway)"; insert_custom_lines sway
ino="$(stat -c %i "$f")"; mt="$(stat -c %Y.%y "$f")"
insert_custom_lines sway
check "noop_does_not_rewrite" '[ "$(stat -c %i "$f")" = "$ino" ] && [ "$(stat -c %Y.%y "$f")" = "$mt" ]'

# prepend keeps newline at EOF when file lacked one
fresh_main mango; f="$(main_of mango)"
# keybinds is the only missing topic and the file has no trailing newline
printf '%s' "$(grep -v keybinds "$REPO_ROOT/compositors/mango/config.conf")" > "$f"
insert_custom_lines mango
check "prepend_adds_trailing_newline" '[ -z "$(tail -c1 "$f")" ] && grep -qxF "source_optional=./custom/keybinds.conf" "$f"'

# already present: untouched, no backup
fresh_main mango; f="$(main_of mango)"
cp "$REPO_ROOT/compositors/mango/config.conf" "$f"
sum1="$(cksum < "$f")"
insert_custom_lines mango
check "already_present_untouched" '[ "$(cksum < "$f")" = "$sum1" ] && [ ! -e "$f.pre-custom-overrides.bak" ]'

# missing main file: silent skip
fresh_main hyprland; rm -f "$(main_of hyprland)"; CUSTOM_OVERRIDES_MANUAL=()
insert_custom_lines hyprland
check "missing_main_skipped" '[ ! -e "$(main_of hyprland)" ] && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 0 ]'

# setup_custom_overrides: starters + lines; skips comps without config dir
rm -rf "$HOME/.config/sway" "$HOME/.config/mango" "$HOME/.config/niri"
fresh_main sway
setup_custom_overrides "$REPO_ROOT" sway mango
check "setup_creates_starters_and_lines" '[ -f "$HOME/.config/sway/custom/keybinds" ] && grep -qxF "include custom/keybinds" "$(main_of sway)" && [ ! -e "$HOME/.config/mango" ]'

# ---- hyprland: load lines only go in when config/custom.lua is our helper ----
# hypr_verify <hyprland.lua>: 0 when Hyprland is not installed or says "config ok".
hypr_verify() {
    command -v Hyprland >/dev/null 2>&1 || return 0
    local run
    run="$(mktemp -d "$SANDBOX/run.XXXXXX")" && chmod 700 "$run" || return 1
    env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$run" \
        timeout 60 Hyprland --verify-config -c "$1" 2>&1 | grep -q '^config ok'
}
command -v Hyprland >/dev/null 2>&1 || echo "skip  Hyprland not installed: --verify-config checks are skipped"
# full_hypr: old main config plus all default config files and our helper.
full_hypr() {
    fresh_main hyprland
    cp "$REPO_ROOT"/compositors/hyprland/config/*.lua "$HOME/.config/hypr/config/"
}

check "helper_has_marker" '[ "$(head -n1 "$REPO_ROOT/compositors/hyprland/config/custom.lua")" = "-- serpantinum: custom overrides helper" ]'

full_hypr; f="$(main_of hyprland)"; CUSTOM_OVERRIDES_MANUAL=()
insert_custom_lines hyprland
check "hypr_with_our_helper_inserted" 'placement_ok hyprland && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 0 ]'
check "hypr_with_our_helper_verifies" 'hypr_verify "$f"'

# Trigger A: config/ is a symlink (helper present through it).
full_hypr; f="$(main_of hyprland)"; CUSTOM_OVERRIDES_MANUAL=()
mv "$HOME/.config/hypr/config" "$SANDBOX/hconf"; ln -s "$SANDBOX/hconf" "$HOME/.config/hypr/config"
insert_custom_lines hyprland
check "hypr_symlinked_config_not_edited" 'cmp -s "$f" "$FIX/hyprland.main" && [ ! -e "$f.pre-custom-overrides.bak" ] && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ]'
check "hypr_symlinked_config_verifies" 'hypr_verify "$f"'
rm -f "$HOME/.config/hypr/config"; rm -rf "$SANDBOX/hconf"

# Trigger B: the user's own config/custom.lua.
full_hypr; f="$(main_of hyprland)"; CUSTOM_OVERRIDES_MANUAL=()
printf 'return true\n' > "$HOME/.config/hypr/config/custom.lua"
insert_custom_lines hyprland
check "hypr_foreign_helper_not_edited" 'cmp -s "$f" "$FIX/hyprland.main" && [ ! -e "$f.pre-custom-overrides.bak" ] && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ] && [ "$(cat "$HOME/.config/hypr/config/custom.lua")" = "return true" ]'
check "hypr_foreign_helper_verifies" 'hypr_verify "$f"'

# ---- set -e safety (the installer runs with set -e) ----
# run_e <cmd...>: run under set -e in a subshell, starting with an empty
# CUSTOM_OVERRIDES_MANUAL; sets RUN_RC and copies the list back.
run_e() {
    CUSTOM_OVERRIDES_MANUAL=()
    ( set -e; "$@"; declare -p CUSTOM_OVERRIDES_MANUAL > "$SANDBOX/manual.out" )
    RUN_RC=$?
    CUSTOM_OVERRIDES_MANUAL=()
    # shellcheck disable=SC1090
    [ -f "$SANDBOX/manual.out" ] && source <(sed "s/^declare -a /declare -ga /" "$SANDBOX/manual.out")
    rm -f "$SANDBOX/manual.out"
}

# dangling custom/ symlink: nothing is created through it
rm -rf "$HOME/.config/niri"; mkdir -p "$HOME/.config/niri"
ln -s "$SANDBOX/no-such-dir/custom" "$HOME/.config/niri/custom"
run_e ensure_custom_starters "$REPO_ROOT" niri
check "dangling_custom_dir_survives" '[ "$RUN_RC" = 0 ] && [ -L "$HOME/.config/niri/custom" ] && [ ! -e "$SANDBOX/no-such-dir" ]'
fresh_main niri; ln -s "$SANDBOX/no-such-dir/custom" "$HOME/.config/niri/custom"
run_e setup_custom_overrides "$REPO_ROOT" niri
check "dangling_custom_dir_setup_survives" '[ "$RUN_RC" = 0 ] && [ ! -e "$SANDBOX/no-such-dir" ]'

# custom/ symlinked to a real folder: no starters written through it
rm -rf "$HOME/.config/niri" "$SANDBOX/custom-elsewhere"; mkdir -p "$HOME/.config/niri" "$SANDBOX/custom-elsewhere"
ln -s "$SANDBOX/custom-elsewhere" "$HOME/.config/niri/custom"
run_e ensure_custom_starters "$REPO_ROOT" niri
check "symlinked_custom_dir_not_written" '[ "$RUN_RC" = 0 ] && [ -z "$(ls -A "$SANDBOX/custom-elsewhere")" ]'
rm -f "$HOME/.config/niri/custom"

if [ "$(id -u)" != 0 ]; then
    # read-only custom/ folder
    rm -rf "$HOME/.config/niri"; mkdir -p "$HOME/.config/niri/custom"; chmod 555 "$HOME/.config/niri/custom"
    run_e ensure_custom_starters "$REPO_ROOT" niri
    check "readonly_custom_dir_survives" '[ "$RUN_RC" = 0 ] && [ -z "$(ls -A "$HOME/.config/niri/custom")" ]'
    chmod 755 "$HOME/.config/niri/custom"

    # failed write while inserting: the user is told which lines to add
    fresh_main niri; f="$(main_of niri)"
    cp "$f" "$f.pre-custom-overrides.bak"; chmod 555 "$HOME/.config/niri"
    run_e insert_custom_lines niri
    check "failed_insert_listed_as_manual" '[ "$RUN_RC" = 0 ] && cmp -s "$f" "$FIX/niri.main" && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ] && [ "${CUSTOM_OVERRIDES_MANUAL[0]}" = "$f|include \"custom/env.kdl\"" ]'
    chmod 755 "$HOME/.config/niri"

    fresh_main niri; f="$(main_of niri)"; chmod 555 "$HOME/.config/niri"
    run_e insert_custom_lines niri
    check "failed_backup_listed_as_manual" '[ "$RUN_RC" = 0 ] && cmp -s "$f" "$FIX/niri.main" && [ "${#CUSTOM_OVERRIDES_MANUAL[@]}" = 6 ]'
    chmod 755 "$HOME/.config/niri"
else
    echo "skip  read-only checks (running as root)"
fi

# notice: stub t to echo its key and args
t() { echo "$*"; }
COMPOSITOR_EDITED_FILES=("$HOME/.config/hypr/config/keybinds.lua" "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/niri/config/input.kdl")
CUSTOM_OVERRIDES_MANUAL=("$HOME/.config/sway/config|include custom/keybinds" "$HOME/.config/sway/config|include custom/input")
notice_out="$(print_custom_overrides_notice | sed "s/\x1b\[[0-9;]*m//g")"
check "notice_lists_edited" 'grep -q "installer.custom.edited_header" <<<"$notice_out" && grep -q "~/.config/hypr/config/keybinds.lua" <<<"$notice_out" && grep -q "~/.config/niri/config/input.kdl" <<<"$notice_out" && grep -q "installer.custom.manual_header" <<<"$notice_out" && grep -q "include custom/input" <<<"$notice_out"'
check "notice_hint_once_per_dir" '[ "$(grep -c "edited_hint dir=~/.config/hypr$" <<<"$notice_out")" = 1 ] && grep -q "edited_hint dir=~/.config/niri$" <<<"$notice_out" && [ "$(grep -c "manual_header" <<<"$notice_out")" = 1 ]'
COMPOSITOR_EDITED_FILES=() CUSTOM_OVERRIDES_MANUAL=()
check "notice_silent_when_empty" '[ -z "$(print_custom_overrides_notice)" ]'
unset -f t

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
