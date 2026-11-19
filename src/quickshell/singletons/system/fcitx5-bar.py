#!/usr/bin/env python3
"""Stream Fcitx5 status as JSON; accept 'next' on stdin."""
import json
import os
import select
import sys


def label(method, languages):
    language = languages.get(method, "")
    return language.replace("-", "_").split("_")[0].upper() or method


def next_method(current, methods):
    if not methods:
        raise ValueError("Fcitx5 input method group is empty")
    return methods[(methods.index(current) + 1) % len(methods)] if current in methods else methods[0]


def run():
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        print("Install PyGObject to enable the Fcitx5 keyboard picker", file=sys.stderr)
        return 3

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def call(method, arguments=None):
        return bus.call_sync(
            "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1",
            method, arguments, None, Gio.DBusCallFlags.NO_AUTO_START, 1000, None,
        ).unpack()

    def methods():
        group = call("CurrentInputMethodGroup")[0]
        items = call("InputMethodGroupInfo", GLib.Variant("(s)", (group,)))[1]
        return [item[0] for item in items]

    previous = None
    last_current = ""
    languages = {}
    pending = b""
    commands = []
    while True:
        try:
            current = call("CurrentInputMethod")[0] or last_current
            if not current:
                current = next_method("", methods())
            if not languages or current not in languages:
                languages = {item[0]: item[5] for item in call("AvailableInputMethods")[0]}
            for command in commands:
                if command != b"next":
                    continue
                target = next_method(current, methods())
                call("SetCurrentIM", GLib.Variant("(s)", (target,)))
                current = call("CurrentInputMethod")[0] or target
            last_current = current
            status = {"available": True, "method": current, "label": label(current, languages)}
        except (GLib.Error, ValueError) as error:
            last_current = ""
            languages = {}
            status = {"available": False}
            if commands:
                print(f"Switch failed: {error}", file=sys.stderr, flush=True)
        commands = []
        if status != previous:
            print(json.dumps(status), flush=True)
            previous = status
        # ponytail: poll twice per second; replace when the controller exposes an active-method change signal.
        if select.select([sys.stdin], [], [], 0.5)[0]:
            data = os.read(sys.stdin.fileno(), 4096)
            if not data:
                return 0
            parts = (pending + data).split(b"\n")
            commands = [command for command in parts[:-1] if command == b"next"]
            pending = parts[-1]


if __name__ == "__main__":
    sys.exit(run())
