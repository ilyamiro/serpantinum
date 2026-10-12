#!/usr/bin/env bash

setup() {
    source "$PROJECT_ROOT/install/modules/drivers.sh"
    MODULES_ROOT="$TEST_TMP/modules"
    mkdir -p "$MODULES_ROOT"
    INSTALLED_PKGS=""
    use_gpu none
    add_kernel 6.11.1-arch1-1 linux
}

use_gpu() {
    LSPCI_FIXTURE="$FIXTURES_DIR/lspci/$1.txt"
    [[ -f "$LSPCI_FIXTURE" ]] || fail "missing fixture $1"
}

add_kernel() {
    mkdir -p "$MODULES_ROOT/$1"
    echo "$2" > "$MODULES_ROOT/$1/pkgbase"
}

lspci() {
    cat "$LSPCI_FIXTURE"
}

# Mimics `pacman -T`: prints the requested packages that are not installed.
pacman() {
    [[ "$1" == "-T" ]] || fail "unexpected pacman call: $*"
    shift
    local pkg
    for pkg in "$@"; do
        grep -qxF -- "$pkg" <<< "$INSTALLED_PKGS" || echo "$pkg"
    done
}

test_detects_nothing_without_gpu() {
    assert_empty "$(detect_gpu_vendors)"
    assert_empty "$(get_driver_packages)"
}

test_ignores_virtual_gpu() {
    use_gpu vm
    assert_empty "$(detect_gpu_vendors)"
    assert_empty "$(get_driver_packages)"
}

test_ignores_non_display_devices() {
    use_gpu nvidia_turing
    # Host bridge is Intel, audio function is NVIDIA: neither is a GPU.
    assert_eq "10de:1f08" "$(list_gpu_ids)"
    assert_eq "nvidia" "$(detect_gpu_vendors)"
}

test_detects_hybrid_laptop_vendors() {
    use_gpu hybrid_intel_nvidia
    assert_eq $'intel\nnvidia' "$(detect_gpu_vendors)"
}

test_deduplicates_vendor_with_two_gpus() {
    use_gpu amd_apu_and_dgpu
    assert_eq "amd" "$(detect_gpu_vendors)"
}

test_nvidia_branch_open_for_turing() {
    use_gpu nvidia_turing
    assert_eq "open" "$(detect_nvidia_branch)"
}

test_nvidia_branch_580xx_for_pascal() {
    use_gpu nvidia_pascal
    assert_eq "580xx" "$(detect_nvidia_branch)"
}

test_nvidia_branch_470xx_for_kepler() {
    use_gpu nvidia_kepler
    assert_eq "470xx" "$(detect_nvidia_branch)"
}

test_nvidia_branch_follows_oldest_gpu() {
    use_gpu mixed_nvidia_generations
    assert_eq "580xx" "$(detect_nvidia_branch)"
}

test_amd_packages() {
    use_gpu amd
    local pkgs
    pkgs=$(get_driver_packages)
    assert_eq $'mesa\nlib32-mesa\nvulkan-radeon\nlib32-vulkan-radeon' "$pkgs"
}

test_intel_and_amd_share_mesa() {
    use_gpu intel_amd
    local pkgs
    pkgs=$(get_driver_packages)
    assert_line_count "$pkgs" "mesa" 1
    assert_line_count "$pkgs" "lib32-mesa" 1
    assert_contains_line "$pkgs" "vulkan-intel"
    assert_contains_line "$pkgs" "intel-media-driver"
    assert_contains_line "$pkgs" "vulkan-radeon"
}

test_nvidia_open_packages_with_headers() {
    use_gpu nvidia_turing
    local pkgs
    pkgs=$(get_driver_packages)
    assert_contains_line "$pkgs" "nvidia-open-dkms"
    assert_contains_line "$pkgs" "nvidia-utils"
    assert_contains_line "$pkgs" "lib32-nvidia-utils"
    assert_contains_line "$pkgs" "linux-headers"
    assert_not_contains_line "$pkgs" "mesa"
}

test_nvidia_legacy_packages() {
    use_gpu nvidia_pascal
    local pkgs
    pkgs=$(get_driver_packages)
    assert_contains_line "$pkgs" "nvidia-580xx-dkms"
    assert_contains_line "$pkgs" "nvidia-580xx-utils"
    assert_not_contains_line "$pkgs" "nvidia-open-dkms"
}

test_headers_for_every_installed_kernel() {
    use_gpu nvidia_turing
    add_kernel 6.6.50-1-lts linux-lts
    add_kernel 6.11.1-zen1-1-zen linux-zen
    add_kernel 6.11.0-arch1-1 linux
    mkdir -p "$MODULES_ROOT/extramodules-6.11-arch"
    local pkgs
    pkgs=$(get_driver_packages)
    assert_line_count "$pkgs" "linux-headers" 1
    assert_contains_line "$pkgs" "linux-lts-headers"
    assert_contains_line "$pkgs" "linux-zen-headers"
}

test_existing_nvidia_driver_is_left_alone() {
    use_gpu hybrid_intel_nvidia
    INSTALLED_PKGS="nvidia-utils"
    local pkgs
    pkgs=$(get_driver_packages)
    assert_contains_line "$pkgs" "vulkan-intel"
    assert_not_contains_line "$pkgs" "nvidia-open-dkms"
    assert_not_contains_line "$pkgs" "linux-headers"
}

test_append_driver_packages_respects_toggle() {
    use_gpu amd
    local -a target_list=("kitty")

    OPT_DRIVERS=false
    append_driver_packages target_list
    assert_eq "kitty" "${target_list[*]}"

    OPT_DRIVERS=true
    append_driver_packages target_list
    assert_eq "kitty mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon" "${target_list[*]}"
}

test_append_driver_packages_without_gpu_keeps_list() {
    local -a target_list=("kitty" "jq")
    append_driver_packages target_list
    assert_eq "kitty jq" "${target_list[*]}"
}

test_works_under_errexit() {
    use_gpu amd
    # install.sh runs with `set -e`; a false condition inside must not abort.
    local out
    out=$(set -e; get_driver_packages; echo END)
    assert_eq "END" "$(tail -n1 <<< "$out")"
}
