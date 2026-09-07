#!/usr/bin/env bash

rm -f /tmp/serpantinumd.lock /tmp/serpantinumd.pid 2>/dev/null

if command -v systemctl &>/dev/null; then
    systemctl --user stop graphical-session.target 2>/dev/null
    systemctl --user stop graphical-session-pre.target 2>/dev/null
fi

if command -v dinitctl &>/dev/null; then
    dinitctl --user stop graphical-session 2>/dev/null
fi

sleep 0.2

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; then
    hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || \
    pkill -SIGTERM -x Hyprland 2>/dev/null
elif [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; then
    niri msg action quit --skip-confirmation 2>/dev/null || \
    niri msg action quit 2>/dev/null || \
    pkill -SIGTERM -x niri 2>/dev/null
elif [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; then
    swaymsg exit 2>/dev/null || \
    pkill -SIGTERM -x sway 2>/dev/null
elif [ -n "$WAYFIRE_SOCKET" ] || pgrep -x wayfire &>/dev/null; then
    wayfire-msg -c exit 2>/dev/null || \
    pkill -SIGTERM -x wayfire 2>/dev/null
elif [ -n "$RIVER_SOCKET" ] || pgrep -x river &>/dev/null; then
    riverctl exit 2>/dev/null || \
    pkill -SIGTERM -x river 2>/dev/null
else
    if command -v loginctl &>/dev/null; then
        loginctl terminate-session "${XDG_SESSION_ID:-self}" 2>/dev/null || \
        loginctl terminate-user "$USER" 2>/dev/null
    fi
fi
