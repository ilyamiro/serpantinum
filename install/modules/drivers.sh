#!/usr/bin/env bash

OPT_DRIVERS=true

MODULES_ROOT="${MODULES_ROOT:-/usr/lib/modules}"

# NVIDIA device ids: Turing (TU1xx) and newer start at 0x1e00 and are supported
# by the open kernel modules, Maxwell starts at 0x1380 and is served by the 580xx
# legacy branch, anything older needs the 470xx branch.
NVIDIA_OPEN_MIN_ID=$((0x1e00))
NVIDIA_580XX_MIN_ID=$((0x1380))

# Prints "vendor:device" pairs (lowercase hex) for every display controller.
list_gpu_ids() {
    lspci -nn 2>/dev/null \
        | grep -iE 'vga|3d|display' \
        | grep -oE '\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]' \
        | tr -d '[]' \
        | tr 'A-F' 'a-f'
}

# Prints unique vendor names (nvidia, amd, intel) of the detected GPUs.
detect_gpu_vendors() {
    local id vendor
    local -A seen=()
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        case "${id%%:*}" in
            10de) vendor="nvidia" ;;
            1002) vendor="amd" ;;
            8086) vendor="intel" ;;
            *) continue ;;
        esac
        if [[ -z "${seen[$vendor]}" ]]; then
            seen[$vendor]=1
            echo "$vendor"
        fi
    done <<< "$(list_gpu_ids)"
}

# Prints the newest NVIDIA driver branch able to drive every detected NVIDIA GPU:
# open, 580xx or 470xx.
detect_nvidia_branch() {
    local id device branch="open"
    while IFS= read -r id; do
        [[ "${id%%:*}" != "10de" ]] && continue
        device=$((16#${id##*:}))
        if (( device < NVIDIA_580XX_MIN_ID )); then
            branch="470xx"
        elif (( device < NVIDIA_OPEN_MIN_ID )) && [[ "$branch" == "open" ]]; then
            branch="580xx"
        fi
    done <<< "$(list_gpu_ids)"
    echo "$branch"
}

# Prints the headers package of every installed kernel, needed by dkms modules.
get_kernel_headers() {
    local pkgbase
    local -A seen=()
    for pkgbase in "$MODULES_ROOT"/*/pkgbase; do
        [[ -f "$pkgbase" ]] || continue
        local kernel
        kernel=$(<"$pkgbase")
        [[ -z "$kernel" || -n "${seen[$kernel]}" ]] && continue
        seen[$kernel]=1
        echo "${kernel}-headers"
    done
}

nvidia_driver_installed() {
    [[ -z "$(pacman -T nvidia-utils 2>/dev/null)" ]]
}

# Prints the driver packages for the detected hardware, one per line.
get_driver_packages() {
    local vendor
    local -a pkgs=()
    local mesa_added=false

    while IFS= read -r vendor; do
        case "$vendor" in
            amd)
                [[ "$mesa_added" == false ]] && pkgs+=("mesa" "lib32-mesa") && mesa_added=true
                pkgs+=("vulkan-radeon" "lib32-vulkan-radeon")
                ;;
            intel)
                [[ "$mesa_added" == false ]] && pkgs+=("mesa" "lib32-mesa") && mesa_added=true
                pkgs+=("vulkan-intel" "lib32-vulkan-intel" "intel-media-driver")
                ;;
            nvidia)
                # Swapping an already working NVIDIA driver for another branch
                # conflicts in pacman and can leave the system without graphics.
                nvidia_driver_installed && continue
                case "$(detect_nvidia_branch)" in
                    open) pkgs+=("nvidia-open-dkms" "nvidia-utils" "lib32-nvidia-utils") ;;
                    580xx) pkgs+=("nvidia-580xx-dkms" "nvidia-580xx-utils" "lib32-nvidia-580xx-utils") ;;
                    470xx) pkgs+=("nvidia-470xx-dkms" "nvidia-470xx-utils" "lib32-nvidia-470xx-utils") ;;
                esac
                pkgs+=("libva-nvidia-driver")
                while IFS= read -r headers; do
                    [[ -n "$headers" ]] && pkgs+=("$headers")
                done <<< "$(get_kernel_headers)"
                ;;
        esac
    done <<< "$(detect_gpu_vendors)"

    [[ ${#pkgs[@]} -gt 0 ]] && printf '%s\n' "${pkgs[@]}"
    return 0
}

# Appends the driver packages to the named array when driver installation is enabled.
append_driver_packages() {
    local -n target_ref="$1"
    [[ "$OPT_DRIVERS" == true ]] || return 0
    local pkg
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && target_ref+=("$pkg")
    done <<< "$(get_driver_packages)"
}
