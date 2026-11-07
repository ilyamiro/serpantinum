"""Offline tests for the Sway backend of display_txn.py (no compositor needed).

The headless fixture is real `swaymsg -t get_outputs -r` output (sway 1.12). A real laptop
panel cannot be captured from a nested sway, so the hardware outputs are built by hand with
the same keys.

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
spec = importlib.util.spec_from_file_location("display_txn_sway", SCRIPT)
dt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dt)
dt.VERIFY_DELAY = 0.001
dt.POLL_INTERVAL = 0.01

with open(os.path.join(HERE, "fixtures", "sway_headless_outputs.json")) as f:
    HEADLESS = json.load(f)


def hw_output(name, make, model, serial, w, h, hz, x, y, modes, active=True, scale=1.0,
              transform="normal"):
    """The keys sway really emits; modes are (w, h, mHz). A disabled output has no current_mode."""
    out = {"name": name, "make": make, "model": model, "serial": serial, "active": active,
           "power": active, "focused": False, "non_desktop": False,
           "modes": [{"width": mw, "height": mh, "refresh": mr, "picture_aspect_ratio": "16:9"}
                     for mw, mh, mr in modes],
           "rect": {"x": x if active else 0, "y": y if active else 0,
                    "width": w if active else 0, "height": h if active else 0}}
    if active:
        out.update(scale=scale, transform=transform,
                   current_mode={"width": w, "height": h, "refresh": hz})
    return out


def laptop_and_dell():
    return [
        hw_output("eDP-1", "AU Optronics", "B156HAN15.H", "0x00000000", 1920, 1080, 60061, 0, 0,
                  [(1920, 1080, 60061), (1920, 1080, 144061)]),
        hw_output("HDMI-A-1", "Dell Inc.", "Inspiron 3043", "0x00000001", 1920, 1080, 60000, 1920, 0,
                  [(1920, 1080, 60000), (1280, 720, 60000)]),
    ]


class FakeSway:
    """Simulates swaymsg: get_outputs and the `output ...` commands."""

    def __init__(self, outputs):
        self.outputs = {o["name"]: o for o in outputs}
        self.calls = []
        self.fail = None

    def __call__(self, args, timeout=5):
        self.calls.append(args)
        if args[:4] == ["swaymsg", "-r", "-t", "get_outputs"]:
            return 0, json.dumps(list(self.outputs.values())), ""
        if args[:3] == ["swaymsg", "-r", "--"]:
            results = []
            for cmd in args[3].split(";"):
                results.append(self._output(cmd.split()))
            return 0, json.dumps(results), ""
        return 1, "", "unexpected"

    def _output(self, words):
        if self.fail:
            return {"success": False, "error": self.fail}
        o = self.outputs.get(words[1])
        if o is None:
            return {"success": False, "error": "Cannot apply to unknown output"}
        if words[2] == "disable":
            for k in ("current_mode", "scale", "transform"):
                o.pop(k, None)
            o.update(active=False, power=False, rect={"x": 0, "y": 0, "width": 0, "height": 0})
            return {"success": True}
        i = 3
        w = h = hz = x = y = scale = transform = None
        while i < len(words):
            key = words[i]
            if key == "mode":
                i += 1
                if words[i] == "--custom":
                    i += 1
                res, _, rate = words[i].partition("@")
                w, h = (int(v) for v in res.split("x"))
                hz = int(round(float(rate[:-2]) * 1000))
            elif key == "position":
                x, y = int(words[i + 1]), int(words[i + 2])
                i += 2
            elif key == "scale":
                scale = float(words[i + 1])
                i += 1
            elif key == "transform":
                transform = words[i + 1]
                i += 1
            i += 1
        scale = scale if scale is not None else 1.0
        sideways = transform in ("90", "270", "flipped-90", "flipped-270")
        lw, lh = (h, w) if sideways else (w, h)
        o.update(active=True, power=True, scale=scale, transform=transform,
                 current_mode={"width": w, "height": h, "refresh": hz},
                 rect={"x": x, "y": y, "width": int(lw / scale), "height": int(lh / scale)})
        return {"success": True}


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.saved = {k: os.environ.get(k) for k in (
            "XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "SWAYSOCK",
            "HYPRLAND_INSTANCE_SIGNATURE", "SERPANTINUM_DISPLAY_BACKEND", "PATH")}
        os.environ["XDG_RUNTIME_DIR"] = self.tmp.name
        os.environ["XDG_STATE_HOME"] = self.tmp.name
        os.environ["XDG_CONFIG_HOME"] = self.tmp.name
        self.sway = FakeSway(laptop_and_dell())
        self.backend = dt.SwayBackend(runner=self.sway)
        self.spawned = []
        self.saved_spawn = dt.spawn_watcher
        dt.spawn_watcher = lambda txn_id, backend_name=None: self.spawned.append(txn_id) or "test"

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
        with open(path, "w") as f:
            f.write(text)

    def make_bin(self, name, body):
        d = os.path.join(self.tmp.name, "bin")
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name)
        with open(path, "w") as f:
            f.write("#!/bin/sh\n%s\n" % body)
        os.chmod(path, 0o755)
        return d


class StateTests(Base):
    def test_hardware_output_is_normalised(self):
        m = next(m for m in self.backend.state()["monitors"] if m["name"] == "eDP-1")
        self.assertEqual((m["width"], m["height"], m["refresh"]), (1920, 1080, 60.061))
        self.assertEqual(m["description"], "AU Optronics B156HAN15.H 0x00000000")
        self.assertEqual(m["modes"], [[1920, 1080, 60.061], [1920, 1080, 144.061]])
        self.assertTrue(m["enabled"])
        self.assertEqual((m["x"], m["y"], m["scale"], m["transform"]), (0, 0, 1.0, 0))

    def test_transform_strings_map_to_the_shared_numbering(self):
        for i, name in enumerate(dt.SWAY_TRANSFORMS):
            self.sway.outputs["eDP-1"]["transform"] = name
            m = next(m for m in self.backend.state()["monitors"] if m["name"] == "eDP-1")
            self.assertEqual(m["transform"], i)

    def test_disabled_output_keeps_a_usable_mode(self):
        self.sway.outputs["HDMI-A-1"] = hw_output("HDMI-A-1", "Dell Inc.", "Inspiron 3043", "0x00000001",
                                                  0, 0, 0, 0, 0, [(1280, 720, 60000), (1920, 1080, 60000)],
                                                  active=False)
        m = next(m for m in self.backend.state()["monitors"] if m["name"] == "HDMI-A-1")
        self.assertFalse(m["enabled"])
        self.assertEqual((m["width"], m["height"], m["refresh"]), (1920, 1080, 60.0))
        # ...so switching it back on validates
        self.assertEqual(dt.validate(self.plan(**{"HDMI-A-1": {"enabled": True, "x": 1920}}),
                                     self.backend.state())[0], [])

    def test_real_headless_json(self):
        backend = dt.SwayBackend(runner=FakeSway(HEADLESS))
        st = backend.state()
        self.assertEqual(st["backend"], "sway")
        for m in st["monitors"]:
            self.assertEqual(m["description"], "")          # "Unknown Unknown Unknown" is no identity
            self.assertTrue(m["modes"])                      # virtual outputs list none: synthesised
            if m["enabled"]:
                self.assertIn([m["width"], m["height"], m["refresh"]], m["modes"])
                self.assertGreater(m["refresh"], 0)
        self.assertEqual(backend._custom, {"HEADLESS-1", "HEADLESS-2", "HEADLESS-3"})

    def test_non_desktop_outputs_are_ignored(self):
        self.sway.outputs["DP-9"] = dict(hw_output("DP-9", "Valve", "Index", "1", 1920, 1080, 90000, 0, 0,
                                                   [(1920, 1080, 90000)]), non_desktop=True)
        self.assertNotIn("DP-9", [m["name"] for m in self.backend.state()["monitors"]])


class ScaleTests(Base):
    def test_fractional_and_existing_scales_are_accepted(self):
        for s in (0.5, 1.0, 1.1, 1.25, 1.5, 3.0):
            self.assertTrue(dt.SwayBackend.accepts_scale(s, 1920, 1080), s)

    def test_nonsense_scales_are_rejected(self):
        for s in (0.0, -1.0, 10.0, float("nan"), float("inf")):
            self.assertFalse(dt.SwayBackend.accepts_scale(s, 1920, 1080), s)

    def test_validate_uses_it_for_sway_state(self):
        st = self.backend.state()
        ok = self.plan(**{"eDP-1": {"scale": 1.1}})
        self.assertEqual(dt.validate(ok, st)[0], [])
        bad = self.plan(**{"eDP-1": {"scale": 99.0}})
        self.assertTrue(any("scale_invalid" in e for e in dt.validate(bad, st)[0]))


class ApplyTests(Base):
    def test_enable_first_disable_last_in_one_command(self):
        plan = self.plan(**{"eDP-1": {"enabled": False}, "HDMI-A-1": {"x": 0}})
        self.backend.apply(plan)
        script = self.sway.calls[-1][3]
        self.assertEqual(self.sway.calls[-1][:3], ["swaymsg", "-r", "--"])
        self.assertLess(script.index("output HDMI-A-1 enable"), script.index("output eDP-1 disable"))

    def test_command_carries_every_field(self):
        self.backend.apply(self.plan(**{"HDMI-A-1": {"width": 1280, "height": 720, "x": 10, "y": 20,
                                                     "scale": 1.5, "transform": 5}}))
        script = self.sway.calls[-1][3]
        self.assertIn("output HDMI-A-1 enable mode 1280x720@60.000Hz position 10 20 scale 1.5 "
                      "transform flipped-90", script)
        self.assertNotIn("--custom", script)

    def test_virtual_outputs_use_custom_modes(self):
        backend = dt.SwayBackend(runner=FakeSway(HEADLESS))
        backend.apply(dt.plan_from_state(backend.state()))
        self.assertIn("mode --custom", backend.run.calls[-1][3])

    def test_failed_command_raises(self):
        self.sway.fail = "Invalid mode"
        with self.assertRaises(dt.DisplayError) as cm:
            self.backend.apply(self.plan())
        self.assertIn("Invalid mode", str(cm.exception))

    def test_unsafe_output_names_never_reach_swaymsg(self):
        plan = self.plan()
        plan["monitors"][0]["name"] = 'x"; exec rm -rf ~'
        with self.assertRaises(dt.DisplayError):
            self.backend.apply(plan)
        self.assertFalse(any(c[:3] == ["swaymsg", "-r", "--"] for c in self.sway.calls))

    def test_full_transaction_confirm_and_revert(self):
        before = self.backend.state()
        r = dt.cmd_apply(self.backend, self.plan(**{"HDMI-A-1": {"x": 0, "y": 1080}}), 15)
        self.assertTrue(r["ok"], r)
        moved = {m["name"]: m for m in self.backend.state()["monitors"]}["HDMI-A-1"]
        self.assertEqual((moved["x"], moved["y"]), (0, 1080))
        self.assertEqual(dt.finish(self.backend, r["id"], "revert", reason="requested"), "restored")
        after = {m["name"]: m for m in self.backend.state()["monitors"]}
        for m in before["monitors"]:
            self.assertEqual((after[m["name"]]["x"], after[m["name"]]["y"]), (m["x"], m["y"]))


class RestoreTargetTests(Base):
    def snapshot(self, backend_name, names):
        return {"backend": backend_name,
                "monitors": [{"name": n, "description": "", "enabled": True, "width": 1920, "height": 1080,
                              "refresh": 60.0, "x": 0, "y": 0, "scale": 1.0, "transform": 0,
                              "modes": [[1920, 1080, 60.0]]} for n in names]}

    def test_restore_refuses_a_compositor_that_is_not_the_snapshots(self):
        calls = len(self.sway.calls)
        out = dt.restore(self.backend, self.snapshot("hyprland", ["eDP-1"]))
        self.assertEqual(out, "failed")
        self.assertFalse(any(c[:3] == ["swaymsg", "-r", "--"] for c in self.sway.calls[calls:]))

    def test_restore_refuses_when_no_output_matches(self):
        out = dt.restore(self.backend, self.snapshot("sway", ["HEADLESS-9"]))
        self.assertEqual(out, "failed")
        self.assertFalse(any(c[:3] == ["swaymsg", "-r", "--"] for c in self.sway.calls))

    def test_restore_with_a_missing_output_still_works(self):
        out = dt.restore(self.backend, self.snapshot("sway", ["eDP-1", "DP-3-gone"]))
        # DP-3-gone does not exist: the apply fails, but the safe layout of what exists is used
        self.assertIn(out, ("safe_layout", "restored", "failed"))
        self.assertTrue(any(c[:3] == ["swaymsg", "-r", "--"] for c in self.sway.calls))


class PersistenceTests(Base):
    def rendered(self, state=None):
        return self.backend.persist_render(state or self.backend.state())

    def test_blocks_use_make_model_serial(self):
        text = self.rendered()
        self.assertIn('output "Dell Inc. Inspiron 3043 0x00000001" {', text)
        self.assertIn("    mode 1920x1080@60.000Hz\n    position 1920 0\n    scale 1.0\n    transform normal", text)
        self.assertIn("include ~/.config/sway/serpantinum/monitors", text)

    def test_disabled_outputs_are_not_saved(self):
        st = self.backend.state()
        next(m for m in st["monitors"] if m["name"] == "eDP-1")["enabled"] = False
        text = self.rendered(st)
        self.assertNotIn("AU Optronics", text)
        self.assertIn("Dell Inc.", text)

    def test_identical_panels_fall_back_to_the_connector(self):
        self.sway.outputs["eDP-1"].update(make="Dell Inc.", model="Inspiron 3043", serial="0x00000001")
        text = self.rendered()
        self.assertIn('output "eDP-1" {', text)
        self.assertIn('output "HDMI-A-1" {', text)
        self.assertNotIn("Inspiron", text.replace("# Dell Inc. Inspiron 3043 0x00000001", ""))

    def test_headless_outputs_are_saved_by_name(self):
        backend = dt.SwayBackend(runner=FakeSway(HEADLESS))
        self.assertIn('output "HEADLESS-1" {', backend.persist_render(backend.state()))

    def test_a_description_with_quotes_or_braces_cannot_inject_config(self):
        self.sway.outputs["eDP-1"]["model"] = 'X" { } \nexec evil'
        text = self.rendered()
        self.assertNotIn("exec evil\n", text.replace("# ", "#"))
        self.assertIn('output "eDP-1" {', text)

    def test_flipped_transform_is_written_in_sway_syntax(self):
        st = self.backend.state()
        next(m for m in st["monitors"] if m["name"] == "eDP-1")["transform"] = 7
        self.assertIn("transform flipped-270", self.rendered(st))

    def test_persist_writes_file_and_keeps_a_backup(self):
        os.environ["PATH"] = self.make_bin("sway", "exit 0")
        path = self.backend.persist(self.backend.state())
        self.assertEqual(path, os.path.join(self.tmp.name, "sway", "serpantinum", "monitors"))
        self.backend.persist(self.backend.state())
        self.assertTrue(os.path.exists(path + ".bak"))

    def test_a_file_sway_rejects_is_refused_and_the_old_one_kept(self):
        os.environ["PATH"] = self.make_bin("sway", "exit 0")
        path = self.backend.persist(self.backend.state())
        good = self.read(path)
        os.environ["PATH"] = self.make_bin("sway", 'echo "[ERROR] bad" >&2; exit 1')
        st = self.backend.state()
        next(m for m in st["monitors"] if m["name"] == "eDP-1")["x"] = 5
        with self.assertRaises(dt.DisplayError):
            self.backend.persist(st)
        self.assertEqual(self.read(path), good)
        self.assertEqual([f for f in os.listdir(os.path.dirname(path)) if f.endswith(".tmp")], [])

    def test_validation_passes_the_file_to_sway_validate(self):
        log = os.path.join(self.tmp.name, "args")
        os.environ["PATH"] = self.make_bin("sway", 'echo "$@" > %s; exit 0' % log)
        self.backend.persist(self.backend.state())
        self.assertTrue(self.read(log).startswith("--validate -c "))

    def test_missing_sway_binary_skips_verification(self):
        os.environ["PATH"] = os.path.join(self.tmp.name, "empty")
        self.assertIsNone(dt.find_sway_binary())
        self.assertTrue(dt.verify_sway(__file__))


class PersistInfoTests(Base):
    def setUp(self):
        super().setUp()
        self.root = os.path.join(self.tmp.name, "sway")
        os.makedirs(self.root)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def test_nothing_configured(self):
        info = self.backend.persist_info()
        self.assertEqual((info["exists"], info["included"], info["managed"]), (False, False, False))
        self.assertTrue(info["writable"])

    def test_include_line_is_detected(self):
        self.write("config", "set $mod Mod4\ninclude ~/.config/sway/serpantinum/monitors\n")
        self.assertTrue(self.backend.persist_info()["included"])

    def test_include_in_config_d_is_detected(self):
        self.write("config.d/outputs.conf", "include $HOME/.config/sway/serpantinum/monitors\n")
        self.assertTrue(self.backend.persist_info()["included"])

    def test_commented_include_does_not_count(self):
        self.write("config", "# include ~/.config/sway/serpantinum/monitors\n")
        self.assertFalse(self.backend.persist_info()["included"])

    def test_our_own_module_is_not_a_user_include(self):
        self.write("serpantinum/monitors", "# include ~/.config/sway/serpantinum/monitors\ninclude serpantinum/monitors\n")
        self.assertFalse(self.backend.persist_info()["included"])

    def test_nix_managed_config_is_reported(self):
        store = os.path.join(self.tmp.name, "store")
        os.makedirs(store)
        target = os.path.join(store, "sway-config")
        self.write_file(target, "# nix\n")
        os.symlink(target, os.path.join(self.root, "config"))
        saved = dt.NIX_STORE
        dt.NIX_STORE = store
        try:
            self.assertTrue(self.backend.persist_info()["managed"])
        finally:
            dt.NIX_STORE = saved


class DiscoveryTests(Base):
    """TTY rescue / reverter: sockets $XDG_RUNTIME_DIR/sway-ipc.<uid>.<pid>.sock."""

    def setUp(self):
        super().setUp()
        os.environ.pop("SWAYSOCK", None)
        os.environ.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        os.environ.pop("SERPANTINUM_DISPLAY_BACKEND", None)
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

    def sock(self, pid, outputs, age=1):
        path = os.path.join(self.tmp.name, "sway-ipc.%d.%d.sock" % (os.getuid(), pid))
        open(path, "w").close()
        t = time.time() - age
        os.utime(path, (t, t))
        self.answers[path] = outputs
        return path

    def install_swaymsg(self):
        lines = ["#!/bin/sh", 'case "$SWAYSOCK" in']
        for path, names in self.answers.items():
            body = "exit 1" if names is None else "echo '%s'" % json.dumps([{"name": n} for n in names])
            lines.append("  %s) %s ;;" % (path, body))
        lines += ["  *) exit 1 ;;", "esac"]
        os.environ["PATH"] = self.make_bin("swaymsg", "\n".join(lines[1:])) + os.pathsep + self.saved["PATH"]

    def detect(self):
        self.install_swaymsg()
        return dt.detect_backend()

    def test_real_session_beats_a_newer_headless_one(self):
        real = self.sock(self.sleeper(), ["eDP-1"], age=500)
        self.sock(self.sleeper(), ["HEADLESS-1"], age=1)
        backend = self.detect()
        self.assertEqual(backend.name, "sway")
        self.assertEqual(os.environ["SWAYSOCK"], real)

    def test_dead_socket_is_ignored(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        self.sock(dead.pid, ["eDP-1"], age=1)
        alive = self.sock(self.sleeper(), ["DP-1"], age=900)
        self.detect()
        self.assertEqual(os.environ["SWAYSOCK"], alive)

    def test_sockets_of_other_users_are_ignored(self):
        path = os.path.join(self.tmp.name, "sway-ipc.%d.%d.sock" % (os.getuid() + 1, self.sleeper()))
        open(path, "w").close()
        self.install_swaymsg()
        with self.assertRaises(dt.DisplayError):
            dt.detect_backend()

    def test_nothing_running_is_unsupported(self):
        self.install_swaymsg()
        with self.assertRaises(dt.DisplayError):
            dt.detect_backend()

    def test_stale_swaysock_in_the_environment_falls_through_to_discovery(self):
        os.environ["SWAYSOCK"] = os.path.join(self.tmp.name, "gone.sock")
        live = self.sock(self.sleeper(), ["eDP-1"])
        self.detect()
        self.assertEqual(os.environ["SWAYSOCK"], live)

    def test_a_real_sway_beats_a_nested_hyprland(self):
        # The reverse mistake would repair a test window instead of the user's screens.
        hypr = os.path.join(self.tmp.name, "hypr", "nested")
        os.makedirs(hypr)
        open(os.path.join(hypr, ".socket.sock"), "w").close()
        self.write_file(os.path.join(hypr, "hyprland.lock"), "%d\n" % self.sleeper())
        live = self.sock(self.sleeper(), ["eDP-1"], age=900)
        self.answers_hypr = ["WAYLAND-1"]
        self.make_bin("hyprctl", "echo '[{\"name\": \"WAYLAND-1\"}]'")
        self.install_swaymsg()
        os.environ["PATH"] = os.path.join(self.tmp.name, "bin") + os.pathsep + self.saved["PATH"]
        backend = dt.detect_backend()
        self.assertEqual(backend.name, "sway")
        self.assertEqual(os.environ["SWAYSOCK"], live)

    def test_a_real_hyprland_beats_a_nested_sway(self):
        hypr = os.path.join(self.tmp.name, "hypr", "real")
        os.makedirs(hypr)
        open(os.path.join(hypr, ".socket.sock"), "w").close()
        self.write_file(os.path.join(hypr, "hyprland.lock"), "%d\n" % self.sleeper())
        self.sock(self.sleeper(), ["HEADLESS-1"], age=1)
        self.make_bin("hyprctl", "echo '[{\"name\": \"eDP-1\"}]'")
        self.install_swaymsg()
        backend = dt.detect_backend()
        self.assertEqual(backend.name, "hyprland")

    def test_forced_backend_ignores_the_other_compositors_variables(self):
        # systemd --user managers carry the variables of a different session: the reverter
        # is told which backend it serves and must not follow those.
        live = self.sock(self.sleeper(), ["eDP-1"])
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "someone-elses-session"
        os.environ["SWAYSOCK"] = live
        os.environ["SERPANTINUM_DISPLAY_BACKEND"] = "sway"
        self.assertEqual(dt.detect_backend().name, "sway")

    def test_spawn_names_the_backend_for_the_reverter(self):
        dt.spawn_watcher = self.saved_spawn
        os.environ["SERPANTINUM_DISPLAY_NO_SYSTEMD"] = "1"
        popen = subprocess.Popen
        seen = {}

        def fake_popen(args, **kw):
            seen["env"] = dict(os.environ)
            return type("P", (), {})()
        subprocess.Popen = fake_popen
        try:
            dt.spawn_watcher("abcdef123456", "sway")
        finally:
            subprocess.Popen = popen
            os.environ.pop("SERPANTINUM_DISPLAY_NO_SYSTEMD", None)
        self.assertEqual(seen["env"]["SERPANTINUM_DISPLAY_BACKEND"], "sway")


if __name__ == "__main__":
    unittest.main()
