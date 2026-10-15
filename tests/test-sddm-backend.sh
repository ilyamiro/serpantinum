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

# Runs the real setup_sddm under `set -e`, like install.sh does, with sudo
# redirected into a temp root. The installer must keep going in every case.
run_setup_test() {
    local name="$1"
    local wayland_flag="$2"
    local expected_srv="$3"
    local expected_cmd="$4"
    shift 4
    local mock_binaries=("$@")

    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/bin"
    for bin in "${mock_binaries[@]}"; do
        touch "$tmpdir/bin/$bin"
        chmod +x "$tmpdir/bin/$bin"
    done
    for bin in cat tee rm mkdir cp chmod date; do
        ln -s "$(command -v "$bin")" "$tmpdir/bin/$bin"
    done

    local status=0
    bash -e -c '
        repo_root="$1" root="$2" wayland_flag="$3"
        eval "$(sed -n "/^resolve_sddm_backend()/,/^}/p;/^setup_sddm()/,/^}/p" "$repo_root/install/modules/deploy.sh")"
        t() { echo "$1"; }
        sudo() {
            local args=() arg
            for arg in "$@"; do
                arg="${arg//\/etc/$root/etc}"
                args+=("${arg//\/usr\/share/$root/usr/share}")
            done
            "${args[@]}"
        }
        pm_is_installed() { return 1; }
        pm_remove_pkg() { :; }
        enable_system_service() { :; }
        OPT_SDDM=true SDDM_WAYLAND="$wayland_flag" REPLACE_DM=true PM_SDDM_CURSOR_FIX=false
        PATH="$root/bin"
        setup_sddm "$root/project" fresh false
    ' _ "$REPO_ROOT" "$tmpdir" "$wayland_flag" >/dev/null 2>&1 || status=$?

    local conf="$tmpdir/etc/sddm.conf.d/10-material-you.conf"
    local srv="" cmd=""
    if [[ -f "$conf" ]]; then
        srv="$(sed -n 's/^DisplayServer=//p' "$conf")"
        cmd="$(sed -n 's/^CompositorCommand=//p' "$conf")"
    fi

    rm -rf "$tmpdir"

    if [[ "$status" -eq 0 && "$srv" == "$expected_srv" && "$cmd" == "$expected_cmd" ]]; then
        printf "  \e[32m✔ PASS\e[0m: %s\n" "$name"
        pass_count=$((pass_count + 1))
    else
        printf "  \e[31m✘ FAIL\e[0m: %s\n" "$name"
        printf "      Expected: exit=0 server='%s' cmd='%s'\n" "$expected_srv" "$expected_cmd"
        printf "      Got:      exit=%s server='%s' cmd='%s'\n" "$status" "$srv" "$cmd"
        fail_count=$((fail_count + 1))
    fi
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

echo "Running setup_sddm tests under set -e..."

run_setup_test "setup_sddm writes X11 config" \
    false "x11" "" \
    "Xorg"

run_setup_test "setup_sddm falls back to X11 when no Wayland compositor exists" \
    true "x11" "" \
    "Xorg"

run_setup_test "setup_sddm writes Wayland config with weston" \
    true "wayland" "weston --shell=kiosk" \
    "weston" "Xorg"

run_setup_test "setup_sddm writes Wayland config with kwin_wayland" \
    true "wayland" "kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland" "weston"

run_setup_test "setup_sddm skips without touching config when nothing is available" \
    true "" ""

echo "--------------------------------------------------"
echo "Tests completed: $pass_count passed, $fail_count failed"

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
