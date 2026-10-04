#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

RUN_DIR="${QS_RUN_FOCUSTIME:-${XDG_RUNTIME_DIR:-/run/user/${UID:-$(id -u)}}/serpantinum/focustime}"
mkdir -p "$RUN_DIR"

LOG_FILE="$RUN_DIR/focus_events.jsonl"
STATE_FILE="$RUN_DIR/focus_state.json"
: >> "$LOG_FILE"
: >> "$STATE_FILE"

for pid in $(pgrep -f "${0##*/}"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

cleanup() {
    trap - EXIT SIGTERM SIGINT
    pkill -P $$ 2>/dev/null
    exit 0
}
trap cleanup EXIT SIGTERM SIGINT

if [ -n "$NIRI_SOCKET" ] || pgrep -x niri >/dev/null 2>&1; then
    COMPOSITOR="niri"
elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland >/dev/null 2>&1; then
    COMPOSITOR="hyprland"
else
    COMPOSITOR="unknown"
fi

cls=""
title=""
active_addr=""

get_active_window_hyprland() {
    local data cls_lower title_lower
    data=$(timeout 2 hyprctl activewindow -j 2>/dev/null)
    if [ -z "$data" ] || [ "$data" = "{}" ]; then
        active_addr=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    IFS='|' read -r active_addr cls title < <(jq -r '(.initialClass // .class // "Unknown") as $c | "\(.address // "")|\($c)|\(.initialTitle // .title // $c)"' <<< "$data")
    cls="${cls:-Desktop}"
    title="${title:-Desktop}"
    cls_lower="${cls,,}"
    title_lower="${title,,}"
    if [[ "$cls_lower" == *quickshell* ]] || [[ "$title_lower" == *qs-master* ]] || [[ "$cls_lower" == *qs-master* ]]; then
        cls="Quickshell"
        title="Quickshell"
    fi
}

get_active_window_niri() {
    local data cls_lower title_lower
    data=$(timeout 2 niri msg -j focused-window 2>/dev/null)
    if [ -z "$data" ] || [ "$data" = "null" ] || [ "$data" = "{}" ]; then
        cls="Desktop"
        title="Desktop"
        return
    fi
    IFS='|' read -r cls title < <(jq -r '(.app_id // "Unknown") as $c | "\($c)|\(.title // $c)"' <<< "$data")
    cls="${cls:-Desktop}"
    title="${title:-Desktop}"
    cls_lower="${cls,,}"
    title_lower="${title,,}"
    if [[ "$cls_lower" == *quickshell* ]] || [[ "$title_lower" == *qs-master* ]] || [[ "$cls_lower" == *qs-master* ]]; then
        cls="Quickshell"
        title="Quickshell"
    fi
}

get_active_window() {
    if [ "$COMPOSITOR" = "niri" ]; then
        get_active_window_niri
    else
        get_active_window_hyprland
    fi
}

last_cls=""
last_title=""

emit_state() {
    local target_cls="$1" target_title="$2" ts esc_cls esc_title json_payload

    if [ "$target_cls" = "$last_cls" ] && [ "$target_title" = "$last_title" ]; then
        return
    fi
    last_cls="$target_cls"
    last_title="$target_title"

    printf -v ts '%(%s)T' -1

    esc_cls="${target_cls//\\/\\\\}"
    esc_cls="${esc_cls//\"/\\\"}"
    esc_cls="${esc_cls//$'\n'/\\n}"
    esc_cls="${esc_cls//$'\r'/\\r}"
    esc_cls="${esc_cls//$'\t'/\\t}"

    esc_title="${target_title//\\/\\\\}"
    esc_title="${esc_title//\"/\\\"}"
    esc_title="${esc_title//$'\n'/\\n}"
    esc_title="${esc_title//$'\r'/\\r}"
    esc_title="${esc_title//$'\t'/\\t}"

    json_payload="{\"timestamp\":$ts,\"app_class\":\"$esc_cls\",\"app_title\":\"$esc_title\"}"

    echo "$json_payload" >> "$LOG_FILE"
    echo "$json_payload" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

listen_events() {
    if [ "$COMPOSITOR" = "niri" ]; then
        niri msg --json event-stream 2>/dev/null
    else
        socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null
    fi
}

get_active_window
emit_state "$cls" "$title"

while true; do
    while read -r line; do
        case "$COMPOSITOR" in
            niri)
                case "$line" in
                    *'"WindowFocusChanged"'*|*'"WindowOpenedOrChanged"'*|*'"WindowClosed"'*|*'"WorkspaceActivated"'*)
                        while read -t 0.05 -r extra_line; do
                            continue
                        done
                        get_active_window
                        emit_state "$cls" "$title"
                        ;;
                esac
                ;;
            *)
                case "$line" in
                    activewindowv2*|closewindow*)
                        target="$line"
                        closed=false
                        [[ "$line" == closewindow* ]] && closed=true
                        while read -t 0.05 -r extra_line; do
                            case "$extra_line" in
                                activewindowv2*) target="$extra_line" ;;
                                closewindow*) closed=true ;;
                            esac
                        done
                        if [ "$closed" = false ] && [ "${target#activewindowv2>>}" = "${active_addr#0x}" ]; then
                            continue
                        fi
                        get_active_window
                        emit_state "$cls" "$title"
                        ;;
                esac
                ;;
        esac
    done < <(listen_events)
    sleep 1
done
