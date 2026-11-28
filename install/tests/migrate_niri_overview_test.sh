#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SCRIPT="$REPO_ROOT/src/scripts/migrate_niri_overview.sh"
SANDBOX="$(mktemp -d)"
STUBS="$SANDBOX/stubs"
REAL_PATH="$PATH"
trap 'rm -rf "$SANDBOX"' EXIT

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

mkdir -p "$STUBS"
export SERPANTINUM_DIR="$REPO_ROOT/src"
export XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -p "$XDG_RUNTIME_DIR"

reset_home() {
    export HOME="$SANDBOX/home-$1"
    export XDG_CONFIG_HOME="$HOME/.config"
    NIRI_DIR="$XDG_CONFIG_HOME/niri"
    CONFIG="$NIRI_DIR/config.kdl"
    MARKER="$HOME/.local/state/serpantinum/niri-overview-migrated"
    mkdir -p "$NIRI_DIR"
}

rule_count() {
    grep -rho --include='*.kdl' 'wallpaper-overview' "$NIRI_DIR" | wc -l
}

if command -v niri >/dev/null 2>&1; then
    echo "== an updated user whose config lacks the rule"
    reset_home update
    cp -r "$REPO_ROOT/compositors/niri/." "$NIRI_DIR/"
    sed -i '/^layer-rule {/,/^}/d' "$NIRI_DIR/config/layout.kdl"
    original="$(cat "$CONFIG")"
    original_lines="$(wc -l < "$CONFIG")"
    bash "$SCRIPT"
    check "the rule is added once" "[ \"\$(rule_count)\" -eq 1 ]"
    check "it lands in the main config" "grep -q 'place-within-backdrop true' '$CONFIG'"
    check "the existing config is kept" "[ \"\$(head -n "$original_lines" '$CONFIG')\" = \"\$original\" ]"
    check "the result is a valid niri config" "niri validate -c '$CONFIG' >/dev/null 2>&1"
    check "no temp file is left behind" "[ -z \"\$(ls -A '$NIRI_DIR' | grep serpantinum)\" ]"
    check "a marker is written" "[ -f '$MARKER' ]"
    rm -f "$MARKER"
    bash "$SCRIPT"
    check "a rerun without the marker does not duplicate the rule" "[ \"\$(rule_count)\" -eq 1 ]"

    echo "== a fresh install that already ships the rule"
    reset_home fresh
    cp -r "$REPO_ROOT/compositors/niri/." "$NIRI_DIR/"
    before="$(cat "$CONFIG")"
    bash "$SCRIPT"
    check "the config is untouched" "[ \"\$(cat '$CONFIG')\" = \"\$before\" ] && [ \"\$(rule_count)\" -eq 1 ]"
    check "a marker is written" "[ -f '$MARKER' ]"

    echo "== a config that niri rejects"
    reset_home broken
    printf 'layout {\n' > "$CONFIG"
    bash "$SCRIPT"
    check "the config is untouched" "[ \"\$(cat '$CONFIG')\" = 'layout {' ]"
    check "no temp file is left behind" "[ -z \"\$(ls -A '$NIRI_DIR' | grep serpantinum)\" ]"
    check "a marker is written" "[ -f '$MARKER' ]"
else
    echo "skip  niri is not installed; real-config cases not run"
fi

printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/niri"
chmod +x "$STUBS/niri"
export PATH="$STUBS:$REAL_PATH"

echo "== a symlinked config"
reset_home link
printf 'layout {}\n' > "$SANDBOX/dotfiles.kdl"
ln -s "$SANDBOX/dotfiles.kdl" "$CONFIG"
bash "$SCRIPT"
check "the link target is not edited" "[ \"\$(cat '$SANDBOX/dotfiles.kdl')\" = 'layout {}' ] && [ -L '$CONFIG' ]"
check "a marker is written" "[ -f '$MARKER' ]"

echo "== no niri config yet"
reset_home none
rmdir "$NIRI_DIR"
bash "$SCRIPT"
check "nothing is created" "[ ! -e '$NIRI_DIR' ]"
check "no marker, so a later niri setup is still migrated" "[ ! -f '$MARKER' ]"

echo "$([ "$failures" -eq 0 ] && echo 'all passed' || echo "$failures FAILED")"
[ "$failures" -eq 0 ]
