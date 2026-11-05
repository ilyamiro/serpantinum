"""Offline tests for display_txn.py (no compositor needed).

Run: python3 -m unittest discover -s tests/display -v
"""

import importlib.util
import json
import os
import sys
import tempfile
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "..", "src", "quickshell", "guide", "display", "display_txn.py")
spec = importlib.util.spec_from_file_location("display_txn", SCRIPT)
dt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dt)

dt.VERIFY_DELAY = 0.001
dt.POLL_INTERVAL = 0.01


def hypr_monitor(name, desc, w, h, r, x, y, modes, disabled=False, scale=1.0, transform=0):
    return {"name": name, "description": desc, "width": w, "height": h, "refreshRate": r,
            "x": x, "y": y, "scale": scale, "transform": transform, "disabled": disabled,
            "availableModes": modes, "focused": False}


class FakeHyprland:
    """Simulates hyprctl: keeps monitor state, parses hl.monitor() calls."""

    def __init__(self, monitors, broken_modes=()):
        self.monitors = {m["name"]: m for m in monitors}
        self.broken_modes = set(broken_modes)  # modes that "black out" (state never changes)
        self.calls = []
        self.fail_eval = False

    def __call__(self, args, timeout=5):
        self.calls.append(args)
        if args[:3] == ["hyprctl", "-j", "monitors"]:
            return 0, json.dumps(list(self.monitors.values())), ""
        if args[:2] == ["hyprctl", "eval"]:
            if self.fail_eval:
                return 7, "error: boom", ""
            for line in args[2].splitlines():
                self._apply_lua(line)
            return 0, "ok", ""
        return 1, "", "unexpected"

    def _apply_lua(self, line):
        body = line[line.index("{") + 1:line.rindex("}")]
        fields = {}
        for part in body.split(","):
            k, _, v = part.partition("=")
            fields[k.strip()] = v.strip().strip('"')
        m = self.monitors[fields["output"]]
        if fields.get("disabled") == "true":
            m["disabled"] = True
            return
        mode = fields["mode"]
        if mode in self.broken_modes:
            return
        w, h, r = dt.parse_mode(mode)
        x, _, y = fields["position"].partition("x")
        m.update(disabled=False, width=w, height=h, refreshRate=r, x=int(x), y=int(y),
                 scale=float(fields["scale"]), transform=int(fields["transform"]))


def two_monitors():
    return [
        hypr_monitor("eDP-2", "Panel A", 1920, 1080, 60.061, 0, 0,
                     ["1920x1080@60.06Hz", "1920x1080@144.06Hz"]),
        hypr_monitor("HDMI-A-1", "Dell Inc. Inspiron 3043", 1920, 1080, 60.0, 1920, 0,
                     ["1920x1080@60.00Hz", "1280x720@60.00Hz"]),
    ]


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["XDG_RUNTIME_DIR"] = self.tmp.name
        os.environ["XDG_STATE_HOME"] = self.tmp.name
        os.environ["XDG_CONFIG_HOME"] = self.tmp.name  # never touch the real ~/.config/hypr
        self.fake = FakeHyprland(two_monitors())
        self.backend = dt.HyprlandBackend(runner=self.fake)
        self.spawned = []
        dt.spawn_watcher = lambda txn_id: self.spawned.append(txn_id) or "test"

    def tearDown(self):
        self.tmp.cleanup()

    def mon(self, name):
        return next(m for m in self.backend.state()["monitors"] if m["name"] == name)

    def plan(self, **changes):
        plan = dt.plan_from_state(self.backend.state())
        for m in plan["monitors"]:
            m.update(changes.get(m["name"], {}))
        return plan


class ValidateTests(Base):
    def check(self, plan):
        return dt.validate(plan, self.backend.state())

    def test_current_state_is_valid(self):
        self.assertEqual(self.check(self.plan()), ([], []))

    def test_all_disabled_rejected(self):
        e, _ = self.check(self.plan(**{"eDP-2": {"enabled": False}, "HDMI-A-1": {"enabled": False}}))
        self.assertIn("no_enabled_monitor", e)

    def test_unsupported_mode_rejected(self):
        e, _ = self.check(self.plan(**{"eDP-2": {"refresh": 75.0}}))
        self.assertTrue(any(x.startswith("mode_unsupported:eDP-2") for x in e))

    def test_bad_scale_rejected(self):
        e, _ = self.check(self.plan(**{"eDP-2": {"scale": 1.3}}))
        self.assertTrue(any(x.startswith("scale_invalid") for x in e))

    def test_overlap_rejected(self):
        e, _ = self.check(self.plan(**{"HDMI-A-1": {"x": 1000}}))
        self.assertTrue(any(x.startswith("monitors_overlap") for x in e))

    def test_scaled_monitor_does_not_overlap(self):
        # eDP at scale 1.5 is 1280 logical px wide, so HDMI at x=1280 just touches it.
        e, w = self.check(self.plan(**{"eDP-2": {"scale": 1.5}, "HDMI-A-1": {"x": 1280}}))
        self.assertEqual((e, w), ([], []))

    def test_gap_is_warning(self):
        e, w = self.check(self.plan(**{"HDMI-A-1": {"x": 4000}}))
        self.assertEqual(e, [])
        self.assertIn("monitors_not_adjacent", w)

    def test_renamed_connector_rejected(self):
        e, _ = self.check(self.plan(**{"eDP-2": {"description": "Other panel"}}))
        self.assertIn("monitor_identity_changed:eDP-2", e)

    def test_missing_and_unknown_monitor(self):
        plan = self.plan()
        plan["monitors"][0]["name"] = "DP-9"
        e, _ = self.check(plan)
        self.assertIn("unknown_monitor:DP-9", e)
        self.assertTrue(any(x.startswith("monitor_missing_from_plan") for x in e))

    def test_garbage_fields(self):
        e, _ = self.check(self.plan(**{"eDP-2": {"scale": "abc"}}))
        self.assertIn("monitor_fields_invalid:eDP-2", e)
        e, _ = self.check(self.plan(**{"eDP-2": {"refresh": float("nan")}}))
        self.assertIn("monitor_fields_invalid:eDP-2", e)
        self.assertEqual(dt.validate({"monitors": "x"}, self.backend.state())[0], ["plan_malformed"])

    def test_portrait_logical_size(self):
        # Rotated HDMI (1080 wide logical) right next to eDP.
        e, w = self.check(self.plan(**{"HDMI-A-1": {"transform": 1}}))
        self.assertEqual((e, w), ([], []))

    def test_valid_scales(self):
        s = dt.valid_scales(1920, 1080)
        for v in (1.0, 1.25, 1.5, 2.0):
            self.assertIn(v, s)
        self.assertNotIn(1.3, s)


class TransactionTests(Base):
    def test_apply_then_confirm_keeps_change(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
        self.assertTrue(r["ok"], r)
        self.assertEqual(self.spawned, [r["id"]])
        self.assertEqual(dt.finish(self.backend, r["id"], "confirm"), "confirmed")
        self.assertAlmostEqual(self.mon("eDP-2")["refresh"], 144.06)
        self.assertTrue(os.path.exists(dt.last_good_path()))

    def test_timeout_reverts(self):
        before = self.backend.state()
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 5)
        txn = dt.read_json(dt.txn_path())
        txn["deadline"] = time.time()  # simulate the timeout elapsing
        dt.atomic_write_json(dt.txn_path(), txn)
        dt.cmd_watch(self.backend, r["id"])
        self.assertTrue(dt.matches(dt.plan_from_state(before), self.backend.state()))
        self.assertEqual(dt.read_json(dt.txn_path())["outcome"], "restored")

    def test_revert_request_is_immediate(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"enabled": False}}), 60)
        t = threading.Thread(target=dt.cmd_watch, args=(self.backend, r["id"]))
        t.start()
        dt.cmd_request_revert()
        t.join(5)
        self.assertFalse(t.is_alive())
        self.assertTrue(all(m["enabled"] for m in self.backend.state()["monitors"]))

    def test_confirm_after_revert_is_noop(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 5)
        dt.finish(self.backend, r["id"], "revert", reason="timeout")
        self.assertEqual(dt.finish(self.backend, r["id"], "confirm"), "not_pending")
        self.assertAlmostEqual(self.mon("eDP-2")["refresh"], 60.061)

    def test_blackout_mode_auto_reverts(self):
        # Compositor accepts the call but the mode never takes effect.
        self.fake.broken_modes.add("1920x1080@144.060")
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "apply_not_verified")
        self.assertEqual(dt.cmd_status(self.backend)["pending"], False)

    def test_second_apply_blocked_while_pending(self):
        dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"x": 1920, "y": 1080}}), 15)
        self.assertEqual(r["error"], "transaction_pending")

    def test_invalid_plan_never_touches_compositor(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"enabled": False}, "HDMI-A-1": {"enabled": False}}), 15)
        self.assertFalse(r["ok"])
        self.assertFalse(any(c[:2] == ["hyprctl", "eval"] for c in self.fake.calls))
        self.assertIsNone(dt.read_json(dt.txn_path()))

    def test_lost_watcher_heals_on_status(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 60)
        txn = dt.read_json(dt.txn_path())
        txn["watcher_pid"] = 999999999  # dead pid
        dt.atomic_write_json(dt.txn_path(), txn)
        s = dt.cmd_status(self.backend)
        self.assertEqual(s["healed"], "restored")
        self.assertAlmostEqual(self.mon("eDP-2")["refresh"], 60.061)

    def test_restore_falls_back_to_safe_layout(self):
        snap = self.backend.state()
        snap["monitors"][0]["refresh"] = 30.0  # snapshot that can no longer be applied
        self.fake.broken_modes.add("1920x1080@30.000")
        self.assertEqual(dt.restore(self.backend, snap), "safe_layout")
        self.assertTrue(all(m["enabled"] for m in self.backend.state()["monitors"]))

    def test_disable_order_never_blacks_out(self):
        # Swap which monitor is on: the enable must be sent before the disable.
        self.fake.monitors["HDMI-A-1"]["disabled"] = True
        plan = self.plan(**{"HDMI-A-1": {"enabled": True}, "eDP-2": {"enabled": False}})
        dt.cmd_apply(self.backend, plan, 15)
        script = [c for c in self.fake.calls if c[:2] == ["hyprctl", "eval"]][0][2]
        lines = script.splitlines()
        self.assertIn("HDMI-A-1", lines[0])
        self.assertIn("disabled = true", lines[-1])

    def test_rescue_uses_last_good(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
        dt.finish(self.backend, r["id"], "confirm")
        self.fake.monitors["eDP-2"]["refreshRate"] = 60.061
        self.assertEqual(dt.cmd_rescue(self.backend)["outcome"], "last_good")
        self.assertAlmostEqual(self.mon("eDP-2")["refresh"], 144.06)


class PersistenceTests(Base):
    def test_confirm_writes_module_without_disabled_monitors(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"enabled": False}}), 15)
        dt.finish(self.backend, r["id"], "confirm")
        text = open(dt.persist_path()).read()
        self.assertTrue(dt.persist_path().startswith(self.tmp.name))
        self.assertIn('output = "eDP-2"', text)
        self.assertNotIn("HDMI-A-1", text.split("-- Disabled")[1].split("\n", 2)[2])
        self.assertNotIn("disabled", text.replace("Disabled monitors", ""))
        self.assertTrue(dt.read_json(dt.txn_path())["persisted"])

    def test_generated_lua_passes_hyprland_verify(self):
        path = os.path.join(self.tmp.name, "check.lua")
        with open(path, "w") as f:
            f.write(dt.render_lua(self.backend.state()))
        self.assertTrue(dt.verify_lua(path))

    def test_verify_failure_keeps_previous_file(self):
        dt.persist(self.backend.state())
        before = open(dt.persist_path()).read()
        original = dt.verify_lua
        dt.verify_lua = lambda path: False
        try:
            r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
            self.assertEqual(dt.finish(self.backend, r["id"], "confirm"), "confirmed")
        finally:
            dt.verify_lua = original
        self.assertEqual(open(dt.persist_path()).read(), before)
        self.assertFalse(dt.read_json(dt.txn_path())["persisted"])

    def test_include_detection_ignores_comments(self):
        hypr = dt.hypr_config_dir()
        os.makedirs(hypr, exist_ok=True)
        with open(os.path.join(hypr, "hyprland.lua"), "w") as f:
            f.write('-- require("serpantinum/monitors")\n')
        self.assertFalse(dt.persist_info()["included"])
        with open(os.path.join(hypr, "hyprland.lua"), "a") as f:
            f.write('require("config/monitors")\nrequire("serpantinum/monitors")\n')
        self.assertTrue(dt.persist_info()["included"])


if __name__ == "__main__":
    unittest.main()
