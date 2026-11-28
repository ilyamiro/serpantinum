#!/usr/bin/env bash

if ! declare -f os_release_get >/dev/null; then
    source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/os_release.sh"
fi

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
C_BLUE=$'\e[34m'
C_CYAN=$'\e[36m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'
C_MAGENTA=$'\e[35m'

ENABLE_TELEMETRY=true
INSTALL_FULL_WALLPAPERS=true
SELECTED_COMPOSITORS=()
DETECTED_COMPOSITOR_LABEL=""
MULTIPLE_COMPOSITORS_DETECTED=false
UNSUPPORTED_COMPOSITOR_DETECTED=false
IS_REINSTALL=false
DO_UNINSTALL=false
TUI_HANDLED=false

OPT_SDDM=true
REPLACE_DM=false
SDDM_WAYLAND="$PM_SDDM_WAYLAND_DEFAULT"

USER_NAME="${USER:-$(whoami)}"
OS_NAME="$(os_release_get PRETTY_NAME || true)"
[[ -z "$OS_NAME" ]] && OS_NAME="$(os_release_get NAME || true)"
[[ -z "$OS_NAME" ]] && OS_NAME="$(t "installer.os.default_os")"
CPU_INFO=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || true)
[[ -z "$CPU_INFO" ]] && CPU_INFO="$(t "installer.os.unknown_cpu")"

GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
GPU_INFO=$(echo "$GPU_RAW" | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//g' | xargs)
[[ -z "$GPU_INFO" ]] && GPU_INFO="$(t "installer.os.unknown_gpu")"

cleanup_terminal() {
    printf "\e[?25h" 2>/dev/null || true
    stty echo icanon 2>/dev/null || true
}
trap cleanup_terminal EXIT INT TERM

init_compositor_detection() {
    local installed=()
    for comp in hyprland niri sway mango umbriel; do
        if command -v "$comp" &>/dev/null || pm_is_installed "$(compositor_package_name "$comp")"; then
            installed+=("$comp")
        fi
    done

    local running=""
    local de="${XDG_CURRENT_DESKTOP,,}"
    local session="${DESKTOP_SESSION,,}"

    if [[ -n "$MANGO_INSTANCE_SIGNATURE" ]] || pgrep -x "mango" &>/dev/null || [[ "$de" == *"mango"* ]] || [[ "$session" == *"mango"* ]]; then
        running="mango"
    elif [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]] || pgrep -x "Hyprland" &>/dev/null || pgrep -x "hyprland" &>/dev/null || [[ "$de" == *"hyprland"* ]] || [[ "$session" == *"hyprland"* ]]; then
        running="hyprland"
    elif [[ -n "$SWAYSOCK" ]] || pgrep -x "sway" &>/dev/null || [[ "$de" == *"sway"* ]] || [[ "$session" == *"sway"* ]]; then
        running="sway"
    elif pgrep -x "niri" &>/dev/null || [[ "$de" == *"niri"* ]] || [[ "$session" == *"niri"* ]]; then
        running="niri"
    elif [[ -n "$UMBRIEL_SOCKET" ]] || pgrep -x "umbriel" &>/dev/null || [[ "$de" == *"umbriel"* ]] || [[ "$session" == *"umbriel"* ]]; then
        running="umbriel"
    fi

    if [ -n "$running" ]; then
        SELECTED_COMPOSITORS=("$running")
        DETECTED_COMPOSITOR_LABEL="$running"
    elif [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/version" ]; then
        local saved_comps
        saved_comps=$(awk -F= '/^SELECTED_COMPOSITORS=/{gsub(/"/, "", $2); print $2}' "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/version" 2>/dev/null || true)
        if [ -n "$saved_comps" ]; then
            read -r -a SELECTED_COMPOSITORS <<< "$saved_comps"
            DETECTED_COMPOSITOR_LABEL="$(IFS=, ; echo "${SELECTED_COMPOSITORS[*]}")"
        fi
    fi

    if [ ${#SELECTED_COMPOSITORS[@]} -eq 0 ]; then
        if [ ${#installed[@]} -gt 1 ]; then
            MULTIPLE_COMPOSITORS_DETECTED=true
            SELECTED_COMPOSITORS=()
        elif [ ${#installed[@]} -eq 1 ]; then
            SELECTED_COMPOSITORS=("${installed[0]}")
            DETECTED_COMPOSITOR_LABEL="${installed[0]}"
        else
            UNSUPPORTED_COMPOSITOR_DETECTED=true
            DETECTED_COMPOSITOR_LABEL="$(t "installer.ui.unsupported_compositor")"
            SELECTED_COMPOSITORS=()
        fi
    fi
}

detect_current_dm() {
    if declare -f pm_detect_current_dm >/dev/null; then
        local pm_dm
        pm_dm="$(pm_detect_current_dm)"
        if [ -n "$pm_dm" ]; then
            echo "$pm_dm"
            return 0
        fi
    fi

    local dms=("gdm" "gdm3" "lightdm" "sddm" "lxdm" "lxdm-gtk3" "ly" "greetd" "emptty")
    local dm
    for dm in "${dms[@]}"; do
        if command -v systemctl &>/dev/null; then
            if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
                echo "$dm"
                return 0
            fi
        elif [ -L "/var/service/$dm" ] || [ -d "/var/service/$dm" ]; then
            echo "$dm"
            return 0
        elif command -v rc-service &>/dev/null && rc-service "$dm" status &>/dev/null; then
            echo "$dm"
            return 0
        fi
    done
    echo ""
}

run_installer_ui() {
    local current_dm
    current_dm="$(detect_current_dm)"

    local comp_installed_pairs=""
    local comp pkg
    for comp in hyprland niri sway mango umbriel; do
        pkg="$(compositor_package_name "$comp")"
        if command -v "$comp" &>/dev/null || pm_is_installed "$pkg"; then
            comp_installed_pairs+="${comp}=1"$'\n'
        else
            comp_installed_pairs+="${comp}=0"$'\n'
        fi
    done

    local base_sddm_pkgs=(sddm qt6-declarative qt6-svg "${PM_SDDM_EXTRA_PKGS[@]}")
    local sddm_needs_weston=false
    if ! find_sddm_binary kwin_wayland >/dev/null && ! find_sddm_binary weston >/dev/null; then
        sddm_needs_weston=true
    fi

    local all_candidates=("${REQUIRED_PKGS[@]}" "${base_sddm_pkgs[@]}" "${PM_EXTRA_PKGS[@]}" "weston")
    for comp in hyprland niri sway mango umbriel; do
        all_candidates+=("$(compositor_package_name "$comp")")
    done

    local missing_raw
    missing_raw="$(pm_missing_pkgs "${all_candidates[@]}")"

    local ctx_file res_file
    ctx_file="$(mktemp)"
    res_file="$(mktemp)"

    CTX_FILE="$ctx_file" \
    CTX_PROJECT_ROOT="$PROJECT_ROOT" \
    CTX_MODULES_DIR="$MODULES_DIR" \
    CTX_REPO_SLUG="$REPO_SLUG" \
    CTX_INSTALL_STATE="$INSTALL_STATE" \
    CTX_OLD_VERSION="$OLD_VERSION" \
    CTX_TARGET_VERSION="$TARGET_VERSION" \
    CTX_TARGET_COMMIT="$TARGET_COMMIT" \
    CTX_OLD_COMMIT="$OLD_COMMIT" \
    CTX_USER_NAME="$USER_NAME" \
    CTX_OS_NAME="$OS_NAME" \
    CTX_CPU_INFO="$CPU_INFO" \
    CTX_GPU_INFO="$GPU_INFO" \
    CTX_TELEMETRY_ID="$TELEMETRY_ID" \
    CTX_ENABLE_TELEMETRY="$ENABLE_TELEMETRY" \
    CTX_OPT_SDDM="$OPT_SDDM" \
    CTX_REPLACE_DM="$REPLACE_DM" \
    CTX_SDDM_WAYLAND="$SDDM_WAYLAND" \
    CTX_INSTALL_FULL_WALLPAPERS="$INSTALL_FULL_WALLPAPERS" \
    CTX_SELECTED_COMPOSITORS="$(printf '%s\n' "${SELECTED_COMPOSITORS[@]}")" \
    CTX_DETECTED_COMPOSITOR_LABEL="$DETECTED_COMPOSITOR_LABEL" \
    CTX_MULTIPLE_COMPOSITORS="$MULTIPLE_COMPOSITORS_DETECTED" \
    CTX_UNSUPPORTED_COMPOSITOR="$UNSUPPORTED_COMPOSITOR_DETECTED" \
    CTX_CURRENT_DM="$current_dm" \
    CTX_COMP_INSTALLED="$comp_installed_pairs" \
    CTX_REQUIRED_PKGS="$(printf '%s\n' "${REQUIRED_PKGS[@]}")" \
    CTX_PM_EXTRA_PKGS="$(printf '%s\n' "${PM_EXTRA_PKGS[@]}")" \
    CTX_SDDM_PKGS="$(printf '%s\n' "${base_sddm_pkgs[@]}")" \
    CTX_SDDM_NEEDS_WESTON="$sddm_needs_weston" \
    CTX_ALL_CANDIDATES="$(printf '%s\n' "${all_candidates[@]}")" \
    CTX_MISSING_PKGS="$missing_raw" \
    python3 -c '
import json, os

def lines(name):
    return [x for x in os.environ.get(name, "").splitlines() if x]

def to_bool(name):
    return os.environ.get(name, "").lower() == "true"

missing = set(lines("CTX_MISSING_PKGS"))
pkg_status = {p: (p not in missing) for p in lines("CTX_ALL_CANDIDATES")}

comp_installed = {}
for item in lines("CTX_COMP_INSTALLED"):
    if "=" in item:
        k, v = item.split("=", 1)
        comp_installed[k] = (v == "1")

payload = {
    "project_root": os.environ["CTX_PROJECT_ROOT"],
    "modules_dir": os.environ["CTX_MODULES_DIR"],
    "repo_slug": os.environ["CTX_REPO_SLUG"],
    "install_state": os.environ["CTX_INSTALL_STATE"],
    "old_version": os.environ["CTX_OLD_VERSION"],
    "target_version": os.environ["CTX_TARGET_VERSION"],
    "target_commit": os.environ["CTX_TARGET_COMMIT"],
    "old_commit": os.environ["CTX_OLD_COMMIT"],
    "user_name": os.environ["CTX_USER_NAME"],
    "os_name": os.environ["CTX_OS_NAME"],
    "cpu_info": os.environ["CTX_CPU_INFO"],
    "gpu_info": os.environ["CTX_GPU_INFO"],
    "telemetry_id": os.environ["CTX_TELEMETRY_ID"],
    "enable_telemetry": to_bool("CTX_ENABLE_TELEMETRY"),
    "opt_sddm": to_bool("CTX_OPT_SDDM"),
    "replace_dm": to_bool("CTX_REPLACE_DM"),
    "sddm_wayland": to_bool("CTX_SDDM_WAYLAND"),
    "install_full_wallpapers": to_bool("CTX_INSTALL_FULL_WALLPAPERS"),
    "selected_compositors": lines("CTX_SELECTED_COMPOSITORS"),
    "detected_compositor_label": os.environ["CTX_DETECTED_COMPOSITOR_LABEL"],
    "multiple_compositors_detected": to_bool("CTX_MULTIPLE_COMPOSITORS"),
    "unsupported_compositor_detected": to_bool("CTX_UNSUPPORTED_COMPOSITOR"),
    "current_dm": os.environ["CTX_CURRENT_DM"],
    "compositor_installed": comp_installed,
    "required_pkgs": lines("CTX_REQUIRED_PKGS"),
    "pm_extra_pkgs": lines("CTX_PM_EXTRA_PKGS"),
    "sddm_pkgs": lines("CTX_SDDM_PKGS"),
    "sddm_needs_weston": to_bool("CTX_SDDM_NEEDS_WESTON"),
    "package_installed": pkg_status,
}

with open(os.environ["CTX_FILE"], "w", encoding="utf-8") as fh:
    json.dump(payload, fh)
'

    local tui_status=0
    python3 "$INSTALL_DIR/tui.py" --context "$ctx_file" --result "$res_file" || tui_status=$?

    local action="exit"
    if [ -s "$res_file" ]; then
        action="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("action", "exit"))' "$res_file" 2>/dev/null || echo "exit")"
    fi

    rm -f "$ctx_file" "$res_file"
    TUI_HANDLED=true

    if [ "$tui_status" -ne 0 ]; then
        exit "$tui_status"
    fi

    if [ "$action" = "reboot" ]; then
        sudo reboot now
    fi
}

draw_completion_screen() {
    local target_ver="$1"
    local target_commit="$2"
    cleanup_terminal
    printf "%s%s%s\n" "$C_GREEN" "$(t "installer.ui.installed_success" "ver=$target_ver" "commit=$target_commit")" "$RESET"
    printf "%s\n" "$(t "installer.ui.restart_prompt")"
}
