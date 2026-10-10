#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

eval "$(sed -n '/^resolve_sddm_backend()/,/^}/p' "$REPO_ROOT/install/modules/deploy.sh")"

pass_count=0
fail_count=0

run_test() {
    local name="$1"
    local wayland_flag="$2"
    local expected_srv="$3"
    local expected_cmd="$4"
    shift 4
    local mock_binaries=("$@")

    local tmpdir
    tmpdir="$(mktemp -d)"
    for bin in "${mock_binaries[@]}"; do
        touch "$tmpdir/$bin"
        chmod +x "$tmpdir/$bin"
    done

    local srv="" cmd=""
    local output=""
    if output=$(PATH="$tmpdir" resolve_sddm_backend "$wayland_flag" 2>/dev/null); then
        {
            read -r srv || true
            read -r cmd || true
        } <<< "$output"
    fi

    rm -rf "$tmpdir"

    if [[ "$srv" == "$expected_srv" && "$cmd" == "$expected_cmd" ]]; then
        printf "  \e[32m✔ PASS\e[0m: %s\n" "$name"
        pass_count=$((pass_count + 1))
    else
        printf "  \e[31m✘ FAIL\e[0m: %s\n" "$name"
        printf "      Expected: server='%s' cmd='%s'\n" "$expected_srv" "$expected_cmd"
        printf "      Got:      server='%s' cmd='%s'\n" "$srv" "$cmd"
        fail_count=$((fail_count + 1))
    fi
}

run_fail_test() {
    local name="$1"
    local wayland_flag="$2"
    shift 2
    local mock_binaries=("$@")

    local tmpdir
    tmpdir="$(mktemp -d)"
    for bin in "${mock_binaries[@]}"; do
        touch "$tmpdir/$bin"
        chmod +x "$tmpdir/$bin"
    done

    if PATH="$tmpdir" resolve_sddm_backend "$wayland_flag" >/dev/null 2>&1; then
        printf "  \e[31m✘ FAIL\e[0m: %s (expected failure, but succeeded)\n" "$name"
        fail_count=$((fail_count + 1))
    else
        printf "  \e[32m✔ PASS\e[0m: %s\n" "$name"
        pass_count=$((pass_count + 1))
    fi

    rm -rf "$tmpdir"
}

echo "Running SDDM backend resolution tests..."

run_test "Wayland requested with kwin_wayland" \
    true "wayland" "kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland"

run_test "Wayland requested with weston" \
    true "wayland" "weston --shell=kiosk" \
    "weston"

run_test "Wayland requested with both kwin and weston (prefers kwin)" \
    true "wayland" "kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland" "weston"

run_test "Wayland requested without Wayland compositor (fallback to Xorg)" \
    true "x11" "" \
    "Xorg"

run_fail_test "Wayland requested with neither Wayland compositor nor Xorg (returns error)" \
    true

run_test "X11 requested with Xorg" \
    false "x11" "" \
    "Xorg"

run_test "X11 requested without Xorg (fallback to kwin_wayland)" \
    false "wayland" "kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland"

run_test "X11 requested without Xorg (fallback to weston)" \
    false "wayland" "weston --shell=kiosk" \
    "weston"

run_fail_test "X11 requested with nothing available (returns error)" \
    false

echo "--------------------------------------------------"
echo "Tests completed: $pass_count passed, $fail_count failed"

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
