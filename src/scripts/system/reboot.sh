#!/usr/bin/env bash

rm -f /tmp/serpantinumd.lock /tmp/serpantinumd.pid 2>/dev/null

if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    systemctl reboot && exit 0
fi

if command -v loginctl &>/dev/null; then
    loginctl reboot && exit 0
fi

if command -v dbus-send &>/dev/null; then
    dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.Reboot boolean:true 2>/dev/null && exit 0
fi

if command -v openrc-shutdown &>/dev/null; then
    openrc-shutdown -r now && exit 0
fi

if command -v dinitctl &>/dev/null; then
    dinitctl reboot && exit 0
fi

if command -v reboot &>/dev/null; then
    reboot
fi
