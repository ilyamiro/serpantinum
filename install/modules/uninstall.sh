#!/usr/bin/env bash

uninstall_serpantinum() {
    local project_root="$1"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
    local runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
    local target_base="$HOME/.local/share/serpantinum"
    local apps_state="$state_home/serpantinum/matugen/apps-state.json"
    local done_msg link name font reset_scheme=false
    local applied=() sddm_backups=()

    done_msg="$(t "installer.uninstall.done")"

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.uninstall.stopping")"
    if [ -x "$target_base/bin/serpantinumd" ]; then
        "$target_base/bin/serpantinumd" stop >/dev/null 2>&1 || true
    fi
    if [ -x "$CORE_PREFIX/bin/serpantinum-core" ]; then
        "$CORE_PREFIX/bin/serpantinum-core" quit >/dev/null 2>&1 || true
    fi
    if [ -x "$AUDIO_PREFIX/bin/serpantinum-audio" ]; then
        "$AUDIO_PREFIX/bin/serpantinum-audio" ctl quit >/dev/null 2>&1 || true
    fi
    if [ -x "$GAMMA_PREFIX/bin/serpantinum-gamma" ]; then
        "$GAMMA_PREFIX/bin/serpantinum-gamma" quit >/dev/null 2>&1 || true
    fi

    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.uninstall.resetting")"
    if [ -f "$apps_state" ]; then
        mapfile -t applied < <(jq -r '.applied // {} | keys[]' "$apps_state" 2>/dev/null)
        if ! jq -e '[.applied // {} | .[] | .gsettings // {} | keys[]] | any(endswith("color-scheme"))' "$apps_state" >/dev/null 2>&1; then
            reset_scheme=true
        fi
    fi
    if [ ${#applied[@]} -gt 0 ] && command -v python3 >/dev/null 2>&1; then
        python3 "$project_root/src/scripts/theming/apptheme.py" undo "${applied[@]}" >/dev/null 2>&1 || true
    fi
    if [ "$reset_scheme" = true ] && command -v gsettings >/dev/null 2>&1; then
        gsettings reset org.gnome.desktop.interface color-scheme >/dev/null 2>&1 || true
    fi
    rm -f "$config_home/environment.d/serpantinum-qt.conf"

    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.uninstall.removing")"
    for link in "$HOME/.local/bin/serpantinum" "$HOME/.local/bin/serpantinumd"; do
        if [ -L "$link" ]; then
            rm -f "$link"
        fi
    done
    for link in /usr/local/bin/serpantinum /usr/local/bin/serpantinumd; do
        if [ -L "$link" ]; then
            sudo rm -f "$link" || true
        fi
    done

    sudo rm -f "$CORE_PREFIX/bin/serpantinum-core" "$AUDIO_PREFIX/bin/serpantinum-audio" "$GAMMA_PREFIX/bin/serpantinum-gamma" || true
    sudo rm -rf "$CORE_PREFIX/share/licenses/serpantinum-core" "$AUDIO_PREFIX/share/licenses/serpantinum-audio" "$GAMMA_PREFIX/share/licenses/serpantinum-gamma" || true

    sudo rm -f /etc/pam.d/serpantinum || true

    sudo rm -f /etc/sddm.conf.d/10-material-you.conf || true
    mapfile -t sddm_backups < <(compgen -G "/etc/sddm.conf.backup.*" | sort)
    if [ ${#sddm_backups[@]} -gt 0 ] && [ ! -e /etc/sddm.conf ]; then
        if sudo mv "${sddm_backups[0]}" /etc/sddm.conf; then
            sudo rm -f "${sddm_backups[@]:1}" || true
        fi
    fi
    sudo rm -rf /usr/share/sddm/themes/material-you /usr/local/share/serpantinum || true
    for font in "$project_root/config/sddm/themes/material-you/font/"*.ttf; do
        name="${font##*/}"
        if [ -f "/usr/share/fonts/TTF/$name" ]; then
            sudo rm -f "/usr/share/fonts/TTF/$name" || true
        fi
    done
    fc-cache -f /usr/share/fonts >/dev/null 2>&1 || true

    remove_settings_desktop_entry

    rm -rf "$target_base" "$data_home/serpantinum" \
        "$HOME/.config/serpantinum" "$config_home/serpantinum" \
        "$HOME/.local/state/serpantinum" "$state_home/serpantinum" \
        "$cache_home/serpantinum" "$cache_home/serpantinum-wallpapers" \
        "$cache_home/serpantinum-fonts" "$cache_home/serpantinum-yay-bin" \
        "$cache_home"/serpantinum-core.* "$cache_home"/serpantinum-audio.* \
        "$cache_home"/serpantinum-gamma.* "$cache_home"/serpantinum-ski.* \
        "$runtime_dir/serpantinum" "$runtime_dir/serpantinum.sock"

    hash -r
    echo -e "\n\e[32m[ OK ] $done_msg\e[0m\n"

    rm -rf "$cache_home/serpantinum-installer"
}
