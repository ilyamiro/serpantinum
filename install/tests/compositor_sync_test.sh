#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

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

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
