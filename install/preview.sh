#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required to launch the installer preview.\n' >&2
    exit 1
fi

exec python3 "$SCRIPT_DIR/tui.py" --preview "$@"
