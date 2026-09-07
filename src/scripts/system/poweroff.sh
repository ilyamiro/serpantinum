#!/usr/bin/env bash

rm -f /tmp/serpantinumd.lock /tmp/serpantinumd.pid 2>/dev/null

if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    systemctl poweroff -i && exit 0
fi

if command -v loginctl &>/dev/null; then
    loginctl poweroff && exit 0
fi

if command -v dbus-send &>/dev/null; then
    dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.PowerOff boolean:true 2>/dev/null && exit 0
fi

if command -v openrc-shutdown &>/dev/null; then
    openrc-shutdown -p now && exit 0
fi

if command -v dinitctl &>/dev/null; then
    dinitctl shutdown && exit 0
fi

if command -v poweroff &>/dev/null; then
    poweroff
fi
