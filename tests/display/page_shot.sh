#!/usr/bin/env bash
# usage: page_shot.sh <backend> <compositor-id> <wayland-display> <out-dir>
# Display page screenshots against a TEST compositor, through the sandbox.
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ $# -eq 4 ] || { sed -n '2,3p' "$0" >&2; exit 2; }
OUT=$(mkdir -p "$4" && cd "$4" && pwd)
exec "$HERE/sandbox.sh" "$1" "$2" "$3" -- bash "$HERE/page_shot_run.sh" "$OUT"
