#!/usr/bin/env bash

stale_pids() {
    local name="$1" pattern="$2" installed pid exe
    installed="$(command -v "$name" 2>/dev/null)" || return 0
    installed="$(realpath "$installed" 2>/dev/null)" || return 0
    for pid in $(pgrep -u "$(id -u)" -f "$pattern" 2>/dev/null); do
        exe="$(readlink "/proc/$pid/exe" 2>/dev/null)" || continue
        [ "$exe" != "$installed" ] && echo "$pid"
    done
}

wait_gone() {
    local pid count
    for pid in "$@"; do
        count=0
        while kill -0 "$pid" 2>/dev/null && [ "$count" -lt 40 ]; do
            sleep 0.05
            count=$((count + 1))
        done
        kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null
    done
}

pids="$(stale_pids serpantinum-core '(^|/)serpantinum-core$')"
if [ -n "$pids" ]; then
    serpantinum-core quit >/dev/null 2>&1
    wait_gone $pids
    serpantinum-core start >/dev/null 2>&1
fi

pids="$(stale_pids serpantinum-audio '(^|/)serpantinum-audio daemon$')"
if [ -n "$pids" ]; then
    serpantinum-audio ctl quit >/dev/null 2>&1
    wait_gone $pids
    serpantinum-audio start >/dev/null 2>&1
fi

pids="$(stale_pids serpantinum-gamma '(^|/)serpantinum-gamma$')"
if [ -n "$pids" ]; then
    serpantinum-gamma quit >/dev/null 2>&1
    wait_gone $pids
    serpantinum-gamma start >/dev/null 2>&1
fi

exit 0
