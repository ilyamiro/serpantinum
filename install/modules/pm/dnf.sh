#!/usr/bin/env bash

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig)

PM_EXTRA_PKGS=(jetbrains-mono-fonts fontawesome-6-free-fonts xdg-user-dirs xwayland-satellite pipewire-utils)
PM_SDDM_EXTRA_PKGS=(sddm-wayland-generic adwaita-cursor-theme)
PM_SDDM_WAYLAND_DEFAULT=true
PM_SDDM_CURSOR_FIX=true

declare -A PM_PKG_MAP=(
    [kitty]="kitty"
    [cava]="cava"
    [zbar]="zbar"
    [pavucontrol]="pavucontrol"
    [alsa-utils]="alsa-utils"
    [wl-clipboard]="wl-clipboard"
    [fd]="fd-find"
    [qt6-multimedia]="qt6-qtmultimedia"
    [qt6-5compat]="qt6-qt5compat"
    [ripgrep]="ripgrep"
    [cliphist]="cliphist"
    [jq]="jq"
    [socat]="socat"
    [inotify-tools]="inotify-tools"
    [pamixer]="pamixer"
    [brightnessctl]="brightnessctl"
    [ddcutil]="ddcutil"
    [acpi]="acpi"
    [iw]="iw"
    [bluez]="bluez"
    [bluez-utils]="bluez"
    [libnotify]="libnotify"
    [networkmanager]="NetworkManager"
    [lm_sensors]="lm_sensors"
    [bc]="bc"
    [matugen]="matugen"
    [pipewire]="pipewire"
    [wireplumber]="wireplumber"
    [pipewire-pulse]="pipewire-pulseaudio"
    [pipewire-alsa]="pipewire-alsa"
    [libpulse]="pulseaudio-libs"
    [python]="python3"
    [imagemagick]="ImageMagick"
    [wget]="wget"
    [file]="file"
    [git]="git"
    [psmisc]="psmisc"
    [ffmpeg]="ffmpeg-free|ffmpeg"
    [fastfetch]="fastfetch"
    [quickshell]="quickshell"
    [unzip]="unzip"
    [python-websockets]="python3-websockets"
    [python-jeepney]="python3-jeepney"
    [qt6-websockets]="qt6-qtwebsockets"
    [grim]="grim"
    [playerctl]="playerctl"
    [satty]="satty"
    [xdg-desktop-portal-gtk]="xdg-desktop-portal-gtk"
    [slurp]="slurp"
    [wmctrl]="wmctrl"
    [power-profiles-daemon]="ppd-service"
    [easyeffects]="easyeffects"
    [lsp-plugins-lv2]="lsp-plugins-lv2"
    [nautilus]="nautilus"
    [qt5-wayland]="qt5-qtwayland"
    [qt5-quickcontrols]="qt5-qtquickcontrols"
    [qt5-quickcontrols2]="qt5-qtquickcontrols2"
    [qt5-graphicaleffects]="qt5-qtgraphicaleffects"
    [qt6-wayland]="qt6-qtwayland"
    [qt5ct]="qt5ct"
    [qt6ct]="qt6ct"
    [adwaita-icon-theme]="adwaita-icon-theme"
    [gpu-screen-recorder]="gpu-screen-recorder"
    [wf-recorder]="wf-recorder"
    [adw-gtk-theme]="adw-gtk3-theme"
    [wl-gammarelay-rs]="wl-gammarelay-rs"
    [hyprland]="hyprland"
    [niri]="niri"
    [sway]="sway"
    [sddm]="sddm"
    [qt6-declarative]="qt6-qtdeclarative"
    [qt6-svg]="qt6-qtsvg"
)

declare -A PM_COPR_MAP=(
    [quickshell]="errornointernet/quickshell"
    [hyprland]="mineiro/hyprland"
    [cliphist]="mecattaf/duoRPM"
    [matugen]="mecattaf/duoRPM"
    [wl-gammarelay-rs]="mecattaf/duoRPM"
    [gpu-screen-recorder]="arabianq/gpu-screen-recorder"
)

declare -A PM_RELEASE_MAP=(
    [satty]="https://github.com/gabm/Satty/releases/latest/download/satty-x86_64-unknown-linux-gnu.tar.gz"
)

pm_supports_os() {
    [ -f /etc/os-release ] || return 1
    [ -e /run/ostree-booted ] && return 1
    local id like
    id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    like=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    case "$id" in
        rhel|centos|rocky|almalinux|ol|scientific|amzn) return 1 ;;
    esac
    case " $id $like " in
        *" fedora "*) return 0 ;;
    esac
    return 1
}

pm_prepare_repos() {
    true
}

pm_bootstrap_install() {
    sudo dnf install -y "$@"
}

pm_bootstrap_helper() {
    true
}

pm_full_upgrade() {
    sudo dnf makecache --refresh >/dev/null 2>&1 || true
}

pm_resolve_name() {
    echo "${PM_PKG_MAP[$1]:-$1}"
}

pm_missing_pkgs() {
    local pkg spec alt satisfied
    for pkg in "$@"; do
        if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ]; then
            if ! command -v "$pkg" &>/dev/null && [ ! -x "$HOME/.local/bin/$pkg" ]; then
                echo "$pkg"
            fi
            continue
        fi
        spec="$(pm_resolve_name "$pkg")"
        satisfied=false
        while IFS= read -r alt; do
            if rpm -q --whatprovides "$alt" &>/dev/null; then
                satisfied=true
                break
            fi
        done < <(tr '|' '\n' <<< "$spec")
        [ "$satisfied" = true ] || echo "$pkg"
    done
}

pm_is_installed() {
    rpm -q "$1" &>/dev/null
}

pm_enable_copr() {
    local repo="$1"
    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.deps.enabling_copr" "repo=$repo")"
    if ! dnf copr --help &>/dev/null; then
        if command -v dnf5 &>/dev/null; then
            sudo dnf install -y dnf5-plugins || return 1
        else
            sudo dnf install -y dnf-plugins-core || return 1
        fi
    fi
    sudo dnf copr enable -y "$repo"
}

pm_install_release_binary() {
    local url="$1" binary="$2"
    local bin_dir="$HOME/.local/bin"
    local tmp found
    [ "$(uname -m)" = "x86_64" ] || return 1
    tmp="$(mktemp -d)"
    mkdir -p "$bin_dir"
    if curl -fsSL --connect-timeout 15 --retry 3 "$url" -o "$tmp/pkg.tar.gz" && tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"; then
        found="$(find "$tmp" -type f -name "$binary" | head -n 1)"
        if [ -n "$found" ]; then
            install -m 0755 "$found" "$bin_dir/$binary"
            rm -rf "$tmp"
            return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

pm_install_batch() {
    PM_BATCH_LEFT=("$@")
    local batch=() names=() rest=() pkg
    for pkg in "$@"; do
        if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ] || [ -n "${PM_COPR_MAP[$pkg]:-}" ]; then
            rest+=("$pkg")
        else
            batch+=("$pkg")
            names+=("$(pm_resolve_name "$pkg" | cut -d'|' -f1)")
        fi
    done
    [ ${#batch[@]} -gt 0 ] || return 0
    if sudo dnf install -y "${names[@]}"; then
        for pkg in "${batch[@]}"; do
            echo -e "\n\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
        done
        PM_BATCH_LEFT=("${rest[@]}")
    fi
}

pm_install_pkg() {
    local pkg="$1"
    local spec target

    if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ]; then
        pm_install_release_binary "${PM_RELEASE_MAP[$pkg]}" "$pkg"
        return
    fi
    spec="$(pm_resolve_name "$pkg")"
    target="${spec%%|*}"

    if [ -z "$(dnf repoquery --available --quiet "$target" 2>/dev/null | head -n 1)" ]; then
        local copr="${PM_COPR_MAP[$pkg]:-}"
        if [ -n "$copr" ]; then
            pm_enable_copr "$copr" || return 1
        fi
    fi

    sudo dnf install -y "$target"
}

pm_enable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "systemd" ]; then
        sudo systemctl enable --force "$svc.service" 2>/dev/null || true
    else
        enable_system_service "$svc" "$init_sys"
    fi
}

pm_disable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "systemd" ]; then
        sudo systemctl disable "$svc.service" 2>/dev/null || true
    else
        disable_system_service "$svc" "$init_sys"
    fi
}

pm_configure_sddm_cursor() {
    local conf="$1" theme=""
    if [ -d /usr/share/icons/Adwaita/cursors ]; then
        theme="Adwaita"
    else
        theme="$(find /usr/share/icons -mindepth 2 -maxdepth 2 -type d -name cursors 2>/dev/null | head -n 1 | xargs -r dirname | xargs -r basename)"
    fi
    [ -n "$theme" ] || return 0
    sudo sed -i -e "/^ThemeDir=/a CursorTheme=$theme" -e "/^ThemeDir=/a CursorSize=24" "$conf"
}

pm_remove_pkg() {
    true
}

pm_remove_conflicting_pkg() {
    true
}
