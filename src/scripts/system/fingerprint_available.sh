#!/usr/bin/env bash

PAM_DIR="${1:-/etc/pam.d}"

command -v fprintd-list &>/dev/null || command -v fprintd-enroll &>/dev/null || exit 1

scan() {
    local file="$1" depth="$2" line words target
    [ "$depth" -gt 5 ] && return 1
    [ -r "$file" ] || return 1
    while IFS= read -r line; do
        line="${line%%#*}"
        case "$line" in
            *pam_fprintd*) return 0 ;;
        esac
        read -ra words <<< "$line"
        target=""
        case "${words[0]}" in
            auth|-auth)
                case "${words[1]}" in
                    include|substack) target="${words[2]}" ;;
                esac
                ;;
            @include) target="${words[1]}" ;;
        esac
        [ -z "$target" ] && continue
        case "$target" in
            /*) ;;
            *) target="$PAM_DIR/$target" ;;
        esac
        scan "$target" $((depth + 1)) && return 0
    done < "$file"
    return 1
}

config="$PAM_DIR/serpantinum"
[ -e "$config" ] || config="$PAM_DIR/login"

scan "$config" 0
