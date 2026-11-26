#!/usr/bin/env bash

if ! declare -f os_release_get >/dev/null; then
    source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../os_release.sh"
fi

PORTAGE_VDB_DIR="${PORTAGE_VDB_DIR:-/var/db/pkg}"
PORTAGE_CONFIG_DIR="${PORTAGE_CONFIG_DIR:-/etc/portage}"
PORTAGE_CONF_D_DIR="${PORTAGE_CONF_D_DIR:-/etc/conf.d}"
PORTAGE_INIT_D_DIR="${PORTAGE_INIT_D_DIR:-/etc/init.d}"
PORTAGE_SDDM_SESSION_WRAPPER="${PORTAGE_SDDM_SESSION_WRAPPER:-/usr/local/share/serpantinum/sddm-wayland-session}"
PORTAGE_MATUGEN_MIN_MAJOR=4

portage_is_systemd() {
    if [ -n "${PORTAGE_INIT_SYSTEM:-}" ]; then
        [ "$PORTAGE_INIT_SYSTEM" = "systemd" ]
        return
    fi
    if declare -f detect_init_system >/dev/null; then
        [ "$(detect_init_system)" = "systemd" ]
        return
    fi
    [ -d /run/systemd/system ] || command -v systemctl &>/dev/null
}

PM_BOOTSTRAP_TOOLS=(python3 jq curl git lspci unzip fc-cache xz)

PM_EXTRA_PKGS=(
    jetbrains-mono fontawesome xdg-user-dirs xdg-utils
    xwayland-satellite xwayland dbus polkit xdg-desktop-portal
)
if ! portage_is_systemd; then
    PM_EXTRA_PKGS+=(elogind)
fi

PM_SDDM_EXTRA_PKGS=(sddm-gentoo-config)
if ! portage_is_systemd; then
    PM_SDDM_EXTRA_PKGS+=(display-manager-init)
fi

PM_SDDM_WAYLAND_DEFAULT=true
PM_SDDM_CURSOR_FIX=true
PM_AUDIO_BUILD_PKGS=(gcc make pkgconf pipewire)

declare -A PM_PKG_MAP=(
    [kitty]="x11-terms/kitty"
    [zbar]="media-gfx/zbar"
    [tesseract]="app-text/tesseract"
    [tesseract-data-eng]="app-text/tessdata_fast"
    [wl-clipboard]="gui-apps/wl-clipboard"
    [qt6-multimedia]="dev-qt/qtmultimedia:6"
    [cliphist]="app-misc/cliphist"
    [jq]="app-misc/jq"
    [ddcutil]="app-misc/ddcutil"
    [bluez]="net-wireless/bluez"
    [networkmanager]="net-misc/networkmanager"
    [matugen]="x11-misc/matugen"
    [pipewire]="media-video/pipewire"
    [wireplumber]="media-video/wireplumber"
    [pipewire-pulse]="media-video/pipewire"
    [pipewire-alsa]="media-video/pipewire"
    [libpulse]="media-libs/libpulse"
    [python]="dev-lang/python"
    [python3]="dev-lang/python"
    [imagemagick]="media-gfx/imagemagick"
    [file]="sys-apps/file"
    [ffmpeg]="media-video/ffmpeg"
    [fastfetch]="app-misc/fastfetch"
    [quickshell]="gui-apps/quickshell"
    [grim]="gui-apps/grim"
    [playerctl]="media-sound/playerctl"
    [satty]="gui-apps/satty"
    [xdg-desktop-portal-gtk]="sys-apps/xdg-desktop-portal-gtk"
    [power-profiles-daemon]="sys-power/power-profiles-daemon"
    [qt6-wayland]="dev-qt/qtwayland:6"
    [qt6ct]="gui-apps/qt6ct"
    [adwaita-icon-theme]="x11-themes/adwaita-icon-theme"
    [gpu-screen-recorder]="media-video/gpu-screen-recorder"
    [wf-recorder]="gui-apps/wf-recorder"
    [adw-gtk-theme]="x11-themes/adw-gtk3"
    [hyprland]="gui-wm/hyprland"
    [niri]="gui-wm/niri"
    [sway]="gui-wm/sway"
    [mangowm]="gui-wm/mangowm"
    [umbriel]="gui-wm/umbriel"
    [sddm]="gui-apps/sddm"
    [qt6-declarative]="dev-qt/qtdeclarative:6"
    [qt6-svg]="dev-qt/qtsvg:6"
    [weston]="dev-libs/weston"
    [sddm-gentoo-config]="gui-apps/sddm-gentoo-config"
    [display-manager-init]="gui-libs/display-manager-init"
    [jetbrains-mono]="media-fonts/jetbrains-mono"
    [fontawesome]="media-fonts/fontawesome"
    [xdg-user-dirs]="x11-misc/xdg-user-dirs"
    [xdg-utils]="x11-misc/xdg-utils"
    [xwayland-satellite]="gui-apps/xwayland-satellite"
    [xwayland]="x11-base/xwayland"
    [dbus]="sys-apps/dbus"
    [polkit]="sys-auth/polkit"
    [xdg-desktop-portal]="sys-apps/xdg-desktop-portal"
    [elogind]="sys-auth/elogind"
    [gcc]="sys-devel/gcc"
    [make]="dev-build/make"
    [pkgconf]="dev-util/pkgconf"
    [curl]="net-misc/curl"
    [git]="dev-vcs/git"
    [pciutils]="sys-apps/pciutils"
    [lspci]="sys-apps/pciutils"
    [unzip]="app-arch/unzip"
    [fontconfig]="media-libs/fontconfig"
    [fc-cache]="media-libs/fontconfig"
    [xz]="app-arch/xz-utils"
    [eselect]="app-eselect/eselect-repository"
    [eselect-repository]="app-eselect/eselect-repository"
    [gdm]="gnome-base/gdm"
    [lightdm]="x11-misc/lightdm"
    [lxdm]="lxde-base/lxdm"
    [ly]="x11-misc/ly"
    [greetd]="gui-libs/greetd"
    [emptty]="x11-misc/emptty"
)

declare -A PM_OVERLAY_MAP=(
    [cliphist]="guru"
    [matugen]="guru"
    [quickshell]="guru"
    [satty]="guru"
    [gpu-screen-recorder]="guru"
    [adw-gtk-theme]="guru"
    [niri]="guru"
    [mangowm]="guru"
    [umbriel]="guru"
    [xwayland-satellite]="guru"
    [hyprland]="hyproverlay"
)

declare -A PORTAGE_SYNCED_OVERLAYS=()

pm_supports_os() {
    local os_release
    os_release="$(os_release_path)"
    [ -f "$os_release" ] || return 1
    local id like
    id="$(os_release_get ID "$os_release")"
    like="$(os_release_get ID_LIKE "$os_release")"
    case " ${id,,} ${like,,} " in
        *" gentoo "*|*" funtoo "*|*" calculate "*|*" redcore "*) return 0 ;;
    esac
    return 1
}

pm_prepare_repos() {
    true
}

pm_bootstrap_helper() {
    true
}

pm_resolve_name() {
    echo "${PM_PKG_MAP[$1]:-$1}"
}

pm_bootstrap_install() {
    local atoms=() seen=" " tool atom
    for tool in "$@"; do
        atom="$(pm_resolve_name "$tool")"
        [[ "$atom" == */* ]] || continue
        if [[ "$seen" != *" $atom "* ]]; then
            atoms+=("$atom")
            seen+="$atom "
        fi
    done
    [ ${#atoms[@]} -gt 0 ] || return 0
    sudo emerge --ask=n --noreplace --quiet-build=y "${atoms[@]}"
}

pm_full_upgrade() {
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing_portage")"
    sudo emerge --sync --quiet || true
}

portage_vdb_find_entry() {
    local atom="$1"
    local base_atom="${atom%%:*}"
    local req_slot=""
    [[ "$atom" == *:* ]] && req_slot="${atom#*:}"
    [[ "$base_atom" == */* ]] || return 1

    local cat="${base_atom%%/*}"
    local pn="${base_atom#*/}"
    local cat_dir="$PORTAGE_VDB_DIR/$cat"
    [ -d "$cat_dir" ] || return 1

    local entry name ver slot_val
    for entry in "$cat_dir/$pn-"*; do
        [ -d "$entry" ] || continue
        name="${entry##*/}"
        ver="${name#"${pn}-"}"
        [[ "$ver" =~ ^[0-9]+(\.[0-9]+)*[a-z]?((_alpha|_beta|_pre|_rc|_p)[0-9]*)*(-r[0-9]+)?$ ]] || continue
        if [ -n "$req_slot" ] && [ -f "$entry/SLOT" ]; then
            slot_val="$(<"$entry/SLOT")"
            [ "${slot_val%%/*}" = "$req_slot" ] || continue
        fi
        echo "$entry"
        return 0
    done
    return 1
}

portage_vdb_has_atom() {
    portage_vdb_find_entry "$1" >/dev/null
}

portage_matugen_entry_ok() {
    local entry="$1" name ver major
    name="${entry##*/}"
    ver="${name#matugen-}"
    major="${ver%%.*}"
    [[ "$major" =~ ^[0-9]+$ ]] && [ "$major" -ge "$PORTAGE_MATUGEN_MIN_MAJOR" ]
}

portage_pkg_entry_satisfied() {
    local pkg="$1" entry="$2"
    case "$pkg" in
        pipewire-pulse)
            [ ! -f "$entry/USE" ] || grep -qw "sound-server" "$entry/USE"
            ;;
        pipewire-alsa)
            [ ! -f "$entry/USE" ] || grep -qw "pipewire-alsa" "$entry/USE"
            ;;
        matugen)
            portage_matugen_entry_ok "$entry"
            ;;
        *)
            return 0
            ;;
    esac
}

pm_is_installed() {
    local pkg="$1" spec alt entry
    spec="$(pm_resolve_name "$pkg")"
    while IFS= read -r alt; do
        [ -n "$alt" ] || continue
        if entry="$(portage_vdb_find_entry "$alt")"; then
            if portage_pkg_entry_satisfied "$pkg" "$entry"; then
                return 0
            fi
        fi
    done < <(tr '|' '\n' <<< "$spec")
    return 1
}

pm_missing_pkgs() {
    local pkg
    for pkg in "$@"; do
        pm_is_installed "$pkg" || echo "$pkg"
    done
}

portage_accept_keyword() {
    local arch=""
    if command -v portageq &>/dev/null; then
        arch="$(portageq envvar ARCH 2>/dev/null || true)"
    fi
    if [ -z "$arch" ]; then
        case "$(uname -m)" in
            x86_64|amd64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
        esac
    fi
    if [ -n "$arch" ]; then
        echo "~$arch"
    else
        echo "~amd64 ~arm64"
    fi
}

portage_ensure_config_lines() {
    local kind="$1"
    shift
    local lines=("$@")
    [ ${#lines[@]} -gt 0 ] || return 0

    local base="$PORTAGE_CONFIG_DIR/$kind"
    local target
    if [ -d "$base" ]; then
        target="$base/serpantinum"
    elif [ -f "$base" ]; then
        target="$base"
    else
        sudo mkdir -p "$base" || return 1
        target="$base/serpantinum"
    fi

    local line
    for line in "${lines[@]}"; do
        [ -n "$line" ] || continue
        if [ -f "$target" ] && grep -Fxq "$line" "$target" 2>/dev/null; then
            continue
        fi
        printf '%s\n' "$line" | sudo tee -a "$target" >/dev/null || return 1
    done
}

portage_configure_portage() {
    local kw
    kw="$(portage_accept_keyword)"

    local use_lines=(
        "media-video/pipewire sound-server pipewire-alsa bluetooth dbus echo-cancel"
        "media-video/ffmpeg vulkan"
        "dev-qt/qtmultimedia qml pipewire wayland ffmpeg"
        "dev-qt/qtwayland qml"
        "dev-qt/qtdeclarative svg wayland"
        "dev-qt/qtbase dbus gui network opengl vulkan wayland"
        "dev-libs/weston kiosk"
        "dev-cpp/cpptrace unwind"
        "app-text/tesseract png"
        "gui-apps/wf-recorder pipewire"
        "x11-terms/kitty wayland"
        "sys-apps/xdg-desktop-portal-gtk wayland"
    )
    if [ "${SDDM_WAYLAND:-true}" = true ]; then
        use_lines+=("gui-apps/sddm-gentoo-config weston")
    fi

    local kw_lines=(
        "gui-apps/quickshell $kw"
        "dev-cpp/cpptrace $kw"
        "dev-libs/libdwarf $kw"
        "gui-apps/sddm-gentoo-config $kw"
        "x11-misc/matugen $kw"
        "app-misc/cliphist $kw"
        "gui-apps/satty $kw"
        "media-video/gpu-screen-recorder $kw"
        "gui-apps/wf-recorder $kw"
        "x11-themes/adw-gtk3 $kw"
        "gui-apps/xwayland-satellite $kw"
    )
    if [[ "$kw" == *"~arm64"* ]]; then
        kw_lines+=(
            "sys-power/power-profiles-daemon ~arm64"
            "media-gfx/zbar ~arm64"
        )
    fi

    local pkg
    for pkg in "$@"; do
        case "$pkg" in
            niri)
                kw_lines+=("gui-wm/niri $kw")
                ;;
            mangowm)
                use_lines+=("gui-libs/wlroots X" "gui-wm/mangowm X")
                kw_lines+=("gui-wm/mangowm $kw" "gui-libs/scenefx $kw")
                ;;
            umbriel)
                use_lines+=("gui-libs/wlroots X")
                kw_lines+=("gui-wm/umbriel $kw" "sys-apps/xdg-desktop-portal-umbriel $kw")
                ;;
            hyprland)
                kw_lines+=(
                    "gui-wm/hyprland $kw"
                    "dev-cpp/glaze $kw"
                    "dev-cpp/sdbus-c++ $kw"
                    "dev-libs/hyprgraphics $kw"
                    "dev-libs/hyprland-protocols $kw"
                    "dev-libs/hyprlang $kw"
                    "dev-util/hyprwayland-scanner $kw"
                    "gui-libs/aquamarine $kw"
                    "gui-libs/hyprcursor $kw"
                    "gui-libs/hyprland-guiutils $kw"
                    "gui-libs/hyprland-qt-support $kw"
                    "gui-libs/hyprtoolkit $kw"
                    "gui-libs/hyprutils $kw"
                    "gui-libs/hyprwire $kw"
                    "gui-libs/xdg-desktop-portal-hyprland $kw"
                )
                ;;
        esac
    done
    portage_ensure_config_lines "package.use" "${use_lines[@]}" || return 1
    portage_ensure_config_lines "package.accept_keywords" "${kw_lines[@]}"
}

portage_overlay_enabled() {
    local repo="$1"
    if command -v portageq &>/dev/null && portageq get_repo_path / "$repo" >/dev/null 2>&1; then
        return 0
    fi
    if command -v eselect &>/dev/null && eselect repository list -i 2>/dev/null | grep -Eq "(^|[[:space:]])$repo([[:space:]]|$)"; then
        return 0
    fi
    return 1
}

portage_enable_overlay() {
    local repo="$1"
    if portage_overlay_enabled "$repo"; then
        return 0
    fi

    if ! command -v eselect &>/dev/null || ! eselect repository list >/dev/null 2>&1; then
        sudo emerge --ask=n --noreplace --quiet-build=y app-eselect/eselect-repository dev-vcs/git || return 1
    fi

    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.deps.enabling_overlay" "repo=$repo")"
    sudo eselect repository enable "$repo" || return 1
    sudo emaint sync -r "$repo" || return 1
    PORTAGE_SYNCED_OVERLAYS["$repo"]=1
}

pm_install_batch() {
    PM_BATCH_LEFT=("$@")
    local batch=() names=() rest=() pkg atom seen=" "

    portage_configure_portage "$@" || return 0

    for pkg in "$@"; do
        atom="$(pm_resolve_name "$pkg" | cut -d'|' -f1)"
        if [ -n "${PM_OVERLAY_MAP[$pkg]:-}" ] || portage_vdb_has_atom "$atom"; then
            rest+=("$pkg")
        else
            batch+=("$pkg")
            if [[ "$seen" != *" $atom "* ]]; then
                names+=("$atom")
                seen+="$atom "
            fi
        fi
    done

    [ ${#batch[@]} -gt 0 ] || return 0
    if sudo emerge --ask=n --noreplace --changed-use --quiet-build=y "${names[@]}"; then
        for pkg in "${batch[@]}"; do
            echo -e "\n\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
        done
        PM_BATCH_LEFT=("${rest[@]}")
    fi
}

pm_install_pkg() {
    local pkg="$1"
    local spec target overlay

    portage_configure_portage "$pkg" || return 1

    overlay="${PM_OVERLAY_MAP[$pkg]:-}"
    if [ -n "$overlay" ]; then
        portage_enable_overlay "$overlay" || return 1
    fi

    spec="$(pm_resolve_name "$pkg")"
    target="${spec%%|*}"

    if portage_vdb_has_atom "$target"; then
        sudo emerge --ask=n --update --changed-use --noreplace --quiet-build=y "$target"
    else
        sudo emerge --ask=n --noreplace --quiet-build=y "$target"
    fi
}

pm_upgrade_quickshell() {
    portage_configure_portage quickshell || true
    portage_enable_overlay "guru" || true
    if [ -z "${PORTAGE_SYNCED_OVERLAYS[guru]:-}" ]; then
        sudo emaint sync -r guru >/dev/null 2>&1 || true
        PORTAGE_SYNCED_OVERLAYS["guru"]=1
    fi
    sudo emerge --ask=n --update --quiet-build=y gui-apps/quickshell || true
}

portage_openrc_dm_conf() {
    local conf="$PORTAGE_CONF_D_DIR/display-manager"
    [ -f "$conf" ] || return 1
    awk -F= '/^[[:space:]]*DISPLAYMANAGER=/{gsub(/["'\''[:space:]]/, "", $2); print $2; exit}' "$conf"
}

portage_openrc_dm_enabled() {
    if command -v rc-service &>/dev/null && rc-service display-manager status &>/dev/null; then
        return 0
    fi
    if command -v rc-update &>/dev/null && rc-update show 2>/dev/null | grep -Eq '^[[:space:]]*display-manager[[:space:]]*\|'; then
        return 0
    fi
    return 1
}

pm_detect_current_dm() {
    if portage_is_systemd; then
        return 0
    fi
    if portage_openrc_dm_enabled; then
        local dm
        dm="$(portage_openrc_dm_conf || true)"
        if [ -n "$dm" ]; then
            echo "$dm"
            return 0
        fi
    fi
}

pm_enable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "systemd" ]; then
        sudo systemctl enable --force "$svc.service" 2>/dev/null || true
    elif [ "$init_sys" = "openrc" ]; then
        if [ -x "$PORTAGE_INIT_D_DIR/display-manager" ] || [ -f "$PORTAGE_CONF_D_DIR/display-manager" ]; then
            local conf="$PORTAGE_CONF_D_DIR/display-manager"
            sudo mkdir -p "$PORTAGE_CONF_D_DIR" || true
            if [ -f "$conf" ] && grep -q '^[[:space:]]*DISPLAYMANAGER=' "$conf"; then
                sudo sed -i "s|^[[:space:]]*DISPLAYMANAGER=.*|DISPLAYMANAGER=\"$svc\"|" "$conf"
            else
                printf 'DISPLAYMANAGER="%s"\n' "$svc" | sudo tee -a "$conf" >/dev/null
            fi
            sudo rc-update add display-manager default 2>/dev/null || true
        else
            sudo rc-update add "$svc" default 2>/dev/null || true
        fi
    else
        enable_system_service "$svc" "$init_sys"
    fi
}

pm_disable_display_manager() {
    local svc="$1" init_sys="$2"
    if [ "$init_sys" = "systemd" ]; then
        sudo systemctl disable "$svc.service" 2>/dev/null || true
    elif [ "$init_sys" = "openrc" ]; then
        local conf="$PORTAGE_CONF_D_DIR/display-manager"
        local current
        current="$(portage_openrc_dm_conf || true)"
        if [ "$current" = "$svc" ]; then
            sudo rc-update del display-manager default 2>/dev/null || true
        fi
        if [ -x "$PORTAGE_INIT_D_DIR/$svc" ]; then
            sudo rc-update del "$svc" default 2>/dev/null || true
        fi
    else
        disable_system_service "$svc" "$init_sys"
    fi
}

pm_configure_sddm_session() {
    local conf="$1"
    if portage_is_systemd; then
        return 0
    fi
    local default_cmd="/usr/share/sddm/scripts/wayland-session"

    sudo mkdir -p "$(dirname "$PORTAGE_SDDM_SESSION_WRAPPER")" || return 0
    sudo tee "$PORTAGE_SDDM_SESSION_WRAPPER" >/dev/null <<EOF
#!/bin/sh
if [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session "\$0" "\$@"
fi
if command -v gentoo-pipewire-launcher >/dev/null 2>&1; then
    gentoo-pipewire-launcher >/dev/null 2>&1 &
elif command -v pipewire >/dev/null 2>&1 && ! pgrep -u "\$(id -u)" -x pipewire >/dev/null 2>&1; then
    pipewire >/dev/null 2>&1 &
fi
if [ -x $default_cmd ]; then
    exec $default_cmd "\$@"
fi
exec "\$@"
EOF
    sudo chmod 755 "$PORTAGE_SDDM_SESSION_WRAPPER"

    if grep -q '^SessionCommand=' "$conf"; then
        sudo sed -i "s|^SessionCommand=.*|SessionCommand=$PORTAGE_SDDM_SESSION_WRAPPER|" "$conf"
    elif grep -q '^\[Wayland\]' "$conf"; then
        sudo sed -i "/^\[Wayland\]/a SessionCommand=$PORTAGE_SDDM_SESSION_WRAPPER" "$conf"
    else
        printf '\n[Wayland]\nSessionCommand=%s\n' "$PORTAGE_SDDM_SESSION_WRAPPER" | sudo tee -a "$conf" >/dev/null
    fi
}

portage_openrc_net_active() {
    if command -v rc-service &>/dev/null; then
        rc-service dhcpcd status &>/dev/null && return 0
        local svc
        for svc in "$PORTAGE_INIT_D_DIR"/net.*; do
            [ -e "$svc" ] || continue
            [ "${svc##*/}" = "net.lo" ] && continue
            rc-service "${svc##*/}" status &>/dev/null && return 0
        done
    fi
    return 1
}

portage_setup_openrc_networkmanager() {
    sudo rc-update add NetworkManager default 2>/dev/null || true
    sudo rc-update del dhcpcd default 2>/dev/null || true
    sudo rc-update del wpa_supplicant default 2>/dev/null || true
    if ! portage_openrc_net_active; then
        sudo rc-service NetworkManager start 2>/dev/null || true
    fi
}

pm_setup_services() {
    local init_sys="$1"
    if [ "$init_sys" = "systemd" ]; then
        systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
        systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
        enable_system_service "NetworkManager" "$init_sys"
        enable_system_service "bluetooth" "$init_sys"
        enable_system_service "power-profiles-daemon" "$init_sys"
        return 0
    fi

    if [ "$init_sys" = "openrc" ]; then
        enable_system_service "dbus" "$init_sys"
        enable_system_service "elogind" "$init_sys"
        enable_system_service "bluetooth" "$init_sys"
        enable_system_service "power-profiles-daemon" "$init_sys"
        portage_setup_openrc_networkmanager
        return 0
    fi

    enable_system_service "NetworkManager" "$init_sys"
    enable_system_service "bluetooth" "$init_sys"
    enable_system_service "power-profiles-daemon" "$init_sys"
}

pm_remove_pkg() {
    true
}

pm_remove_conflicting_pkg() {
    true
}
