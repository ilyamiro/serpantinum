#!/usr/bin/env python3
import importlib.util
import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
TUI_PATH = REPO / "install" / "tui.py"
I18N_DIR = REPO / "src" / "assets" / "languages"

spec = importlib.util.spec_from_file_location("serp_tui", TUI_PATH)
tui = importlib.util.module_from_spec(spec)
sys.modules["serp_tui"] = tui
spec.loader.exec_module(tui)


class FakeTerminal:
    def __init__(self, cols=110, rows=36, keys=None):
        self.cols = cols
        self.rows = rows
        self.keys = list(keys or [])
        self.frames = []
        self.resized = False
        self.entered = False
        self.left = False

    def enter(self):
        self.entered = True

    def leave(self):
        self.left = True

    def render_lines(self, lines):
        self.frames.append(lines)

    def read_key(self, timeout=0.05):
        if self.keys:
            return self.keys.pop(0)
        return None


class RenderAndAlignmentTests(unittest.TestCase):
    def make_app(self, cols=110, rows=36, state_mode="current", auth_demo=False, lang="en"):
        state = tui.build_preview_state(str(REPO), state_mode, auth_demo)
        i18n = tui.I18n(str(I18N_DIR), lang_override=lang)
        term = FakeTerminal(cols=cols, rows=rows)
        return tui.InstallerTUI(state, i18n, term=term)

    def assert_frame_fits(self, lines, cols, rows):
        self.assertLessEqual(len(lines), rows)
        for idx, ln in enumerate(lines):
            w = tui.display_width(ln)
            self.assertLessEqual(w, cols, f"Line {idx} overflowed {cols} cols (width={w}): {tui.strip_ansi(ln)!r}")

    def test_all_screens_fit_across_terminal_sizes(self):
        sizes = [(120, 40), (100, 32), (84, 26), (80, 24), (66, 20), (50, 14)]
        screens = ["main", "packages", "compositors", "sddm", "uninstall_confirm", "auth", "progress", "complete"]
        for cols, rows in sizes:
            app = self.make_app(cols=cols, rows=rows)
            app.steps = app.build_steps("update")
            app.steps[0].status = "done"
            app.steps[0].duration = 0.4
            app.steps[1].status = "running"
            app.steps[1].sub_ratio = 0.55
            app.steps[1].sub_text = "quickshell (4/7)"
            app.active_step_idx = 1
            app.run_started_at = time.monotonic() - 12.0
            app.log_lines.append(":: Installing quickshell...")
            app.log_lines.append("[ OK ] Successfully installed matugen")
            for screen in screens:
                app.screen = screen
                app.draw()
                self.assert_frame_fits(app.term.frames[-1], cols, rows)

    def test_box_borders_align_perfectly(self):
        app = self.make_app(cols=110, rows=36)
        for screen in ("main", "packages", "compositors", "sddm", "uninstall_confirm", "auth", "complete"):
            app.screen = screen
            app.draw()
            frame = app.term.frames[-1]
            box_lines = [tui.strip_ansi(ln) for ln in frame if "╭" in ln or "│" in ln or "├" in ln or "╰" in ln]
            self.assertGreater(len(box_lines), 3, screen)
            widths = {tui.display_width(ln) for ln in box_lines}
            self.assertEqual(len(widths), 1, f"{screen} misaligned box widths: {widths}")

    def test_multilingual_rendering_fits(self):
        for lang in ("en", "ru", "ua", "de", "ja", "zh"):
            app = self.make_app(cols=100, rows=32, lang=lang)
            for screen in ("main", "packages", "compositors", "sddm", "uninstall_confirm", "complete"):
                app.screen = screen
                app.draw()
                self.assert_frame_fits(app.term.frames[-1], 100, 32)

    def test_all_logo_tiers_render_and_clear_cleanly(self):
        for mode in ("kitty", "sixel", "braille", "blocks"):
            state = tui.build_preview_state(str(REPO), "current", False)
            i18n = tui.I18n(str(I18N_DIR), lang_override="en")
            term = FakeTerminal(cols=104, rows=34)
            term.graphics_proto = mode
            term.cell_w = 9
            term.cell_h = 18
            graphics_seen = []

            def capture(lines, graphic=None, _t=term, _seen=graphics_seen):
                _t.frames.append(lines)
                _seen.append(graphic)

            term.render_lines = capture
            app = tui.InstallerTUI(state, i18n, term=term, logo_mode=mode)
            for screen in ("main", "packages", "complete"):
                app.screen = screen
                app.draw()
                self.assert_frame_fits(term.frames[-1], 104, 34)
            if mode in ("kitty", "sixel"):
                self.assertEqual(graphics_seen[0][0], mode)
                self.assertIsNone(graphics_seen[1])
                self.assertEqual(graphics_seen[2][0], mode)
            else:
                self.assertEqual(graphics_seen, [None, None, None])


class InteractionAndPreviewSafetyTests(unittest.TestCase):
    def test_navigation_and_toggles(self):
        state = tui.build_preview_state(str(REPO), "current", False)
        i18n = tui.I18n(str(I18N_DIR), lang_override="en")
        term = FakeTerminal(cols=110, rows=36)
        app = tui.InstallerTUI(state, i18n, term=term)

        self.assertTrue(app.state.install_full_wallpapers)
        app.handle_main_key("DOWN")
        app.handle_main_key("DOWN")
        app.handle_main_key("DOWN")
        self.assertEqual(app.main_config_idx, 3)
        app.handle_main_key("RIGHT")
        self.assertFalse(app.state.install_full_wallpapers)

        app.handle_main_key("DOWN")
        self.assertEqual(app.main_config_idx, 4)
        app.handle_main_key("LEFT")
        self.assertFalse(app.state.enable_telemetry)

        app.handle_main_key("DOWN")
        self.assertEqual(app.main_focus_section, "actions")
        app.handle_main_key("RIGHT")
        self.assertEqual(app.main_action_idx, 1)

        app.handle_main_key("1")
        self.assertEqual(app.screen, "packages")
        app.handle_packages_key("RIGHT")
        self.assertEqual(app.pkg_tab, 1)
        app.handle_packages_key("/")
        for ch in "quick":
            app.handle_packages_key(ch)
        self.assertEqual([p for p, _ in app.filtered_packages()], ["quickshell"])
        app.handle_packages_key("ESC")
        app.handle_packages_key("ESC")
        app.handle_packages_key("ESC")
        self.assertEqual(app.screen, "main")

        app.handle_main_key("2")
        self.assertEqual(app.screen, "compositors")
        app.handle_compositors_key("2")
        self.assertIn("niri", app.state.selected_compositors)
        app.handle_compositors_key("ESC")
        self.assertEqual(app.screen, "main")

        app.handle_main_key("3")
        self.assertEqual(app.screen, "sddm")
        orig_sddm = app.state.opt_sddm
        app.handle_sddm_key("SPACE")
        self.assertEqual(app.state.opt_sddm, not orig_sddm)
        app.handle_sddm_key("ESC")
        self.assertEqual(app.screen, "main")

    def test_preview_executes_zero_subprocesses_for_install_and_uninstall(self):
        for mode in ("update", "reinstall", "uninstall"):
            state = tui.build_preview_state(str(REPO), "current", False)
            i18n = tui.I18n(str(I18N_DIR), lang_override="en")
            term = FakeTerminal(cols=110, rows=36, keys=["f"] * 40)
            app = tui.InstallerTUI(state, i18n, term=term)
            with mock.patch("subprocess.run", side_effect=AssertionError("subprocess.run called in preview")), \
                 mock.patch("subprocess.Popen", side_effect=AssertionError("subprocess.Popen called in preview")):
                app.begin_action(mode)
            self.assertEqual(app.screen, "complete")
            self.assertTrue(all(s.status in ("done", "skipped") for s in app.steps))
            app.handle_complete_key("y")
            self.assertEqual(app.state.action_result, "exit")
            if mode != "uninstall":
                self.assertIn("Preview", app.toast_text)

    def test_no_compositor_blocks_install_with_toast(self):
        state = tui.build_preview_state(str(REPO), "fresh", False)
        state.selected_compositors = []
        i18n = tui.I18n(str(I18N_DIR), lang_override="en")
        term = FakeTerminal(cols=110, rows=36)
        app = tui.InstallerTUI(state, i18n, term=term)
        app.begin_action("install")
        self.assertEqual(app.screen, "main")
        self.assertEqual(app.main_config_idx, 1)
        self.assertEqual(app.toast_kind, "error")

    def test_preview_launcher_pty_smoke(self):
        import fcntl, struct, termios
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 34, 104, 0, 0))
        proc = subprocess.Popen(
            [sys.executable, str(TUI_PATH), "--preview", "--state", "current"],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor"),
            close_fds=True,
        )
        os.close(slave)
        output = bytearray()
        def drain(duration=0.15):
            end = time.monotonic() + duration
            while time.monotonic() < end:
                ready, _, _ = select.select([master], [], [], 0.03)
                if ready:
                    try:
                        chunk = os.read(master, 8192)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output.extend(chunk)
        try:
            drain(0.5)
            os.write(master, b"1")
            drain(0.2)
            os.write(master, b"\x1b")
            drain(0.2)
            os.write(master, b"q")
            drain(0.4)
            proc.wait(timeout=3.0)
        finally:
            os.close(master)
        self.assertEqual(proc.returncode, 0)
        text = tui.strip_ansi(output.decode("utf-8", errors="replace"))
        self.assertIn("Preview", text)
        self.assertIn("Configuration", text)
        self.assertIn("Package installation overview", text)

    def test_real_step_answers_sudo_prompt_with_verified_password(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "step_runner.sh").write_text(
                'for i in 1 2; do printf %s "$SUDO_PROMPT"; sleep 0.3; read -rs pw; echo; [ "$pw" = hunter2 ] || exit 1; done; echo AUTH_OK\n'
            )
            app = RenderAndAlignmentTests.make_app(self)
            app.state.modules_dir = tmp
            app.sudo_password = "hunter2"
            r, w = os.pipe()
            app.term.in_fd = r
            try:
                rc = app._run_real_step(tui.StepItem("deps", "deps"))
            finally:
                os.close(r)
                os.close(w)
            self.assertEqual(rc, 0)
            self.assertIn("AUTH_OK", app.log_lines)
            self.assertFalse(any("hunter2" in ln or tui.SUDO_PROMPT_MARKER.strip() in ln for ln in app.log_lines))

    def test_real_step_logs_lines_printed_while_running(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "step_runner.sh").write_text(
                "echo first line; sleep 0.3; printf '50%% (1/2)\\r'; sleep 0.3; printf '100%% (2/2)\\r'; sleep 0.3; echo second line; sleep 0.3\n"
            )
            app = RenderAndAlignmentTests.make_app(self)
            app.state.modules_dir = tmp
            r, w = os.pipe()
            app.term.in_fd = r
            step = tui.StepItem("wallpapers", "wallpapers")
            try:
                rc = app._run_real_step(step)
            finally:
                os.close(r)
                os.close(w)
            self.assertEqual(rc, 0)
            self.assertEqual([ln for ln in app.log_lines if "line" in ln or "%" in ln], ["first line", "second line"])
            self.assertEqual(step.sub_ratio, 1.0)

    def test_password_prompt_input_is_masked(self):
        app = RenderAndAlignmentTests.make_app(self)
        app.screen = "progress"
        app.waiting_input = True
        app.input_masked = True
        app.input_buffer = "hunter2"
        frame = "\n".join(tui.strip_ansi(ln) for ln in app.render_progress_screen())
        self.assertNotIn("hunter2", frame)
        self.assertIn("•" * 7, frame)

    def test_json_translations_valid(self):
        data = json.loads((I18N_DIR / "en.json").read_text(encoding="utf-8"))
        self.assertIn("installer", data)
        self.assertIn("steps", data["installer"])
        self.assertIn("section_config", data["installer"]["ui"])


if __name__ == "__main__":
    unittest.main()
