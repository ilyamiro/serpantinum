#!/usr/bin/env bash
set -e

main() {
    local slug="${REPO_SLUG:-ilyamiro/serpantinum}"
    local branch="${SERPANTINUM_BRANCH:-master}"
    local dir
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    curl -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install.sh"
    if [ -t 0 ]; then
        bash "$dir/install.sh" "$@"
    elif [ -r /dev/tty ]; then
        bash "$dir/install.sh" "$@" < /dev/tty
    else
        bash "$dir/install.sh" "$@"
    fi
}

main "$@"
