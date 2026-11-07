"""Offline tests for the Niri backend of display_txn.py (no compositor needed).

niri_winit_outputs.json is real `niri msg -j outputs` output (niri 26.04, nested). A nested niri
has one output that ignores transform and power, so hardware outputs are built by hand with
the same keys (niri-ipc `Output`: modes, current_mode index or null, logical or null).

Run: python3 -m unittest discover -s tests/display -v
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "..", "src", "quickshell", "guide", "display", "display_txn.py")
spec = importlib.util.spec_from_file_location("display_txn_niri", SCRIPT)
dt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dt)
dt.VERIFY_DELAY = 0.001
dt.POLL_INTERVAL = 0.01

with open(os.path.join(HERE, "fixtures", "niri_winit_outputs.json")) as f:
    WINIT = json.load(f)


def hw_output(name, make, model, serial, modes, current, x=0, y=0, scale=1.0, transform="Normal", on=True):
    """modes: (w, h, mHz); current: index. An output that is off has no current_mode / logical."""
    out = {"name": name, "make": make, "model": model, "serial": serial, "physical_size": [340, 190],
           "modes": [{"width": w, "height": h, "refresh_rate": r, "is_preferred": i == 0}
                     for i, (w, h, r) in enumerate(modes)],
           "current_mode": current if on else None, "is_custom_mode": False,
           "vrr_supported": False, "vrr_enabled": False, "logical": None}
    if on:
        w, h, _ = modes[current]
        out["logical"] = {"x": x, "y": y, "width": int(w / scale), "height": int(h / scale),
                          "scale": scale, "transform": transform}
    return out


def laptop_and_dell():
    return {
        "eDP-1": hw_output("eDP-1", "AU Optronics", "B156HAN15.H", "0x00000000",
                           [(1920, 1080, 60061), (1920, 1080, 144061)], 0),
        "HDMI-A-1": hw_output("HDMI-A-1", "Dell Inc.", "Inspiron 3043", "0x00000001",
                              [(1920, 1080, 60000), (1280, 720, 60000)], 0, x=1920),
    }


class FakeNiri:
    """Simulates `niri msg`: -j outputs, and output NAME on|off|mode|scale|transform|position."""

    def __init__(self, outputs):
        self.outputs = outputs
        self.calls = []
        self.fail = None

    def __call__(self, args, timeout=5):
        self.calls.append(args)
        if args[:4] == ["niri", "msg", "-j", "outputs"]:
            return 0, json.dumps(self.outputs), ""
        if args[:3] == ["niri", "msg", "output"]:
            if self.fail:
                return 0, self.fail, ""
            name, action, rest = args[3], args[4], args[5:]
            o = self.outputs.get(name)
            if o is None:      # niri answers rc=0 for an unknown output
                return 0, 'Output "%s" is not connected.\nThe change will apply when it is connected.' % name, ""
            self._do(o, action, rest)
            return 0, "", ""
        return 1, "", "unexpected"

    def _do(self, o, action, rest):
        log = o.setdefault("_pending", {})
        if action == "off":
            o["current_mode"], o["logical"] = None, None
        elif action == "on":
            if o["current_mode"] is None:
                o["current_mode"] = 0
                o["logical"] = {"x": 0, "y": 0, "width": 0, "height": 0, "scale": 1.0, "transform": "Normal"}
        elif action == "mode":
            res, _, rate = rest[0].partition("@")
            w, h = (int(v) for v in res.split("x"))
            for i, m in enumerate(o["modes"]):
                if (m["width"], m["height"]) == (w, h) and abs(m["refresh_rate"] - float(rate) * 1000) < 50:
                    o["current_mode"] = i
        elif action == "scale":
            o["logical"]["scale"] = float(rest[0])
        elif action == "transform":
            o["logical"]["transform"] = {"normal": "Normal", "90": "_90", "180": "_180", "270": "_270",
                                         "flipped": "Flipped", "flipped-90": "Flipped90",
                                         "flipped-180": "Flipped180", "flipped-270": "Flipped270"}[rest[0]]
        elif action == "position":
            o["logical"]["x"], o["logical"]["y"] = int(rest[1]), int(rest[2])
        if o["logical"]:
            m = o["modes"][o["current_mode"]]
            sideways = o["logical"]["transform"] in ("_90", "_270", "Flipped90", "Flipped270")
            w, h = (m["height"], m["width"]) if sideways else (m["width"], m["height"])
            o["logical"]["width"] = int(w / o["logical"]["scale"])
            o["logical"]["height"] = int(h / o["logical"]["scale"])


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.saved = {k: os.environ.get(k) for k in (
            "XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "NIRI_SOCKET", "SWAYSOCK",
            "HYPRLAND_INSTANCE_SIGNATURE", "SERPANTINUM_DISPLAY_BACKEND", "PATH", "WAYLAND_DISPLAY")}
        for k in ("XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME"):
            os.environ[k] = self.tmp.name
        self.niri = FakeNiri(laptop_and_dell())
        self.backend = dt.NiriBackend(runner=self.niri)
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


class StateTests(Base):
    def test_hardware_output_is_normalised(self):
        m = self.mon(self.backend.state(), "eDP-1")
        self.assertEqual((m["width"], m["height"], m["refresh"]), (1920, 1080, 60.061))
        self.assertEqual(m["description"], "AU Optronics B156HAN15.H 0x00000000")
        self.assertEqual(m["modes"], [[1920, 1080, 60.061], [1920, 1080, 144.061]])
        self.assertEqual((m["enabled"], m["x"], m["y"], m["scale"], m["transform"]), (True, 0, 0, 1.0, 0))

    def test_current_mode_is_an_index_into_modes(self):
        self.niri.outputs["eDP-1"]["current_mode"] = 1
        self.assertEqual(self.mon(self.backend.state(), "eDP-1")["refresh"], 144.061)

    def test_transform_names(self):
        for value, number in [("Normal", 0), ("_90", 1), ("90", 1), ("_180", 2), ("270", 3), ("Flipped", 4),
                              ("Flipped90", 5), ("Flipped180", 6), ("Flipped270", 7), ("flipped-90", 5)]:
            self.assertEqual(dt.parse_niri_transform(value), number, value)

    def test_unknown_transform_is_normal_and_logged(self):
        self.assertEqual(dt.parse_niri_transform("Sideways"), 0)

    def test_output_that_is_off_keeps_a_usable_mode(self):
        self.niri.outputs["HDMI-A-1"] = hw_output("HDMI-A-1", "Dell Inc.", "Inspiron 3043", "0x00000001",
                                                  [(1280, 720, 60000), (1920, 1080, 60000)], 0, on=False)
        m = self.mon(self.backend.state(), "HDMI-A-1")
        self.assertFalse(m["enabled"])
        self.assertEqual((m["width"], m["height"], m["refresh"]), (1920, 1080, 60.0))
        st = self.backend.state()
        self.assertEqual(dt.validate(self.plan(**{"HDMI-A-1": {"enabled": True, "x": 1920}}), st)[0], [])

    def test_real_winit_json(self):
        st = dt.NiriBackend(runner=FakeNiri(WINIT)).state()
        m = st["monitors"][0]
        self.assertEqual((st["backend"], m["name"]), ("niri", "winit"))
        self.assertEqual(m["description"], "Smithay Winit Unknown")   # niri's own spelling of a missing serial
        self.assertEqual(m["transform"], 6)                          # "Flipped180"
        self.assertIn([m["width"], m["height"], m["refresh"]], m["modes"])
        self.assertTrue(m["enabled"])

    def test_unknown_make_model_serial_is_no_identity(self):
        self.niri.outputs["eDP-1"].update(make=None, model=None, serial=None)
        self.assertEqual(self.mon(self.backend.state(), "eDP-1")["description"], "")

    def test_bad_json_is_an_error(self):
        backend = dt.NiriBackend(runner=lambda a, timeout=5: (0, "[1, 2]", ""))
        with self.assertRaises(dt.DisplayError):
            backend.state()


class ApplyTests(Base):
    def cmds(self):
        return [c[3:] for c in self.niri.calls if c[:3] == ["niri", "msg", "output"]]

    def test_enable_first_disable_last(self):
        self.backend.apply(self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"x": 0}}))
        names = [c[0] for c in self.cmds()]
        self.assertEqual(names[-1], "eDP-1")
        self.assertEqual(self.cmds()[-1], ["eDP-1", "off"])
        self.assertEqual(names.index("HDMI-A-1"), 0)

    def test_every_field_is_sent(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"width": 1280, "height": 720, "x": 10, "y": 20,
                                                     "scale": 1.5, "transform": 5}}))
        mine = [c[1:] for c in self.cmds() if c[0] == "HDMI-A-1"]
        self.assertEqual(mine, [["on"], ["mode", "1280x720@60.000"], ["scale", "1.5"],
                                ["transform", "flipped-90"], ["position", "set", "10", "20"]])

    def test_changes_land_in_the_state(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"x": 0, "y": 1080, "scale": 1.5, "transform": 1}}))
        m = self.mon(self.backend.state(), "HDMI-A-1")
        self.assertEqual((m["x"], m["y"], m["scale"], m["transform"]), (0, 1080, 1.5, 1))

    def test_unknown_output_is_an_error_even_though_niri_says_rc_0(self):
        plan = self.plan()
        plan["monitors"][0]["name"] = "DP-9"
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)

    def test_unsafe_output_names_never_reach_niri(self):
        plan = self.plan()
        plan["monitors"][0]["name"] = 'x"; rm -rf ~'
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertFalse(self.cmds())

    def test_failing_command_raises(self):
        self.niri.fail = "Output foo is not connected"
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(self.plan())

    def test_transaction_confirm_and_revert(self):
        before = self.backend.state()
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"x": 0, "y": 1080}}), 15)
        self.assertTrue(r["ok"], r)
        self.assertEqual((self.mon(self.backend.state(), "HDMI-A-1")["x"]), 0)
        self.assertEqual(dt.finish(self.backend, r["id"], "revert", reason="requested"), "restored")
        after = self.backend.state()
        for m in before["monitors"]:
            self.assertEqual((self.mon(after, m["name"])["x"], self.mon(after, m["name"])["y"]), (m["x"], m["y"]))

    def test_restore_refuses_another_compositor(self):
        snap = {"backend": "hyprland", "monitors": [{"name": "eDP-1"}]}
        self.assertEqual(dt.restore(self.backend, snap), "failed")
        self.assertFalse(self.cmds())

    def test_scale_rule(self):
        for s in (0.5, 1.1, 1.5, 3.0):
            self.assertTrue(dt.NiriBackend.accepts_scale(s, 1920, 1080), s)
        for s in (0.0, 99.0, float("nan")):
            self.assertFalse(dt.NiriBackend.accepts_scale(s, 1920, 1080), s)
        self.assertEqual(dt.NiriBackend.valid_scales(1920, 1080)[0], 0.5)

    def test_logical_size_is_truncated_like_niri(self):
        self.niri.outputs["eDP-1"]["modes"].append({"width": 950, "height": 1028, "refresh_rate": 60000})
        self.backend.apply(self.plan(**{"eDP-1": {"width": 950, "height": 1028, "refresh": 60.0, "scale": 1.4},
                                        "HDMI-A-1": {"x": 678}}))
        st = self.backend.state()
        self.assertEqual(self.mon(st, "eDP-1")["x"], 0)
        self.assertEqual(dt.validate(dt.plan_from_state(st), st)[0], [])   # 950 / 1.4 = 678.57 -> 678


class PersistenceTests(Base):
    def rendered(self, state=None):
        return self.backend.persist_render(state or self.backend.state())

    def test_block_syntax(self):
        text = self.rendered()
        self.assertIn('output "Dell Inc. Inspiron 3043 0x00000001" {\n    mode "1920x1080@60.000"\n'
                      '    scale 1.0\n    transform "normal"\n    position x=1920 y=0\n}', text)
        self.assertIn('include "serpantinum/monitors.kdl"', text)

    def test_disabled_outputs_are_not_saved(self):
        st = self.backend.state()
        self.mon(st, "eDP-1")["enabled"] = False
        text = self.rendered(st)
        self.assertNotIn("AU Optronics", text)
        self.assertIn("Dell Inc.", text)

    def test_identical_panels_use_the_connector(self):
        self.niri.outputs["eDP-1"].update(make="Dell Inc.", model="Inspiron 3043", serial="0x00000001")
        text = self.rendered()
        self.assertIn('output "eDP-1" {', text)
        self.assertIn('output "HDMI-A-1" {', text)

    def test_hostile_description_cannot_inject_config(self):
        self.niri.outputs["eDP-1"]["model"] = 'X" { } \nspawn-at-startup "evil"'
        text = self.rendered()
        self.assertNotIn('\nspawn-at-startup', text)
        self.assertIn('output "eDP-1" {', text)

    def test_flipped_transform(self):
        st = self.backend.state()
        self.mon(st, "eDP-1")["transform"] = 7
        self.assertIn('transform "flipped-270"', self.rendered(st))

    def test_persist_writes_validates_and_keeps_a_backup(self):
        os.environ["PATH"] = self.make_bin("niri", "exit 0")
        path = self.backend.persist(self.backend.state())
        self.assertEqual(path, os.path.join(self.tmp.name, "niri", "serpantinum", "monitors.kdl"))
        self.backend.persist(self.backend.state())
        self.assertTrue(os.path.exists(path + ".bak"))

    def test_validation_runs_niri_validate_on_the_file(self):
        log = os.path.join(self.tmp.name, "args")
        os.environ["PATH"] = self.make_bin("niri", 'echo "$@" > %s; exit 0' % log)
        self.backend.persist(self.backend.state())
        self.assertTrue(self.read(log).startswith("validate -c "))

    def test_a_rejected_file_keeps_the_old_one(self):
        os.environ["PATH"] = self.make_bin("niri", "exit 0")
        path = self.backend.persist(self.backend.state())
        good = self.read(path)
        os.environ["PATH"] = self.make_bin("niri", "exit 1")
        st = self.backend.state()
        self.mon(st, "eDP-1")["x"] = 5
        with self.assertRaises(dt.DisplayError):
            self.backend.persist(st)
        self.assertEqual(self.read(path), good)
        self.assertEqual([f for f in os.listdir(os.path.dirname(path)) if f.endswith(".tmp")], [])

    def test_missing_niri_binary_skips_verification(self):
        os.environ["PATH"] = os.path.join(self.tmp.name, "empty")
        self.assertTrue(dt.verify_niri(__file__))


class PersistInfoTests(Base):
    def setUp(self):
        super().setUp()
        self.root = os.path.join(self.tmp.name, "niri")
        os.makedirs(self.root)

    def test_nothing_configured(self):
        info = self.backend.persist_info()
        self.assertEqual((info["exists"], info["included"], info["managed"]), (False, False, False))
        self.assertTrue(info["writable"])

    def test_relative_and_absolute_includes_are_detected(self):
        for line in ('include "serpantinum/monitors.kdl"', 'include "~/.config/niri/serpantinum/monitors.kdl"',
                     'include "serpantinum/monitors.kdl" optional=true'):
            self.write_file(os.path.join(self.root, "config.kdl"), line + "\n")
            self.assertTrue(self.backend.persist_info()["included"], line)

    def test_commented_include_does_not_count(self):
        self.write_file(os.path.join(self.root, "config.kdl"), '// include "serpantinum/monitors.kdl"\n')
        self.assertFalse(self.backend.persist_info()["included"])

    def test_our_own_module_is_not_a_user_include(self):
        self.write_file(os.path.join(self.root, "serpantinum", "monitors.kdl"),
                        'include "serpantinum/monitors.kdl"\n')
        self.assertFalse(self.backend.persist_info()["included"])

    def test_nix_managed_config(self):
        store = os.path.join(self.tmp.name, "store")
        os.makedirs(store)
        target = os.path.join(store, "niri-config")
        self.write_file(target, "// nix\n")
        os.symlink(target, os.path.join(self.root, "config.kdl"))
        saved, dt.NIX_STORE = dt.NIX_STORE, store
        try:
            self.assertTrue(self.backend.persist_info()["managed"])
        finally:
            dt.NIX_STORE = saved


class DetectionTests(Base):
    def setUp(self):
        super().setUp()
        for k in ("NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE", "SERPANTINUM_DISPLAY_BACKEND", "WAYLAND_DISPLAY"):
            os.environ.pop(k, None)
        self.procs = []
        self.answers = {}

    def tearDown(self):
        for p in self.procs:
            p.kill()
            p.wait()
        super().tearDown()

    def sleeper(self):
        p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        self.procs.append(p)
        time.sleep(0.2)
        return p.pid

    def sock(self, display, pid, outputs, age=1):
        path = os.path.join(self.tmp.name, "niri.%s.%d.sock" % (display, pid))
        self.write_file(path, "")
        t = time.time() - age
        os.utime(path, (t, t))
        self.answers[path] = outputs
        return path

    def install_niri(self):
        lines = ['case "$NIRI_SOCKET" in']
        for path, names in self.answers.items():
            body = "exit 1" if names is None else "echo '%s'" % json.dumps({n: {"name": n} for n in names})
            lines.append("  %s) %s ;;" % (path, body))
        lines += ["  *) exit 1 ;;", "esac"]
        os.environ["PATH"] = self.make_bin("niri", "\n".join(lines)) + os.pathsep + self.saved["PATH"]

    def test_inside_niri_needs_our_wayland_display(self):
        s = self.sock("wayland-2", os.getpid(), ["winit"])
        os.environ["NIRI_SOCKET"] = s
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        self.assertTrue(dt.NiriBackend.detect())
        os.environ["WAYLAND_DISPLAY"] = "wayland-1"      # a client of ANOTHER compositor
        self.assertFalse(dt.NiriBackend.detect())
        os.environ.pop("WAYLAND_DISPLAY")                # TTY: nothing to compare, trust the variable
        self.assertTrue(dt.NiriBackend.detect())

    def test_sway_and_hyprland_nested_in_niri_are_not_taken_for_niri_hosts(self):
        # a Sway started inside niri inherits NIRI_SOCKET; niri must not claim it.
        s = self.sock("wayland-2", os.getpid(), ["winit"])
        os.environ["NIRI_SOCKET"] = s
        os.environ["WAYLAND_DISPLAY"] = "wayland-9"
        swaysock = os.path.join(self.tmp.name, "sway.sock")
        self.write_file(swaysock, "")
        os.environ["SWAYSOCK"] = swaysock
        self.assertFalse(dt.NiriBackend.detect())
        self.assertTrue(dt.SwayBackend.detect())
        # ...and a sway/Hyprland variable inherited by a process that IS a client of niri is ignored
        os.environ["WAYLAND_DISPLAY"] = "wayland-2"
        self.assertTrue(dt.NiriBackend.detect())
        self.assertFalse(dt.SwayBackend.detect())
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "outer"
        self.assertFalse(dt.HyprlandBackend.detect())
        self.assertEqual(dt.detect_backend().name, "niri")

    def test_real_niri_beats_a_nested_one_from_a_tty(self):
        real = self.sock("wayland-0", self.sleeper(), ["eDP-1"], age=500)
        self.sock("wayland-2", self.sleeper(), ["winit"], age=1)
        self.install_niri()
        self.assertEqual(dt.detect_backend().name, "niri")
        self.assertEqual(os.environ["NIRI_SOCKET"], real)

    def test_dead_socket_is_ignored(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        self.sock("wayland-0", dead.pid, ["eDP-1"])
        alive = self.sock("wayland-1", self.sleeper(), ["DP-1"], age=900)
        self.install_niri()
        dt.detect_backend()
        self.assertEqual(os.environ["NIRI_SOCKET"], alive)

    def test_a_real_niri_beats_a_nested_sway_and_the_reverse(self):
        self.sock("wayland-0", self.sleeper(), ["eDP-1"], age=900)
        swaysock = os.path.join(self.tmp.name, "sway-ipc.%d.%d.sock" % (os.getuid(), self.sleeper()))
        self.write_file(swaysock, "")
        self.make_bin("swaymsg", 'echo \'[{"name": "HEADLESS-1"}]\'')
        self.install_niri()
        os.environ["PATH"] = os.path.join(self.tmp.name, "bin") + os.pathsep + self.saved["PATH"]
        self.assertEqual(dt.detect_backend().name, "niri")

    def test_nothing_running_is_unsupported(self):
        self.install_niri()
        with self.assertRaises(dt.DisplayError):
            dt.detect_backend()

    def test_reverter_is_told_the_niri_socket(self):
        dt.spawn_watcher = self.saved_spawn
        os.environ["NIRI_SOCKET"] = "/x/niri.wayland-2.1.sock"
        os.environ["SERPANTINUM_DISPLAY_NO_SYSTEMD"] = "1"
        seen = {}
        popen = subprocess.Popen

        def fake(args, **kw):
            seen["env"] = dict(os.environ)
            return type("P", (), {})()
        subprocess.Popen = fake
        try:
            dt.spawn_watcher("abcdef123456", "niri")
        finally:
            subprocess.Popen = popen
            os.environ.pop("SERPANTINUM_DISPLAY_NO_SYSTEMD", None)
        self.assertEqual(seen["env"]["SERPANTINUM_DISPLAY_BACKEND"], "niri")


if __name__ == "__main__":
    unittest.main()
