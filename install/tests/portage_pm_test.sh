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

assert_ok() {
    local label="$1"
    shift
    if "$@"; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (command failed: $*)"
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local label="$1"
    shift
    if "$@"; then
        echo "FAIL: $label (expected failure, got success: $*)"
        FAIL=$((FAIL + 1))
    else
        PASS=$((PASS + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (missing '$needle' in '$haystack')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (unexpected '$needle' in '$haystack')"
        FAIL=$((FAIL + 1))
    fi
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

TOOLS_BIN="$TMP_ROOT/tools"
mkdir -p "$TOOLS_BIN"
for tool in bash cat cp sed grep mkdir rmdir rm mv sleep seq dirname realpath id jq touch ln chmod readlink xargs tr cut head awk wc basename env date uname find sort tee printf test; do
    if path="$(command -v "$tool" 2>/dev/null)"; then
        ln -sf "$path" "$TOOLS_BIN/$tool"
    fi
done

setup_sandbox() {
    local sb="$TMP_ROOT/$1"
    rm -rf "$sb"
    mkdir -p "$sb/bin" "$sb/vdb" "$sb/portage" "$sb/conf.d" "$sb/init.d" "$sb/state" "$sb/home"
    : > "$sb/calls.log"
    : > "$sb/enabled_repos"
    : > "$sb/portageq_repos"
    : > "$sb/rc_enabled"
    : > "$sb/rc_active"
    : > "$sb/systemd_enabled"
    : > "$sb/systemd_active"

    cat > "$sb/bin/sudo" <<'EOF'
#!/usr/bin/env bash
while [[ "${1:-}" == -* ]]; do
    shift
done
exec "$@"
EOF

    cat > "$sb/bin/emerge" <<'EOF'
#!/usr/bin/env bash
echo "emerge $*" >> "$MOCK_STATE/calls.log"
if [[ "${MOCK_EMERGE_FAIL:-0}" == "1" ]]; then
    exit 1
fi
for arg in "$@"; do
    if [[ "$arg" == "app-eselect/eselect-repository" && -n "${MOCK_INSTALL_ESELECT_TARGET:-}" ]]; then
        cat > "$MOCK_INSTALL_ESELECT_TARGET" <<'EOS'
#!/usr/bin/env bash
echo "eselect $*" >> "$MOCK_STATE/calls.log"
if [[ "$1" == "repository" && "$2" == "list" ]]; then
    if [[ "$3" == "-i" ]]; then
        cat "$MOCK_STATE/enabled_repos"
    else
        echo "Available repositories:"
        echo "  guru"
        echo "  hyproverlay"
    fi
elif [[ "$1" == "repository" && "$2" == "enable" ]]; then
    echo "$3" >> "$MOCK_STATE/enabled_repos"
fi
EOS
        chmod +x "$MOCK_INSTALL_ESELECT_TARGET"
    fi
done
EOF

    cat > "$sb/bin/eselect" <<'EOF'
#!/usr/bin/env bash
echo "eselect $*" >> "$MOCK_STATE/calls.log"
if [[ "$1" == "repository" && "$2" == "list" ]]; then
    if [[ "${3:-}" == "-i" ]]; then
        cat "$MOCK_STATE/enabled_repos"
    else
        echo "Available repositories:"
        echo "  guru"
        echo "  hyproverlay"
    fi
elif [[ "$1" == "repository" && "$2" == "enable" ]]; then
    echo "$3" >> "$MOCK_STATE/enabled_repos"
fi
EOF

    cat > "$sb/bin/emaint" <<'EOF'
#!/usr/bin/env bash
echo "emaint $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/portageq" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "envvar" && "$2" == "ARCH" ]]; then
    echo "${MOCK_ARCH:-amd64}"
    exit 0
fi
if [[ "$1" == "get_repo_path" ]]; then
    if grep -qxF "$3" "$MOCK_STATE/portageq_repos" 2>/dev/null; then
        echo "/var/db/repos/$3"
        exit 0
    fi
    exit 1
fi
exit 1
EOF

    cat > "$sb/bin/rc-update" <<'EOF'
#!/usr/bin/env bash
echo "rc-update $*" >> "$MOCK_STATE/calls.log"
if [[ "$1" == "show" ]]; then
    cat "$MOCK_STATE/rc_enabled"
elif [[ "$1" == "add" ]]; then
    printf ' %s | %s\n' "$2" "${3:-default}" >> "$MOCK_STATE/rc_enabled"
elif [[ "$1" == "del" ]]; then
    grep -vE "^[[:space:]]*$2[[:space:]]*\|" "$MOCK_STATE/rc_enabled" > "$MOCK_STATE/rc_enabled.tmp" || true
    mv "$MOCK_STATE/rc_enabled.tmp" "$MOCK_STATE/rc_enabled"
fi
EOF

    cat > "$sb/bin/rc-service" <<'EOF'
#!/usr/bin/env bash
if [[ "$2" == "status" ]]; then
    grep -qxF "$1" "$MOCK_STATE/rc_active" 2>/dev/null
    exit $?
fi
echo "rc-service $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "is-enabled" ]]; then
    grep -qxF "$2" "$MOCK_STATE/systemd_enabled" 2>/dev/null
    exit $?
fi
if [[ "$1" == "is-active" ]]; then
    grep -qxF "$2" "$MOCK_STATE/systemd_active" 2>/dev/null
    exit $?
fi
echo "systemctl $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/tar" <<'EOF'
#!/usr/bin/env bash
echo "tar $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/unzip" <<'EOF'
#!/usr/bin/env bash
echo "unzip $*" >> "$MOCK_STATE/calls.log"
EOF

    cat > "$sb/bin/fc-list" <<'EOF'
#!/usr/bin/env bash
echo "fc-list $*" >> "$MOCK_STATE/calls.log"
EOF

    chmod +x "$sb/bin/"*
    echo "$sb"
}

SB="$(setup_sandbox detect)"

cat > "$SB/os-gentoo" <<'EOF'
NAME=Gentoo
ID=gentoo
PRETTY_NAME="Gentoo Linux"
EOF
assert_eq "detect_package_manager on Gentoo" "portage" "$(
    PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-gentoo" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$SB/os-calculate" <<'EOF'
NAME="Calculate Linux"
ID=calculate
ID_LIKE=gentoo
EOF
assert_eq "detect_package_manager on Calculate derivative" "portage" "$(
    PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-calculate" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$SB/os-funtoo" <<'EOF'
ID=funtoo
EOF
assert_eq "detect_package_manager on Funtoo" "portage" "$(
    PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-funtoo" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$SB/os-unknown" <<'EOF'
ID=customdistro
EOF
assert_eq "detect_package_manager fallback with emerge in PATH" "portage" "$(
    PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-unknown" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

mkdir -p "$SB/bin_no_emerge"
assert_eq "detect_package_manager returns empty without emerge" "" "$(
    PATH="$SB/bin_no_emerge:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-gentoo" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        detect_package_manager
    '
)"

cat > "$SB/os-ubuntu" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF

assert_ok "pm_supports_os positive on Gentoo" env PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-gentoo" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'
assert_ok "pm_supports_os positive on Calculate derivative" env PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-calculate" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'
assert_fail "pm_supports_os negative on Ubuntu" env PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/os-ubuntu" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'
assert_fail "pm_supports_os negative when os-release missing" env PATH="$SB/bin:$TOOLS_BIN" OS_RELEASE_FILE="$SB/missing" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'

resolve_check() {
    local init_mode="$1"
    PATH="$SB/bin:$TOOLS_BIN" PORTAGE_INIT_SYSTEM="$init_mode" bash -c '
        source "'"$REPO_ROOT"'/install/modules/deps.sh"
        source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
        all=(
            "${REQUIRED_PKGS[@]}"
            "${PM_EXTRA_PKGS[@]}"
            "${PM_SDDM_EXTRA_PKGS[@]}"
            "${PM_AUDIO_BUILD_PKGS[@]}"
            "${PM_BOOTSTRAP_TOOLS[@]}"
            sddm qt6-declarative qt6-svg weston
            hyprland niri sway mangowm umbriel
        )
        bad=0
        for p in "${all[@]}"; do
            atom="$(pm_resolve_name "$p")"
            if [[ ! "$atom" =~ ^[a-z0-9-]+/[a-zA-Z0-9+_.-]+(:[0-9]+)?$ ]]; then
                echo "UNMAPPED:$p->$atom"
                bad=1
            fi
        done
        echo "BAD=$bad"
        echo "EXTRA=${PM_EXTRA_PKGS[*]}"
        echo "SDDM=${PM_SDDM_EXTRA_PKGS[*]}"
    '
}

OUT_OPENRC="$(resolve_check openrc)"
assert_contains "all packages resolve to valid category/pkg on openrc" "BAD=0" "$OUT_OPENRC"
assert_contains "openrc PM_EXTRA_PKGS includes elogind" "elogind" "$OUT_OPENRC"
assert_contains "openrc PM_SDDM_EXTRA_PKGS includes display-manager-init" "display-manager-init" "$OUT_OPENRC"

OUT_SYSTEMD="$(resolve_check systemd)"
assert_contains "all packages resolve to valid category/pkg on systemd" "BAD=0" "$OUT_SYSTEMD"
assert_not_contains "systemd PM_EXTRA_PKGS omits elogind" "elogind" "$OUT_SYSTEMD"
assert_not_contains "systemd PM_SDDM_EXTRA_PKGS omits display-manager-init" "display-manager-init" "$OUT_SYSTEMD"

SPOT_RESOLVE="$(PATH="$SB/bin:$TOOLS_BIN" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    for p in sddm wf-recorder weston qt6ct make adw-gtk-theme tesseract-data-eng qt6-multimedia qt6-wayland qt6-declarative qt6-svg hyprland mangowm matugen quickshell cliphist; do
        printf "%s=%s\n" "$p" "$(pm_resolve_name "$p")"
    done
')"
assert_contains "sddm maps to gui-apps/sddm" "sddm=gui-apps/sddm" "$SPOT_RESOLVE"
assert_contains "wf-recorder maps to gui-apps/wf-recorder" "wf-recorder=gui-apps/wf-recorder" "$SPOT_RESOLVE"
assert_contains "weston maps to dev-libs/weston" "weston=dev-libs/weston" "$SPOT_RESOLVE"
assert_contains "qt6ct maps to gui-apps/qt6ct" "qt6ct=gui-apps/qt6ct" "$SPOT_RESOLVE"
assert_contains "make maps to dev-build/make" "make=dev-build/make" "$SPOT_RESOLVE"
assert_contains "adw-gtk-theme maps to x11-themes/adw-gtk3" "adw-gtk-theme=x11-themes/adw-gtk3" "$SPOT_RESOLVE"
assert_contains "tesseract-data-eng maps to app-text/tessdata_fast" "tesseract-data-eng=app-text/tessdata_fast" "$SPOT_RESOLVE"
assert_contains "qt6-multimedia maps to dev-qt/qtmultimedia:6" "qt6-multimedia=dev-qt/qtmultimedia:6" "$SPOT_RESOLVE"
assert_contains "qt6-wayland maps to dev-qt/qtwayland:6" "qt6-wayland=dev-qt/qtwayland:6" "$SPOT_RESOLVE"
assert_contains "qt6-declarative maps to dev-qt/qtdeclarative:6" "qt6-declarative=dev-qt/qtdeclarative:6" "$SPOT_RESOLVE"
assert_contains "qt6-svg maps to dev-qt/qtsvg:6" "qt6-svg=dev-qt/qtsvg:6" "$SPOT_RESOLVE"
assert_contains "hyprland maps to gui-wm/hyprland" "hyprland=gui-wm/hyprland" "$SPOT_RESOLVE"
assert_contains "mangowm maps to gui-wm/mangowm" "mangowm=gui-wm/mangowm" "$SPOT_RESOLVE"

SB="$(setup_sandbox vdb)"
mkdir -p "$SB/vdb/x11-terms/kitty-terminfo-0.37.0"
mkdir -p "$SB/vdb/dev-qt/qtmultimedia-5.15.14"
echo "5/5.15" > "$SB/vdb/dev-qt/qtmultimedia-5.15.14/SLOT"
mkdir -p "$SB/vdb/media-video/pipewire-1.6.9"
echo "dbus bluetooth" > "$SB/vdb/media-video/pipewire-1.6.9/USE"
mkdir -p "$SB/vdb/x11-misc/matugen-3.1.0"
mkdir -p "$SB/vdb/dev-lang/python-3.13.18_p1"

assert_fail "kitty-terminfo does not falsely match kitty" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed kitty
'
assert_fail "qtmultimedia slot 5 does not satisfy qt6-multimedia" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed qt6-multimedia
'
assert_ok "pipewire without sound-server satisfies pipewire" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed pipewire
'
assert_fail "pipewire without sound-server fails pipewire-pulse" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed pipewire-pulse
'
assert_fail "pipewire without pipewire-alsa fails pipewire-alsa" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed pipewire-alsa
'
assert_fail "matugen 3.1.0 does not satisfy matugen >= 4" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed matugen
'
assert_ok "alternatives match when second alternative installed" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed "app-misc/jq|dev-lang/python"
'
assert_fail "alternatives fail when neither installed" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed "app-misc/jq|gui-apps/grim"
'

MISSING_BEFORE="$(PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_missing_pkgs kitty qt6-multimedia pipewire pipewire-pulse pipewire-alsa matugen python adw-gtk-theme
' | tr '\n' ' ')"
assert_eq "pm_missing_pkgs returns logical names only" "kitty qt6-multimedia pipewire-pulse pipewire-alsa matugen adw-gtk-theme " "$MISSING_BEFORE"

mkdir -p "$SB/vdb/x11-terms/kitty-0.49.2"
mkdir -p "$SB/vdb/dev-qt/qtmultimedia-6.11.3"
echo "6/6.11" > "$SB/vdb/dev-qt/qtmultimedia-6.11.3/SLOT"
echo "dbus bluetooth sound-server pipewire-alsa" > "$SB/vdb/media-video/pipewire-1.6.9/USE"
rm -rf "$SB/vdb/x11-misc/matugen-3.1.0"
mkdir -p "$SB/vdb/x11-misc/matugen-4.2.0"

assert_ok "kitty-0.49.2 matches kitty" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed kitty
'
assert_ok "qtmultimedia slot 6 satisfies qt6-multimedia" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed qt6-multimedia
'
assert_ok "pipewire with USE flags satisfies pipewire-pulse" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed pipewire-pulse
'
assert_ok "pipewire with USE flags satisfies pipewire-alsa" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed pipewire-alsa
'
assert_ok "matugen 4.2.0 satisfies matugen >= 4" env PATH="$SB/bin:$TOOLS_BIN" PORTAGE_VDB_DIR="$SB/vdb" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_is_installed matugen
'

SB="$(setup_sandbox bootstrap)"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_bootstrap_install python3 jq lspci pciutils fc-cache xz
'
assert_eq "pm_bootstrap_install maps and deduplicates atoms" "emerge --ask=n --noreplace --quiet-build=y dev-lang/python app-misc/jq sys-apps/pciutils media-libs/fontconfig app-arch/xz-utils" "$(cat "$SB/calls.log")"

SB="$(setup_sandbox portage_cfg_dir)"
mkdir -p "$SB/portage/package.use" "$SB/portage/package.accept_keywords"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=true bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage sway
'
USE_CONTENT="$(cat "$SB/portage/package.use/serpantinum")"
KW_CONTENT="$(cat "$SB/portage/package.accept_keywords/serpantinum")"
assert_contains "package.use has pipewire flags" "media-video/pipewire sound-server pipewire-alsa bluetooth dbus echo-cancel" "$USE_CONTENT"
assert_contains "package.use has qtmultimedia ffmpeg flag" "dev-qt/qtmultimedia qml pipewire wayland ffmpeg" "$USE_CONTENT"
assert_contains "package.use has qtbase opengl vulkan wayland flags" "dev-qt/qtbase dbus gui network opengl vulkan wayland" "$USE_CONTENT"
assert_contains "package.use has cpptrace unwind flag" "dev-cpp/cpptrace unwind" "$USE_CONTENT"
assert_contains "package.use has tesseract png flag" "app-text/tesseract png" "$USE_CONTENT"
assert_contains "package.use has sddm-gentoo-config weston when SDDM_WAYLAND=true" "gui-apps/sddm-gentoo-config weston" "$USE_CONTENT"
assert_contains "package.accept_keywords has quickshell ~amd64" "gui-apps/quickshell ~amd64" "$KW_CONTENT"
assert_contains "package.accept_keywords has cpptrace ~amd64" "dev-cpp/cpptrace ~amd64" "$KW_CONTENT"
assert_contains "package.accept_keywords has libdwarf ~amd64" "dev-libs/libdwarf ~amd64" "$KW_CONTENT"
assert_contains "package.accept_keywords has sddm-gentoo-config ~amd64" "gui-apps/sddm-gentoo-config ~amd64" "$KW_CONTENT"
assert_not_contains "sway does not write hyprland keywords" "gui-wm/hyprland" "$KW_CONTENT"
assert_not_contains "sway does not write wlroots X flag" "gui-libs/wlroots X" "$USE_CONTENT"
assert_not_contains "amd64 does not write arm64 zbar keyword" "media-gfx/zbar ~arm64" "$KW_CONTENT"

LINES_USE_1="$(wc -l < "$SB/portage/package.use/serpantinum")"
LINES_KW_1="$(wc -l < "$SB/portage/package.accept_keywords/serpantinum")"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=true bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage sway
'
assert_eq "package.use directory mode is idempotent" "$LINES_USE_1" "$(wc -l < "$SB/portage/package.use/serpantinum")"
assert_eq "package.accept_keywords directory mode is idempotent" "$LINES_KW_1" "$(wc -l < "$SB/portage/package.accept_keywords/serpantinum")"

PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="arm64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=true bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage hyprland
'
KW_HYPR="$(cat "$SB/portage/package.accept_keywords/serpantinum")"
assert_contains "hyprland writes gui-wm/hyprland keyword" "gui-wm/hyprland ~arm64" "$KW_HYPR"
assert_contains "hyprland writes dev-cpp/glaze keyword" "dev-cpp/glaze ~arm64" "$KW_HYPR"
assert_contains "hyprland writes dev-cpp/sdbus-c++ keyword" "dev-cpp/sdbus-c++ ~arm64" "$KW_HYPR"
assert_contains "hyprland writes gui-libs/aquamarine keyword" "gui-libs/aquamarine ~arm64" "$KW_HYPR"
assert_contains "arm64 writes power-profiles-daemon ~arm64" "sys-power/power-profiles-daemon ~arm64" "$KW_HYPR"
assert_contains "arm64 writes zbar ~arm64" "media-gfx/zbar ~arm64" "$KW_HYPR"

PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=true bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage mangowm umbriel
'
USE_WLR="$(cat "$SB/portage/package.use/serpantinum")"
assert_contains "mangowm/umbriel writes gui-libs/wlroots X" "gui-libs/wlroots X" "$USE_WLR"
assert_contains "mangowm writes gui-wm/mangowm X" "gui-wm/mangowm X" "$USE_WLR"

SB="$(setup_sandbox portage_cfg_file)"
printf 'app-misc/custom foo\n' > "$SB/portage/package.use"
printf 'app-misc/custom ~amd64\n' > "$SB/portage/package.accept_keywords"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=false bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage niri
'
FILE_USE="$(cat "$SB/portage/package.use")"
FILE_KW="$(cat "$SB/portage/package.accept_keywords")"
assert_contains "regular file package.use preserves existing lines" "app-misc/custom foo" "$FILE_USE"
assert_contains "regular file package.use appends pipewire" "media-video/pipewire sound-server pipewire-alsa bluetooth dbus echo-cancel" "$FILE_USE"
assert_not_contains "SDDM_WAYLAND=false omits sddm-gentoo-config weston" "gui-apps/sddm-gentoo-config weston" "$FILE_USE"
assert_contains "regular file package.accept_keywords preserves existing lines" "app-misc/custom ~amd64" "$FILE_KW"
assert_contains "regular file package.accept_keywords appends niri" "gui-wm/niri ~amd64" "$FILE_KW"

FILE_USE_COUNT="$(wc -l < "$SB/portage/package.use")"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" PORTAGE_CONFIG_DIR="$SB/portage" SDDM_WAYLAND=false bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_configure_portage niri
'
assert_eq "regular file package.use is idempotent" "$FILE_USE_COUNT" "$(wc -l < "$SB/portage/package.use")"

SB="$(setup_sandbox overlay_install_eselect)"
rm -f "$SB/bin/eselect"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_INSTALL_ESELECT_TARGET="$SB/bin/eselect" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_enable_overlay guru
' >/dev/null
CALLS_OV="$(cat "$SB/calls.log")"
assert_contains "missing eselect installs eselect-repository and git" "emerge --ask=n --noreplace --quiet-build=y app-eselect/eselect-repository dev-vcs/git" "$CALLS_OV"
assert_contains "enables guru via eselect" "eselect repository enable guru" "$CALLS_OV"
assert_contains "syncs guru via emaint" "emaint sync -r guru" "$CALLS_OV"

: > "$SB/calls.log"
echo "guru" > "$SB/portageq_repos"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    portage_enable_overlay guru
' >/dev/null
assert_eq "already enabled guru skips eselect and emaint" "" "$(cat "$SB/calls.log")"

SB="$(setup_sandbox batch)"
mkdir -p "$SB/vdb/media-video/pipewire-1.6.9"
echo "dbus" > "$SB/vdb/media-video/pipewire-1.6.9/USE"
echo "guru" > "$SB/portageq_repos"
echo "hyproverlay" >> "$SB/portageq_repos"

BATCH_LEFT_OUT="$(PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_install_batch kitty jq quickshell pipewire-pulse sway hyprland >/dev/null
    printf "%s," "${PM_BATCH_LEFT[@]}"
')"
assert_eq "pm_install_batch leaves overlay and vdb packages" "quickshell,pipewire-pulse,hyprland," "$BATCH_LEFT_OUT"
assert_contains "pm_install_batch runs single emerge for main-tree packages" "emerge --ask=n --noreplace --changed-use --quiet-build=y x11-terms/kitty app-misc/jq gui-wm/sway" "$(cat "$SB/calls.log")"

SB="$(setup_sandbox batch_fail)"
BATCH_FAIL_LEFT="$(PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_EMERGE_FAIL=1 \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_install_batch kitty jq quickshell >/dev/null
    printf "%s," "${PM_BATCH_LEFT[@]}"
')"
assert_eq "pm_install_batch failure falls back to all packages" "kitty,jq,quickshell," "$BATCH_FAIL_LEFT"

SB="$(setup_sandbox single_pkg)"
mkdir -p "$SB/vdb/media-video/pipewire-1.6.9"
echo "dbus" > "$SB/vdb/media-video/pipewire-1.6.9/USE"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_install_pkg sway
    pm_install_pkg quickshell
    pm_install_pkg pipewire-pulse
' >/dev/null
SINGLE_CALLS="$(cat "$SB/calls.log")"
assert_contains "pm_install_pkg main-tree runs --noreplace" "emerge --ask=n --noreplace --quiet-build=y gui-wm/sway" "$SINGLE_CALLS"
assert_not_contains "sway does not enable hyproverlay" "hyproverlay" "$SINGLE_CALLS"
assert_contains "pm_install_pkg overlay enables guru" "eselect repository enable guru" "$SINGLE_CALLS"
assert_contains "pm_install_pkg overlay emerges quickshell" "emerge --ask=n --noreplace --quiet-build=y gui-apps/quickshell" "$SINGLE_CALLS"
assert_contains "pm_install_pkg in-VDB package uses --update --changed-use --noreplace" "emerge --ask=n --update --changed-use --noreplace --quiet-build=y media-video/pipewire" "$SINGLE_CALLS"

: > "$SB/calls.log"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_install_pkg hyprland
' >/dev/null
HYPR_CALLS="$(cat "$SB/calls.log")"
assert_contains "hyprland enables hyproverlay" "eselect repository enable hyproverlay" "$HYPR_CALLS"
assert_contains "hyprland syncs hyproverlay" "emaint sync -r hyproverlay" "$HYPR_CALLS"
assert_contains "hyprland emerges gui-wm/hyprland" "emerge --ask=n --noreplace --quiet-build=y gui-wm/hyprland" "$HYPR_CALLS"

SB="$(setup_sandbox services_systemd)"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="systemd" bash -c '
    source "'"$REPO_ROOT"'/install/modules/service.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_setup_services systemd
'
SYS_CALLS="$(cat "$SB/calls.log")"
assert_contains "systemd enables pipewire user sockets" "systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service" "$SYS_CALLS"
assert_contains "systemd starts pipewire user sockets" "systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service" "$SYS_CALLS"
assert_contains "systemd enables NetworkManager" "systemctl enable --now NetworkManager.service" "$SYS_CALLS"
assert_contains "systemd enables bluetooth" "systemctl enable --now bluetooth.service" "$SYS_CALLS"
assert_contains "systemd enables power-profiles-daemon" "systemctl enable --now power-profiles-daemon.service" "$SYS_CALLS"

SB="$(setup_sandbox services_openrc)"
rm -f "$SB/bin/systemctl"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="openrc" PORTAGE_INIT_D_DIR="$SB/init.d" bash -c '
    source "'"$REPO_ROOT"'/install/modules/service.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_setup_services openrc
'
ORC_CALLS="$(cat "$SB/calls.log")"
assert_contains "openrc adds dbus" "rc-update add dbus default" "$ORC_CALLS"
assert_contains "openrc adds elogind" "rc-update add elogind default" "$ORC_CALLS"
assert_contains "openrc adds bluetooth" "rc-update add bluetooth default" "$ORC_CALLS"
assert_contains "openrc adds power-profiles-daemon" "rc-update add power-profiles-daemon default" "$ORC_CALLS"
assert_contains "openrc adds NetworkManager" "rc-update add NetworkManager default" "$ORC_CALLS"
assert_contains "openrc deletes dhcpcd" "rc-update del dhcpcd default" "$ORC_CALLS"
assert_contains "openrc deletes wpa_supplicant" "rc-update del wpa_supplicant default" "$ORC_CALLS"
assert_contains "openrc starts NetworkManager when no net active" "rc-service NetworkManager start" "$ORC_CALLS"

SB="$(setup_sandbox services_openrc_net)"
rm -f "$SB/bin/systemctl"
echo "net.eth0" > "$SB/rc_active"
touch "$SB/init.d/net.lo" "$SB/init.d/net.eth0"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="openrc" PORTAGE_INIT_D_DIR="$SB/init.d" bash -c '
    source "'"$REPO_ROOT"'/install/modules/service.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_setup_services openrc
'
assert_not_contains "openrc skips starting NetworkManager while net.eth0 active" "rc-service NetworkManager start" "$(cat "$SB/calls.log")"

SB="$(setup_sandbox dm_systemd)"
echo "gdm.service" > "$SB/systemd_enabled"
assert_eq "detect_current_dm on systemd detects gdm" "gdm" "$(
    PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="systemd" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
        source "'"$REPO_ROOT"'/install/modules/ui.sh"
        trap - EXIT INT TERM
        detect_current_dm
    '
)"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="systemd" bash -c '
    source "'"$REPO_ROOT"'/install/modules/service.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_disable_display_manager gdm systemd
    pm_enable_display_manager sddm systemd
'
DM_SYS_CALLS="$(cat "$SB/calls.log")"
assert_contains "systemd disables gdm.service" "systemctl disable gdm.service" "$DM_SYS_CALLS"
assert_contains "systemd force-enables sddm.service" "systemctl enable --force sddm.service" "$DM_SYS_CALLS"

SB="$(setup_sandbox dm_openrc)"
rm -f "$SB/bin/systemctl"
touch "$SB/init.d/display-manager"
chmod +x "$SB/init.d/display-manager"
printf 'DISPLAYMANAGER="lightdm"\n' > "$SB/conf.d/display-manager"
printf ' display-manager | default\n' > "$SB/rc_enabled"

assert_eq "detect_current_dm on openrc reads DISPLAYMANAGER" "lightdm" "$(
    PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="openrc" \
    PORTAGE_CONF_D_DIR="$SB/conf.d" PORTAGE_INIT_D_DIR="$SB/init.d" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
        source "'"$REPO_ROOT"'/install/modules/ui.sh"
        trap - EXIT INT TERM
        detect_current_dm
    '
)"

PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="openrc" \
PORTAGE_CONF_D_DIR="$SB/conf.d" PORTAGE_INIT_D_DIR="$SB/init.d" bash -c '
    source "'"$REPO_ROOT"'/install/modules/service.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_disable_display_manager lightdm openrc
    pm_enable_display_manager sddm openrc
'
DM_ORC_CALLS="$(cat "$SB/calls.log")"
assert_not_contains "openrc does not stop active display-manager mid-install" "rc-service display-manager stop" "$DM_ORC_CALLS"
assert_contains "openrc removes display-manager from default" "rc-update del display-manager default" "$DM_ORC_CALLS"
assert_contains "openrc sets DISPLAYMANAGER=sddm" 'DISPLAYMANAGER="sddm"' "$(cat "$SB/conf.d/display-manager")"
assert_eq "openrc does not duplicate DISPLAYMANAGER line" "1" "$(grep -c 'DISPLAYMANAGER=' "$SB/conf.d/display-manager")"
assert_contains "openrc adds display-manager to default" "rc-update add display-manager default" "$DM_ORC_CALLS"

SB="$(setup_sandbox sddm_session)"
cat > "$SB/sddm-sys.conf" <<'EOF'
[Theme]
Current=material-you

[Wayland]
CompositorCommand=/usr/bin/weston --shell=kiosk
EOF
cp "$SB/sddm-sys.conf" "$SB/sddm-openrc.conf"

PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="systemd" \
PORTAGE_SDDM_SESSION_WRAPPER="$SB/wrapper-sys" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_configure_sddm_session "'"$SB"'/sddm-sys.conf"
'
assert_fail "systemd pm_configure_sddm_session does not create wrapper" test -e "$SB/wrapper-sys"
assert_not_contains "systemd pm_configure_sddm_session leaves sddm conf untouched" "SessionCommand=" "$(cat "$SB/sddm-sys.conf")"

rm -f "$SB/bin/systemctl"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" PORTAGE_INIT_SYSTEM="openrc" \
PORTAGE_SDDM_SESSION_WRAPPER="$SB/wrapper-openrc" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_configure_sddm_session "'"$SB"'/sddm-openrc.conf"
'
assert_ok "openrc pm_configure_sddm_session creates executable wrapper" test -x "$SB/wrapper-openrc"
WRAP_BODY="$(cat "$SB/wrapper-openrc")"
assert_contains "openrc wrapper uses dbus-run-session" "dbus-run-session" "$WRAP_BODY"
assert_contains "openrc wrapper uses gentoo-pipewire-launcher" "gentoo-pipewire-launcher" "$WRAP_BODY"
assert_contains "openrc sddm conf sets SessionCommand" "SessionCommand=$SB/wrapper-openrc" "$(cat "$SB/sddm-openrc.conf")"

SB="$(setup_sandbox upgrade_qs)"
PATH="$SB/bin:$TOOLS_BIN" MOCK_STATE="$SB" MOCK_ARCH="amd64" \
PORTAGE_CONFIG_DIR="$SB/portage" PORTAGE_VDB_DIR="$SB/vdb" \
I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" bash -c '
    source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_upgrade_quickshell
' >/dev/null
QS_CALLS="$(cat "$SB/calls.log")"
assert_contains "pm_upgrade_quickshell enables guru" "eselect repository enable guru" "$QS_CALLS"
assert_contains "pm_upgrade_quickshell updates gui-apps/quickshell" "emerge --ask=n --update --quiet-build=y gui-apps/quickshell" "$QS_CALLS"
assert_eq "pm_upgrade_quickshell syncs guru once" "1" "$(grep -c 'emaint sync -r guru' "$SB/calls.log")"

echo "Passed: $PASS, Failed: $FAIL"
[ "$FAIL" -eq 0 ]
