#!/usr/bin/env bash
# Hyprland only. Minimize the focused window: take its snapshot (shown by the dock's hover
# preview), then move it to the hidden special:minimized workspace. Restoring is done by
# clicking the window in the dock.
set -u

win=$(hyprctl activewindow -j 2>/dev/null) || exit 0
addr=$(jq -r '.address // empty' <<<"$win")
[ -n "$addr" ] || exit 0
[ "$(jq -r '.workspace.name' <<<"$win")" = "special:minimized" ] && exit 0

"$(dirname "$(realpath "${BASH_SOURCE[0]}")")/window_snapshot.sh" "$addr"

hyprctl dispatch "hl.dsp.window.move({workspace=\"special:minimized\", window=\"address:$addr\", follow=false})" >/dev/null
