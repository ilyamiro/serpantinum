#!/usr/bin/env bash

WORKER_URL="https://dots-telemetry.ilyamiro-work.workers.dev"

MODE=""
VERSION=""
OLD_VERSION=""
INSTALL_STATE=""
COMPOSITOR=""
TELEMETRY_ID=""
OS_NAME=""
TELEMETRY_ENABLED="true"
FAILED_PACKAGES=""
CPU_INFO=""
GPU_INFO=""
KERNEL_INFO=""
RAM_INFO=""
DE_INFO=""
ARCH_INFO=""
SESSION_INFO=""

format_uuid() {
    local raw
    raw=$(echo "$1" | tr -d '-' | tr '[:upper:]' '[:lower:]' | tr -cd '0-9a-f')
    if [[ ${#raw} -eq 32 ]]; then
        echo "$raw" | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
    else
        echo "$1"
    fi
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --mode|-m) MODE="$2"; shift 2 ;;
        --version|-v) VERSION="$2"; shift 2 ;;
        --old-version) OLD_VERSION="$2"; shift 2 ;;
        --install-state) INSTALL_STATE="$2"; shift 2 ;;
        --compositor|-c) COMPOSITOR="$2"; shift 2 ;;
        --id) TELEMETRY_ID="$2"; shift 2 ;;
        --os) OS_NAME="$2"; shift 2 ;;
        --enabled) TELEMETRY_ENABLED="$2"; shift 2 ;;
        --failed) FAILED_PACKAGES="$2"; shift 2 ;;
        --cpu) CPU_INFO="$2"; shift 2 ;;
        --gpu) GPU_INFO="$2"; shift 2 ;;
        --kernel) KERNEL_INFO="$2"; shift 2 ;;
        --ram) RAM_INFO="$2"; shift 2 ;;
        --de) DE_INFO="$2"; shift 2 ;;
        --arch) ARCH_INFO="$2"; shift 2 ;;
        --session) SESSION_INFO="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$MODE" ]]; then
    exit 1
fi

TELEMETRY_ID=$(format_uuid "$TELEMETRY_ID")

if [[ -z "$OS_NAME" && -f /etc/os-release ]]; then
    OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

if [[ "$OS_NAME" =~ "Fedora" ]]; then
    exit 0
fi

if [[ -z "$WORKER_URL" || "$WORKER_URL" == *"YOUR_USERNAME"* ]]; then
    exit 0
fi

payload=""

if [[ "$MODE" == "init" || "$MODE" == "full" ]]; then
    if [[ "$TELEMETRY_ENABLED" == "true" ]]; then
        payload=$(cat <<EOF
{
  "type": "${MODE}",
  "version": "${VERSION}",
  "id": "${TELEMETRY_ID}",
  "os": "${OS_NAME//\"/\\\"}"
}
EOF
)
    else
        payload=$(cat <<EOF
{
  "type": "${MODE}",
  "version": "${VERSION}",
  "id": "${TELEMETRY_ID}"
}
EOF
)
    fi
elif [[ "$MODE" == "done" ]]; then
    if [[ "$TELEMETRY_ENABLED" == "true" ]]; then
        [[ -z "$RAM_INFO" ]] && RAM_INFO=$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "Unknown")
        [[ -z "$KERNEL_INFO" ]] && KERNEL_INFO=$(uname -r 2>/dev/null || echo "Unknown")
        [[ -z "$DE_INFO" ]] && DE_INFO=${XDG_CURRENT_DESKTOP:-"TTY / Unknown"}
        [[ -z "$CPU_INFO" ]] && CPU_INFO=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
        [[ -z "$ARCH_INFO" ]] && ARCH_INFO=$(uname -m 2>/dev/null || echo "Unknown")
        [[ -z "$SESSION_INFO" ]] && SESSION_INFO=${XDG_SESSION_TYPE:-"Unknown"}
        if [[ -z "$GPU_INFO" ]]; then
            GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display')
            GPU_INFO=$(echo "$GPU_RAW" | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//g' | xargs)
            [[ -z "$GPU_INFO" ]] && GPU_INFO="Unknown / Virtual Machine"
        fi

        payload=$(cat <<EOF
{
  "type": "done",
  "version": "${VERSION}",
  "old_version": "${OLD_VERSION//\"/\\\"}",
  "install_state": "${INSTALL_STATE//\"/\\\"}",
  "compositor": "${COMPOSITOR//\"/\\\"}",
  "id": "${TELEMETRY_ID}",
  "telemetry_enabled": true,
  "failed_packages": "${FAILED_PACKAGES//\"/\\\"}",
  "os": "${OS_NAME//\"/\\\"}",
  "kernel": "${KERNEL_INFO//\"/\\\"}",
  "ram": "${RAM_INFO//\"/\\\"}",
  "de": "${DE_INFO//\"/\\\"}",
  "cpu": "${CPU_INFO//\"/\\\"}",
  "gpu": "${GPU_INFO//\"/\\\"}",
  "arch": "${ARCH_INFO//\"/\\\"}",
  "session": "${SESSION_INFO//\"/\\\"}"
}
EOF
)
    else
        payload=$(cat <<EOF
{
  "type": "done",
  "version": "${VERSION}",
  "old_version": "${OLD_VERSION//\"/\\\"}",
  "install_state": "${INSTALL_STATE//\"/\\\"}",
  "id": "${TELEMETRY_ID}",
  "telemetry_enabled": false
}
EOF
)
    fi
fi

if [[ -n "$payload" ]]; then
    curl -X POST -H "Content-Type: application/json" -d "$payload" "$WORKER_URL" -s -o /dev/null &
fi
