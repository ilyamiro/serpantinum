#!/usr/bin/env bash

MODULE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
if [ -z "$SERPANTINUM_DIR" ]; then
    if [ -d "$(dirname "$(dirname "$MODULE_DIR")")/src" ]; then
        export SERPANTINUM_DIR="$(dirname "$(dirname "$MODULE_DIR")")/src"
    fi
fi

if [ -n "$SERPANTINUM_DIR" ] && [ -f "$SERPANTINUM_DIR/scripts/caching.sh" ]; then
    source "$SERPANTINUM_DIR/scripts/caching.sh"
fi

STATE_DIR="${QS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum}"
VERSION_FILE="$STATE_DIR/version"
DEFAULT_FALLBACK_VERSION="2.0.0"

format_uuid() {
    local raw
    raw=$(echo "$1" | tr -d '-' | tr '[:upper:]' '[:lower:]' | tr -cd '0-9a-f')
    if [[ ${#raw} -eq 32 ]]; then
        echo "$raw" | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
    else
        echo "$1"
    fi
}

get_telemetry_id() {
    if [ -f "$VERSION_FILE" ]; then
        local id
        id=$(awk -F= '/^TELEMETRY_ID=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE")
        if [ -n "$id" ]; then
            format_uuid "$id"
            return
        fi
    fi

    local raw_id=""
    if command -v uuidgen &> /dev/null; then
        raw_id=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        raw_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    elif [ -f /etc/machine-id ]; then
        raw_id=$(cat /etc/machine-id 2>/dev/null)
    else
        raw_id=$(head -c 16 /dev/urandom | od -An -t x1 | tr -d ' \n')
    fi

    format_uuid "$raw_id"
}

get_telemetry_enabled() {
    if [ -f "$VERSION_FILE" ]; then
        local enabled
        enabled=$(awk -F= '/^ENABLE_TELEMETRY=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE")
        if [ "$enabled" = "false" ]; then
            echo "false"
            return
        fi
    fi
    echo "true"
}

get_installed_version() {
    local ver=""
    if [ -f "$VERSION_FILE" ]; then
        ver=$(awk -F= '/^SERPANTINUM_VERSION=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE")
    fi
    if [ -z "$ver" ] && [ -n "$SERPANTINUM_VERSION" ]; then
        ver="$SERPANTINUM_VERSION"
    fi
    if [ -z "$ver" ]; then
        if [ -n "$SERPANTINUM_DIR" ] && [ -f "$SERPANTINUM_DIR/version.txt" ]; then
            ver=$(cat "$SERPANTINUM_DIR/version.txt" 2>/dev/null | xargs)
        elif [ -n "$SERPANTINUM_DIR" ] && [ -f "$(dirname "$SERPANTINUM_DIR")/version.txt" ]; then
            ver=$(cat "$(dirname "$SERPANTINUM_DIR")/version.txt" 2>/dev/null | xargs)
        elif [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/version.txt" ]; then
            ver=$(cat "$REPO_ROOT/version.txt" 2>/dev/null | xargs)
        fi
    fi
    if [ -z "$ver" ]; then
        ver="$DEFAULT_FALLBACK_VERSION"
    fi
    echo "$ver"
}

get_installed_commit() {
    if [ -f "$VERSION_FILE" ]; then
        awk -F= '/^SERPANTINUM_COMMIT=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE"
    fi
}

get_target_version() {
    local repo_root="$1"
    local repo_slug="${2:-"${REPO_SLUG:-"timl000/serpantinum"}"}"
    local target_ver=""

    if [ -f "$repo_root/version.txt" ]; then
        target_ver=$(cat "$repo_root/version.txt" 2>/dev/null | xargs)
    fi

    if [[ -z "$target_ver" || "$target_ver" == "null" ]]; then
        if command -v curl &>/dev/null; then
            target_ver=$(curl -s "https://raw.githubusercontent.com/${repo_slug}/${SERPANTINUM_BRANCH:-minecraft}/version.txt" 2>/dev/null | xargs)
        fi
    fi

    if [[ -z "$target_ver" || "$target_ver" == "null" ]]; then
        target_ver="$DEFAULT_FALLBACK_VERSION"
    fi

    echo "$target_ver"
}

get_target_commit() {
    local repo_root="$1"
    local repo_slug="${2:-"${REPO_SLUG:-"timl000/serpantinum"}"}"
    local target_commit=""

    if [ -d "$repo_root/.git" ] && command -v git &>/dev/null; then
        target_commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || true)
    fi

    if [[ -z "$target_commit" || "$target_commit" == "null" ]]; then
        if command -v curl &>/dev/null && command -v jq &>/dev/null; then
            target_commit=$(curl -s "https://api.github.com/repos/${repo_slug}/commits/${SERPANTINUM_BRANCH:-minecraft}" 2>/dev/null | jq -r '.sha[:7] // empty')
        fi
    fi

    if [[ -z "$target_commit" || "$target_commit" == "null" ]]; then
        target_commit="unknown"
    fi

    echo "$target_commit"
}

write_version_state() {
    local version="${1:-"$DEFAULT_FALLBACK_VERSION"}"
    local commit="${2:-"unknown"}"
    local tel_id="$3"
    local tel_enabled="${4:-true}"
    local compositors="$5"

    if [[ -z "$commit" || "$commit" == "null" ]]; then
        commit="unknown"
    fi

    if [[ -z "$tel_id" ]]; then
        tel_id=$(get_telemetry_id)
    else
        tel_id=$(format_uuid "$tel_id")
    fi

    mkdir -p "$STATE_DIR"
    local tmp_file="${VERSION_FILE}.tmp.$$"
    cat <<EOF > "$tmp_file"
SERPANTINUM_VERSION="$version"
SERPANTINUM_COMMIT="$commit"
TELEMETRY_ID="$tel_id"
ENABLE_TELEMETRY="$tel_enabled"
SELECTED_COMPOSITORS="$compositors"
EOF
    mv -f "$tmp_file" "$VERSION_FILE"
}
