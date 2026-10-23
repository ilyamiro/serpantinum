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
    "kitty" "cava" "zbar" "tesseract" "tesseract-data-eng" "pavucontrol" "alsa-utils"
    "wl-clipboard" "fd" "qt6-multimedia" "qt6-5compat" "ripgrep"
    "cliphist" "jq" "socat" "inotify-tools" "pamixer" "brightnessctl" "ddcutil" "acpi" "iw"
    "bluez" "bluez-utils" "libnotify" "networkmanager" "lm_sensors" "bc" "matugen"
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "libpulse" "python"
    "imagemagick" "wget" "file" "git" "psmisc"
    "ffmpeg" "fastfetch" "quickshell" "unzip" "python-websockets" "python-jeepney" "qt6-websockets"
    "grim" "playerctl" "satty" "xdg-desktop-portal-gtk" "slurp" "wmctrl" "power-profiles-daemon" "easyeffects" "calf" "lsp-plugins-lv2" "nautilus" "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland"
    "qt5ct" "qt6ct" "adwaita-icon-theme" "gpu-screen-recorder" "wf-recorder" "adw-gtk-theme" "wl-gammarelay-rs"
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

        if declare -f pm_supports_os >/dev/null && pm_supports_os; then
            return 0
        fi

        echo "$(t "installer.os.error_unsupported" "os=$DETECTED_OS")"
        exit 1
    else
        echo "$(t "installer.os.error_not_found")"
        exit 1
    fi
}

bootstrap_installer_deps() {
    suppress_tty_sleep
    pm_prepare_repos

    local missing=()
    for tool in "${PM_BOOTSTRAP_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        pm_bootstrap_install "${missing[@]}"
    fi

    pm_bootstrap_helper
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

configure_qt_icon_theme() {
    local icon_theme="Adwaita"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local qtct

    for qtct in qt5ct qt6ct; do
        local conf="$config_home/$qtct/$qtct.conf"
        [ -d "$config_home/$qtct" ] || mkdir -p "$config_home/$qtct" 2>/dev/null || continue
        if [ ! -f "$conf" ]; then
            printf '[Appearance]\nicon_theme=%s\n' "$icon_theme" > "$conf"
        elif grep -q '^icon_theme=.\+' "$conf"; then
            continue
        elif grep -q '^icon_theme=' "$conf"; then
            sed -i "s|^icon_theme=.*|icon_theme=$icon_theme|" "$conf"
        elif grep -q '^\[Appearance\]' "$conf"; then
            sed -i "/^\[Appearance\]/a icon_theme=$icon_theme" "$conf"
        else
            printf '\n[Appearance]\nicon_theme=%s\n' "$icon_theme" >> "$conf"
        fi
    done

    local env_dir="$config_home/environment.d"
    local env_file="$env_dir/serpantinum-qt.conf"
    if [ -z "${QT_QPA_PLATFORMTHEME:-}" ] && ! grep -rqs '^QT_QPA_PLATFORMTHEME=' "$env_dir" 2>/dev/null; then
        mkdir -p "$env_dir"
        printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' > "$env_file"
    fi
}

compositor_package_name() {
    case "$1" in
        mango) echo "mangowm" ;;
        *) echo "$1" ;;
    esac
}

find_sddm_binary() {
    local name="$1" dir
    local IFS=:
    for dir in ${SDDM_SEARCH_PATH:-/usr/local/bin:/usr/bin:/bin}; do
        if [ -x "$dir/$name" ]; then
            echo "$dir/$name"
            return 0
        fi
    done
    return 1
}

sddm_has_xorg() {
    find_sddm_binary Xorg >/dev/null || find_sddm_binary X >/dev/null
}

sddm_packages() {
    printf '%s\n' sddm qt6-declarative qt6-svg "${PM_SDDM_EXTRA_PKGS[@]}"
    if [ "$SDDM_WAYLAND" = true ] \
        && ! find_sddm_binary kwin_wayland >/dev/null \
        && ! find_sddm_binary weston >/dev/null \
        && ! sddm_has_xorg; then
        echo weston
    fi
}

MIN_QUICKSHELL_VERSION="0.3.0"

quickshell_version() {
    quickshell --version 2>/dev/null | sed -n 's/^Quickshell \([0-9][0-9.]*\).*/\1/p' | head -n 1
}

quickshell_is_current() {
    local version
    version="$(quickshell_version)"
    [ -n "$version" ] && [ "$(printf '%s\n%s\n' "$MIN_QUICKSHELL_VERSION" "$version" | sort -V | head -n 1)" = "$MIN_QUICKSHELL_VERSION" ]
}

ensure_quickshell_version() {
    command -v quickshell >/dev/null 2>&1 || return 0
    quickshell_is_current && return 0

    echo -e "\n\e[33m  $(t "installer.deps.quickshell_outdated" "version=$(quickshell_version)" "minimum=$MIN_QUICKSHELL_VERSION")\e[0m"
    if declare -f pm_upgrade_quickshell >/dev/null; then pm_upgrade_quickshell || true; fi
    hash -r

    if ! quickshell_is_current; then
        echo -e "\n\e[31m  $(t "installer.deps.quickshell_still_old" "minimum=$MIN_QUICKSHELL_VERSION")\e[0m"
    fi
}

install_dependencies() {
    local install_state="${1:-$INSTALL_STATE}"
    local is_reinstall="${2:-$IS_REINSTALL}"
    shift 2 2>/dev/null || true
    local compositors=("$@")

    pm_remove_conflicting_pkg "quickshell-git"

    local target_list=("${REQUIRED_PKGS[@]}")
    for comp in "${compositors[@]}"; do
        target_list+=("$(compositor_package_name "$comp")")
    done

    if [ "$OPT_SDDM" = true ]; then
        local sddm_pkgs=()
        mapfile -t sddm_pkgs < <(sddm_packages)
        target_list+=("${sddm_pkgs[@]}")
    fi
    target_list+=("${PM_EXTRA_PKGS[@]}")

    if [[ ("$install_state" == "fresh" || "$install_state" == "legacy") && "$is_reinstall" != "true" ]]; then
        pm_full_upgrade
    fi

    local missing_raw
    missing_raw=$(pm_missing_pkgs "${target_list[@]}")

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

        if declare -f pm_install_batch >/dev/null; then
            pm_install_batch "${MISSING_PKGS[@]}"
            MISSING_PKGS=("${PM_BATCH_LEFT[@]}")
        fi

        for pkg in "${MISSING_PKGS[@]}"; do
            echo -e "\n\e[36m=================================================================\e[0m"
            echo -e "\e[34m::\e[0m \e[1m$(t "installer.deps.installing_pkg" "pkg=$pkg")\e[0m"
            echo -e "\e[36m=================================================================\e[0m"

            if pm_install_pkg "$pkg" "$SAFE_JOBS"; then
                echo -e "\n\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
            else
                echo -e "\n\e[31m[ FAILED ] $(t "installer.deps.install_failed" "pkg=$pkg")\e[0m"
                FAILED_PKGS+=("$pkg")
            fi
            sleep 0.2
        done
    fi

    ensure_quickshell_version
    install_fonts
    configure_qt_icon_theme
}
