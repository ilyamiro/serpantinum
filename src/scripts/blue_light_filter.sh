#!/usr/bin/env bash
set -euo pipefail

TEMP_MIN=1000
TEMP_MAX=10000
DAY_TEMP=6500
FALLBACK_DAY_START=390
BUS="org.serpantinum.Gamma"
IFACE="org.serpantinum.Gamma"
SCHEDULE="org.serpantinum.Gamma.Schedule"
GAMMARELAY_PATTERN='^([^ ]*/)?wl-gammarelay-rs( |$)'

VERBOSE=0
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#ARGS[@]} -gt 0 ]]; then
    set -- "${ARGS[@]}"
else
    set --
fi

log() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo "[verbose] $*" >&2
    fi
}

usage() {
    exit 1
}

bus() {
    busctl --user --auto-start=no "$@"
}

gamma_running() {
    bus get-property "$BUS" / "$IFACE" Temperature >/dev/null 2>&1
}

gamma_pid() {
    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
        GetConnectionUnixProcessID s "$BUS" 2>/dev/null | awk '{print $2}'
}

gamma_start() {
    gamma_running && return 0

    if ! command -v serpantinum-gamma >/dev/null 2>&1; then
        log "serpantinum-gamma is not installed."
        return 1
    fi

    if pgrep -f "$GAMMARELAY_PATTERN" >/dev/null 2>&1; then
        log "Stopping wl-gammarelay-rs, which holds the gamma control."
        pkill -TERM -f "$GAMMARELAY_PATTERN" 2>/dev/null || true
        local i=0
        while pgrep -f "$GAMMARELAY_PATTERN" >/dev/null 2>&1 && (( i < 50 )); do
            sleep 0.02
            i=$((i+1))
        done
    fi

    log "Starting serpantinum-gamma."
    setsid -f serpantinum-gamma </dev/null >/dev/null 2>&1

    local i=0
    while ! gamma_running && (( i < 100 )); do
        sleep 0.02
        i=$((i+1))
    done
    gamma_running
}

gamma_stop() {
    local pid
    pid="$(gamma_pid)"
    [[ -n "$pid" ]] || return 0

    log "Stopping serpantinum-gamma ($pid)."
    kill -TERM "$pid" 2>/dev/null || return 0
    local i=0
    while kill -0 "$pid" 2>/dev/null && (( i < 50 )); do
        sleep 0.02
        i=$((i+1))
    done
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
    return 0
}

object_path() {
    local output="${1:-}"
    if [[ -n "$output" ]]; then
        echo "/outputs/${output//[^a-zA-Z0-9]/_}"
    else
        echo "/"
    fi
}

wait_for_path() {
    local path="$1"
    local i=0
    while ! bus get-property "$BUS" "$path" "$IFACE" Temperature >/dev/null 2>&1; do
        (( i < 100 )) || return 1
        sleep 0.02
        i=$((i+1))
    done
}

ready_path() {
    local output="${1:-}"
    gamma_start || return 1

    local path
    path="$(object_path "$output")"
    if ! wait_for_path "$path"; then
        log "Output '$output' is not connected."
        return 1
    fi
    echo "$path"
}

set_property() {
    local path="$1" iface="$2" prop="$3" type="$4" val="$5"
    if ! bus set-property "$BUS" "$path" "$iface" "$prop" "$type" "$val" >/dev/null 2>&1; then
        log "Failed to set $prop on $path."
        return 1
    fi
}

gamma_set_manual() {
    local temp="$1" output="${2:-}"
    local path
    path="$(ready_path "$output")" || return 1

    log "Setting manual temperature $temp on $path."
    set_property "$path" "$IFACE" Temperature q "$temp"
}

gamma_set_auto() {
    local temp="$1" output="${2:-}" lat="${3:-0}" lon="${4:-0}"
    local path
    path="$(ready_path "$output")" || return 1

    if awk -v lat="$lat" -v lon="$lon" 'BEGIN { exit !(lat == 0 && lon == 0) }'; then
        bus call "$BUS" / "$SCHEDULE" ClearLocation >/dev/null 2>&1 || return 1
    else
        bus call "$BUS" / "$SCHEDULE" SetLocation dd "$lat" "$lon" >/dev/null 2>&1 || return 1
    fi

    log "Following the schedule on $path (night_temp=$temp lat=$lat lon=$lon)."
    set_property / "$SCHEDULE" FallbackDayStart q "$FALLBACK_DAY_START" &&
        set_property "$path" "$SCHEDULE" DayTemperature q "$DAY_TEMP" &&
        set_property "$path" "$SCHEDULE" NightTemperature q "$temp" &&
        set_property "$path" "$SCHEDULE" Auto b true
}

gamma_reset() {
    local output="${1:-}"
    gamma_running || return 0

    local path
    path="$(object_path "$output")"
    wait_for_path "$path" || return 0

    log "Resetting $path to neutral temperature and full brightness."
    local ret=0
    set_property "$path" "$IFACE" Temperature q "$DAY_TEMP" || ret=$?
    set_property "$path" "$IFACE" Brightness d 1 || ret=$?
    set_property "$path" "$IFACE" Gamma d 1 || ret=$?
    set_property "$path" "$IFACE" Inverted b false || ret=$?
    return $ret
}

gamma_status() {
    local output="${1:-}"
    if ! gamma_running; then
        echo "stopped"
        return
    fi

    if [[ "$VERBOSE" -eq 1 ]]; then
        local path temp brightness auto
        path="$(object_path "$output")"
        temp="$(bus get-property "$BUS" "$path" "$IFACE" Temperature 2>/dev/null | awk '{print $2}' || true)"
        brightness="$(bus get-property "$BUS" "$path" "$IFACE" Brightness 2>/dev/null | awk '{print $2}' || true)"
        auto="$(bus get-property "$BUS" "$path" "$SCHEDULE" Auto 2>/dev/null | awk '{print $2}' || true)"
        log "Path: $path, Temperature: ${temp:-unknown}K, Brightness: ${brightness:-unknown}, Auto: ${auto:-unknown}"
    fi

    echo "running"
}

[[ $# -ge 1 ]] || usage

CMD="$1"
shift

case "$CMD" in
    set)
        [[ $# -ge 1 ]] || usage
        temp="$1"
        output="${2:-}"
        mode="${3:-manual}"
        lat="${4:-0}"
        lon="${5:-0}"
        if ! [[ "$temp" =~ ^[0-9]+$ ]] || (( temp < TEMP_MIN || temp > TEMP_MAX )); then
            log "Temperature $temp is outside valid range ($TEMP_MIN-$TEMP_MAX)."
            exit 1
        fi
        if ! [[ "$lat" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            log "Latitude '$lat' or longitude '$lon' is not a valid number."
            exit 1
        fi
        if [[ "$mode" == "auto" ]]; then
            gamma_set_auto "$temp" "$output" "$lat" "$lon"
        else
            gamma_set_manual "$temp" "$output"
        fi
        ;;
    reset)
        gamma_reset "${1:-}"
        ;;
    status)
        gamma_status "${1:-}"
        ;;
    start)
        gamma_start
        ;;
    stop)
        gamma_stop
        ;;
    *)
        usage
        ;;
esac
