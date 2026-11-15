#!/usr/bin/env python3
"""Run with: python3 install/tests/fcitx5_bar_test.py"""
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[2] / "src/quickshell/singletons/system/fcitx5-bar.py"
spec = importlib.util.spec_from_file_location("fcitx5_bar", path)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)
try:
    from gi.repository import Gio, GLib
except ImportError:
    Gio = None


class PickerTest(unittest.TestCase):
    def test_cycle_and_labels(self):
        methods = ["keyboard-us", "lotus", "keyboard-de"]
        self.assertEqual([bridge.next_method(item, methods) for item in methods], methods[1:] + methods[:1])
        self.assertEqual(bridge.next_method("missing", methods), methods[0])
        self.assertEqual(bridge.next_method("lotus", ["lotus"]), "lotus")
        with self.assertRaises(ValueError):
            bridge.next_method("lotus", [])
        self.assertEqual(bridge.label("lotus", {"lotus": "vi"}), "VI")
        self.assertEqual(bridge.label("keyboard-us", {"keyboard-us": "en_US"}), "EN")
        self.assertEqual(bridge.label("unknown", {}), "unknown")

    @unittest.skipIf(Gio is None, "PyGObject is optional")
    def test_stream_switch_focus_and_reconnect(self):
        state = SimpleNamespace(current="keyboard-us", connected=True, switches=[])
        methods = ["keyboard-us", "lotus", "keyboard-de"]
        languages = ["en", "vi", "de"]

        def call(service, path, interface, method, arguments, reply_type, flags, timeout, cancellable):
            self.assertEqual(flags, Gio.DBusCallFlags.NO_AUTO_START)
            if not state.connected:
                raise GLib.Error("Service unavailable")
            if method == "CurrentInputMethod":
                result = (state.current,)
            elif method == "CurrentInputMethodGroup":
                result = ("Default",)
            elif method == "InputMethodGroupInfo":
                result = ("us", [(item, "") for item in methods])
            elif method == "AvailableInputMethods":
                result = ([(item, "", "", "", "", language, True) for item, language in zip(methods, languages)],)
            elif method == "SetCurrentIM":
                state.current = arguments.unpack()[0]
                state.switches.append(state.current)
                result = ()
            else:
                self.fail(method)
            return SimpleNamespace(unpack=lambda: result)

        # Polls after each command must follow external focus changes and daemon loss.
        events = iter([
            (None, b"next\nnext\nnext\n"),
            (lambda: setattr(state, "current", "keyboard-de"), b"ignored\n"),
            (lambda: setattr(state, "current", ""), b"ignored\n"),
            (lambda: setattr(state, "connected", False), b"ignored\n"),
            (lambda: setattr(state, "connected", True), b"ignored\n"),
            (None, b""),
        ])
        pending = []

        def ready(readers, writers, errors, timeout):
            update, data = next(events)
            if update:
                update()
            pending.append(data)
            return (readers, [], [])

        output = io.StringIO()
        with patch.object(Gio, "bus_get_sync", return_value=SimpleNamespace(call_sync=call)), \
                patch.object(bridge.select, "select", side_effect=ready), \
                patch.object(bridge.os, "read", side_effect=lambda *args: pending.pop(0)), \
                patch.object(bridge.sys, "stdout", output):
            self.assertEqual(bridge.run(), 0)
        statuses = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(state.switches, ["lotus", "keyboard-de", "keyboard-us"])
        self.assertEqual([item.get("label") for item in statuses], ["EN", "DE", None, "EN"])
        self.assertFalse(statuses[2]["available"])


if __name__ == "__main__":
    unittest.main()
