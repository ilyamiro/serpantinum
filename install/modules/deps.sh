#!/usr/bin/env bash

SUPPORTED_DISTROS=(
    "arch"
    "endeavouros"
    "manjaro"
    "cachyos"
    "garuda"
    "arcolinux"
    "archcraft"
    "artix"
    "blackarch"
    "rebornos"
    "mabox"
    "blendos"
    "parch"
    "parchlinux"
    "biglinux"
    "archlabs"
    "archman"
    "alci"
    "bluestar"
    "archbang"
    "archex"
    "archstrike"
    "athena"
    "athenaos"
    "chimeraos"
    "ctlos"
    "crystal"
    "hefftorlinux"
    "instantos"
    "nyarch"
    "obarun"
    "hyperbola"
    "parabola"
    "salientos"
    "snal"
    "steamos"
    "holo"
    "stormos"
    "tearch"
    "xerolinux"
    "axyl"
    "omarchy"
)

REQUIRED_PKGS=(
    "kitty" "cava" "zbar" "pavucontrol" "alsa-utils"
    "wl-clipboard" "fd" "qt6-multimedia" "qt6-5compat" "ripgrep"
    "cliphist" "jq" "socat" "inotify-tools" "pamixer" "brightnessctl" "ddcutil" "acpi" "iw"
    "bluez" "bluez-utils" "libnotify" "networkmanager" "lm_sensors" "bc" "matugen"
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "libpulse" "python"
    "imagemagick" "wget" "file" "git" "psmisc"
    "ffmpeg" "fastfetch" "quickshell" "unzip" "python-websockets" "qt6-websockets"
    "grim" "playerctl" "satty" "xdg-desktop-portal-gtk" "slurp" "wmctrl" "power-profiles-daemon" "easyeffects" "nautilus" "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland"
    "qt5ct" "qt6ct" "gpu-screen-recorder" "wf-recorder" "adw-gtk-theme" "wl-gammarelay-rs"
)

FAILED_PKGS=()

suppress_tty_sleep() {
    setterm -blank 0 -powerdown 0 2>/dev/null || true
    printf '\033[9;0]' 2>/dev/null || true
}

check_supported_os() {
    if [ "$EUID" -eq 0 ]; then
        echo "$(t "installer.os.error_root")" >&2
        exit 1
    fi

    if [ -f /etc/os-release ]; then
        local DETECTED_OS
        DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

        for os in "${SUPPORTED_DISTROS[@]}"; do
            if [ "$DETECTED_OS" = "$os" ]; then
                return 0
            fi
        done

        # Fedora and its derivatives (Nobara, Ultramarine...) through dnf.
        if [ "$PKG_FAMILY" = "fedora" ]; then
            return 0
        fi

        echo "$(t "installer.os.error_unsupported" "os=$DETECTED_OS")"
        exit 1
    else
        echo "$(t "installer.os.error_not_found")"
        exit 1
    fi
}

enable_multilib() {
    if [ -f /etc/pacman.conf ]; then
        if grep -q "^#\[multilib\]" /etc/pacman.conf; then
            sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
            sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
        fi
    fi
}

bootstrap_installer_deps() {
    suppress_tty_sleep
    [ "$PKG_FAMILY" = "arch" ] && enable_multilib
    pkg_bootstrap
}

install_pkg() {
    pkg_install "$1" "$2"
}

# The full list for this install: the required packages, the chosen
# compositors, SDDM if selected, and what the distribution family needs on top.
target_packages() {
    local list=("${REQUIRED_PKGS[@]}")
    local comp
    for comp in "$@"; do
        list+=("$comp")
    done
    if [ "$OPT_SDDM" = true ]; then
        list+=("sddm" "qt6-declarative" "qt6-svg")
        # No Xorg on Fedora: SDDM has to run its Wayland greeter (weston).
        [ "$PKG_FAMILY" = "fedora" ] && list+=("sddm-wayland-generic")
    fi
    [ "$PKG_FAMILY" = "fedora" ] && list+=("${FEDORA_EXTRA_PKGS[@]}")
    printf '%s\n' "${list[@]}"
}

install_fonts() {
    local target_fonts_dir="$HOME/.local/share/fonts/IosevkaNerdFont"
    if [ ! -d "$target_fonts_dir" ] || [ -z "$(ls -A "$target_fonts_dir" 2>/dev/null | grep -i "\.ttf")" ]; then
        local font_cache="${XDG_CACHE_HOME:-"$HOME/.cache"}/serpantinum-fonts"
        mkdir -p "$font_cache" "$target_fonts_dir"
        echo -e "\n\e[36m[ INFO ]\e[0m Downloading Iosevka Nerd Font..."
        if curl -# -L --connect-timeout 15 --retry 3 "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip" -o "$font_cache/Iosevka.zip"; then
            if [ -f "$font_cache/Iosevka.zip" ]; then
                echo -e "\e[36m[ INFO ]\e[0m Unpacking fonts..."
                unzip -qo "$font_cache/Iosevka.zip" -d "$font_cache/" 2>/dev/null || true
                mv "$font_cache"/*.ttf "$target_fonts_dir/" 2>/dev/null || true
                rm -f "$target_fonts_dir/"*Mono*.ttf 2>/dev/null || true
                sudo mkdir -p /usr/share/fonts/IosevkaNerdFont
                sudo cp -r "$target_fonts_dir/"* /usr/share/fonts/IosevkaNerdFont/ 2>/dev/null || true
            fi
        else
            echo -e "\e[33m[ WARN ]\e[0m Failed to download fonts, skipping..."
        fi
        rm -rf "$font_cache"
    fi

    find "$HOME/.local/share/fonts" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$HOME/.local/share/fonts" -type d -exec chmod 755 {} \; 2>/dev/null || true

    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    fi
}

install_dependencies() {
    local install_state="${1:-$INSTALL_STATE}"
    local is_reinstall="${2:-$IS_REINSTALL}"
    shift 2 2>/dev/null || true
    local compositors=("$@")

    if [ "$PKG_FAMILY" = "arch" ] && pacman -Qq quickshell-git &>/dev/null; then
        yay -R --noconfirm quickshell-git 2>/dev/null || sudo pacman -Rdd --noconfirm quickshell-git 2>/dev/null || true
    fi

    local target_list=()
    mapfile -t target_list < <(target_packages "${compositors[@]}")

    if [[ ("$install_state" == "fresh" || "$install_state" == "legacy") && "$is_reinstall" != "true" ]]; then
        echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
        pkg_sync
    fi

    local missing_raw
    missing_raw=$(pkg_missing "${target_list[@]}")

    local MISSING_PKGS=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && MISSING_PKGS+=("$pkg")
    done <<< "$missing_raw"

    FAILED_PKGS=()

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        echo -e "\n\e[32m  $(t "installer.deps.all_installed")\e[0m\n"
    else
        echo -e "\n\e[33m  $(t "installer.deps.missing_count" "count=${#MISSING_PKGS[@]}")\e[0m"
        echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.installing_title")\n"

        local SAFE_JOBS=$(( $(nproc) / 2 ))
        [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
        [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4

        # On Fedora, everything the repositories have goes in one dnf
        # transaction; the loop below handles the rest (release downloads,
        # COPR, what is not packaged) and retries all of it if the batch fails.
        if [ "$PKG_FAMILY" = "fedora" ]; then
            local repo_pkgs=() other_pkgs=()
            for pkg in "${MISSING_PKGS[@]}"; do
                if [ -n "${RELEASE_URLS[$pkg]:-}" ] || [ -z "$(pkg_name "$pkg")" ] || [ "$pkg" = "hyprland" ]; then
                    other_pkgs+=("$pkg")
                else
                    repo_pkgs+=("$pkg")
                fi
            done
            if [ ${#repo_pkgs[@]} -gt 0 ] && pkg_install_batch "${repo_pkgs[@]}"; then
                echo -e "\n\e[32m[ OK ] ${repo_pkgs[*]}\e[0m"
                MISSING_PKGS=("${other_pkgs[@]}")
            fi
        fi

        for pkg in "${MISSING_PKGS[@]}"; do
            echo -e "\n\e[36m=================================================================\e[0m"
            echo -e "\e[34m::\e[0m \e[1m$(t "installer.deps.installing_pkg" "pkg=$pkg")\e[0m"
            echo -e "\e[36m=================================================================\e[0m"

            if install_pkg "$pkg" "$SAFE_JOBS"; then
                echo -e "\n\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
            else
                echo -e "\n\e[31m[ FAILED ] $(t "installer.deps.install_failed" "pkg=$pkg")\e[0m"
                FAILED_PKGS+=("$pkg")
            fi
            sleep 0.2
        done
    fi

    install_fonts
}
