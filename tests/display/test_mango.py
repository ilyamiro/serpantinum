"""Offline tests for the Mango backend of display_txn.py (no compositor needed).

mango_wlr_randr_headless.json is real `wlr-randr --json` output from a headless mango 0.18.4.
Behaviours the fake wlr-randr below reproduces were observed on that mango (see
docs/configure/compositors/mango.md): outputs are applied one by one, an output that was off is
auto-placed to the right of the others whatever --pos the same request carries, a dry run
checks outputs and modes without applying anything.

Run: python3 -m unittest discover -s tests/display -v
"""

import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "..", "src", "quickshell", "guide", "display", "display_txn.py")
spec = importlib.util.spec_from_file_location("display_txn_mango", SCRIPT)
dt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dt)
dt.VERIFY_DELAY = 0.001
dt.POLL_INTERVAL = 0.01

with open(os.path.join(HERE, "fixtures", "mango_wlr_randr_headless.json")) as f:
    HEADLESS = json.load(f)

TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]


def hw_output(name, make, model, serial, modes, current=0, x=0, y=0, scale=1.0, transform="normal", on=True):
    """modes: (w, h, hz). wlr-randr gives a disabled output no position/scale/transform."""
    out = {"name": name, "description": "%s %s" % (make, model), "make": make, "model": model, "serial": serial,
           "physical_size": {"width": 340, "height": 190}, "enabled": on,
           "modes": [{"width": w, "height": h, "refresh": r, "preferred": i == 0, "current": on and i == current}
                     for i, (w, h, r) in enumerate(modes)],
           "adaptive_sync": False}
    if on:
        out.update(position={"x": x, "y": y}, transform=transform, scale=scale)
    return out


def laptop_and_dell():
    return [
        hw_output("eDP-1", "AU Optronics", "B156HAN15.H", "0x00000000", [(1920, 1080, 60.061), (1920, 1080, 144.061)]),
        hw_output("HDMI-A-1", "Dell Inc.", "Inspiron 3043", "0x00000001",
                  [(1920, 1080, 60.0), (1280, 720, 60.0)], x=1920),
    ]


class FakeWlr:
    """Simulates wlr-randr [--dryrun] [--json] [--output N --on|--off|--mode|--pos|--scale|--transform]."""

    def __init__(self, outputs, virtual=False):
        self.outputs = outputs
        self.virtual = virtual       # a virtual output lists no modes while it is off
        self.calls = []
        self.fail_real = None

    def by_name(self, name):
        return next((o for o in self.outputs if o["name"] == name), None)

    def __call__(self, args, timeout=5):
        self.calls.append(list(args))
        assert args[0] == "wlr-randr"
        rest = args[1:]
        if rest == ["--json"]:
            return 0, json.dumps(self.outputs), ""
        dry = "--dryrun" in rest
        groups, cur = [], None
        i = 0
        while i < len(rest):
            a = rest[i]
            if a == "--dryrun":
                i += 1
            elif a == "--output":
                cur = {"name": rest[i + 1], "ops": []}
                groups.append(cur)
                i += 2
            elif a in ("--on", "--off"):
                cur["ops"].append((a, None))
                i += 1
            else:
                cur["ops"].append((a, rest[i + 1]))
                i += 2
        for g in groups:                      # checking phase, also what --dryrun does
            o = self.by_name(g["name"])
            if o is None:
                return 1, "", "unknown output %s" % g["name"]
            for op, val in g["ops"]:
                if op == "--mode" and self._find_mode(o, val) is None:
                    return 1, "", "unknown mode: %s" % val
        if dry:
            return 0, "", ""
        if self.fail_real:
            return 1, "", self.fail_real
        for g in groups:
            self._apply(self.by_name(g["name"]), g["ops"])
        return 0, "", ""

    @staticmethod
    def _find_mode(o, text):
        res, _, rate = text.partition("@")
        w, h = (int(v) for v in res.split("x"))
        for i, m in enumerate(o["modes"]):
            if (m["width"], m["height"]) == (w, h) and (not rate or abs(m["refresh"] - float(rate)) < 0.01):
                return i
        return None

    def _logical_width(self, o):
        m = next(md for md in o["modes"] if md["current"])
        sideways = o["transform"] in ("90", "270", "flipped-90", "flipped-270")
        return int((m["height"] if sideways else m["width"]) / o["scale"])

    def _apply(self, o, ops):
        woke = False
        for op, val in ops:
            if op == "--off":
                o["enabled"] = False
                for k in ("position", "transform", "scale"):
                    o.pop(k, None)
                for m in o["modes"]:
                    m["current"] = False
                if self.virtual:
                    o["modes"] = []
            elif op == "--on" and not o["enabled"]:
                o["enabled"], woke = True, True
                o.setdefault("scale", 1.0)
                o.setdefault("transform", "normal")
                if o["modes"]:
                    o["modes"][0]["current"] = True
        for op, val in ops:
            if not o["enabled"]:
                continue
            if op == "--mode":
                idx = self._find_mode(o, val)
                for j, m in enumerate(o["modes"]):
                    m["current"] = j == idx
            elif op == "--scale":
                o["scale"] = float(val)
            elif op == "--transform":
                o["transform"] = val
            elif op == "--pos" and not woke:
                x, y = (int(v) for v in val.split(","))
                o["position"] = {"x": x, "y": y}
        if woke:   # auto placement to the right of the other enabled outputs
            right = max([p["position"]["x"] + self._logical_width(p) for p in self.outputs
                         if p is not o and p["enabled"]] or [0])
            o["position"] = {"x": right, "y": 0}


class Base(unittest.TestCase):
    ENV = ("XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "HOME", "NIRI_SOCKET", "SWAYSOCK",
           "HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE", "SERPANTINUM_DISPLAY_BACKEND",
           "SERPANTINUM_DISPLAY_VIRTUAL_ONLY", "PATH", "WAYLAND_DISPLAY")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.saved = {k: os.environ.get(k) for k in self.ENV}
        for k in ("XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "HOME"):
            os.environ[k] = self.tmp.name
        for k in ("NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE", "MANGO_INSTANCE_SIGNATURE",
                  "SERPANTINUM_DISPLAY_BACKEND", "SERPANTINUM_DISPLAY_VIRTUAL_ONLY", "WAYLAND_DISPLAY"):
            os.environ.pop(k, None)
        self.wlr = FakeWlr(laptop_and_dell())
        self.backend = dt.MangoBackend(runner=self.wlr)
        self.saved_spawn = dt.spawn_watcher
        dt.spawn_watcher = lambda txn_id, backend_name=None: "test"

    def tearDown(self):
        dt.spawn_watcher = self.saved_spawn
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        self.tmp.cleanup()

    def plan(self, **changes):
        plan = dt.plan_from_state(self.backend.state())
        for m in plan["monitors"]:
            m.update(changes.get(m["name"], {}))
        return plan

    @staticmethod
    def read(path):
        with open(path) as f:
            return f.read()

    @staticmethod
    def write_file(path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def make_bin(self, name, body):
        d = os.path.join(self.tmp.name, "bin")
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name)
        self.write_file(path, "#!/bin/sh\n%s\n" % body)
        os.chmod(path, 0o755)
        return d

    def mon(self, st, name):
        return next(m for m in st["monitors"] if m["name"] == name)

    def real_calls(self):
        return [c for c in self.wlr.calls if c[1:2] not in (["--json"],) and "--dryrun" not in c]

    def dry_calls(self):
        return [c for c in self.wlr.calls if "--dryrun" in c]


class StateTests(Base):
    def test_hardware_output_is_normalised(self):
        m = self.mon(self.backend.state(), "eDP-1")
        self.assertEqual((m["width"], m["height"], m["refresh"], m["x"], m["y"], m["scale"], m["transform"]),
                         (1920, 1080, 60.061, 0, 0, 1.0, 0))
        self.assertEqual(m["description"], "AU Optronics B156HAN15.H 0x00000000")
        self.assertTrue(m["enabled"])
        self.assertFalse(m["focused"])
        self.assertIn([1920, 1080, 144.061], m["modes"])

    def test_state_backend_name(self):
        self.assertEqual(self.backend.state()["backend"], "mango")

    def test_transform_names(self):
        for i, name in enumerate(TRANSFORMS):
            self.wlr.by_name("eDP-1")["transform"] = name
            self.assertEqual(self.mon(self.backend.state(), "eDP-1")["transform"], i)

    def test_off_output_keeps_a_usable_mode(self):
        self.wlr.outputs[0] = hw_output("eDP-1", "AU Optronics", "B156HAN15.H", "0x00000000",
                                        [(1920, 1080, 60.061), (1920, 1080, 144.061)], on=False)
        m = self.mon(self.backend.state(), "eDP-1")
        self.assertFalse(m["enabled"])
        self.assertEqual((m["width"], m["height"]), (1920, 1080))
        self.assertEqual((m["x"], m["y"]), (0, 0))

    def test_real_headless_json(self):
        self.wlr.outputs = json.loads(json.dumps(HEADLESS))
        st = self.backend.state()
        self.assertEqual([m["name"] for m in st["monitors"]], ["HEADLESS-1", "HEADLESS-2"])
        h2 = self.mon(st, "HEADLESS-2")
        self.assertEqual((h2["width"], h2["height"], h2["refresh"], h2["x"]), (1280, 720, 60.0, 1920))   # 0 Hz -> 60
        self.assertEqual(h2["description"], "")      # null make/model/serial: no identity

    def test_virtual_output_without_modes_while_off(self):
        self.wlr.outputs = json.loads(json.dumps(HEADLESS))
        self.wlr.outputs[0].update(enabled=False, modes=[])
        for k in ("position", "transform", "scale"):
            self.wlr.outputs[0].pop(k, None)
        m = self.mon(self.backend.state(), "HEADLESS-1")
        self.assertFalse(m["enabled"])
        self.assertEqual((m["width"], m["height"], m["refresh"]), (1920, 1080, 60.0))
        self.assertEqual(m["modes"], [[1920, 1080, 60.0]])

    def test_bad_json_is_an_error(self):
        for text in ("not json", '{"a": 1}'):
            b = dt.MangoBackend(runner=lambda args, timeout=5, t=text: (0, t, ""))
            with self.assertRaises(dt.DisplayError):
                b.state()

    def test_failing_wlr_randr_is_an_error(self):
        b = dt.MangoBackend(runner=lambda args, timeout=5: (1, "", "failed to connect"))
        with self.assertRaises(dt.DisplayError):
            b.state()


class ApplyTests(Base):
    def test_dry_run_of_everything_precedes_the_first_real_change(self):
        self.backend.apply(self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"x": 0}}))
        kinds = ["dry" if "--dryrun" in c else "real" for c in self.wlr.calls if c[1:2] != ["--json"]]
        self.assertEqual(kinds, ["dry", "dry", "real", "real"])

    def test_enable_call_never_disables_and_disable_call_comes_last(self):
        self.backend.apply(self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"x": 0}}))
        real = self.real_calls()
        self.assertEqual(len(real), 2)
        self.assertNotIn("--off", real[0])
        self.assertIn("--on", real[0])
        self.assertEqual(real[1], ["wlr-randr", "--output", "eDP-1", "--off"])

    def test_every_field_is_sent(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"width": 1280, "height": 720, "x": 10, "y": 20,
                                                     "scale": 1.5, "transform": 5}}))
        call = self.real_calls()[0]
        i = call.index("HDMI-A-1")
        mine = call[i - 1:i + 10]
        self.assertEqual(mine, ["--output", "HDMI-A-1", "--on", "--mode", "1280x720@60.000", "--pos", "10,20",
                                "--scale", "1.5", "--transform", "flipped-90"])

    def test_changes_land_in_the_state(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"x": 0, "y": 1080, "scale": 1.5, "transform": 1}}))
        m = self.mon(self.backend.state(), "HDMI-A-1")
        self.assertEqual((m["x"], m["y"], m["scale"], m["transform"]), (0, 1080, 1.5, 1))

    def test_a_rejected_dry_run_applies_nothing(self):
        plan = self.plan(**{"HDMI-A-1": {"x": 0}})
        plan["monitors"][0]["width"], plan["monitors"][0]["height"] = 1234, 567   # a mode nobody lists
        before = json.dumps(self.wlr.outputs, sort_keys=True)
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertEqual(json.dumps(self.wlr.outputs, sort_keys=True), before)
        self.assertEqual(self.real_calls(), [])

    def test_unknown_output_applies_nothing(self):
        plan = self.plan()
        plan["monitors"][1]["name"] = "DP-9"
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertEqual(self.real_calls(), [])

    def test_unsafe_output_names_never_reach_wlr_randr(self):
        plan = self.plan()
        plan["monitors"][0]["name"] = 'x"; rm -rf ~'
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertEqual([c for c in self.wlr.calls if c[1:2] != ["--json"]], [])

    def test_a_plan_with_every_output_off_is_refused_before_any_call(self):
        plan = self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"enabled": False}})
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertEqual([c for c in self.wlr.calls if c[1:2] != ["--json"]], [])

    def test_failing_real_call_raises(self):
        self.wlr.fail_real = "boom"
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(self.plan(**{"HDMI-A-1": {"x": 0}}))

    def test_a_reenabled_output_is_positioned_by_a_second_request(self):
        self.backend.apply(self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"x": 0}}))
        self.assertFalse(self.mon(self.backend.state(), "eDP-1")["enabled"])
        self.backend = dt.MangoBackend(runner=self.wlr)
        self.backend.apply(self.plan(**{"eDP-1": {"enabled": True, "x": 1920, "y": 0}, "HDMI-A-1": {"x": 0}}))
        st = self.backend.state()
        self.assertEqual((self.mon(st, "eDP-1")["x"], self.mon(st, "eDP-1")["y"]), (1920, 0))
        self.assertEqual((self.mon(st, "HDMI-A-1")["x"], self.mon(st, "HDMI-A-1")["y"]), (0, 0))

    def test_no_position_request_when_nothing_was_off(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"x": 0}}))
        self.assertEqual(len(self.real_calls()), 1)

    def test_virtual_output_zero_hz_mode_is_sent_without_refresh(self):
        self.wlr.outputs = json.loads(json.dumps(HEADLESS))
        self.backend.apply(self.plan(**{"HEADLESS-2": {"x": 2000}}))
        call = self.real_calls()[0]
        i = call.index("HEADLESS-2")
        self.assertEqual(call[i + 2:i + 4], ["--mode", "1280x720"])

    def test_output_without_modes_is_sent_without_mode(self):
        self.wlr.virtual = True
        self.wlr.outputs = json.loads(json.dumps(HEADLESS))
        self.backend.apply(self.plan(**{"HEADLESS-1": {"enabled": False}}))
        self.assertFalse(self.mon(self.backend.state(), "HEADLESS-1")["enabled"])
        self.backend = dt.MangoBackend(runner=self.wlr)
        self.wlr.calls.clear()
        self.backend.apply(self.plan(**{"HEADLESS-1": {"enabled": True, "x": 0}, "HEADLESS-2": {"x": 1920}}))
        on = next(c for c in self.real_calls() if "--on" in c)
        groups = " ".join(on[1:]).split("--output ")[1:]
        mine = next(g for g in groups if g.startswith("HEADLESS-1 "))
        self.assertNotIn("--mode", mine)
        self.assertIn("--mode", next(g for g in groups if g.startswith("HEADLESS-2 ")))

    def test_transaction_confirm_and_revert(self):
        before = self.backend.state()
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"x": 0, "y": 1080}}), 15)
        self.assertTrue(r["ok"], r)
        self.assertEqual(self.mon(self.backend.state(), "HDMI-A-1")["x"], 0)
        self.assertEqual(dt.finish(self.backend, r["id"], "revert", reason="requested"), "restored")
        after = self.backend.state()
        for m in before["monitors"]:
            self.assertEqual((self.mon(after, m["name"])["x"], self.mon(after, m["name"])["y"]), (m["x"], m["y"]))

    def test_restore_refuses_another_compositor(self):
        snap = {"backend": "hyprland", "monitors": [{"name": "eDP-1"}]}
        self.assertEqual(dt.restore(self.backend, snap), "failed")
        self.assertEqual(self.real_calls(), [])

    def test_scale_rule_is_fractional_quarter_steps(self):
        self.assertIn(1.25, dt.MangoBackend.valid_scales(1920, 1080))
        self.assertTrue(dt.MangoBackend.accepts_scale(1.1, 1920, 1080))
        self.assertFalse(dt.MangoBackend.accepts_scale(9.0, 1920, 1080))

    def test_negative_positions_are_an_error_only_for_mango(self):
        st = self.backend.state()
        plan = dt.plan_from_state(st)
        next(m for m in plan["monitors"] if m["name"] == "eDP-1")["x"] = -1920
        errors, _ = dt.validate(plan, st)
        self.assertIn("position_negative:eDP-1", errors)
        st["backend"] = "sway"
        errors, _ = dt.validate(plan, st)
        self.assertNotIn("position_negative:eDP-1", errors)


class PersistenceTests(Base):
    def rendered(self, state=None):
        return self.backend.persist_render(state or self.backend.state())

    def rules(self, text=None):
        return [ln for ln in (text or self.rendered()).split("\n") if ln.startswith("monitor_rule=")]

    def test_rule_syntax_with_unique_identity(self):
        rules = self.rules()
        self.assertIn("monitor_rule=make:Dell Inc.,model:Inspiron 3043,serial:0x00000001,width:1920,height:1080,"
                      "refresh:60.000,x:1920,y:0,scale:1.0,rr:0", rules)
        self.assertIn("monitor_rule=make:AU Optronics,model:B156HAN15.H,serial:0x00000000,width:1920,height:1080,"
                      "refresh:60.061,x:0,y:0,scale:1.0,rr:0", rules)

    def test_name_is_an_escaped_anchored_regex(self):
        self.wlr.by_name("HDMI-A-1")["serial"] = None       # no complete identity: use the connector
        self.assertIn("monitor_rule=name:^HDMI\\-A\\-1$,width:1920", self.rendered())

    def test_regex_does_not_match_a_longer_connector(self):
        import re
        self.wlr.by_name("HDMI-A-1")["serial"] = None
        rule = next(r for r in self.rules() if r.startswith("monitor_rule=name:"))
        pattern = rule.split(",")[0].split("name:", 1)[1]
        self.assertTrue(re.search(pattern, "HDMI-A-1"))
        self.assertFalse(re.search(pattern, "HDMI-A-10"))
        self.assertFalse(re.search(pattern, "xHDMI-A-1"))

    def test_identical_panels_use_the_connector(self):
        a, b = self.wlr.by_name("eDP-1"), self.wlr.by_name("HDMI-A-1")
        b.update(make=a["make"], model=a["model"], serial=a["serial"])
        text = self.rendered()
        self.assertNotIn("make:", text)
        self.assertIn("name:^eDP\\-1$", text)
        self.assertIn("name:^HDMI\\-A\\-1$", text)

    def test_unsafe_characters_fall_back_to_the_connector(self):
        for bad in ("X, Y", "X:Y", "X#Y", "$HOME", 'X"Y', " X", "X\nY", "a=b", "a\\b"):
            self.wlr.by_name("eDP-1")["model"] = bad
            text = self.rendered()
            rule = next(r for r in self.rules(text) if "eDP" in r)
            self.assertTrue(rule.startswith("monitor_rule=name:^eDP\\-1$"), (bad, rule))

    def test_hostile_description_cannot_inject_config(self):
        self.wlr.by_name("eDP-1")["model"] = "X\nspawn=evil"
        text = self.rendered()
        self.assertNotIn("\nspawn=evil", text)
        for line in text.split("\n"):
            self.assertTrue(line == "" or line.startswith("#") or line.startswith("monitor_rule="), line)

    def test_a_missing_serial_means_no_identity(self):
        self.wlr.by_name("HDMI-A-1")["serial"] = None
        rule = next(r for r in self.rules() if "x:1920" in r)
        self.assertIn("name:^HDMI", rule)

    def test_disabled_outputs_are_not_saved(self):
        st = self.backend.state()
        self.mon(st, "eDP-1")["enabled"] = False
        text = self.rendered(st)
        self.assertNotIn("AU Optronics", text)
        self.assertEqual(len(self.rules(text)), 1)

    def test_rotation_uses_wl_output_numbers(self):
        st = self.backend.state()
        self.mon(st, "eDP-1")["transform"] = 7
        self.assertIn("rr:7", self.rendered(st))

    def test_negative_coordinates_are_never_written(self):
        st = self.backend.state()
        self.mon(st, "eDP-1")["x"] = -5
        self.assertNotIn("x:-", self.rendered(st))

    def test_every_line_fits_mangos_value_buffer(self):
        self.wlr.by_name("eDP-1")["make"] = "M" * 120
        self.wlr.by_name("eDP-1")["model"] = "N" * 120
        for r in self.rules():
            self.assertLess(len(r) - len("monitor_rule="), 255)

    def test_header_tells_the_two_source_lines(self):
        text = self.rendered()
        self.assertIn("source_optional=./serpantinum/monitors.conf", text)
        self.assertIn("TWO", text)

    def test_persist_writes_validates_and_keeps_a_backup(self):
        os.environ["PATH"] = self.make_bin("mango", "exit 0")
        path = self.backend.persist(self.backend.state())
        self.assertEqual(path, os.path.join(self.tmp.name, ".config", "mango", "serpantinum", "monitors.conf"))
        self.backend.persist(self.backend.state())
        self.assertTrue(os.path.exists(path + ".bak"))

    def test_validation_runs_mango_p_on_a_conf_file(self):
        log = os.path.join(self.tmp.name, "args")
        os.environ["PATH"] = self.make_bin("mango", 'echo "$@" > %s; exit 0' % log)
        self.backend.persist(self.backend.state())
        args = self.read(log).split()
        self.assertEqual(args[:2], ["-p", "-c"])
        self.assertTrue(args[2].endswith(".conf"))      # the extension selects mango's .conf parser

    def test_a_rejected_file_keeps_the_old_one(self):
        os.environ["PATH"] = self.make_bin("mango", "exit 0")
        path = self.backend.persist(self.backend.state())
        good = self.read(path)
        os.environ["PATH"] = self.make_bin("mango", "exit 1")
        st = self.backend.state()
        self.mon(st, "eDP-1")["x"] = 5
        with self.assertRaises(dt.DisplayError):
            self.backend.persist(st)
        self.assertEqual(self.read(path), good)
        self.assertEqual([f for f in os.listdir(os.path.dirname(path)) if f.endswith(".tmp")], [])

    def test_missing_mango_binary_skips_verification(self):
        os.environ["PATH"] = os.path.join(self.tmp.name, "empty")
        self.assertTrue(dt.verify_mango(__file__))

    @unittest.skipUnless(dt.find_mango_binary(), "mango is not installed")
    def test_real_mango_accepts_what_we_write_and_rejects_garbage(self):
        path = self.backend.persist(self.backend.state())
        self.assertTrue(dt.verify_mango(path))
        bad = os.path.join(self.tmp.name, "bad.conf")
        self.write_file(bad, "monitor_rule=name:X,width:1920\n")      # width without height/refresh
        self.assertFalse(dt.verify_mango(bad))


class PersistInfoTests(Base):
    def setUp(self):
        super().setUp()
        self.root = os.path.join(self.tmp.name, ".config", "mango")
        os.makedirs(self.root)
        self.conf = os.path.join(self.root, "config.conf")

    LINE = "source_optional=./serpantinum/monitors.conf"
    RULE = "monitor_rule=name:eDP-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1"

    def info(self, text):
        self.write_file(self.conf, text)
        return self.backend.persist_info()

    def test_nothing_configured(self):
        info = self.backend.persist_info()
        self.assertEqual((info["exists"], info["included"], info["managed"], info["complete"]),
                         (False, False, False, False))
        self.assertTrue(info["writable"])

    def test_line_first_and_last_is_complete(self):
        info = self.info("%s\n%s\n%s\n" % (self.LINE, self.RULE, self.LINE))
        self.assertTrue(info["included"])
        self.assertTrue(info["complete"])

    def test_line_only_first_is_not_complete(self):
        info = self.info("%s\n%s\n" % (self.LINE, self.RULE))
        self.assertTrue(info["included"])
        self.assertFalse(info["complete"])

    def test_line_only_last_is_not_complete(self):
        info = self.info("%s\n%s\n" % (self.RULE, self.LINE))
        self.assertFalse(info["complete"])

    def test_without_user_rules_one_line_is_enough(self):
        self.assertTrue(self.info("bind=SUPER,q,killclient\n%s\n" % self.LINE)["complete"])

    def test_plain_and_absolute_source_forms_are_detected(self):
        for line in ("source=./serpantinum/monitors.conf", "source = ~/.config/mango/serpantinum/monitors.conf",
                     self.LINE):
            self.assertTrue(self.info(line + "\n")["included"], line)

    def test_commented_line_does_not_count(self):
        self.assertFalse(self.info("# %s\n" % self.LINE)["included"])

    def test_toml_only_config_is_reported(self):
        os.remove(self.conf) if os.path.exists(self.conf) else None
        self.write_file(os.path.join(self.root, "config.toml"), "[global]\n")
        self.assertTrue(self.backend.persist_info()["toml"])

    def test_nix_managed_config(self):
        store = os.path.join(self.tmp.name, "store")
        os.makedirs(store)
        target = os.path.join(store, "mango-config")
        self.write_file(target, "# nix\n")
        os.symlink(target, self.conf)
        saved, dt.NIX_STORE = dt.NIX_STORE, store
        try:
            self.assertTrue(self.backend.persist_info()["managed"])
        finally:
            dt.NIX_STORE = saved

    def test_config_dir_follows_home_not_xdg(self):
        os.environ["XDG_CONFIG_HOME"] = os.path.join(self.tmp.name, "elsewhere")
        self.assertEqual(dt.mango_config_dir(), os.path.join(self.tmp.name, ".config", "mango"))


class Listener:
    """A real listening Unix socket, so SO_PEERCRED reports a real owner."""

    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(path)
        self.sock.listen(8)

    def close(self):
        self.sock.close()


CHILD = r"""
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(8)
print("ready", flush=True)
time.sleep(60)
"""


class DetectionTests(Base):
    def setUp(self):
        super().setUp()
        self.procs, self.listeners = [], []

    def tearDown(self):
        for p in self.procs:
            p.kill()
            p.wait()
        for lst in self.listeners:
            lst.close()
        super().tearDown()

    def path(self, name):
        return os.path.join(self.tmp.name, name)

    def own_display(self, name="wayland-2"):
        """A wayland socket served by THIS process (pid = os.getpid())."""
        self.listeners.append(Listener(self.path(name)))
        return name

    def child_display(self, name):
        """A wayland socket served by another process; returns (pid, name)."""
        p = subprocess.Popen([sys.executable, "-c", CHILD, self.path(name)], stdout=subprocess.PIPE, text=True)
        self.procs.append(p)
        p.stdout.readline()
        return p.pid, name

    def signature(self, pid, age=1):
        path = self.path("mango-%d.sock" % pid)
        self.write_file(path, "")
        t = time.time() - age
        os.utime(path, (t, t))
        return path

    def install_wlr(self, answers):
        """answers: {display: [output names] | None} (None = does not answer)."""
        lines = ['case "$WAYLAND_DISPLAY" in']
        for disp, names in answers.items():
            body = "exit 1" if names is None else "echo '%s'" % json.dumps([{"name": n} for n in names])
            lines.append("  %s) %s ;;" % (disp, body))
        lines += ["  *) exit 1 ;;", "esac"]
        os.environ["PATH"] = self.make_bin("wlr-randr", "\n".join(lines)) + os.pathsep + self.saved["PATH"]

    def test_socket_owner_is_the_serving_process(self):
        self.own_display()
        self.assertEqual(dt.socket_owner_pid(self.path("wayland-2")), os.getpid())
        pid, name = self.child_display("wayland-3")
        self.assertEqual(dt.socket_owner_pid(self.path(name)), pid)
        self.assertIsNone(dt.socket_owner_pid(self.path("nothing")))

    def test_display_is_found_by_owner_pid(self):
        pid, name = self.child_display("wayland-0")
        self.own_display("wayland-1")
        self.assertEqual(dt.mango_display_of(pid, self.tmp.name), "wayland-0")
        self.assertEqual(dt.mango_display_of(os.getpid(), self.tmp.name), "wayland-1")
        self.assertIsNone(dt.mango_display_of(1, self.tmp.name))

    def test_inside_mango_needs_the_display_served_by_that_mango(self):
        self.own_display("wayland-2")
        os.environ["MANGO_INSTANCE_SIGNATURE"] = self.signature(os.getpid())
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        self.assertTrue(dt.MangoBackend.detect())
        pid, other = self.child_display("wayland-5")       # a client of ANOTHER compositor
        os.environ["WAYLAND_DISPLAY"] = other
        self.assertFalse(dt.MangoBackend.detect())
        os.environ.pop("WAYLAND_DISPLAY")                  # no display to prove it: not detected
        self.assertFalse(dt.MangoBackend.detect())

    def test_signature_of_a_dead_mango_is_ignored(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        self.own_display("wayland-2")
        os.environ["MANGO_INSTANCE_SIGNATURE"] = self.signature(dead.pid)
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        self.assertFalse(dt.MangoBackend.detect())

    def test_compositors_nested_in_mango_are_not_taken_for_mango(self):
        # a Sway/Hyprland/niri started inside mango inherits MANGO_INSTANCE_SIGNATURE but serves
        # its own wayland socket
        self.own_display("wayland-2")                       # "mango"
        os.environ["MANGO_INSTANCE_SIGNATURE"] = self.signature(os.getpid())
        pid, nested = self.child_display("wayland-7")
        os.environ["WAYLAND_DISPLAY"] = nested
        swaysock = self.path("sway.sock")
        self.write_file(swaysock, "")
        os.environ["SWAYSOCK"] = swaysock
        self.assertFalse(dt.MangoBackend.detect())
        self.assertTrue(dt.SwayBackend.detect())
        self.assertEqual(dt.detect_backend().name, "sway")

    def test_sway_variable_inherited_by_a_client_of_mango_is_ignored(self):
        self.own_display("wayland-2")
        os.environ["MANGO_INSTANCE_SIGNATURE"] = self.signature(os.getpid())
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        swaysock = self.path("sway.sock")
        self.write_file(swaysock, "")
        os.environ["SWAYSOCK"] = swaysock
        self.assertFalse(dt.SwayBackend.detect())
        self.assertTrue(dt.MangoBackend.detect())
        self.assertEqual(dt.detect_backend().name, "mango")

    def test_real_mango_beats_a_nested_one_from_a_tty(self):
        real_pid, real_disp = self.child_display("wayland-0")
        real = self.signature(real_pid, age=500)
        nested_pid, nested_disp = self.child_display("wayland-2")
        self.signature(nested_pid, age=1)
        self.install_wlr({real_disp: ["eDP-1"], nested_disp: ["WAYLAND-1"]})
        self.assertEqual(dt.detect_backend().name, "mango")
        self.assertEqual(os.environ["MANGO_INSTANCE_SIGNATURE"], real)
        self.assertEqual(os.environ["WAYLAND_DISPLAY"], real_disp)

    def test_instance_without_a_findable_display_is_skipped(self):
        pid, disp = self.child_display("wayland-0")
        self.signature(pid)
        orphan = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        self.procs.append(orphan)
        time.sleep(0.2)
        self.signature(orphan.pid, age=900)
        self.install_wlr({disp: ["DP-1"]})
        dt.detect_backend()
        self.assertTrue(os.environ["MANGO_INSTANCE_SIGNATURE"].endswith("mango-%d.sock" % pid))

    def test_dead_socket_is_ignored(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        self.signature(dead.pid)
        self.install_wlr({})
        with self.assertRaises(dt.DisplayError):
            dt.detect_backend()

    def test_a_real_mango_beats_a_nested_sway(self):
        pid, disp = self.child_display("wayland-0")
        self.signature(pid, age=900)
        swaysock = self.path("sway-ipc.%d.%d.sock" % (os.getuid(), self.child_display("wayland-8")[0]))
        self.write_file(swaysock, "")
        self.make_bin("swaymsg", 'echo \'[{"name": "HEADLESS-1"}]\'')
        self.install_wlr({disp: ["eDP-1"]})
        self.assertEqual(dt.detect_backend().name, "mango")

    def test_nested_mango_never_beats_a_real_sway(self):
        pid, disp = self.child_display("wayland-2")
        self.signature(pid, age=1)
        swaysock = self.path("sway-ipc.%d.%d.sock" % (os.getuid(), self.child_display("wayland-9")[0]))
        self.write_file(swaysock, "")
        self.make_bin("swaymsg", 'echo \'[{"name": "eDP-1"}]\'')
        self.install_wlr({disp: ["WAYLAND-1"]})
        self.assertEqual(dt.detect_backend().name, "sway")

    def test_forcing_the_backend_ignores_the_others(self):
        self.own_display("wayland-2")
        os.environ["MANGO_INSTANCE_SIGNATURE"] = self.signature(os.getpid())
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        os.environ["SERPANTINUM_DISPLAY_BACKEND"] = "mango"
        self.assertEqual(dt.detect_backend().name, "mango")


class TargetGuardTests(Base):
    """The real (non-injected) backend must talk only to the mango it was created for."""

    def setUp(self):
        super().setUp()
        self.listener = Listener(os.path.join(self.tmp.name, "wayland-2"))
        sig = os.path.join(self.tmp.name, "mango-%d.sock" % os.getpid())
        self.write_file(sig, "")
        os.environ["MANGO_INSTANCE_SIGNATURE"] = sig
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        os.environ["PATH"] = self.make_bin("wlr-randr", "echo '%s'" % json.dumps(HEADLESS)) + os.pathsep + self.saved["PATH"]

    def tearDown(self):
        self.listener.close()
        super().tearDown()

    def test_matching_target_works(self):
        b = dt.MangoBackend()
        self.assertEqual([m["name"] for m in b.state()["monitors"]], ["HEADLESS-1", "HEADLESS-2"])

    def test_switched_wayland_display_is_refused(self):
        b = dt.MangoBackend()
        other = Listener(os.path.join(self.tmp.name, "wayland-9"))
        try:
            os.environ["WAYLAND_DISPLAY"] = "wayland-missing"
            with self.assertRaises(dt.DisplayError) as e:
                b.state()
            self.assertIn("mango_target_mismatch", str(e.exception))
        finally:
            other.close()

    def test_apply_is_refused_when_the_target_changed(self):
        b = dt.MangoBackend()
        b.state()
        os.environ["WAYLAND_DISPLAY"] = "wayland-missing"
        with self.assertRaises(dt.DisplayError):
            b.apply({"monitors": [{"name": "HEADLESS-1", "enabled": True, "width": 1920, "height": 1080,
                                   "refresh": 60.0, "x": 0, "y": 0, "scale": 1.0, "transform": 0}]})

    def test_missing_wlr_randr_is_reported_not_guessed(self):
        os.environ["PATH"] = os.path.join(self.tmp.name, "empty")
        with self.assertRaises(dt.DisplayError) as e:
            dt.MangoBackend().state()
        self.assertIn("wlr_randr_missing", str(e.exception))

    def test_missing_wlr_randr_never_applies(self):
        os.environ["PATH"] = os.path.join(self.tmp.name, "empty")
        with self.assertRaises(dt.DisplayError):
            dt.MangoBackend().apply({"monitors": []})

    def test_virtual_only_guard_applies_to_mango_too(self):
        os.environ["SERPANTINUM_DISPLAY_VIRTUAL_ONLY"] = "1"
        wlr = FakeWlr(laptop_and_dell())
        b = dt.MangoBackend(runner=wlr)
        with self.assertRaises(dt.DisplayError):
            dt.guarded_apply(b, dt.plan_from_state(b.state()))
        self.assertEqual([c for c in wlr.calls if c[1:2] != ["--json"]], [])

    def test_reverter_is_told_the_mango_instance(self):
        dt.spawn_watcher = self.saved_spawn
        os.environ["SERPANTINUM_DISPLAY_NO_SYSTEMD"] = "1"
        seen = {}
        popen = subprocess.Popen

        def fake(args, **kw):
            seen["env"] = dict(os.environ)
            return type("P", (), {})()
        subprocess.Popen = fake
        try:
            dt.spawn_watcher("abcdef123456", "mango")
        finally:
            subprocess.Popen = popen
            os.environ.pop("SERPANTINUM_DISPLAY_NO_SYSTEMD", None)
        self.assertEqual(seen["env"]["SERPANTINUM_DISPLAY_BACKEND"], "mango")
        self.assertIn("MANGO_INSTANCE_SIGNATURE", seen["env"])
        src = self.read(SCRIPT)
        self.assertIn('"MANGO_INSTANCE_SIGNATURE"', src.split("env_keys = (")[1].split(")")[0])


if __name__ == "__main__":
    unittest.main()
