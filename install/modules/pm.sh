#!/usr/bin/env bash

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"

if ! declare -f os_release_get >/dev/null; then
    source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/os_release.sh"
fi

detect_package_manager() {
    local os_release
    os_release="$(os_release_path)"
    if [ -f "$os_release" ]; then
        local id like
        id="$(os_release_get ID "$os_release")"
        like="$(os_release_get ID_LIKE "$os_release")"
        case " ${id,,} ${like,,} " in
            *" fedora "*) command -v dnf &>/dev/null && { echo "dnf"; return; } ;;
            *" void "*) command -v xbps-install &>/dev/null && { echo "void"; return; } ;;
            *" gentoo "*|*" funtoo "*|*" calculate "*|*" redcore "*) command -v emerge &>/dev/null && { echo "portage"; return; } ;;
        esac
    fi

    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v xbps-install &>/dev/null; then
        echo "void"
    elif command -v emerge &>/dev/null; then
        echo "portage"
    fi
}

PM_NAME="$(detect_package_manager)"
PM_NAME="${PM_NAME:-pacman}"

PM_EXTRA_PKGS=()
PM_SDDM_EXTRA_PKGS=()
PM_SDDM_WAYLAND_DEFAULT=false
PM_SDDM_CURSOR_FIX=false
PM_AUDIO_BUILD_PKGS=()

source "$PM_MODULES_DIR/$PM_NAME.sh"
