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

ORIGINAL_SPAWN = dt.spawn_watcher
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
        self.assertIn('output = "desc:Panel A"', text)
        self.assertNotIn("Inspiron", text)
        self.assertNotIn("disabled = ", text)
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


class IdentityTests(Base):
    def swapped_state(self):
        """Same two panels after a reboot, but the connector names changed."""
        mons = two_monitors()
        mons[0]["name"], mons[1]["name"] = "eDP-1", "DP-3"
        self.fake.monitors = {m["name"]: m for m in mons}

    def test_persist_uses_desc_when_unique(self):
        text = dt.render_lua(self.backend.state())
        self.assertIn('output = "desc:Panel A"', text)
        self.assertIn('output = "desc:Dell Inc. Inspiron 3043"', text)
        self.assertNotIn('output = "eDP-2"', text)

    def test_persist_falls_back_to_name_for_identical_panels(self):
        for m in self.fake.monitors.values():
            m["description"] = "Generic 0x00000001"
        text = dt.render_lua(self.backend.state())
        self.assertIn('output = "eDP-2"', text)
        self.assertIn('output = "HDMI-A-1"', text)
        self.assertNotIn("desc:", text.split("\n\n", 1)[1])

    def test_persist_falls_back_when_description_is_prefix_of_another(self):
        self.fake.monitors["eDP-2"]["description"] = "Dell Inc."
        self.fake.monitors["HDMI-A-1"]["description"] = "Dell Inc. Inspiron 3043"
        text = dt.render_lua(self.backend.state())
        self.assertIn('output = "eDP-2"', text)
        self.assertIn('output = "HDMI-A-1"', text)

    def test_persist_falls_back_when_description_empty(self):
        self.fake.monitors["eDP-2"]["description"] = ""
        text = dt.render_lua(self.backend.state())
        self.assertIn('output = "eDP-2"', text)
        self.assertIn('output = "desc:Dell Inc. Inspiron 3043"', text)

    def test_lua_string_escaping_passes_hyprland_verify(self):
        tricky = 'Odd "Maker" \\ Modelo ñ 日本 \x07 9'
        self.assertEqual(dt.lua_str('a"b\\c\x07'), '"a\\"b\\\\c\\007"')
        self.fake.monitors["eDP-2"]["description"] = tricky
        path = os.path.join(self.tmp.name, "tricky.lua")
        with open(path, "w", encoding="utf-8") as f:
            f.write(dt.render_lua(self.backend.state()))
        self.assertTrue(dt.verify_lua(path))

    def test_plan_follows_panel_when_connector_renamed(self):
        old = self.plan(**{"eDP-2": {"refresh": 144.06}})  # saved while it was eDP-2
        self.swapped_state()
        resolved, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertEqual(errors, [])
        names = {m["description"]: m["name"] for m in resolved["monitors"]}
        self.assertEqual(names["Panel A"], "eDP-1")
        self.assertEqual(names["Dell Inc. Inspiron 3043"], "DP-3")
        r = dt.cmd_apply(self.backend, old, 15)
        self.assertTrue(r["ok"], r)
        self.assertAlmostEqual(self.mon("eDP-1")["refresh"], 144.06)

    def test_names_exchanged_between_panels_do_not_swap_layouts(self):
        old = self.plan()  # Panel A on the left as eDP-2, Inspiron on the right as HDMI-A-1
        mons = two_monitors()
        mons[0]["name"], mons[1]["name"] = "HDMI-A-1", "eDP-2"  # names exchanged
        self.fake.monitors = {m["name"]: m for m in mons}
        resolved, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertEqual(errors, [])
        by_desc = {m["description"]: m for m in resolved["monitors"]}
        self.assertEqual(by_desc["Panel A"]["name"], "HDMI-A-1")
        self.assertEqual(by_desc["Panel A"]["x"], 0)
        self.assertEqual(by_desc["Dell Inc. Inspiron 3043"]["name"], "eDP-2")
        self.assertEqual(by_desc["Dell Inc. Inspiron 3043"]["x"], 1920)

    def test_identical_panels_keep_their_connector(self):
        for m in self.fake.monitors.values():
            m["description"] = "Generic 0x00000001"
        old = self.plan(**{"HDMI-A-1": {"x": 1920}})
        resolved, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertEqual(errors, [])
        self.assertEqual({m["name"]: m["x"] for m in resolved["monitors"]}, {"eDP-2": 0, "HDMI-A-1": 1920})

    def test_strict_mode_rejects_absent_monitor(self):
        old = self.plan()
        self.fake.monitors.pop("HDMI-A-1")
        _, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertTrue(any(e.startswith("unknown_monitor") for e in errors))

    def test_partial_mode_drops_absent_and_keeps_unmentioned(self):
        profile = {"monitors": [dict(m) for m in self.plan()["monitors"] if m["name"] == "HDMI-A-1"]}
        profile["monitors"].append({"name": "DP-9", "description": "Gone Monitor", "enabled": True,
                                    "width": 1920, "height": 1080, "refresh": 60.0, "x": 0, "y": 0,
                                    "scale": 1.0, "transform": 0})
        resolved, errors, warnings = dt.resolve_plan(profile, self.backend.state(), partial=True)
        self.assertEqual(errors, [])
        self.assertIn("profile_monitor_absent:DP-9", warnings)
        self.assertEqual(sorted(m["name"] for m in resolved["monitors"]), ["HDMI-A-1", "eDP-2"])

    def test_identity_changed_when_connector_drives_other_panel(self):
        old = self.plan()
        self.fake.monitors["eDP-2"]["description"] = "Other panel"
        self.fake.monitors["HDMI-A-1"]["description"] = "Another"
        _, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertIn("monitor_identity_changed:eDP-2", errors)

    def test_legacy_plan_without_description_matches_by_name(self):
        old = self.plan()
        for m in old["monitors"]:
            m["description"] = ""
        resolved, errors, _ = dt.resolve_plan(old, self.backend.state())
        self.assertEqual(errors, [])
        self.assertEqual(sorted(m["name"] for m in resolved["monitors"]), ["HDMI-A-1", "eDP-2"])

    def test_rescue_after_rename_restores_last_good_layout(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"refresh": 144.06}}), 15)
        dt.finish(self.backend, r["id"], "confirm")
        self.swapped_state()
        self.fake.monitors["eDP-1"]["refreshRate"] = 60.061
        out = dt.cmd_rescue(self.backend)
        self.assertEqual(out["outcome"], "last_good")
        self.assertAlmostEqual(self.mon("eDP-1")["refresh"], 144.06)

    def test_apply_partial_flag_loads_profile_with_absent_monitor(self):
        profile = {"monitors": [m for m in self.plan(**{"eDP-2": {"refresh": 144.06}})["monitors"]]}
        profile["monitors"].append({"name": "DP-9", "description": "Gone Monitor", "enabled": True,
                                    "width": 1920, "height": 1080, "refresh": 60.0, "x": 3840, "y": 0,
                                    "scale": 1.0, "transform": 0})
        self.assertFalse(dt.cmd_apply(self.backend, profile, 15)["ok"])
        r = dt.cmd_apply(self.backend, profile, 15, partial=True)
        self.assertTrue(r["ok"], r)
        self.assertIn("profile_monitor_absent:DP-9", r["warnings"])


class ReflowTests(Base):
    def reflow(self, name, **changes):
        old = self.plan()
        new = self.plan(**{name: changes})
        return {m["name"]: m for m in dt.reflow_plan(old, new, name)["monitors"]}

    def test_scale_up_pulls_right_neighbour_in(self):
        out = self.reflow("eDP-2", scale=1.5)  # 1920 -> 1280 logical
        self.assertEqual(out["HDMI-A-1"]["x"], 1280)
        self.assertEqual(dt.validate({"monitors": list(out.values())}, self.backend.state()), ([], []))

    def test_resolution_change_pushes_right_neighbour_out(self):
        self.fake.monitors["eDP-2"]["availableModes"].append("3840x2160@60.00Hz")
        out = self.reflow("eDP-2", width=3840, height=2160, scale=1.0)
        self.assertEqual(out["HDMI-A-1"]["x"], 3840)
        self.assertEqual(out["eDP-2"]["x"], 0)

    def test_left_monitor_is_untouched_when_right_one_changes(self):
        out = self.reflow("HDMI-A-1", scale=2.0)
        self.assertEqual((out["eDP-2"]["x"], out["HDMI-A-1"]["x"]), (0, 1920))

    def test_chain_moves_together(self):
        mons = two_monitors() + [hypr_monitor("DP-3", "Third", 1920, 1080, 60.0, 3840, 0, ["1920x1080@60.00Hz"])]
        self.fake.monitors = {m["name"]: m for m in mons}
        out = self.reflow("eDP-2", scale=2.0)  # 1920 -> 960 logical, shift -960
        self.assertEqual((out["HDMI-A-1"]["x"], out["DP-3"]["x"]), (960, 2880))

    def test_vertical_stack_shifts_down(self):
        self.fake.monitors["HDMI-A-1"].update(x=0, y=1080)
        out = self.reflow("eDP-2", scale=1.5)  # 1080 -> 720 logical high
        self.assertEqual(out["HDMI-A-1"]["y"], 720)
        self.assertEqual(out["HDMI-A-1"]["x"], 0)

    def test_rotation_swaps_logical_size(self):
        out = self.reflow("eDP-2", transform=1)  # 1920x1080 -> 1080 wide
        self.assertEqual(out["HDMI-A-1"]["x"], 1080)

    def test_unrelated_row_is_not_shifted(self):
        mons = two_monitors() + [hypr_monitor("DP-3", "Third", 1920, 1080, 60.0, 0, 1080, ["1920x1080@60.00Hz"])]
        mons[1]["x"], mons[1]["y"] = 1920, 0
        self.fake.monitors = {m["name"]: m for m in mons}
        out = self.reflow("HDMI-A-1", scale=2.0)  # right monitor shrinks; nothing is right of it
        self.assertEqual((out["eDP-2"]["x"], out["DP-3"]["x"], out["DP-3"]["y"]), (0, 0, 1080))

    def test_disabled_or_unchanged_size_returns_plan_as_is(self):
        old = self.plan()
        self.assertEqual(dt.reflow_plan(old, old, "eDP-2"), old)
        new = self.plan(**{"eDP-2": {"enabled": False}})
        self.assertEqual(dt.reflow_plan(old, new, "eDP-2"), new)

    def test_apply_with_reflow_keeps_layout_valid(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"scale": 1.5}}), 15, reflow="eDP-2")
        self.assertTrue(r["ok"], r)
        self.assertEqual(self.mon("HDMI-A-1")["x"], 1280)
        self.assertEqual(r["warnings"], [])

    def test_apply_without_reflow_keeps_gap_warning(self):
        r = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"scale": 1.5}}), 15)
        self.assertTrue(r["ok"], r)
        self.assertIn("monitors_not_adjacent", r["warnings"])

    def test_inline_json_plan(self):
        plan = self.plan()
        self.assertEqual(dt.load_plan(json.dumps(plan)), plan)


class WatcherSpawnTests(Base):
    def run_spawn(self, runtime):
        calls = []

        class Done:
            returncode = 0

        orig_run, orig_which = dt.subprocess.run, dt.shutil.which
        dt.subprocess.run = lambda args, **kw: calls.append(args) or Done()
        dt.shutil.which = lambda name: "/usr/bin/systemd-run"
        if runtime is None:
            os.environ.pop("SERPANTINUM_DISPLAY_RUNTIME", None)
        else:
            os.environ["SERPANTINUM_DISPLAY_RUNTIME"] = runtime
        try:
            self.assertEqual(ORIGINAL_SPAWN("abcdef123456"), "systemd")
        finally:
            dt.subprocess.run, dt.shutil.which = orig_run, orig_which
            os.environ.pop("SERPANTINUM_DISPLAY_RUNTIME", None)
        return calls[0]

    def test_reverter_gets_the_parents_runtime_dir_when_overridden(self):
        custom = os.path.join(self.tmp.name, "custom-rt")
        args = self.run_spawn(custom)
        self.assertIn("--setenv", args)
        self.assertIn("SERPANTINUM_DISPLAY_RUNTIME=%s" % custom, args)

    def test_reverter_gets_the_resolved_default_runtime_dir(self):
        args = self.run_spawn(None)
        self.assertIn("SERPANTINUM_DISPLAY_RUNTIME=%s" % dt.runtime_dir(), args)

    def test_reverter_unit_restarts_on_failure_and_forwards_config_home(self):
        args = self.run_spawn(None)
        self.assertIn("--property=Restart=on-failure", args)
        self.assertIn("XDG_CONFIG_HOME=%s" % os.environ["XDG_CONFIG_HOME"], args)


class InstanceDetectionTests(Base):
    """TTY rescue: with no HYPRLAND_INSTANCE_SIGNATURE the right compositor must be found,
    never a nested test window or a leftover directory of a crashed one."""

    def setUp(self):
        super().setUp()
        self.hypr = os.path.join(self.tmp.name, "hypr")
        self.procs = []
        self.saved_sig = os.environ.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def tearDown(self):
        for p in self.procs:
            p.kill()
            p.wait()
        if self.saved_sig is not None:
            os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = self.saved_sig
        else:
            os.environ.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        super().tearDown()

    def sleeper(self, wayland):
        import subprocess
        env = {"PATH": os.environ.get("PATH", "")}
        if wayland:
            env["WAYLAND_DISPLAY"] = "wayland-1"
        p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], env=env)
        self.procs.append(p)
        time.sleep(0.2)
        return p.pid

    def instance(self, sig, pid, age):
        d = os.path.join(self.hypr, sig)
        os.makedirs(d)
        open(os.path.join(d, ".socket.sock"), "w").close()
        if pid is not None:
            with open(os.path.join(d, "hyprland.lock"), "w") as f:
                f.write("%d\n" % pid)
        t = time.time() - age
        os.utime(d, (t, t))

    def detect(self):
        dt.detect_backend()
        return os.environ["HYPRLAND_INSTANCE_SIGNATURE"]

    def test_real_session_beats_a_newer_nested_one(self):
        self.instance("real", self.sleeper(False), age=500)
        self.instance("nested", self.sleeper(True), age=1)
        self.assertEqual(self.detect(), "real")

    def test_dead_instance_directory_is_ignored(self):
        import subprocess
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        self.instance("crashed", dead.pid, age=1)
        self.instance("alive", self.sleeper(False), age=900)
        self.assertEqual(self.detect(), "alive")

    def test_newest_wins_between_two_real_sessions(self):
        self.instance("old", self.sleeper(False), age=800)
        self.instance("new", self.sleeper(False), age=5)
        self.assertEqual(self.detect(), "new")

    def test_only_a_nested_instance_is_still_usable(self):
        self.instance("nested", self.sleeper(True), age=1)
        self.assertEqual(self.detect(), "nested")

    def test_missing_lock_file_keeps_the_instance_usable(self):
        self.instance("nolock", None, age=1)
        self.assertEqual(self.detect(), "nolock")

    def test_no_instances_is_unsupported(self):
        os.makedirs(self.hypr)
        with self.assertRaises(dt.DisplayError):
            dt.detect_backend()

    def test_explicit_signature_is_never_overridden(self):
        self.instance("other", self.sleeper(False), age=1)
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "mine"
        dt.detect_backend()
        self.assertEqual(os.environ["HYPRLAND_INSTANCE_SIGNATURE"], "mine")


class RuntimeDirTests(Base):
    """Distros without /run/user/<uid> (Void without elogind) must still work, safely."""

    def setUp(self):
        super().setUp()
        self.saved = {k: os.environ.pop(k, None) for k in ("XDG_RUNTIME_DIR", "SERPANTINUM_DISPLAY_RUNTIME")}
        self.saved_base, self.saved_tmp = dt.RUN_USER_BASE, tempfile.tempdir
        dt.RUN_USER_BASE = os.path.join(self.tmp.name, "no-such-run-user")
        tempfile.tempdir = self.tmp.name
        self.fallback = os.path.join(self.tmp.name, "serpantinum-display-%d" % os.getuid())

    def tearDown(self):
        dt.RUN_USER_BASE, tempfile.tempdir = self.saved_base, self.saved_tmp
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)   # a test may have set it: do not leak it
            else:
                os.environ[k] = v
        super().tearDown()

    def test_xdg_runtime_dir_is_preferred(self):
        os.environ["XDG_RUNTIME_DIR"] = self.tmp.name
        self.assertEqual(dt.runtime_dir(), os.path.join(self.tmp.name, "serpantinum-display"))

    def test_falls_back_to_a_private_temp_dir(self):
        path = dt.runtime_dir()
        self.assertEqual(path, self.fallback)
        self.assertEqual(os.stat(path).st_mode & 0o777, 0o700)

    def test_fallback_is_stable_across_calls(self):
        self.assertEqual(dt.runtime_dir(), dt.runtime_dir())

    def test_unwritable_xdg_dir_falls_back(self):
        ro = os.path.join(self.tmp.name, "ro")
        os.makedirs(ro, mode=0o500)
        os.environ["XDG_RUNTIME_DIR"] = ro
        try:
            if os.access(ro, os.W_OK):
                self.skipTest("running as a user that ignores directory permissions")
            self.assertEqual(dt.runtime_dir(), self.fallback)
        finally:
            os.chmod(ro, 0o700)

    def test_symlink_in_the_shared_temp_dir_is_refused(self):
        os.symlink(self.tmp.name, self.fallback)
        with self.assertRaises(dt.DisplayError):
            dt.runtime_dir()

    def test_loose_permissions_on_our_own_dir_are_tightened(self):
        os.makedirs(self.fallback, mode=0o777)
        os.chmod(self.fallback, 0o777)
        self.assertEqual(dt.runtime_dir(), self.fallback)
        self.assertEqual(os.stat(self.fallback).st_mode & 0o777, 0o700)

    def test_directory_owned_by_someone_else_is_refused(self):
        os.makedirs(self.fallback, mode=0o700)
        real = os.lstat

        class Foreign:
            def __init__(self, st):
                self.st_mode, self.st_uid = st.st_mode, st.st_uid + 1

        dt.os.lstat = lambda p: Foreign(real(p)) if p == self.fallback else real(p)
        try:
            with self.assertRaises(dt.DisplayError):
                dt.runtime_dir()
        finally:
            dt.os.lstat = real

    def test_explicit_override_still_wins(self):
        target = os.path.join(self.tmp.name, "custom")
        os.environ["SERPANTINUM_DISPLAY_RUNTIME"] = target
        self.assertEqual(dt.runtime_dir(), target)

    def test_a_full_transaction_works_without_a_runtime_dir(self):
        result = dt.cmd_apply(self.backend, self.plan(**{"eDP-2": {"x": 0}}), 15)
        self.assertTrue(result["ok"])
        self.assertTrue(os.path.exists(os.path.join(self.fallback, "txn.lock")))


class ManagedConfigTests(Base):
    """NixOS / Home Manager: hyprland.lua is a link into the read-only store."""

    def setUp(self):
        super().setUp()
        self.store = os.path.join(self.tmp.name, "store")
        os.makedirs(self.store)
        self.saved_store = dt.NIX_STORE
        dt.NIX_STORE = self.store
        self.hypr = os.path.join(self.tmp.name, "hypr")      # XDG_CONFIG_HOME is tmp
        os.makedirs(self.hypr)

    def tearDown(self):
        dt.NIX_STORE = self.saved_store
        super().tearDown()

    def write(self, path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def test_plain_config_is_not_managed(self):
        self.write(os.path.join(self.hypr, "hyprland.lua"), 'require("config/monitors")\n')
        info = dt.persist_info()
        self.assertFalse(info["managed"])
        self.assertTrue(info["writable"])

    def test_hyprland_lua_linked_into_the_store_is_managed(self):
        target = os.path.join(self.store, "abc-hyprland.lua")
        self.write(target, "-- generated\n")
        os.symlink(target, os.path.join(self.hypr, "hyprland.lua"))
        self.assertTrue(dt.persist_info()["managed"])

    def test_whole_config_dir_linked_into_the_store_is_managed_and_not_writable(self):
        os.rmdir(self.hypr)
        target = os.path.join(self.store, "abc-hypr")
        self.write(os.path.join(target, "hyprland.lua"), "-- generated\n")
        os.symlink(target, self.hypr)
        os.chmod(target, 0o500)
        try:
            info = dt.persist_info()
            self.assertTrue(info["managed"])
            if not os.access(target, os.W_OK):
                self.assertFalse(info["writable"])
        finally:
            os.chmod(target, 0o700)

    def test_link_outside_the_store_is_not_managed(self):
        other = os.path.join(self.tmp.name, "dotfiles", "hyprland.lua")
        self.write(other, "-- mine\n")
        os.symlink(other, os.path.join(self.hypr, "hyprland.lua"))
        self.assertFalse(dt.persist_info()["managed"])

    def test_missing_config_dir_does_not_crash(self):
        os.rmdir(self.hypr)
        info = dt.persist_info()
        self.assertFalse(info["managed"])
        self.assertTrue(info["writable"])

    def test_managed_config_does_not_change_the_included_detection(self):
        target = os.path.join(self.store, "abc-hyprland.lua")
        self.write(target, 'require("serpantinum/monitors")\n')
        os.symlink(target, os.path.join(self.hypr, "hyprland.lua"))
        info = dt.persist_info()
        self.assertTrue(info["managed"])
        self.assertTrue(info["included"])


class VerifyLuaTests(Base):
    """verify_lua must find Hyprland even when PATH lacks it (systemd user service)."""

    def setUp(self):
        super().setUp()
        self.bin = os.path.join(self.tmp.name, "bin")
        os.makedirs(self.bin)
        self.saved_path = os.environ.get("PATH", "")
        self.lua = os.path.join(self.tmp.name, "m.lua")
        with open(self.lua, "w") as f:
            f.write("-- x\n")

    def tearDown(self):
        os.environ["PATH"] = self.saved_path
        super().tearDown()

    def make_bin(self, name, body):
        path = os.path.join(self.bin, name)
        with open(path, "w") as f:
            f.write("#!/bin/sh\n" + body + "\n")
        os.chmod(path, 0o755)
        return path

    def log_text(self):
        try:
            return open(dt.log_path()).read()
        except OSError:
            return ""

    def test_found_in_path(self):
        self.make_bin("Hyprland", 'echo "config ok"')
        os.environ["PATH"] = self.bin
        self.assertTrue(dt.verify_lua(self.lua))

    def test_found_next_to_hyprctl_when_not_in_path(self):
        self.make_bin("hyprctl", "true")
        self.make_bin("Hyprland", 'echo "config ok"')
        # hyprctl reachable through a different directory than Hyprland's own
        other = os.path.join(self.tmp.name, "other")
        os.makedirs(other)
        os.symlink(os.path.join(self.bin, "hyprctl"), os.path.join(other, "hyprctl"))
        os.environ["PATH"] = other
        self.assertEqual(os.path.basename(dt.find_hyprland_binary()), "Hyprland")
        self.assertTrue(dt.verify_lua(self.lua))

    def test_a_config_hyprland_rejects_is_refused(self):
        self.make_bin("Hyprland", 'echo "error: bad"; exit 1')
        os.environ["PATH"] = self.bin
        self.assertFalse(dt.verify_lua(self.lua))

    def test_missing_hyprland_skips_verification_and_logs_it(self):
        os.environ["PATH"] = self.bin  # empty bin dir
        self.assertIsNone(dt.find_hyprland_binary())
        self.assertTrue(dt.verify_lua(self.lua))
        self.assertIn("verify skipped", self.log_text())


if __name__ == "__main__":
    unittest.main()
