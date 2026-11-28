#!/usr/bin/env bash

os_release_path() {
    if [ -n "${OS_RELEASE_FILE+x}" ]; then
        printf '%s\n' "$OS_RELEASE_FILE"
    elif [ -f /etc/os-release ]; then
        printf '%s\n' "/etc/os-release"
    elif [ -f /usr/lib/os-release ]; then
        printf '%s\n' "/usr/lib/os-release"
    else
        printf '%s\n' "/etc/os-release"
    fi
}

os_release_get() {
    local key="$1"
    local file="${2:-$(os_release_path)}"
    [ -f "$file" ] || return 1

    local line val="" found=false
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        case "$line" in
            ""|\#*) continue ;;
            "${key}="*)
                val="${line#"${key}="}"
                found=true
                ;;
        esac
    done < "$file"

    [ "$found" = true ] || return 0

    val="${val%"${val##*[![:space:]]}"}"

    if [ "${#val}" -ge 2 ] && [ "${val:0:1}" = '"' ] && [ "${val: -1}" = '"' ]; then
        val="${val:1:${#val}-2}"
        if [[ "$val" == *\\* ]]; then
            local out="" i=0 len=${#val} ch next
            while [ "$i" -lt "$len" ]; do
                ch="${val:$i:1}"
                if [ "$ch" = '\' ] && [ $((i + 1)) -lt "$len" ]; then
                    next="${val:$((i + 1)):1}"
                    case "$next" in
                        \"|\\|\$|\`)
                            out+="$next"
                            i=$((i + 2))
                            continue
                            ;;
                    esac
                fi
                out+="$ch"
                i=$((i + 1))
            done
            val="$out"
        fi
    elif [ "${#val}" -ge 2 ] && [ "${val:0:1}" = "'" ] && [ "${val: -1}" = "'" ]; then
        val="${val:1:${#val}-2}"
    fi

    printf '%s\n' "$val"
}
