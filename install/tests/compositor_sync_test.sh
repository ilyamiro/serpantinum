#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SANDBOX="$(mktemp -d)"
trap 'chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME"

source "$REPO_ROOT/install/modules/migrate.sh"
source "$REPO_ROOT/install/modules/compositor_sync.sh"

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

g() { git -C "$REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }

REPO="$SANDBOX/repo"
mkdir -p "$REPO/compositors/niri/config"
git -C "$REPO" init -q
C="$REPO/compositors/niri"
printf 'main A\n' > "$C/config.kdl"
printf 'a A\n' > "$C/config/a.kdl"
printf 'b A\n' > "$C/config/b.kdl"
printf 'gone A\n' > "$C/config/gone.kdl"
g add -A; g commit -q -m A
COMMIT_A=$(g rev-parse HEAD)
printf 'a B\n' > "$C/config/a.kdl"
printf 'b B\nmore\n' > "$C/config/b.kdl"
printf 'new B\n' > "$C/config/new.kdl"
g rm -q -f "compositors/niri/config/gone.kdl"
g add -A; g commit -q -m B
COMMIT_B=$(g rev-parse HEAD)

CFG="$HOME/.config/niri"
reset_cfg() {
    rm -rf "$HOME/.config"
    mkdir -p "$CFG"
    git -C "$REPO" archive "$COMMIT_A" compositors/niri | tar -x -C "$SANDBOX" --transform 's|^compositors/niri|cfgtmp|'
    cp -a "$SANDBOX/cfgtmp/." "$CFG/"
    rm -rf "$SANDBOX/cfgtmp"
    mkdir -p "$CFG/custom/sub"
    printf 'mine\n' > "$CFG/custom/keybinds.kdl"
    printf 'deep\n' > "$CFG/custom/sub/z.kdl"
    COMPOSITOR_EDITED_FILES=()
}
listed() { local x; for x in "${COMPOSITOR_EDITED_FILES[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }

# Scenario 1: mixed edits, old = A
reset_cfg
CUSTOM_SUM=$(cd "$CFG/custom" && find . -type f | sort | xargs sha256sum)
printf 'b A\nuser line\n' > "$CFG/config/b.kdl"
printf 'main A\n' > "$CFG/config.kdl"
printf 'gone A\nedited\n' > "$CFG/config/gone.kdl"
cp "$CFG/config/gone.kdl" "$SANDBOX/gone.edited"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "unedited_is_replaced" '[ "$(cat "$CFG/config/a.kdl")" = "a B" ]'
check "edited_is_kept" '[ "$(cat "$CFG/config/b.kdl")" = "$(printf "b A\nuser line")" ] && listed "$CFG/config/b.kdl"'
check "new_file_is_added" '[ "$(cat "$CFG/config/new.kdl")" = "new B" ]'
check "deleted_upstream_edited_kept_and_listed" 'cmp -s "$CFG/config/gone.kdl" "$SANDBOX/gone.edited" && listed "$CFG/config/gone.kdl"'
check "unedited_not_listed" '! listed "$CFG/config/a.kdl" && ! listed "$CFG/config.kdl"'
check "custom_untouched" '[ "$(cd "$CFG/custom" && find . -type f | sort | xargs sha256sum)" = "$CUSTOM_SUM" ]'

# Scenario 2: migration removed a line
reset_cfg
printf '' > "$CFG/config/b.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "edited_by_migration_is_kept" '[ ! -s "$CFG/config/b.kdl" ] && listed "$CFG/config/b.kdl"'
check "deleted_upstream_unedited_removed" '[ ! -e "$CFG/config/gone.kdl" ]'

# Scenario 3: missing default restored
reset_cfg
rm "$CFG/config/a.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "missing_default_is_restored" '[ "$(cat "$CFG/config/a.kdl")" = "a B" ] && ! listed "$CFG/config/a.kdl"'

# Scenario 4: unknown / unusable old commit
for oc in unknown "" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef; do
    reset_cfg
    rm "$CFG/config/new.kdl" 2>/dev/null
    refresh_compositor_defaults "$REPO" "$oc" "$COMMIT_B" niri
    check "unknown_commit_copies_only_missing [$oc]" '[ "$(cat "$CFG/config/a.kdl")" = "a A" ] && [ "$(cat "$CFG/config/new.kdl")" = "new B" ] && listed "$CFG/config/a.kdl" && listed "$CFG/config/b.kdl" && ! listed "$CFG/config/new.kdl" && [ -e "$CFG/config/gone.kdl" ]'
done

# Scenario 5: symlinked file
reset_cfg
printf 'outside\n' > "$SANDBOX/outside.kdl"
rm "$CFG/config/a.kdl"; ln -s "$SANDBOX/outside.kdl" "$CFG/config/a.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "symlinked_file_kept" '[ -L "$CFG/config/a.kdl" ] && [ "$(cat "$SANDBOX/outside.kdl")" = "outside" ] && listed "$CFG/config/a.kdl"'

# Scenario 6: symlinked folder
reset_cfg
mkdir -p "$SANDBOX/outdir"; cp "$CFG/config/"*.kdl "$SANDBOX/outdir/"
rm -rf "$CFG/config"; ln -s "$SANDBOX/outdir" "$CFG/config"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "symlinked_folder_not_written" '[ "$(cat "$SANDBOX/outdir/a.kdl")" = "a A" ] && [ ! -e "$SANDBOX/outdir/new.kdl" ] && listed "$CFG/config/a.kdl"'

# Scenario 7: second refresh
reset_cfg
printf 'b A\nuser line\n' > "$CFG/config/b.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
SUM1=$(cd "$CFG" && find . -type f | sort | xargs sha256sum)
COMPOSITOR_EDITED_FILES=()
refresh_compositor_defaults "$REPO" "$COMMIT_B" "$COMMIT_B" niri
SUM2=$(cd "$CFG" && find . -type f | sort | xargs sha256sum)
check "second_refresh_is_noop" '[ "$SUM1" = "$SUM2" ] && [ ${#COMPOSITOR_EDITED_FILES[@]} -eq 1 ] && listed "$CFG/config/b.kdl"'

# Scenario 8: prune
reset_cfg
mkdir -p "$CFG/config/emptydir"
printf 'x\n' > "$CFG/config/stray.kdl"
mkdir -p "$CFG/custom/emptysub"
prune_compositor_dir "$CFG" "$C"
check "prune_keeps_custom" '[ ! -e "$CFG/config/stray.kdl" ] && [ -f "$CFG/custom/keybinds.kdl" ] && [ -f "$CFG/custom/sub/z.kdl" ] && [ -d "$CFG/custom/sub" ] && [ -d "$CFG/custom/emptysub" ]'
check "prune_removes_empty_dirs" '[ ! -e "$CFG/config/emptydir" ]'

# Symlinked base dir
reset_cfg
mv "$CFG" "$SANDBOX/dotfiles"
ln -s "$SANDBOX/dotfiles" "$CFG"
DOT_SUM=$(cd "$SANDBOX/dotfiles" && find . -type f | sort | xargs sha256sum)
DOT_SUM=$(cd "$SANDBOX/dotfiles" && find . -type f | sort | xargs sha256sum)
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "symlinked_base_untouched" '[ "$(cd "$SANDBOX/dotfiles" && find . -type f | sort | xargs sha256sum)" = "$DOT_SUM" ] && [ ! -e "$SANDBOX/dotfiles/config/new.kdl" ] && listed "$CFG/config/a.kdl"'

# Missing config dir
reset_cfg
rm -rf "$CFG"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "missing_config_dir_untouched" '[ ! -e "$CFG" ] && [ ${#COMPOSITOR_EDITED_FILES[@]} -eq 0 ]'

# Working tree changes are not deployed
reset_cfg
printf 'a WORKTREE\n' > "$C/config/a.kdl"
rm "$C/config/b.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_A" "$COMMIT_B" niri
check "uses_new_commit_not_worktree" '[ "$(cat "$CFG/config/a.kdl")" = "a B" ] && [ "$(cat "$CFG/config/b.kdl")" = "$(printf "b B\nmore")" ]'
git -C "$REPO" checkout -q -- compositors

# Non-ASCII file names
printf 'u A\n' > "$C/config/é.kdl"
g add -A; g commit -q -m U1
COMMIT_U1=$(g rev-parse HEAD)
printf 'u B\n' > "$C/config/é.kdl"
g add -A; g commit -q -m U2
COMMIT_U2=$(g rev-parse HEAD)
reset_cfg
printf 'u A\n' > "$CFG/config/é.kdl"
refresh_compositor_defaults "$REPO" "$COMMIT_U1" "$COMMIT_U2" niri
check "non_ascii_filename" '[ "$(cat "$CFG/config/é.kdl")" = "u B" ]'

# config_path_is_real
reset_cfg
ln -s "$SANDBOX" "$CFG/linkdir"
check "config_path_is_real" 'config_path_is_real "$CFG" config/a.kdl && ! config_path_is_real "$CFG" linkdir/x && config_path_is_real "$CFG" config/nonexistent.kdl'

# ---- refresh failures never abort the installer (it runs with set -e) ----
# run_refresh_e <old> <new> <comp>: refresh under set -e in a subshell; sets REFRESH_RC
# and copies COMPOSITOR_EDITED_FILES back.
run_refresh_e() {
    ( set -e; refresh_compositor_defaults "$REPO" "$1" "$2" "$3"; declare -p COMPOSITOR_EDITED_FILES > "$SANDBOX/edited.out" )
    REFRESH_RC=$?
    COMPOSITOR_EDITED_FILES=()
    # shellcheck disable=SC1091
    [ -f "$SANDBOX/edited.out" ] && source <(sed "s/^declare -a /declare -ga /" "$SANDBOX/edited.out")
    rm -f "$SANDBOX/edited.out"
}
if [ "$(id -u)" != 0 ]; then
    reset_cfg
    chmod 444 "$CFG/config/a.kdl"
    run_refresh_e "$COMMIT_A" "$COMMIT_B" niri
    check "readonly_unedited_file_kept_and_listed" '[ "$REFRESH_RC" = 0 ] && [ "$(cat "$CFG/config/a.kdl")" = "a A" ] && listed "$CFG/config/a.kdl"'
    check "readonly_file_later_files_processed" '[ "$(cat "$CFG/config/b.kdl")" = "$(printf "b B\nmore")" ] && [ "$(cat "$CFG/config/new.kdl")" = "new B" ]'
    chmod 644 "$CFG/config/a.kdl"

    reset_cfg
    chmod 444 "$CFG/config/a.kdl"; chmod 555 "$CFG/config"
    run_refresh_e "$COMMIT_A" "$COMMIT_B" niri
    check "unwritable_dir_survives" '[ "$REFRESH_RC" = 0 ]'
    check "unwritable_dir_files_unchanged_and_listed" '[ "$(cat "$CFG/config/a.kdl")" = "a A" ] && [ "$(cat "$CFG/config/b.kdl")" = "b A" ] && [ -e "$CFG/config/gone.kdl" ] && [ ! -e "$CFG/config/new.kdl" ] && listed "$CFG/config/a.kdl" && listed "$CFG/config/b.kdl" && listed "$CFG/config/new.kdl" && listed "$CFG/config/gone.kdl"'
    check "unwritable_dir_no_temp_files" '[ -z "$(find "$CFG" -name ".*" ! -path "$CFG" | head -1)" ]'
    chmod 755 "$CFG/config"
else
    echo "skip  unwritable-file checks (running as root)"
fi

# ---- hyprland: hyprland.lua is only refreshed when config/custom.lua is ours ----
# hypr_verify <hyprland.lua>: 0 when Hyprland is not installed or says "config ok".
hypr_verify() {
    command -v Hyprland >/dev/null 2>&1 || return 0
    local run
    run="$(mktemp -d "$SANDBOX/run.XXXXXX")" && chmod 700 "$run" || return 1
    env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$run" \
        timeout 60 Hyprland --verify-config -c "$1" 2>&1 | grep -q '^config ok'
}
command -v Hyprland >/dev/null 2>&1 || echo "skip  Hyprland not installed: --verify-config checks are skipped"

HREPO="$SANDBOX/hrepo"
hg() { git -C "$HREPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
mkdir -p "$HREPO/compositors/hyprland"
git -C "$HREPO" init -q
# A: the release before custom overrides (no helper, no custom lines); B: this tree.
cp -r "$REPO_ROOT/compositors/hyprland/." "$HREPO/compositors/hyprland/"
rm "$HREPO/compositors/hyprland/config/custom.lua"
cp "$REPO_ROOT/install/tests/fixtures/custom_overrides/hyprland.main" "$HREPO/compositors/hyprland/hyprland.lua"
hg add -A; hg commit -q -m A
H_A=$(hg rev-parse HEAD)
cp -r "$REPO_ROOT/compositors/hyprland/." "$HREPO/compositors/hyprland/"
hg add -A; hg commit -q -m B
H_B=$(hg rev-parse HEAD)
HCFG="$HOME/.config/hypr"
H_OLD_MAIN="$REPO_ROOT/install/tests/fixtures/custom_overrides/hyprland.main"
H_NEW_MAIN="$REPO_ROOT/compositors/hyprland/hyprland.lua"
reset_hypr() {
    rm -rf "$HOME/.config"
    mkdir -p "$HCFG"
    git -C "$HREPO" archive "$H_A" compositors/hyprland | tar -x -C "$HCFG" --strip-components=2
    COMPOSITOR_EDITED_FILES=()
}

reset_hypr
REPO="$HREPO" run_refresh_e "$H_A" "$H_B" hyprland
check "hypr_unedited_refreshed" '[ "$REFRESH_RC" = 0 ] && cmp -s "$HCFG/hyprland.lua" "$H_NEW_MAIN" && cmp -s "$HCFG/config/custom.lua" "$REPO_ROOT/compositors/hyprland/config/custom.lua" && [ ${#COMPOSITOR_EDITED_FILES[@]} -eq 0 ]'
check "hypr_unedited_refreshed_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# Trigger A: config/ is a symlink, so the helper can't be written there.
reset_hypr
mv "$HCFG/config" "$SANDBOX/hconf"; ln -s "$SANDBOX/hconf" "$HCFG/config"
REPO="$HREPO" run_refresh_e "$H_A" "$H_B" hyprland
check "hypr_symlinked_config_keeps_main" '[ "$REFRESH_RC" = 0 ] && cmp -s "$HCFG/hyprland.lua" "$H_OLD_MAIN" && listed "$HCFG/hyprland.lua" && [ ! -e "$SANDBOX/hconf/custom.lua" ]'
check "hypr_symlinked_config_verifies" 'hypr_verify "$HCFG/hyprland.lua"'
rm -f "$HCFG/config"; rm -rf "$SANDBOX/hconf"

# Trigger B: the user already has their own config/custom.lua.
reset_hypr
printf 'return true\n' > "$HCFG/config/custom.lua"
REPO="$HREPO" run_refresh_e "$H_A" "$H_B" hyprland
check "hypr_user_custom_lua_keeps_main" '[ "$REFRESH_RC" = 0 ] && cmp -s "$HCFG/hyprland.lua" "$H_OLD_MAIN" && [ "$(cat "$HCFG/config/custom.lua")" = "return true" ] && listed "$HCFG/hyprland.lua" && listed "$HCFG/config/custom.lua"'
check "hypr_user_custom_lua_verifies" 'hypr_verify "$HCFG/hyprland.lua"'

# A helper that still starts with the marker counts as ours, even if edited.
reset_hypr
mkdir -p "$HCFG/config"
{ cat "$REPO_ROOT/compositors/hyprland/config/custom.lua"; echo "-- my note"; } > "$HCFG/config/custom.lua"
REPO="$HREPO" run_refresh_e "$H_A" "$H_B" hyprland
check "hypr_marked_helper_counts_as_ours" '[ "$REFRESH_RC" = 0 ] && cmp -s "$HCFG/hyprland.lua" "$H_NEW_MAIN" && listed "$HCFG/config/custom.lua" && ! listed "$HCFG/hyprland.lua"'

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
