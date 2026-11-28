#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

run_state_and_version() {
    local home_dir="$1"
    HOME="$home_dir" \
    XDG_CONFIG_HOME="$home_dir/.config" \
    XDG_STATE_HOME="$home_dir/.local/state" \
    SERPANTINUM_DIR="$REPO_ROOT/src" \
    REPO_ROOT="$REPO_ROOT" \
    bash -c '
        unset QS_STATE_DIR SERPANTINUM_VERSION
        source "'"$REPO_ROOT"'/install/modules/state.sh"
        source "'"$REPO_ROOT"'/install/modules/version.sh"
        printf "%s|%s\n" "$(detect_install_state)" "$(get_installed_version)"
    '
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

H="$TMP_ROOT/fresh"
mkdir -p "$H"
assert_eq "fresh install returns fresh and empty old version" "fresh|" "$(run_state_and_version "$H")"

H="$TMP_ROOT/generic_hypr_json"
mkdir -p "$H/.config/hypr"
printf '{}\n' > "$H/.config/hypr/settings.json"
assert_eq "standalone hypr settings.json is not legacy" "fresh|" "$(run_state_and_version "$H")"

H="$TMP_ROOT/legacy_with_version"
mkdir -p "$H/.local/state"
printf 'LOCAL_VERSION="1.9.4"\n' > "$H/.local/state/imperative-dots-version"
assert_eq "legacy with 1.x imperative-dots-version" "legacy|1.9.4" "$(run_state_and_version "$H")"

H="$TMP_ROOT/legacy_with_v_prefix"
mkdir -p "$H/.local/state"
printf 'LOCAL_VERSION="v1.4.2"\n' > "$H/.local/state/imperative-dots-version"
assert_eq "legacy strips leading v from 1.x version" "legacy|1.4.2" "$(run_state_and_version "$H")"

H="$TMP_ROOT/legacy_with_non_1x"
mkdir -p "$H/.local/state"
printf 'LOCAL_VERSION="2.5.3"\n' > "$H/.local/state/imperative-dots-version"
assert_eq "legacy rejects non-1.x version in marker" "legacy|" "$(run_state_and_version "$H")"

H="$TMP_ROOT/legacy_watcher_only"
mkdir -p "$H/.config/hypr/scripts"
touch "$H/.config/hypr/scripts/settings_watcher.sh"
assert_eq "legacy watcher without version file returns empty old version" "legacy|" "$(run_state_and_version "$H")"

H="$TMP_ROOT/current_install"
mkdir -p "$H/.local/state/serpantinum"
printf 'SERPANTINUM_VERSION="2.5.2"\n' > "$H/.local/state/serpantinum/version"
assert_eq "current install reads installed 2.x version" "current|2.5.2" "$(run_state_and_version "$H")"

H="$TMP_ROOT/migrate_cleanup"
mkdir -p "$H/.local/state" "$H/.config/hypr/scripts"
printf 'LOCAL_VERSION="1.8.0"\n' > "$H/.local/state/imperative-dots-version"
printf '#!/usr/bin/env bash\n' > "$H/.config/hypr/scripts/settings_watcher.sh"
HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" bash -c '
    pm_remove_conflicting_pkg() { :; }
    source "'"$REPO_ROOT"'/install/modules/migrate.sh"
    migrate_legacy hyprland
'
assert_eq "after migrate_legacy without v2 version file, state is fresh not legacy" "fresh|" "$(run_state_and_version "$H")"

MOCK_BIN="$TMP_ROOT/bin"
PAYLOAD_FILE="$TMP_ROOT/payload.json"
mkdir -p "$MOCK_BIN"
cat <<'EOF' > "$MOCK_BIN/curl"
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "-d" ]]; then
        printf '%s' "$2" > "$MOCK_PAYLOAD_FILE"
        exit 0
    fi
    shift
done
EOF
chmod +x "$MOCK_BIN/curl"

run_telemetry() {
    rm -f "$PAYLOAD_FILE"
    PATH="$MOCK_BIN:$PATH" MOCK_PAYLOAD_FILE="$PAYLOAD_FILE" \
        bash "$REPO_ROOT/install/modules/telemetry.sh" \
        --mode done \
        --version "$1" \
        --old-version "$2" \
        --install-state "$3" \
        --compositor "hyprland" \
        --id "1033a555-8580-43ba-893a-07abbb58f633" \
        --os "CachyOS" \
        --enabled true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$PAYLOAD_FILE" ] && break
        sleep 0.05
    done
    jq -r '.install_state + "|" + .old_version + "|" + .version' "$PAYLOAD_FILE"
}

assert_eq "telemetry strips 2.5.3 old_version on legacy" "legacy||2.5.3" "$(run_telemetry "2.5.3" "2.5.3" "legacy")"
assert_eq "telemetry keeps 1.x old_version on legacy" "legacy|1.9.4|2.5.3" "$(run_telemetry "2.5.3" "1.9.4" "legacy")"
assert_eq "telemetry strips old_version on fresh" "fresh||2.5.3" "$(run_telemetry "2.5.3" "2.5.3" "fresh")"
assert_eq "telemetry preserves old_version on current update" "current|2.5.2|2.5.3" "$(run_telemetry "2.5.3" "2.5.2" "current")"
assert_eq "telemetry preserves old_version on current reinstall" "current|2.5.3|2.5.3" "$(run_telemetry "2.5.3" "2.5.3" "current")"

echo "Passed: $PASS, Failed: $FAIL"
[ "$FAIL" -eq 0 ]
