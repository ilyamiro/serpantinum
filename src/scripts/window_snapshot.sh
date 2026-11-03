#!/usr/bin/env bash
# Hyprland only. Save a small JPEG of one window for the dock's hover previews.
#   window_snapshot.sh <address>
# One file per window instance (named after its address), overwritten in place: there is no history, and
# files of windows that no longer exist are removed. Does nothing unless the window is actually
# on screen right now, so it never photographs another workspace or a special workspace.
set -u

dir="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/windows"

# window_snapshot.sh --forget <address>...   delete the snapshots of windows that appeared or closed.
# A new window can reuse the address of a closed one, so it must never inherit the old picture.
if [ "${1:-}" = "--forget" ]; then
    shift
    for a in "$@"; do
        [[ "$a" =~ ^(0x)?[0-9a-f]+$ ]] && rm -f "$dir/${a#0x}.jpg" "$dir/${a#0x}.part"
    done
    exit 0
fi

addr="${1:-}"
[[ "$addr" =~ ^0x[0-9a-f]+$ ]] || exit 0
command -v grim >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || exit 0

mkdir -p "$dir"

clients=$(hyprctl clients -j 2>/dev/null) || exit 0

# A window instance is its address (without 0x): each window has its own file, so two windows of one
# app never overwrite each other. Files of windows that no longer exist are removed.
alive=$(jq -r '.[].address | ltrimstr("0x")' <<<"$clients")
for f in "$dir"/*.jpg; do
    [ -e "$f" ] || continue
    grep -qx "$(basename "$f" .jpg)" <<<"$alive" || rm -f "$f"
done

win=$(jq -c --arg a "$addr" '.[] | select(.address == $a)' <<<"$clients")
[ -n "$win" ] || exit 0
key="${addr#0x}"

# Visible = mapped, not hidden, on a real workspace that is the active one of its monitor.
wsid=$(jq -r '.workspace.id' <<<"$win")
mon=$(jq -r '.monitor' <<<"$win")
active=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson m "$mon" '.[] | select(.id == $m) | .activeWorkspace.id')
[ "$(jq -r '(.mapped and (.hidden | not))' <<<"$win")" = true ] || exit 0
[ "$wsid" -gt 0 ] 2>/dev/null && [ "$wsid" = "$active" ] || exit 0

# A Serpantinum panel on screen would end up in the picture.
widget=$(jq -r '.widget // "hidden"' "${XDG_RUNTIME_DIR:-/run/user/$UID}/serpantinum/current_widget" 2>/dev/null || echo hidden)
[ "$widget" = "hidden" ] || exit 0

geom=$(jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<<"$win")
if timeout 2 grim -g "$geom" -s 0.5 -t jpeg -q 75 "$dir/$key.part" 2>/dev/null; then
    mv -f "$dir/$key.part" "$dir/$key.jpg"
else
    rm -f "$dir/$key.part"
fi
