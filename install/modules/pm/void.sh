#!/usr/bin/env bash

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig xz)

PM_EXTRA_PKGS=(
    font-awesome6 ttf-jetbrains-mono xdg-user-dirs xdg-utils xwayland-satellite xorg-server-xwayland
    libspa-bluetooth dbus elogind polkit xdg-desktop-portal
)
PM_SDDM_EXTRA_PKGS=()
PM_SDDM_WAYLAND_DEFAULT=true
PM_SDDM_CURSOR_FIX=true
PM_AUDIO_BUILD_PKGS=(gcc make pkg-config pipewire-devel)

VOID_HYPRLAND_REPO_CONF="/etc/xbps.d/20-serpantinum-hyprland.conf"
VOID_HYPRLAND_REPO_BASE="https://mirror.black-hole.dev"
VOID_SDDM_SESSION_WRAPPER="/usr/local/share/serpantinum/sddm-wayland-session"

declare -A PM_PKG_MAP=(
    [tesseract]="tesseract-ocr"
    [tesseract-data-eng]="tesseract-ocr-eng"
    [qt6-5compat]="qt6-qt5compat"
    [bluez-utils]="bluez"
    [networkmanager]="NetworkManager"
    [pipewire-pulse]="pipewire"
    [pipewire-alsa]="alsa-pipewire"
    [libpulse]="libpulseaudio"
    [python]="python3"
    [imagemagick]="ImageMagick"
    [ffmpeg]="ffmpeg|ffmpeg6"
    [python-websockets]="python3-websockets"
    [python-jeepney]="python3-jeepney"
    [mangowm]="mangowc"
)

declare -A PM_EXTERNAL_REPO_MAP=(
    [hyprland]=1
)

declare -A PM_RELEASE_MAP=(
    [adw-gtk-theme]="lassekongo83/adw-gtk3"
    [ttf-jetbrains-mono]="JetBrains/JetBrainsMono"
)

pm_supports_os() {
    [ -f /etc/os-release ] || return 1
    local id like
    id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    like=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    case " $id $like " in
        *" void "*) return 0 ;;
    esac
    return 1
}

pm_prepare_repos() {
    sudo xbps-install -Sy >/dev/null 2>&1 || true
    sudo xbps-install -uy xbps >/dev/null 2>&1 || true
}

pm_bootstrap_install() {
    sudo xbps-install -Sy "$@"
}

pm_bootstrap_helper() {
    true
}

pm_full_upgrade() {
    sudo xbps-install -Suy xbps || true
    sudo xbps-install -Suy || true
}

pm_resolve_name() {
    echo "${PM_PKG_MAP[$1]:-$1}"
}

pm_release_installed() {
    case "$1" in
        adw-gtk-theme)
            local dir
            for dir in /usr/share/themes "${XDG_DATA_HOME:-$HOME/.local/share}/themes" "$HOME/.themes"; do
                [ -d "$dir/adw-gtk3" ] && return 0
            done
            return 1
            ;;
        ttf-jetbrains-mono)
            command -v fc-list &>/dev/null && fc-list : family 2>/dev/null | grep -qiF "JetBrains Mono"
            ;;
        *)
            return 1
            ;;
    esac
}

pm_is_installed() {
    local alt
    while IFS= read -r alt; do
        xbps-query "$alt" &>/dev/null && return 0
    done < <(pm_resolve_name "$1" | tr '|' '\n')
    return 1
}

pm_missing_pkgs() {
    local pkg
    for pkg in "$@"; do
        if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ]; then
            pm_release_installed "$pkg" || echo "$pkg"
        else
            pm_is_installed "$pkg" || echo "$pkg"
        fi
    done
}

pm_enable_hyprland_repo() {
    [ -f "$VOID_HYPRLAND_REPO_CONF" ] && return 0
    local arch
    arch="$(xbps-uhelper arch 2>/dev/null || uname -m)"
    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.deps.enabling_repo" "repo=$VOID_HYPRLAND_REPO_BASE/$arch")"
    sudo mkdir -p "$(dirname "$VOID_HYPRLAND_REPO_CONF")" || return 1
    printf 'repository=%s/%s/\n' "$VOID_HYPRLAND_REPO_BASE" "$arch" | sudo tee "$VOID_HYPRLAND_REPO_CONF" >/dev/null || return 1
    sudo xbps-install -Sy
}

pm_github_asset_url() {
    local repo="$1" pattern="$2"
    curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | jq -r --arg re "$pattern" '[.assets[] | select(.name | test($re))][0].browser_download_url // empty' 2>/dev/null
}

pm_install_release() {
    local pkg="$1" repo="${PM_RELEASE_MAP[$1]}"
    local url tmp status=1

    case "$pkg" in
        adw-gtk-theme) url="$(pm_github_asset_url "$repo" '\.tar\.xz$')" ;;
        ttf-jetbrains-mono) url="$(pm_github_asset_url "$repo" '\.zip$')" ;;
    esac
    [ -n "$url" ] || return 1

    tmp="$(mktemp -d)"
    if curl -fsSL --connect-timeout 15 --retry 3 "$url" -o "$tmp/${url##*/}"; then
        case "$pkg" in
            adw-gtk-theme)
                mkdir -p "$tmp/out"
                if tar -xJf "$tmp/${url##*/}" -C "$tmp/out" && [ -d "$tmp/out/adw-gtk3" ]; then
                    sudo mkdir -p /usr/share/themes \
                        && sudo cp -r "$tmp/out/." /usr/share/themes/ \
                        && sudo chmod -R a+rX /usr/share/themes/adw-gtk3* \
                        && status=0
                fi
                ;;
            ttf-jetbrains-mono)
                if unzip -qo "$tmp/${url##*/}" 'fonts/ttf/*.ttf' -d "$tmp/out" && compgen -G "$tmp/out/fonts/ttf/*.ttf" >/dev/null; then
                    sudo mkdir -p /usr/share/fonts/JetBrainsMono \
                        && sudo install -m 0644 "$tmp/out/fonts/ttf/"*.ttf /usr/share/fonts/JetBrainsMono/ \
                        && status=0
                    fc-cache -f /usr/share/fonts/JetBrainsMono >/dev/null 2>&1 || true
                fi
                ;;
        esac
    fi
    rm -rf "$tmp"
    return "$status"
}

pm_install_batch() {
    PM_BATCH_LEFT=("$@")
    local batch=() names=() rest=() pkg
    for pkg in "$@"; do
        if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ] || [ -n "${PM_EXTERNAL_REPO_MAP[$pkg]:-}" ]; then
            rest+=("$pkg")
        else
            batch+=("$pkg")
            names+=("$(pm_resolve_name "$pkg" | cut -d'|' -f1)")
        fi
    done
    [ ${#batch[@]} -gt 0 ] || return 0
    if sudo xbps-install -y "${names[@]}"; then
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
        pm_install_release "$pkg"
        return
    fi
    spec="$(pm_resolve_name "$pkg")"
    target="${spec%%|*}"

    if [ -n "${PM_EXTERNAL_REPO_MAP[$pkg]:-}" ] && ! xbps-query -R "$target" &>/dev/null; then
        pm_enable_hyprland_repo || return 1
    fi

    sudo xbps-install -y "$target"
}

void_service_linked() {
    [ -e "/var/service/$1" ] || [ -L "/var/service/$1" ]
}

void_link_service() {
    local svc="$1"
    [ -d "/etc/sv/$svc" ] || return 1
    void_service_linked "$svc" && return 0
    sudo ln -s "/etc/sv/$svc" /var/service/
}

void_link_service_for_next_boot() {
    local svc="$1" i
    [ -d "/etc/sv/$svc" ] || return 1
    void_service_linked "$svc" && return 0
    sudo touch "/etc/sv/$svc/down" || return 1
    if ! sudo ln -s "/etc/sv/$svc" /var/service/; then
        sudo rm -f "/etc/sv/$svc/down"
        return 1
    fi
    for i in $(seq 1 24); do
        sudo sv status "/var/service/$svc" >/dev/null 2>&1 && break
        sleep 0.5
    done
    sudo rm -f "/etc/sv/$svc/down"
}

void_disable_service_at_boot() {
    local svc="$1"
    void_service_linked "$svc" || return 0
    [ -d "/etc/sv/$svc" ] || return 0
    sudo touch "/etc/sv/$svc/down"
}

pm_enable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "runit" ]; then
        void_link_service_for_next_boot "$svc" || true
    else
        enable_system_service "$svc" "$init_sys"
    fi
}

pm_disable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "runit" ]; then
        void_disable_service_at_boot "$svc"
    else
        disable_system_service "$svc" "$init_sys"
    fi
}

pm_configure_sddm_session() {
    local conf="$1"
    local default_cmd="/usr/share/sddm/scripts/wayland-session"

    sudo mkdir -p "$(dirname "$VOID_SDDM_SESSION_WRAPPER")" || return 0
    sudo tee "$VOID_SDDM_SESSION_WRAPPER" >/dev/null <<EOF
#!/bin/sh
if [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session "\$0" "\$@"
fi
if command -v pipewire >/dev/null 2>&1 && ! pgrep -u "\$(id -u)" -x pipewire >/dev/null 2>&1; then
    pipewire >/dev/null 2>&1 &
fi
if [ -x $default_cmd ]; then
    exec $default_cmd "\$@"
fi
exec "\$@"
EOF
    sudo chmod 755 "$VOID_SDDM_SESSION_WRAPPER"

    if grep -q '^\[Wayland\]' "$conf"; then
        sudo sed -i "/^\[Wayland\]/a SessionCommand=$VOID_SDDM_SESSION_WRAPPER" "$conf"
    else
        printf '\n[Wayland]\nSessionCommand=%s\n' "$VOID_SDDM_SESSION_WRAPPER" | sudo tee -a "$conf" >/dev/null
    fi
}

void_configure_pipewire() {
    local src
    sudo mkdir -p /etc/pipewire/pipewire.conf.d
    for src in /usr/share/examples/wireplumber/10-wireplumber.conf /usr/share/examples/pipewire/20-pipewire-pulse.conf; do
        [ -f "$src" ] || continue
        [ -e "/etc/pipewire/pipewire.conf.d/${src##*/}" ] || sudo ln -s "$src" /etc/pipewire/pipewire.conf.d/
    done

    sudo mkdir -p /etc/alsa/conf.d
    for src in /usr/share/alsa/alsa.conf.d/50-pipewire.conf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf; do
        [ -f "$src" ] || continue
        [ -e "/etc/alsa/conf.d/${src##*/}" ] || sudo ln -s "$src" /etc/alsa/conf.d/
    done
}

void_switch_to_networkmanager() {
    void_service_linked NetworkManager && return 0
    void_link_service_for_next_boot NetworkManager || return 0
    local svc
    for svc in dhcpcd wpa_supplicant; do
        void_disable_service_at_boot "$svc"
    done
}

pm_setup_services() {
    local init_sys="$1"
    void_configure_pipewire
    if [ "$init_sys" != "runit" ] || [ ! -d /var/service ]; then
        enable_system_service "dbus" "$init_sys"
        enable_system_service "bluetoothd" "$init_sys"
        enable_system_service "NetworkManager" "$init_sys"
        enable_system_service "power-profiles-daemon" "$init_sys"
        return 0
    fi
    void_link_service dbus || true
    void_link_service bluetoothd || true
    void_link_service power-profiles-daemon || true
    void_switch_to_networkmanager
}

pm_remove_pkg() {
    true
}

pm_remove_conflicting_pkg() {
    true
}

pm_upgrade_quickshell() {
    sudo xbps-install -Suy quickshell || true
}
