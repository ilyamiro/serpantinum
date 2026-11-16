#!/usr/bin/env bash

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"

detect_package_manager() {
    if [ -f /etc/os-release ]; then
        local id like
        id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
        like=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
        case " $id $like " in
            *" fedora "*) command -v dnf &>/dev/null && { echo "dnf"; return; } ;;
            *" void "*) command -v xbps-install &>/dev/null && { echo "void"; return; } ;;
        esac
    fi

    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v xbps-install &>/dev/null; then
        echo "void"
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
