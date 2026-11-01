#!/usr/bin/env bash

detect_init_system() {
    if [[ -d /run/systemd/system ]] || command -v systemctl &>/dev/null; then
        echo "systemd"
    elif command -v openrc-init &>/dev/null || [[ -d /run/openrc ]]; then
        echo "openrc"
    elif command -v dinit &>/dev/null || [[ -d /etc/dinit.d ]]; then
        echo "dinit"
    elif command -v runit &>/dev/null || [[ -d /run/runit ]]; then
        echo "runit"
    elif command -v s6-svscan &>/dev/null; then
        echo "s6"
    else
        echo "generic"
    fi
}

enable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl enable --now "$svc.service" 2>/dev/null || sudo systemctl enable -f "$svc.service" 2>/dev/null || sudo systemctl enable "$svc.service" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-update add "$svc" default 2>/dev/null || true
            sudo rc-service "$svc" start 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl enable "$svc" 2>/dev/null || sudo dinitctl start "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -d "/etc/sv/$svc" ]; then
                sudo ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b add default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

disable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl disable --now "$svc.service" 2>/dev/null || sudo systemctl disable "$svc.service" 2>/dev/null || sudo systemctl disable "$svc" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-service "$svc" stop 2>/dev/null || true
            sudo rc-update del "$svc" default 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl stop "$svc" 2>/dev/null || true
            sudo dinitctl disable "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -L "/var/service/$svc" ] || [ -d "/var/service/$svc" ]; then
                sudo rm -f "/var/service/$svc" 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b del default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

enable_user_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable --now "$svc.service" 2>/dev/null || systemctl --user enable "$svc.service" 2>/dev/null || true
            ;;
        dinit)
            dinitctl --user enable "$svc" 2>/dev/null || dinitctl --user start "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

setup_services() {
    local init_sys
    init_sys=$(detect_init_system)

    if declare -f pm_setup_services >/dev/null; then
        pm_setup_services "$init_sys"
        return 0
    fi

    if [[ "$init_sys" == "systemd" ]]; then
        systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
        systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
    fi

    enable_system_service "NetworkManager" "$init_sys"
    enable_system_service "power-profiles-daemon" "$init_sys"
}
