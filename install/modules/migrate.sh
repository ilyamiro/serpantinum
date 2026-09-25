#!/usr/bin/env bash

get_compositor_config_dir_name() {
    local comp="$1"
    case "$comp" in
        hyprland) echo "hypr" ;;
        niri) echo "niri" ;;
        sway) echo "sway" ;;
        *) echo "$comp" ;;
    esac
}

backup_compositor_directory() {
    local comp="$1"
    local dir_name
    dir_name=$(get_compositor_config_dir_name "$comp")

    local COMP_DIR="$HOME/.config/$dir_name"
    local BACKUP_BASE="$HOME/.config/${dir_name}_backup"
    local BACKUP_DIR="$BACKUP_BASE/backup_$(date +%Y%m%d_%H%M%S)"

    if [ -d "$COMP_DIR" ] && [ "$(ls -A "$COMP_DIR" 2>/dev/null)" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$COMP_DIR/." "$BACKUP_DIR/" 2>/dev/null || true
    fi
}

backup_compositors() {
    local compositors=("$@")
    for comp in "${compositors[@]}"; do
        backup_compositor_directory "$comp"
    done
}

migrate_legacy() {
    local compositors=("$@")
    pkill -f "settings_watcher.sh" 2>/dev/null || true
    pkill -f "hypr/scripts/quickshell" 2>/dev/null || true

    if [ "$PKG_FAMILY" = "arch" ] && pacman -Qq quickshell-git &>/dev/null; then
        yay -R --noconfirm quickshell-git 2>/dev/null || sudo pacman -Rdd --noconfirm quickshell-git 2>/dev/null || true
    fi

    backup_compositors "${compositors[@]}"

    if [ -f "$HOME/.local/state/imperative-dots-version" ]; then
        mkdir -p "$HOME/.config/hypr_backup"
        mv "$HOME/.local/state/imperative-dots-version" "$HOME/.config/hypr_backup/imperative-dots-version.bak" 2>/dev/null || true
    fi
}
