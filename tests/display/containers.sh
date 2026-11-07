#!/usr/bin/env bash
# Run the display-manager tests on other distros without touching this machine.
#
#   tests/display/containers.sh              # fedora, void and nixos
#   tests/display/containers.sh void nixos   # only some
#
# Needs rootless podman and network (images and packages are downloaded inside throwaway
# containers). The repository is mounted READ-ONLY, so a test or script that tries to write
# next to its own files fails. These runs check the logic and the packaging assumptions of
# each distro; they cannot check real monitors (there is no Hyprland in a container).
#
#   fedora  python3 from dnf; the suite.
#   void    musl-less glibc image: no systemd, no /run/user, no XDG_RUNTIME_DIR. The suite plus a
#           smoke test that the runtime dir falls back to a private temp dir and the reverter
#           uses setsid.
#   nixos   python3 from nixpkgs; the suite, detection of a hyprland.lua that really is a link
#           into /nix/store, and a copy of src/ shaped like nix/package.nix's installPhase.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tests/display"
command -v podman >/dev/null || { echo "Falta podman." >&2; exit 1; }

run() {  # run <image> <extra mounts...> -- <shell command>
    local image="$1"; shift
    local mounts=()
    while [ "$1" != "--" ]; do mounts+=("$1"); shift; done
    shift
    podman run --rm -e PYTHONDONTWRITEBYTECODE=1 -v "$ROOT:/repo:ro" -w /repo "${mounts[@]}" "$image" sh -c "$1"
}

SUITE='python3 --version; python3 -m unittest discover -s tests/display 2>&1 | tail -n 4'

fedora() {
    run registry.fedoraproject.org/fedora:latest -- "dnf install -y -q python3 >/dev/null 2>&1; $SUITE"
}

void() {
    run ghcr.io/void-linux/void-glibc:latest \
        -v "$HERE/container-void-smoke.py:/smoke.py:ro" -- \
        "xbps-install -Syu xbps >/dev/null 2>&1; xbps-install -Sy python3 >/dev/null 2>&1; $SUITE; echo '--- Void smoke'; python3 /smoke.py"
}

nixos() {
    run docker.io/nixos/nix:latest \
        -v "$HERE/container-nix-check.sh:/nixcheck.sh:ro" -- \
        'nix-shell -p python3 --run "sh /nixcheck.sh"'
}

targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(fedora void nixos)
for t in "${targets[@]}"; do
    case "$t" in fedora|void|nixos) ;; *) echo "Desconocido: $t (fedora|void|nixos)" >&2; exit 1 ;; esac
    echo "=================== $t"
    "$t"
done
