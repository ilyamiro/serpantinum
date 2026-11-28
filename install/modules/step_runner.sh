#!/usr/bin/env bash

set -e

STEP="${1:-}"
if [ -z "$STEP" ]; then
    exit 1
fi

MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
INSTALL_DIR="$(dirname "$MODULES_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$INSTALL_DIR")}"

export SERPANTINUM_DIR="${SERPANTINUM_DIR:-$PROJECT_ROOT/src}"
export I18N_DIR="${I18N_DIR:-$PROJECT_ROOT/src/assets/languages}"
export SERPANTINUM_INSTALLER=1

source "$PROJECT_ROOT/src/scripts/i18n.sh"
source "$MODULES_DIR/os_release.sh"
source "$MODULES_DIR/pm.sh"
source "$MODULES_DIR/deps.sh"
source "$MODULES_DIR/ski.sh"
source "$MODULES_DIR/daemons.sh"
source "$MODULES_DIR/audio.sh"
source "$MODULES_DIR/gamma.sh"
source "$MODULES_DIR/core.sh"
source "$MODULES_DIR/state.sh"
source "$MODULES_DIR/migrate.sh"
source "$MODULES_DIR/deploy.sh"
source "$MODULES_DIR/version.sh"
source "$MODULES_DIR/config.sh"
source "$MODULES_DIR/service.sh"
source "$MODULES_DIR/uninstall.sh"

SELECTED_COMPOSITORS=()
if [ -n "${SELECTED_COMPOSITORS_STR:-}" ]; then
    read -r -a SELECTED_COMPOSITORS <<< "$SELECTED_COMPOSITORS_STR"
fi

FAILED_PKGS=()
if [ -n "${SERP_FAILED_PKGS_FILE:-}" ] && [ -f "$SERP_FAILED_PKGS_FILE" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && FAILED_PKGS+=("$line")
    done < "$SERP_FAILED_PKGS_FILE"
fi

save_failed_pkgs() {
    if [ -n "${SERP_FAILED_PKGS_FILE:-}" ] && [ -d "$(dirname "$SERP_FAILED_PKGS_FILE")" ]; then
        printf '%s\n' "${FAILED_PKGS[@]}" > "$SERP_FAILED_PKGS_FILE"
    fi
}
trap save_failed_pkgs EXIT

case "$STEP" in
    prepare)
        TARGET_VERSION="$(get_target_version "$PROJECT_ROOT" "$REPO_SLUG")"
        TARGET_COMMIT="$(get_target_commit "$PROJECT_ROOT" "$REPO_SLUG")"
        if [ "${ENABLE_TELEMETRY:-false}" = true ] && [ -f "$MODULES_DIR/telemetry.sh" ]; then
            bash "$MODULES_DIR/telemetry.sh" --mode init --version "$TARGET_VERSION" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY"
        fi
        printf '[ OK ] %s (%s)\n' "$TARGET_VERSION" "$TARGET_COMMIT"
        ;;
    migrate)
        migrate_legacy "${SELECTED_COMPOSITORS[@]}"
        printf '[ OK ] %s\n' "$(t "installer.steps.migrate")"
        ;;
    backup)
        backup_compositors "${SELECTED_COMPOSITORS[@]}"
        printf '[ OK ] %s\n' "$(t "installer.steps.backup")"
        ;;
    deps)
        install_dependencies "$INSTALL_STATE" "$IS_REINSTALL" "${SELECTED_COMPOSITORS[@]}"
        ;;
    ski)
        install_ski
        ;;
    audio)
        install_audio_daemon
        ;;
    gamma)
        install_gamma_daemon
        ;;
    core)
        install_core_daemon
        ;;
    deploy)
        deploy_package "$PROJECT_ROOT" "$OLD_COMMIT" "$TARGET_COMMIT" "$IS_REINSTALL" "$INSTALL_STATE" "${SELECTED_COMPOSITORS[@]}"
        printf '[ OK ] %s\n' "$(t "installer.steps.deploy")"
        ;;
    sddm)
        setup_sddm "$PROJECT_ROOT" "$INSTALL_STATE" "$IS_REINSTALL"
        ;;
    wallpapers)
        install_wallpapers "$INSTALL_FULL_WALLPAPERS"
        ;;
    config)
        WALLPAPER_DIR="$(get_wallpaper_dir)"
        init_serpantinum_config "$PROJECT_ROOT" "$WALLPAPER_DIR" "$INSTALL_STATE" "$IS_REINSTALL"
        configure_ski_defaults
        setup_services
        hand_over_from_easyeffects
        printf '[ OK ] %s\n' "$(t "installer.steps.config")"
        ;;
    finalize)
        write_version_state "$TARGET_VERSION" "$TARGET_COMMIT" "$TELEMETRY_ID" "$ENABLE_TELEMETRY" "${SELECTED_COMPOSITORS[*]}" "$OPT_SDDM" "$SDDM_WAYLAND" "$INSTALL_FULL_WALLPAPERS"
        if [[ "$INSTALL_STATE" == "legacy" || "$INSTALL_STATE" == "fresh" || "$IS_REINSTALL" == true ]]; then
            rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/first_launch.done" "$HOME/.local/state/serpantinum/first_launch.done" "$HOME/.local/state/quickshell/first_launch.done"
        fi
        if [ "${ENABLE_TELEMETRY:-false}" = true ] && [ -f "$MODULES_DIR/telemetry.sh" ]; then
            bash "$MODULES_DIR/telemetry.sh" --mode done --version "$TARGET_VERSION" --old-version "$OLD_VERSION" --install-state "$INSTALL_STATE" --compositor "${SELECTED_COMPOSITORS[*]}" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY" --failed "${FAILED_PKGS[*]}"
        fi
        printf '[ OK ] %s\n' "$(t "installer.steps.finalize")"
        ;;
    uninstall_stop)
        uninstall_stop_daemons
        ;;
    uninstall_reset)
        uninstall_reset_defaults "$PROJECT_ROOT"
        ;;
    uninstall_remove)
        uninstall_remove_files "$PROJECT_ROOT"
        ;;
    *)
        printf 'Unknown installer step: %s\n' "$STEP" >&2
        exit 1
        ;;
esac
