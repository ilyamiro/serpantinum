#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SDDM_FUNCS="$(
    sed -n '/^find_sddm_binary()/,/^}/p;/^sddm_packages()/,/^}/p' "$REPO_ROOT/install/modules/deps.sh"
    sed -n '/^resolve_sddm_backend()/,/^}/p;/^setup_sddm()/,/^}/p' "$REPO_ROOT/install/modules/deploy.sh"
)"
eval "$SDDM_FUNCS"

pass_count=0
fail_count=0

pass() {
    printf "  \e[32m✔ PASS\e[0m: %s\n" "$1"
    pass_count=$((pass_count + 1))
}

fail() {
    printf "  \e[31m✘ FAIL\e[0m: %s\n" "$1"
    shift
    printf "      %s\n" "$@"
    fail_count=$((fail_count + 1))
}

# Creates $1/sddm (what SDDM can see) and $1/user (only on the installer's
# PATH). A binary named "user:foo" goes into the second one.
make_bins() {
    local dir="$1" bin
    shift
    mkdir -p "$dir/sddm" "$dir/user"
    for bin in "$@"; do
        if [[ "$bin" == user:* ]]; then
            bin="user/${bin#user:}"
        else
            bin="sddm/$bin"
        fi
        touch "$dir/$bin"
        chmod +x "$dir/$bin"
    done
}

# Prints the value of key $3 inside section [$2] of file $1.
conf_value() {
    awk -v section="[$2]" -v key="$3=" '
        /^\[/ { current = $0; next }
        current == section && index($0, key) == 1 { print substr($0, length(key) + 1) }
    ' "$1"
}

# Expected commands use @BIN@ for the directory SDDM sees.
run_test() {
    local name="$1"
    local wayland_flag="$2"
    local expected_srv="$3"
    local expected_cmd="$4"
    shift 4

    local tmpdir
    tmpdir="$(mktemp -d)"
    make_bins "$tmpdir" "$@"
    expected_cmd="${expected_cmd//@BIN@/$tmpdir/sddm}"

    local srv="" cmd="" output=""
    if output=$(PATH="$tmpdir/user:$PATH" SDDM_SEARCH_PATH="$tmpdir/sddm" resolve_sddm_backend "$wayland_flag" 2>/dev/null); then
        {
            read -r srv || true
            read -r cmd || true
        } <<< "$output"
    fi

    rm -rf "$tmpdir"

    if [[ "$srv" == "$expected_srv" && "$cmd" == "$expected_cmd" ]]; then
        pass "$name"
    else
        fail "$name" \
            "Expected: server='$expected_srv' cmd='$expected_cmd'" \
            "Got:      server='$srv' cmd='$cmd'"
    fi
}

run_fail_test() {
    local name="$1"
    local wayland_flag="$2"
    shift 2

    local tmpdir
    tmpdir="$(mktemp -d)"
    make_bins "$tmpdir" "$@"

    if PATH="$tmpdir/user:$PATH" SDDM_SEARCH_PATH="$tmpdir/sddm" resolve_sddm_backend "$wayland_flag" >/dev/null 2>&1; then
        fail "$name" "Expected failure, but succeeded"
    else
        pass "$name"
    fi

    rm -rf "$tmpdir"
}

# Runs the real setup_sddm under `set -e`, like install.sh does, with sudo
# redirected into a temp root. The installer must keep going in every case.
# An empty expected server means no config may be written.
run_setup_test() {
    local name="$1"
    local wayland_flag="$2"
    local expected_srv="$3"
    local expected_cmd="$4"
    shift 4

    local tmpdir
    tmpdir="$(mktemp -d)"
    make_bins "$tmpdir" "$@"
    expected_cmd="${expected_cmd//@BIN@/$tmpdir/sddm}"

    local status=0
    SDDM_FUNCS="$SDDM_FUNCS" SDDM_SEARCH_PATH="$tmpdir/sddm" bash -e -c '
        root="$1" wayland_flag="$2"
        eval "$SDDM_FUNCS"
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
        setup_sddm "$root/project" fresh false
    ' _ "$tmpdir" "$wayland_flag" >/dev/null 2>&1 || status=$?

    local conf="$tmpdir/etc/sddm.conf.d/10-material-you.conf"
    local theme="" srv="" cmd=""
    if [[ -f "$conf" ]]; then
        theme="$(conf_value "$conf" Theme Current)"
        srv="$(conf_value "$conf" General DisplayServer)"
        cmd="$(conf_value "$conf" Wayland CompositorCommand)"
    fi

    rm -rf "$tmpdir"

    local expected_theme=""
    [[ -n "$expected_srv" ]] && expected_theme="material-you"

    if [[ "$status" -eq 0 && "$theme" == "$expected_theme" && "$srv" == "$expected_srv" && "$cmd" == "$expected_cmd" ]]; then
        pass "$name"
    else
        fail "$name" \
            "Expected: exit=0 theme='$expected_theme' server='$expected_srv' cmd='$expected_cmd'" \
            "Got:      exit=$status theme='$theme' server='$srv' cmd='$cmd'"
    fi
}

run_packages_test() {
    local name="$1"
    local wayland_flag="$2"
    local expect_weston="$3"
    shift 3

    local tmpdir
    tmpdir="$(mktemp -d)"
    make_bins "$tmpdir" "$@"

    local pkgs
    # shellcheck disable=SC2034 # read by sddm_packages
    local PM_SDDM_EXTRA_PKGS=()
    pkgs="$(PATH="$tmpdir/user:$PATH" SDDM_SEARCH_PATH="$tmpdir/sddm" SDDM_WAYLAND="$wayland_flag" sddm_packages | tr '\n' ' ')"

    rm -rf "$tmpdir"

    local has_weston=no
    [[ " $pkgs" == *" weston "* ]] && has_weston=yes

    if [[ "$has_weston" == "$expect_weston" && " $pkgs" == " sddm qt6-declarative qt6-svg "* ]]; then
        pass "$name"
    else
        fail "$name" "Expected weston: $expect_weston" "Got packages: $pkgs"
    fi
}

echo "Running SDDM backend resolution tests..."

run_test "Wayland requested with kwin_wayland" \
    true "wayland" "@BIN@/kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland"

run_test "Wayland requested with weston" \
    true "wayland" "@BIN@/weston --shell=kiosk" \
    "weston"

run_test "Wayland requested with both kwin and weston (prefers kwin)" \
    true "wayland" "@BIN@/kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland" "weston"

run_test "Wayland requested without Wayland compositor (fallback to Xorg)" \
    true "x11" "" \
    "Xorg"

run_test "Wayland requested with weston only on the user PATH (fallback to Xorg)" \
    true "x11" "" \
    "user:weston" "Xorg"

run_fail_test "Wayland requested with neither Wayland compositor nor Xorg (returns error)" \
    true

run_test "X11 requested with Xorg" \
    false "x11" "" \
    "Xorg"

run_test "X11 requested with only the X symlink" \
    false "x11" "" \
    "X"

run_test "X11 requested without Xorg (fallback to kwin_wayland)" \
    false "wayland" "@BIN@/kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland"

run_test "X11 requested without Xorg (fallback to weston)" \
    false "wayland" "@BIN@/weston --shell=kiosk" \
    "weston"

run_fail_test "X11 requested with nothing available (returns error)" \
    false

run_fail_test "X11 requested with Xorg only on the user PATH (returns error)" \
    false "user:Xorg"

echo "Running setup_sddm tests under set -e..."

run_setup_test "setup_sddm writes X11 config" \
    false "x11" "" \
    "Xorg"

run_setup_test "setup_sddm falls back to X11 when no Wayland compositor exists" \
    true "x11" "" \
    "Xorg"

run_setup_test "setup_sddm writes Wayland config with weston" \
    true "wayland" "@BIN@/weston --shell=kiosk" \
    "weston" "Xorg"

run_setup_test "setup_sddm writes Wayland config with kwin_wayland" \
    true "wayland" "@BIN@/kwin_wayland --no-global-shortcuts --no-lockscreen --locale1" \
    "kwin_wayland" "weston"

run_setup_test "setup_sddm skips without touching config when nothing is available" \
    true "" ""

echo "Running SDDM package list tests..."

run_packages_test "Wayland without a compositor adds weston" \
    true yes

run_packages_test "Wayland with kwin_wayland does not add weston" \
    true no "kwin_wayland"

run_packages_test "Wayland with weston does not add it again" \
    true no "weston"

run_packages_test "Wayland with weston only on the user PATH adds weston" \
    true yes "user:weston"

run_packages_test "X11 does not add weston" \
    false no

echo "--------------------------------------------------"
echo "Tests completed: $pass_count passed, $fail_count failed"

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
