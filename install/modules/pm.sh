#!/usr/bin/env bash

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"

detect_package_manager() {
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
