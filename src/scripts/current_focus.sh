#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

RUN_DIR="${QS_RUN_FOCUSTIME:-${XDG_RUNTIME_DIR:-/run/user/${UID:-$(id -u)}}/serpantinum/focustime}"
mkdir -p "$RUN_DIR" 2>/dev/null

PID_FILE="$RUN_DIR/current_focus.pid"
LOG_FILE="$RUN_DIR/focus_events.jsonl"
STATE_FILE="$RUN_DIR/focus_state.json"
: >> "$LOG_FILE"
: >> "$STATE_FILE"

# Prevent tmpfs unbounded memory growth by trimming existing log file to last 200 lines
if [ -f "$LOG_FILE" ]; then
    tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
log_append_count=0

# Clean termination of old instance via PID file instead of heavy proc-scanning
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
        kill -TERM "$old_pid" 2>/dev/null
        for _ in 1 2 3 4 5; do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.01 2>/dev/null || :
        done
        kill -9 "$old_pid" 2>/dev/null || :
    fi
fi
echo "$$" > "$PID_FILE"

cleanup() {
    trap - EXIT SIGTERM SIGINT
    rm -f "$PID_FILE" 2>/dev/null
    pkill -P $$ 2>/dev/null
    exit 0
}
trap cleanup EXIT SIGTERM SIGINT

# Fast compositor detection: prioritize environment variables to avoid proc scans
if [ -n "$MANGO_INSTANCE_SIGNATURE" ]; then
    COMPOSITOR="mango"
elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    COMPOSITOR="hyprland"
elif [ -n "$NIRI_SOCKET" ]; then
    COMPOSITOR="niri"
elif [ -n "$SWAYSOCK" ]; then
    COMPOSITOR="sway"
elif command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
    COMPOSITOR="hyprland"
elif command -v niri >/dev/null 2>&1 && pgrep -x niri >/dev/null 2>&1; then
    COMPOSITOR="niri"
elif command -v swaymsg >/dev/null 2>&1 && pgrep -x sway >/dev/null 2>&1; then
    COMPOSITOR="sway"
elif command -v mmsg >/dev/null 2>&1 && pgrep -x mango >/dev/null 2>&1; then
    COMPOSITOR="mango"
else
    COMPOSITOR="unknown"
fi

cls=""
title=""
active_addr=""
active_niri_id=""
active_sway_id=""
active_mango_id=""

get_active_window_hyprland() {
    local data raw cls_lower title_lower
    data=$(timeout 0.4 hyprctl activewindow -j 2>/dev/null)
    if [ -z "$data" ] || [ "$data" = "{}" ]; then
        active_addr=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    raw=$(jq -r '(.initialClass // .class // "Unknown") as $c | "\(.address // "")|\($c)|\(.initialTitle // .title // $c)"' <<< "$data" 2>/dev/null)
    IFS='|' read -r active_addr cls title <<< "$raw"
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
    local data raw cls_lower title_lower
    data=$(timeout 0.4 niri msg -j focused-window 2>/dev/null)
    if [ -z "$data" ] || [ "$data" = "null" ] || [ "$data" = "{}" ]; then
        active_niri_id=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    raw=$(jq -r '(.app_id // "Unknown") as $c | "\(.id // "")|\($c)|\(.title // $c)"' <<< "$data" 2>/dev/null)
    IFS='|' read -r active_niri_id cls title <<< "$raw"
    cls="${cls:-Desktop}"
    title="${title:-Desktop}"
    cls_lower="${cls,,}"
    title_lower="${title,,}"
    if [[ "$cls_lower" == *quickshell* ]] || [[ "$title_lower" == *qs-master* ]] || [[ "$cls_lower" == *qs-master* ]]; then
        cls="Quickshell"
        title="Quickshell"
    fi
}

get_active_window_sway() {
    local data raw cls_lower title_lower
    data=$(timeout 0.4 swaymsg -t get_tree 2>/dev/null)
    if [ -z "$data" ]; then
        active_sway_id=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    raw=$(jq -r '.. | select(.focused? == true and (.type? == "con" or .type? == "floating_con")) | "\(.id // "")|\(.app_id // .window_properties?.class // "Unknown")|\(.name // "Unknown")"' <<< "$data" 2>/dev/null)
    if [ -z "$raw" ]; then
        active_sway_id=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    IFS='|' read -r active_sway_id cls title <<< "$raw"
    cls="${cls:-Desktop}"
    title="${title:-Desktop}"
    cls_lower="${cls,,}"
    title_lower="${title,,}"
    if [[ "$cls_lower" == *quickshell* ]] || [[ "$title_lower" == *qs-master* ]] || [[ "$cls_lower" == *qs-master* ]]; then
        cls="Quickshell"
        title="Quickshell"
    fi
}

get_active_window_mango() {
    local data raw cls_lower title_lower
    data=$(timeout 0.4 mmsg get focusing-client 2>/dev/null)
    if [ -z "$data" ] || [[ "$data" == *'"error"'* ]]; then
        active_mango_id=""
        cls="Desktop"
        title="Desktop"
        return
    fi
    raw=$(jq -r '(.appid // "Unknown") as $c | "\(.id // "")|\($c)|\(.title // $c)"' <<< "$data" 2>/dev/null)
    IFS='|' read -r active_mango_id cls title <<< "$raw"
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
    case "$COMPOSITOR" in
        niri) get_active_window_niri ;;
        sway) get_active_window_sway ;;
        mango) get_active_window_mango ;;
        *)    get_active_window_hyprland ;;
    esac
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

    # Direct stdout output for instant IPC delivery to Quickshell Process listener
    printf '%s\n' "$json_payload"

    # In-place write preserving file inode to prevent inotify watcher disconnection
    printf '%s\n' "$json_payload" > "$STATE_FILE"
    printf '%s\n' "$json_payload" >> "$LOG_FILE"

    log_append_count=$((log_append_count + 1))
    if [ "$log_append_count" -ge 100 ]; then
        log_append_count=0
        if [ -f "$LOG_FILE" ]; then
            tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

listen_events() {
    if [ "$COMPOSITOR" = "niri" ]; then
        niri msg --json event-stream 2>/dev/null
    elif [ "$COMPOSITOR" = "sway" ]; then
        swaymsg -t subscribe -m '["window", "workspace"]' 2>/dev/null
    elif [ "$COMPOSITOR" = "mango" ]; then
        mmsg watch focusing-client 2>/dev/null
    else
        local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
        if [ ! -S "$sock" ]; then
            sock="/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
        fi
        socat -u UNIX-CONNECT:"$sock" - 2>/dev/null
    fi
}

get_active_window
emit_state "$cls" "$title"

while true; do
    while read -r line; do
        case "$COMPOSITOR" in
            niri)
                case "$line" in
                    *'"WindowFocusChanged"'*|*'"WindowClosed"'*|*'"WorkspaceActivated"'*|*'"WindowOpenedOrChanged"'*)
                        target_id=""
                        has_focus_event=false
                        is_window_changed=false
                        closed=false
                        is_workspace=false

                        _parse_niri_line() {
                            local l="$1"
                            [[ "$l" == *'"WindowClosed"'* ]] && closed=true
                            [[ "$l" == *'"WorkspaceActivated"'* ]] && is_workspace=true
                            if [[ "$l" =~ \"WindowFocusChanged\":\{\"id\":([0-9]+)\} ]]; then
                                target_id="${BASH_REMATCH[1]}"
                                has_focus_event=true
                            elif [[ "$l" == *'"WindowFocusChanged":{"id":null}'* ]]; then
                                target_id="null"
                                has_focus_event=true
                            elif [[ "$l" == *'"WindowOpenedOrChanged"'* ]]; then
                                if [[ "$l" =~ \"is_focused\":\ *true ]]; then
                                    if [[ "$l" =~ \"window\":\{\"id\":([0-9]+) ]] || [[ "$l" =~ \"id\":([0-9]+) ]]; then
                                        target_id="${BASH_REMATCH[1]}"
                                        has_focus_event=true
                                        is_window_changed=true
                                    fi
                                fi
                            fi
                        }

                        _parse_niri_line "$line"
                        while read -t 0.02 -r extra_line; do
                            _parse_niri_line "$extra_line"
                        done

                        # If it was an unfocused WindowOpenedOrChanged with no other relevant events, ignore
                        if [ "$closed" = false ] && [ "$has_focus_event" = false ] && [ "$is_workspace" = false ]; then
                            continue
                        fi

                        # If it was a pure focus event to the currently active window, skip
                        if [ "$closed" = false ] && [ "$has_focus_event" = true ] && [ "$is_window_changed" = false ]; then
                            if [ "$target_id" = "$active_niri_id" ] || { [ "$target_id" = "null" ] && [ -z "$active_niri_id" ]; }; then
                                continue
                            fi
                        fi
                        get_active_window
                        emit_state "$cls" "$title"
                        ;;
                esac
                ;;
            sway)
                case "$line" in
                    *'"change"'*)
                        target_id=""
                        has_focus_event=false
                        is_window_changed=false
                        closed=false
                        is_workspace=false

                        _parse_sway_line() {
                            local l="$1"
                            if [[ "$l" =~ \"change\":\ *\"close\" ]]; then
                                closed=true
                            elif [[ "$l" =~ \"change\":\ *\"focus\" ]] && [[ "$l" =~ \"current\": ]]; then
                                is_workspace=true
                            elif [[ "$l" =~ \"change\":\ *\"focus\" ]] && [[ "$l" =~ \"container\": ]]; then
                                if [[ "$l" =~ \"container\":\{[^{}]*\"id\":\ *([0-9]+) ]] || [[ "$l" =~ \"id\":\ *([0-9]+) ]]; then
                                    target_id="${BASH_REMATCH[1]}"
                                fi
                                has_focus_event=true
                            elif [[ "$l" =~ \"change\":\ *\"title\" ]]; then
                                if [[ "$l" =~ \"focused\":\ *true ]]; then
                                    if [[ "$l" =~ \"container\":\{[^{}]*\"id\":\ *([0-9]+) ]] || [[ "$l" =~ \"id\":\ *([0-9]+) ]]; then
                                        target_id="${BASH_REMATCH[1]}"
                                    fi
                                    has_focus_event=true
                                    is_window_changed=true
                                fi
                            fi
                        }

                        _parse_sway_line "$line"
                        while read -t 0.02 -r extra_line; do
                            _parse_sway_line "$extra_line"
                        done

                        # If it was an unfocused title/window event with no other relevant events, ignore
                        if [ "$closed" = false ] && [ "$has_focus_event" = false ] && [ "$is_workspace" = false ]; then
                            continue
                        fi

                        # If it was a pure focus event to the currently active window, skip
                        if [ "$closed" = false ] && [ "$has_focus_event" = true ] && [ "$is_window_changed" = false ]; then
                            if [ -n "$target_id" ] && [ "$target_id" = "$active_sway_id" ]; then
                                continue
                            fi
                        fi
                        get_active_window
                        emit_state "$cls" "$title"
                        ;;
                esac
                ;;
            mango)
                while read -t 0.02 -r _; do :; done
                get_active_window
                emit_state "$cls" "$title"
                ;;
            *)
                case "$line" in
                    activewindowv2*|closewindow*)
                        target="$line"
                        closed=false
                        [[ "$line" == closewindow* ]] && closed=true
                        while read -t 0.02 -r extra_line; do
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
