#!/usr/bin/env bash
#
# Minimize windows to the "minimized" special workspace on Hyprland
# (macOS-style minimize-to-dock) and restore them on demand.
#
# State is tracked in $QS_RUN_DIR/minimized.json so the dock can list
# minimized windows with icons and restore them on click.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/i18n.sh"

STATE_FILE="$QS_RUN_DIR/minimized.json"
SPECIAL_WS="special:minimized"

need_hyprland() {
    if ! command -v hyprctl >/dev/null 2>&1 || [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        echo "$(t "minimize.error_hyprland_only")" >&2
        exit 1
    fi
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Serpantinum" "$1" 2>/dev/null || true
}

# hypr_eval <lua-body> : run hl.dispatch(...) via eval (required on the
# Lua config parser where classic `hyprctl dispatch args` is unavailable).
hypr_eval() {
    hyprctl eval "$1" >/dev/null 2>&1
}

load_state() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" 2>/dev/null || echo "[]"
}

save_state() {
    mkdir -p "$QS_RUN_DIR" 2>/dev/null || true
    printf '%s\n' "$1" > "$STATE_FILE"
}

# Drop entries whose windows no longer exist.
prune_state() {
    local state addrs addr
    state="$(load_state)"
    addrs="$(hyprctl clients -j 2>/dev/null | jq -r '.[].address' 2>/dev/null)"
    state="$(printf '%s' "$state" | jq --argjson keep "$(printf '%s' "$addrs" | jq -R . | jq -s .)" \
        'map(select(.address as $a | $keep | index($a)))' 2>/dev/null || echo "[]")"
    save_state "$state"
    printf '%s' "$state"
}

active_address() {
    hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null
}

focused_workspace_id() {
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null
}

cmd_minimize() {
    need_hyprland
    local addr="${1:-}"
    [[ -z "$addr" ]] && addr="$(active_address)"
    if [[ -z "$addr" ]]; then
        echo "$(t "minimize.error_no_window")" >&2
        exit 1
    fi
    local info cls title floating
    info="$(hyprctl clients -j 2>/dev/null | jq -r --arg a "$addr" '.[] | select(.address == $a) | "\(.class)|\(.title)|\(.floating)"' 2>/dev/null | head -n 1)"
    cls="${info%%|*}"
    title="$(printf '%s' "${info#*|}" | cut -d'|' -f1)"
    floating="$(printf '%s' "$info" | awk -F'|' '{print $NF}')"
    # Float first so the tiling layout doesn't reflow when the window leaves
    # (macOS-like behavior); original state is restored on unminimize.
    local was_floating="true"
    if [[ "$floating" != "true" ]]; then
        was_floating="false"
        hypr_eval "hl.dispatch(hl.dsp.window.float({ action = \"set\", window = \"address:$addr\" }))"
    fi
    hypr_eval "hl.dispatch(hl.dsp.window.move({ workspace = \"$SPECIAL_WS\", window = \"address:$addr\" }))"
    local state
    state="$(prune_state)"
    state="$(printf '%s' "$state" | jq --arg a "$addr" --arg c "$cls" --arg t "$title" --argjson f "$was_floating" \
        'map(select(.address != $a)) + [{address: $a, class: $c, title: $t, floating: $f}]' 2>/dev/null)"
    save_state "$state"
    notify "$(t "minimize.minimized_title")"
    echo "$(t "minimize.minimized_title")"
}

cmd_restore() {
    need_hyprland
    local addr="${1:-}"
    if [[ -z "$addr" ]]; then
        echo "$(t "minimize.error_no_address")" >&2
        exit 1
    fi
    local ws
    ws="$(focused_workspace_id)"
    [[ -z "$ws" ]] && ws="1"
    hypr_eval "hl.dispatch(hl.dsp.window.move({ workspace = $ws, window = \"address:$addr\" }))"
    hypr_eval "hl.dispatch(hl.dsp.focus({ window = \"address:$addr\" }))"
    local state was_floating
    state="$(prune_state)"
    was_floating="$(printf '%s' "$state" | jq -r --arg a "$addr" '.[] | select(.address == $a) | .floating // true' 2>/dev/null | head -n 1)"
    if [[ "$was_floating" == "false" ]]; then
        # small delay: unsetting float in the same tick as leaving the
        # special workspace is silently dropped by the compositor
        sleep 0.5
        hypr_eval "hl.dispatch(hl.dsp.window.float({ action = \"unset\", window = \"address:$addr\" }))"
    fi
    state="$(printf '%s' "$state" | jq --arg a "$addr" 'map(select(.address != $a))' 2>/dev/null || echo "[]")"
    save_state "$state"
    echo "$(t "minimize.restored_title")"
}

cmd_list() {
    need_hyprland
    prune_state | jq -r '.[] | "\(.address)|\(.class)|\(.title)"' 2>/dev/null
}

case "${1:-}" in
    ""|minimize) cmd_minimize "${2:-}" ;;
    0x*) cmd_minimize "$1" ;;
    restore) cmd_restore "${2:-}" ;;
    list) cmd_list ;;
    -h|--help|help) echo "$(t "minimize.help")" ;;
    *)
        echo "$(t "minimize.error_unknown_arg" "ARG=$1")" >&2
        exit 1
        ;;
esac
