#!/usr/bin/env python3
import importlib.util
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import time
import tomllib
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ENGINE = REPO / "src" / "scripts" / "theming" / "apptheme.py"
BUILTIN = REPO / "src" / "assets" / "matugen" / "apps"
MATUGEN_QML = REPO / "src" / "quickshell" / "singletons" / "theme" / "Matugen.qml"
THEMES = REPO / "src" / "assets" / "themes"
REAL_MATUGEN = shutil.which("matugen")
REAL_BASH = shutil.which("bash")
REAL_NODE = shutil.which("node")
CORE_TOOLS = ["bash", "sh", "env", "cat", "mkdir", "basename", "dirname", "touch", "timeout", "sleep", "cp", "mv", "rm", "printf", "true"]

spec = importlib.util.spec_from_file_location("apptheme", ENGINE)
apptheme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apptheme)
apptheme.EXTRA_BIN_DIRS = ()

ALL_BUILTIN = sorted(p.name for p in BUILTIN.iterdir() if (p / "app.json").is_file())
FAKE_BINS = ["kitty", "cava", "qt6ct", "qt5ct", "dolphin", "alacritty", "foot", "ghostty", "wezterm", "konsole", "hx",
             "nvim", "zed", "btop", "fastfetch", "tmux", "zellij", "zathura", "fuzzel", "rofi", "spicetify", "pywalfox",
             "vim", "kak", "micro", "subl", "gnome-text-editor", "rio", "tilix", "xfce4-terminal", "warp-terminal",
             "fish", "bat", "wofi", "yazi", "lazygit", "starship", "fzf", "lsd", "spf", "glow", "fcitx5", "vicinae",
             "walker", "opencode", "claude", "codex", "halloy", "code", "obs", "telegram-desktop", "emacs", "obsidian",
             "thunderbird", "zen-browser", "prismlauncher", "speedcrunch", "atuin", "aerc", "k9s", "spotify_player", "firefox"]

GSETTINGS_STUB = """#!/usr/bin/env bash
db="$STUB_STATE/gsettings"
mkdir -p "$db"
echo "gsettings $*" >> "$STUB_STATE/calls.log"
f="$db/$2.$3"
case "$1" in
  get) if [ -f "$f" ]; then cat "$f"; else echo "'default'"; fi ;;
  set) printf '%s\\n' "$4" > "$f" ;;
  list-schemas) echo org.gnome.desktop.interface ;;
esac
"""

LOG_STUB = """#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$STUB_STATE/calls.log"
[ "$(basename "$0")" = tmux ] && [ "$1" = has-session ] && exit 1
exit 0
"""

MATUGEN_WRAPPER = """#!/usr/bin/env bash
echo run >> "$STUB_STATE/matugen.log"
exec "{real}" "$@"
"""


def make_exec(path, body):
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def generate_palette(directory, mode, color="#6750a4"):
    empty = directory / "empty.toml"
    empty.write_text("[config]\n\n[templates]\n")
    out = subprocess.run([REAL_MATUGEN, "-c", str(empty), "color", "hex", color, "-m", mode, "-j", "hex"],
                         capture_output=True, check=True)
    return out.stdout


def extract_to_md3():
    src = MATUGEN_QML.read_text()
    start = src.index("    function toMd3(colorsObj) {")
    end = src.index("\n    function generate(", start)
    return src[start:end]


def static_palette(preset_file, mode):
    preset = json.loads(Path(preset_file).read_text())
    js = extract_to_md3().replace("function toMd3(colorsObj)", "function toMd3(colorsObj)", 1)
    script = js + "\nconst out = toMd3(" + json.dumps(preset["colors"]) + ");\nout.mode = " + json.dumps(mode) + \
        ";\nout.is_dark_mode = out.mode === 'dark';\nprocess.stdout.write(JSON.stringify(out));\n"
    res = subprocess.run([REAL_NODE, "-e", script], capture_output=True, check=True)
    return res.stdout


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="apptheme-test-"))
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.stubs = self.tmp / "stubs"
        self.stubs.mkdir()
        self.stub_state = self.tmp / "stub-state"
        self.stub_state.mkdir()
        make_exec(self.stubs / "gsettings", GSETTINGS_STUB)
        for name in ["pkill", "gdbus", "tmux", "pywalfox"]:
            make_exec(self.stubs / name, LOG_STUB)
        make_exec(self.stubs / "matugen", MATUGEN_WRAPPER.format(real=REAL_MATUGEN))
        self.saved_env = dict(os.environ)
        tools = self.tmp / "tools"
        tools.mkdir()
        for tool in CORE_TOOLS:
            real = shutil.which(tool, path=self.saved_env.get("PATH"))
            if real:
                os.symlink(real, tools / tool)
        os.symlink(sys.executable, tools / "python3")
        base_path = str(tools)
        os.environ.clear()
        os.environ.update({
            "HOME": str(self.home),
            "PATH": str(self.stubs) + os.pathsep + base_path,
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "XDG_CONFIG_DIRS": str(self.tmp / "etc-xdg"),
            "XDG_DATA_DIRS": str(self.tmp / "usr-share"),
            "XDG_RUNTIME_DIR": str(self.tmp / "run"),
            "SERPANTINUM_MATUGEN": str(self.stubs / "matugen"),
            "STUB_STATE": str(self.stub_state),
            "QT_QPA_PLATFORMTHEME": "qt6ct",
            "LANG": "C.UTF-8",
        })
        apptheme._PATH_CACHE.clear()
        self.ctx = apptheme.Context()
        self.ctx.work.mkdir(parents=True, exist_ok=True)
        self.set_palette("dark")

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.saved_env)
        apptheme._PATH_CACHE.clear()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def install(self, *names):
        for name in names:
            make_exec(self.stubs / name, "#!/bin/sh\nexit 0\n")
        apptheme._PATH_CACHE.clear()

    def set_palette(self, mode, color="#6750a4"):
        self.ctx.palette.write_bytes(generate_palette(self.tmp, mode, color))

    def cfg(self, rel):
        return self.home / ".config" / rel

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode())
        return path

    def apply(self, enabled, **kw):
        return apptheme.apply(self.ctx, enabled, **kw)

    def calls(self):
        f = self.stub_state / "calls.log"
        time.sleep(0.4)
        return f.read_text().splitlines() if f.exists() else []

    def reset_calls(self):
        time.sleep(0.4)
        (self.stub_state / "calls.log").unlink(missing_ok=True)

    def matugen_runs(self):
        f = self.stub_state / "matugen.log"
        return len(f.read_text().splitlines()) if f.exists() else 0

    def gset(self, key):
        f = self.stub_state / "gsettings" / ("org.gnome.desktop.interface." + key)
        return f.read_text().strip() if f.exists() else "'default'"


class CatalogTests(Sandbox):
    def test_catalog_is_valid(self):
        apps = apptheme.load_apps(self.ctx)
        self.assertEqual(sorted(apps), ALL_BUILTIN)
        for app in apps.values():
            self.assertIsNone(app.error, app.id)
            self.assertIn(app.data.get("category"), apptheme.CATEGORIES, app.id)
        defaults = sorted(a.id for a in apps.values() if a.data.get("default"))
        self.assertEqual(defaults, ["cava", "gtk", "kitty", "qt"])

    def test_no_compositor_templates(self):
        for name in ALL_BUILTIN:
            text = (BUILTIN / name / "app.json").read_text()
            for comp in ("hypr", "niri", "sway", "mango"):
                self.assertNotIn("/" + comp, text.lower(), name)

    def render_everything(self, palette_bytes):
        self.ctx.palette.write_bytes(palette_bytes)
        self.install(*FAKE_BINS)
        self.write(self.cfg("wezterm/wezterm.lua"), "local config = {}\nreturn config\n")
        self.write(self.cfg("superfile/config.toml"), 'theme = "catppuccin"\n')
        for d in ["emacs", "Code"]:
            self.cfg(d).mkdir(parents=True, exist_ok=True)
        for profile in [".zen/b.default", ".mozilla/firefox/c.default-release"]:
            self.write(self.home / profile / "prefs.js", "")
        (self.home / "Notes/.obsidian").mkdir(parents=True, exist_ok=True)
        self.write(self.cfg("obsidian/obsidian.json"), json.dumps({"vaults": {"x": {"path": str(self.home / "Notes")}}}))
        result = self.apply(ALL_BUILTIN, force=True)
        for app_id in ALL_BUILTIN:
            self.assertIn(app_id, result["apps"], app_id)
            self.assertTrue(result["apps"][app_id]["ok"], (app_id, result["apps"][app_id]))
        for path in self.home.rglob("*"):
            if path.is_file() and "/matugen/" not in str(path):
                self.assertNotIn("{{", path.read_text(errors="replace"), path)
        return result

    def check_outputs(self, mode):
        tomllib.loads(self.cfg("alacritty/themes/serpantinum.toml").read_text())
        tomllib.loads(self.cfg("helix/themes/serpantinum.toml").read_text())
        tomllib.loads(self.cfg("helix/config.toml").read_text())
        tomllib.loads(self.cfg("wezterm/colors/serpantinum.toml").read_text())
        tomllib.loads(self.cfg("alacritty/alacritty.toml").read_text())
        tomllib.loads(self.cfg("rio/themes/serpantinum.toml").read_text())
        self.assertEqual(tomllib.loads(self.cfg("rio/config.toml").read_text())["theme"], "serpantinum")
        json.loads(self.cfg("sublime-text/Packages/User/Serpantinum.sublime-color-scheme").read_text())
        plistlib.loads(self.cfg("bat/themes/serpantinum.tmTheme").read_bytes())
        for line in self.cfg("fish/conf.d/serpantinum.fish").read_text().splitlines()[2:]:
            self.assertRegex(line, r"^set -g fish_[a-z_]+ ")
        hexre = re.compile(r"^#[0-9a-f]{6}$")
        for rel in ["yazi/flavors/serpantinum.yazi/flavor.toml", "superfile/theme/serpantinum.toml", "halloy/themes/serpantinum.toml",
                    "atuin/themes/serpantinum.toml", "spotify-player/theme.toml", "spotify-player/app.toml", "superfile/config.toml",
                    "halloy/config.toml", "atuin/config.toml"]:
            tomllib.loads(self.cfg(rel).read_text())
        vicinae = tomllib.loads((self.home / ".local/share/vicinae/themes/serpantinum.toml").read_text())
        self.assertEqual(vicinae["meta"]["variant"], mode)
        self.assertEqual(tomllib.loads(self.cfg("yazi/theme.toml").read_text())["flavor"], {"dark": "serpantinum", "light": "serpantinum"})
        starship = tomllib.loads(self.cfg("starship.toml").read_text())
        self.assertEqual(starship["palette"], "serpantinum")
        self.assertTrue(all(hexre.match(v) for v in starship["palettes"]["serpantinum"].values()))
        self.assertIn("serpantinum", [t["name"] for t in tomllib.loads(self.cfg("spotify-player/theme.toml").read_text())["themes"]])
        for path in [self.home / ".claude/themes/serpantinum.json", self.cfg("glow/serpantinum.json")]:
            json.loads(path.read_text())
        self.assertEqual(json.loads((self.home / ".claude/themes/serpantinum.json").read_text())["base"], mode)
        code = json.loads(self.cfg("Code/User/settings.json").read_text())
        self.assertEqual(code["workbench.colorTheme"], "Default {} Modern".format(mode.title()))
        self.assertTrue(all(hexre.match(v) for v in code["workbench.colorCustomizations"].values()))
        self.assertEqual(json.loads((self.home / "Notes/.obsidian/appearance.json").read_text()), {"enabledCssSnippets": ["serpantinum"]})
        self.assertTrue((self.home / "Notes/.obsidian/snippets/serpantinum.css").is_file())
        for profile in [".zen/b.default", ".mozilla/firefox/c.default-release"]:
            self.assertTrue((self.home / profile / "chrome/serpantinum.css").is_file(), profile)
            self.assertIn('@import url("serpantinum.css");', (self.home / profile / "chrome/userChrome.css").read_text())
            self.assertIn('"toolkit.legacyUserProfileCustomizations.stylesheets", true', (self.home / profile / "user.js").read_text())
        for line in self.cfg("aerc/stylesets/serpantinum").read_text().splitlines():
            if line:
                self.assertRegex(line, r"^[a-z_*]+(\.[a-z*]+)*\.(fg|bg|bold|default|normal)=(#[0-9a-f]{6}|true)$")
        for line in self.cfg("lsd/serpantinum.yaml").read_text().splitlines():
            if "[" in line:
                self.assertRegex(line, r": \[\d{1,3}, \d{1,3}, \d{1,3}\]$")
        self.assertIn("gui:\n  theme:", self.cfg("lazygit/config.yml").read_text())
        el = self.cfg("emacs/serpantinum-theme.el").read_text()
        self.assertEqual(el.count("("), el.count(")"))
        hexre = re.compile(r"^#[0-9a-f]{6}$")
        for line in self.cfg("btop/themes/serpantinum.theme").read_text().splitlines():
            m = re.match(r'^theme\[[a-z_]+\]="(.*)"$', line)
            self.assertTrue(m and hexre.match(m.group(1)), line)
        qt = self.cfg("qt6ct/colors/serpantinum.conf").read_text()
        for key in ("active_colors", "inactive_colors", "disabled_colors"):
            values = re.search(key + r"=(.*)", qt).group(1).split(", ")
            self.assertEqual(len(values), 22)
            self.assertTrue(all(hexre.match(v) for v in values), values)
        kde = (self.home / ".local/share/color-schemes/Serpantinum.colors").read_text()
        for line in kde.splitlines():
            if line.startswith(("Background", "Foreground", "Decoration")):
                self.assertRegex(line, r"=\d{1,3},\d{1,3},\d{1,3}$")
        for line in self.cfg("foot/themes/serpantinum").read_text().splitlines():
            if line and not line.startswith("["):
                self.assertRegex(line, r"^[a-z0-9-]+=[0-9a-f]{6}$")
        for line in self.cfg("fuzzel/serpantinum.ini").read_text().splitlines()[1:]:
            self.assertRegex(line, r"^[a-z-]+=[0-9a-f]{8}$")
        for name in ("gtk-3.0", "gtk-4.0"):
            css = self.cfg(name + "/serpantinum.css").read_text()
            self.assertEqual(css.count("{"), css.count("}"))
            for line in css.splitlines():
                if line.startswith("@define-color"):
                    self.assertRegex(line, r"^@define-color [a-z_]+ (#[0-9a-f]{6}|alpha\(#[0-9a-f]{6}, [0-9.]+\));$")

    def validate_with_real_apps(self):
        nvim = shutil.which("nvim", path=self.saved_env.get("PATH"))
        if nvim:
            res = subprocess.run([nvim, "--clean", "--headless", "-c", "luafile " + str(self.cfg("nvim/colors/serpantinum.lua")), "-c", "qa!"],
                                 capture_output=True, text=True, timeout=30, env=dict(self.saved_env, HOME=str(self.home)))
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertNotIn("Error", res.stderr)
        vim = shutil.which("vim", path=self.saved_env.get("PATH"))
        if vim:
            res = subprocess.run([vim, "--clean", "-es", "-c", "source " + str(self.home / ".vim/colors/serpantinum.vim"), "-c", "qa!"],
                                 capture_output=True, text=True, timeout=30, env=dict(self.saved_env, HOME=str(self.home)))
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        tmux = shutil.which("tmux", path=self.saved_env.get("PATH"))
        if tmux:
            sock = "apptheme-test-" + str(os.getpid())
            env = dict(self.saved_env, HOME=str(self.home), TMUX_TMPDIR=str(self.tmp))
            env.pop("TMUX", None)
            res = subprocess.run([tmux, "-L", sock, "-f", "/dev/null", "new-session", "-d", ";", "source-file", str(self.cfg("tmux/serpantinum.conf"))],
                                 capture_output=True, text=True, timeout=30, env=env)
            subprocess.run([tmux, "-L", sock, "kill-server"], capture_output=True, env=env)
            self.assertEqual(res.returncode, 0, res.stderr)
        foot = shutil.which("foot", path=self.saved_env.get("PATH"))
        if foot:
            res = subprocess.run([foot, "--check-config", "-c", str(self.cfg("foot/foot.ini"))],
                                 capture_output=True, text=True, timeout=30, env=dict(self.saved_env, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config")))
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        rofi = shutil.which("rofi", path=self.saved_env.get("PATH"))
        if rofi:
            res = subprocess.run([rofi, "-no-config", "-theme", str(self.home / ".local/share/rofi/themes/serpantinum.rasi"), "-dump-theme"],
                                 capture_output=True, text=True, timeout=30, env=dict(self.saved_env, HOME=str(self.home)))
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            self.assertNotIn("Error", res.stdout + res.stderr)

    def test_render_all_dark(self):
        self.render_everything(generate_palette(self.tmp, "dark"))
        self.check_outputs("dark")
        self.validate_with_real_apps()

    def test_render_all_light(self):
        self.render_everything(generate_palette(self.tmp, "light", "#b33b15"))
        self.check_outputs("light")
        self.assertEqual(self.gset("color-scheme"), "'default'")

    def test_render_all_static_presets(self):
        if not REAL_NODE:
            self.skipTest("node is not available")
        dump = json.loads(generate_palette(self.tmp, "dark"))
        expected = set(dump["colors"])
        presets = []
        for p in sorted(THEMES.glob("*.json")):
            try:
                if "colors" in json.loads(p.read_text()):
                    presets.append(p)
            except ValueError:
                pass
        self.assertGreater(len(presets), 50)
        for index, preset in enumerate(presets):
            mode = "light" if "Light" in preset.name or "Latte" in preset.name else "dark"
            data = static_palette(preset, mode)
            parsed = json.loads(data)
            self.assertEqual(set(parsed["colors"]), expected, preset.name)
            if index % 12 == 0:
                self.render_everything(data)
                self.check_outputs(mode)


class IntegrationTests(Sandbox):
    def test_kitty_fresh_install_and_undo(self):
        self.install("kitty")
        res = self.apply(["kitty"])
        self.assertTrue(res["apps"]["kitty"]["ok"])
        conf = self.cfg("kitty/kitty.conf").read_text()
        self.assertIn("include themes/serpantinum.conf", conf)
        self.assertTrue(self.cfg("kitty/themes/serpantinum.conf").is_file())
        self.assertTrue(any(c.startswith("pkill -USR1 -x kitty") for c in self.calls()))
        apptheme.apply(self.ctx, [])
        self.assertFalse(self.cfg("kitty/kitty.conf").exists())
        self.assertFalse(self.cfg("kitty/themes/serpantinum.conf").exists())

    def test_kitty_existing_config_roundtrip_and_legacy_include(self):
        self.install("kitty")
        original = "font_size 12\n\ninclude ~/.config/kitty/colors.conf\nmap ctrl+t new_tab\n"
        self.write(self.cfg("kitty/kitty.conf"), original)
        self.apply(["kitty"])
        conf = self.cfg("kitty/kitty.conf").read_text()
        self.assertIn("# serpantinum-disabled: include ~/.config/kitty/colors.conf", conf)
        self.assertTrue(conf.rstrip().endswith("# <<< serpantinum theme <<<"))
        self.assertIn("map ctrl+t new_tab", conf)
        self.apply([])
        self.assertEqual(self.cfg("kitty/kitty.conf").read_text(), original)

    def test_idempotent_no_rerender_no_reload(self):
        self.install("kitty", "cava")
        self.write(self.cfg("kitty/kitty.conf"), "font_size 12\n")
        self.apply(["kitty", "cava"])
        first = self.cfg("kitty/kitty.conf").read_bytes()
        runs = self.matugen_runs()
        self.reset_calls()
        for _ in range(3):
            res = self.apply(["kitty", "cava"])
            self.assertFalse(res["apps"]["kitty"]["changed"])
            self.assertFalse(res["apps"]["cava"]["changed"])
        self.assertEqual(self.matugen_runs(), runs)
        self.assertEqual(self.cfg("kitty/kitty.conf").read_bytes(), first)
        self.assertEqual(self.calls(), [])

    def test_palette_change_rerenders_and_reloads_once(self):
        self.install("kitty")
        self.apply(["kitty"])
        before = self.cfg("kitty/themes/serpantinum.conf").read_text()
        self.reset_calls()
        self.set_palette("dark", "#1b8a3a")
        res = self.apply(["kitty"])
        self.assertTrue(res["apps"]["kitty"]["changed"])
        self.assertNotEqual(self.cfg("kitty/themes/serpantinum.conf").read_text(), before)
        self.assertEqual(len([c for c in self.calls() if c.startswith("pkill -USR1 -x kitty")]), 1)

    def test_user_edit_of_output_is_restored(self):
        self.install("kitty")
        self.apply(["kitty"])
        out = self.cfg("kitty/themes/serpantinum.conf")
        good = out.read_text()
        out.write_text("garbage\n")
        self.apply(["kitty"])
        self.assertEqual(out.read_text(), good)

    def test_cava_legacy_full_config(self):
        self.install("cava")
        legacy = textwrap.dedent("""\
            [general]
            framerate = 60
            bars = 0

            [color]
            background = '#111111'
            foreground = '#222222'

            gradient = 1
            gradient_count = 3
            gradient_color_1 = '#333333'

            [eq]
            1 = 1.0
            """)
        self.write(self.cfg("cava/config"), legacy)
        self.apply(["cava"])
        conf = self.cfg("cava/config").read_text()
        color = conf.split("[color]")[1].split("[eq]")[0]
        self.assertIn("theme = 'serpantinum'", color)
        for key in ("background", "foreground", "gradient", "gradient_count", "gradient_color_1"):
            self.assertRegex(color, r"# serpantinum-disabled: " + key + r" = ")
        self.assertIn("framerate = 60", conf)
        self.assertTrue(self.cfg("cava/themes/serpantinum").is_file())
        self.apply([])
        self.assertEqual(self.cfg("cava/config").read_text(), legacy)

    def test_cava_without_color_section(self):
        self.install("cava")
        original = "[general]\nbars = 0\n"
        self.write(self.cfg("cava/config"), original)
        self.apply(["cava"])
        conf = self.cfg("cava/config").read_text()
        self.assertRegex(conf, r"\[color\]\ntheme = 'serpantinum'")
        self.apply(["cava"])
        self.assertEqual(conf, self.cfg("cava/config").read_text())
        self.apply([])
        self.assertEqual(self.cfg("cava/config").read_text(), original)

    def test_helix_top_level_and_disable(self):
        self.install("hx")
        original = 'theme = "onedark"\n\n[editor]\nline-number = "relative"\n'
        self.write(self.cfg("helix/config.toml"), original)
        self.apply(["helix"])
        parsed = tomllib.loads(self.cfg("helix/config.toml").read_text())
        self.assertEqual(parsed["theme"], "serpantinum")
        self.assertEqual(parsed["editor"]["line-number"], "relative")
        self.apply([])
        self.assertEqual(self.cfg("helix/config.toml").read_text(), original)

    def test_alacritty_variants(self):
        self.install("alacritty")
        self.write(self.cfg("alacritty/alacritty.toml"), "[general]\nlive_config_reload = true\n\n[font]\nsize = 11\n")
        self.apply(["alacritty"])
        parsed = tomllib.loads(self.cfg("alacritty/alacritty.toml").read_text())
        self.assertTrue(parsed["general"]["import"][0].endswith("alacritty/themes/serpantinum.toml"))
        self.assertTrue(parsed["general"]["import"][0].startswith("~/"))
        self.apply([])
        manual = "[general]\nimport = [\n  \"~/x.toml\",\n]\n"
        self.write(self.cfg("alacritty/alacritty.toml"), manual)
        res = self.apply(["alacritty"])
        self.assertEqual(res["apps"]["alacritty"]["issues"][0]["code"], "manual")
        self.assertEqual(self.cfg("alacritty/alacritty.toml").read_text(), manual)

    def test_alacritty_legacy_location_is_used_not_hidden(self):
        self.install("alacritty")
        legacy = self.write(self.home / ".alacritty.toml", "[font]\nsize = 11\n")
        self.apply(["alacritty"])
        self.assertFalse(self.cfg("alacritty/alacritty.toml").exists())
        self.assertIn("serpantinum.toml", legacy.read_text())

    def test_wezterm_before_return_and_manual(self):
        self.install("wezterm")
        res = self.apply(["wezterm"])
        self.assertEqual(res["apps"]["wezterm"]["issues"][0]["code"], "missing_config")
        original = "local wezterm = require 'wezterm'\nlocal config = wezterm.config_builder()\nconfig.color_scheme = 'Nord'\nreturn config\n"
        self.write(self.cfg("wezterm/wezterm.lua"), original)
        self.apply(["wezterm"])
        lines = self.cfg("wezterm/wezterm.lua").read_text().splitlines()
        self.assertEqual(lines[-1], "return config")
        self.assertIn('config.color_scheme = "Serpantinum"', lines)
        self.assertIn("-- serpantinum-disabled: config.color_scheme = 'Nord'", lines)
        self.apply([])
        self.assertEqual(self.cfg("wezterm/wezterm.lua").read_text(), original)
        table = "return {\n  font_size = 11,\n}\n"
        self.write(self.cfg("wezterm/wezterm.lua"), table)
        res = self.apply(["wezterm"])
        self.assertEqual(res["apps"]["wezterm"]["issues"][0]["code"], "manual")
        self.assertEqual(self.cfg("wezterm/wezterm.lua").read_text(), table)

    def test_ghostty_prefers_existing_file(self):
        self.install("ghostty")
        self.write(self.cfg("ghostty/config.ghostty"), "font-size = 12\ntheme = dark:x,light:y\n")
        self.apply(["ghostty"])
        self.assertFalse(self.cfg("ghostty/config").exists())
        text = self.cfg("ghostty/config.ghostty").read_text()
        self.assertIn("theme = serpantinum", text)
        self.assertIn("# serpantinum-disabled: theme = dark:x,light:y", text)
        self.assertTrue(any(c.startswith("gdbus call") for c in self.calls()))

    def test_qt_ini_values_and_restore(self):
        self.install("qt6ct")
        original = "[Appearance]\ncolor_scheme_path=/usr/share/qt6ct/colors/darker.conf\ncustom_palette=false\nstyle=Fusion\n\n[Fonts]\nfixed=\"Mono,9\"\n"
        self.write(self.cfg("qt6ct/qt6ct.conf"), original)
        self.apply(["qt"])
        text = self.cfg("qt6ct/qt6ct.conf").read_text()
        self.assertIn("color_scheme_path=" + str(self.cfg("qt6ct/colors/serpantinum.conf")), text)
        self.assertIn("custom_palette=true", text)
        self.assertIn("style=Fusion", text)
        self.assertFalse(self.cfg("qt5ct/colors/serpantinum.conf").exists())
        self.apply([])
        self.assertEqual(self.cfg("qt6ct/qt6ct.conf").read_text(), original)

    def test_ini_config_created_by_us_is_removed(self):
        self.install("qt6ct")
        self.apply(["qt"])
        self.assertTrue(self.cfg("qt6ct/qt6ct.conf").is_file())
        self.apply([])
        self.assertFalse(self.cfg("qt6ct/qt6ct.conf").exists())

    def test_qt_respects_later_user_change_on_undo(self):
        self.install("qt6ct")
        self.apply(["qt"])
        path = self.cfg("qt6ct/qt6ct.conf")
        path.write_text(path.read_text().replace("custom_palette=true", "custom_palette=false"))
        self.apply([])
        text = path.read_text()
        self.assertIn("custom_palette=false", text)
        self.assertNotIn("serpantinum", text)

    def test_qt_rewritten_by_app_still_tracked(self):
        self.install("qt6ct")
        self.apply(["qt"])
        path = self.cfg("qt6ct/qt6ct.conf")
        path.write_text("[Appearance]\ncustom_palette=true\ncolor_scheme_path=" + str(self.cfg("qt6ct/colors/serpantinum.conf")) + "\nicon_theme=Papirus\n")
        self.apply([])
        self.assertEqual(path.read_text(), "[Appearance]\nicon_theme=Papirus\n")

    def test_qt_listing_issues(self):
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        codes = [i["code"] for i in listing["qt"]["issues"]]
        self.assertIn("requires", codes)
        self.install("qt6ct")
        os.environ["QT_QPA_PLATFORMTHEME"] = ""
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        codes = [i["code"] for i in listing["qt"]["issues"]]
        self.assertEqual(codes, ["env"])

    def test_gtk_css_import_and_gsettings(self):
        original = "@define-color my_color #ff0000;\nwindow { padding: 2px; }\n"
        self.write(self.cfg("gtk-3.0/gtk.css"), original)
        theme_dir = self.tmp / "usr-share" / "themes" / "adw-gtk3-dark"
        res = self.apply(["gtk"])
        css = self.cfg("gtk-3.0/gtk.css").read_text()
        self.assertTrue(css.startswith("/* >>> serpantinum theme >>> */\n@import url(\"serpantinum.css\");"))
        self.assertTrue(self.cfg("gtk-4.0/gtk.css").is_file())
        self.assertEqual(self.gset("color-scheme"), "'prefer-dark'")
        self.assertEqual(self.gset("gtk-theme"), "'default'")
        self.assertIn("no_theme", [i["code"] for i in res["apps"]["gtk"]["issues"]])
        theme_dir.mkdir(parents=True)
        (theme_dir.parent / "adw-gtk3").mkdir()
        self.apply(["gtk"], force=True)
        self.assertEqual(self.gset("gtk-theme"), "'adw-gtk3-dark'")
        self.set_palette("light")
        self.apply(["gtk"])
        self.assertEqual(self.gset("color-scheme"), "'default'")
        self.assertEqual(self.gset("gtk-theme"), "'adw-gtk3'")
        self.apply([])
        self.assertEqual(self.cfg("gtk-3.0/gtk.css").read_text(), original)
        self.assertFalse(self.cfg("gtk-4.0/gtk.css").exists())
        self.assertEqual(self.gset("color-scheme"), "'default'")
        self.assertEqual(self.gset("gtk-theme"), "'default'")

    def test_gsettings_user_change_is_kept_on_undo(self):
        self.apply(["gtk"])
        subprocess.run([str(self.stubs / "gsettings"), "set", "org.gnome.desktop.interface", "color-scheme", "'prefer-light'"], check=True)
        self.apply([])
        self.assertEqual(self.gset("color-scheme"), "'prefer-light'")

    def test_kde_values_from_merge(self):
        self.install("dolphin")
        original = "[General]\nfixed=Hack,10\n\n[Icons]\nTheme=breeze-dark\n\n[Colors:View]\nBackgroundNormal=1,2,3\n"
        self.write(self.cfg("kdeglobals"), original)
        self.apply(["kde"])
        text = self.cfg("kdeglobals").read_text()
        self.assertIn("ColorScheme=Serpantinum", text)
        self.assertIn("[Colors:Header][Inactive]", text)
        self.assertIn("Theme=breeze-dark", text)
        self.assertNotIn("Name=Serpantinum", text)
        self.assertNotIn("BackgroundNormal=1,2,3", text)
        self.apply([])
        self.assertEqual(self.cfg("kdeglobals").read_text(), original)

    def test_btop_kv(self):
        self.install("btop")
        original = '#? Config file for btop\n\ncolor_theme = "Default"\ntheme_background = True\n'
        self.write(self.cfg("btop/btop.conf"), original)
        self.apply(["btop"])
        self.assertIn('color_theme = "serpantinum"', self.cfg("btop/btop.conf").read_text())
        self.apply([])
        self.assertEqual(self.cfg("btop/btop.conf").read_text(), original)

    def test_tmux_prefers_home_conf(self):
        self.install("tmux")
        original = "set -g mouse on\n"
        self.write(self.home / ".tmux.conf", original)
        self.apply(["tmux"])
        self.assertIn("source-file -q ~/.config/tmux/serpantinum.conf", (self.home / ".tmux.conf").read_text())
        self.assertFalse(self.cfg("tmux/tmux.conf").exists())
        self.apply([])
        self.assertEqual((self.home / ".tmux.conf").read_text(), original)

    def test_foot_version_selects_template(self):
        for version, header in (("1.20.2", "[colors]"), ("1.28.0", "[colors-dark]")):
            make_exec(self.stubs / "foot", "#!/bin/sh\necho 'foot version: " + version + " +pgo'\n")
            apptheme._PATH_CACHE.clear()
            apptheme._VERSION_CACHE.clear()
            self.apply(["foot"], force=True)
            lines = self.cfg("foot/themes/serpantinum").read_text().splitlines()
            self.assertEqual(lines[0], header)
            self.assertEqual(lines.count("[colors]") + lines.count("[colors-dark]"), 1)

    def test_foot_and_fuzzel_top_section(self):
        self.install("foot", "fuzzel")
        foot = "[main]\nfont=Mono:size=11\n\n[colors]\nalpha=0.9\n"
        self.write(self.cfg("foot/foot.ini"), foot)
        self.apply(["foot", "fuzzel"])
        lines = self.cfg("foot/foot.ini").read_text().splitlines()
        self.assertEqual(lines[1], "include=~/.config/foot/themes/serpantinum")
        self.assertIn("include=~/.config/fuzzel/serpantinum.ini", self.cfg("fuzzel/fuzzel.ini").read_text())
        self.apply([])
        self.assertEqual(self.cfg("foot/foot.ini").read_text(), foot)
        self.assertFalse(self.cfg("fuzzel/fuzzel.ini").exists())

    def test_zellij_and_rofi_and_zathura(self):
        self.install("zellij", "rofi", "zathura")
        self.write(self.cfg("zellij/config.kdl"), 'theme "dracula"\nkeybinds {\n    normal {\n        theme "x"\n    }\n}\n')
        self.write(self.cfg("rofi/config.rasi"), 'configuration {\n  modi: "drun";\n}\n@theme "gruvbox"\n')
        self.apply(["zellij", "rofi", "zathura"])
        zellij = self.cfg("zellij/config.kdl").read_text()
        self.assertIn('// serpantinum-disabled: theme "dracula"', zellij)
        self.assertIn('        theme "x"', zellij)
        rofi = self.cfg("rofi/config.rasi").read_text()
        self.assertIn('// serpantinum-disabled: @theme "gruvbox"', rofi)
        self.assertTrue(rofi.rstrip().endswith("// <<< serpantinum theme <<<"))
        self.assertIn("include serpantinum", self.cfg("zathura/zathurarc").read_text())

    def test_kakoune_rio_bat_wofi(self):
        self.install("kak", "rio", "bat", "wofi")
        self.write(self.cfg("kak/kakrc"), "colorscheme gruvbox-dark\nset-option global tabstop 4\n")
        self.write(self.cfg("rio/config.toml"), 'theme = "dracula"\n\n[window]\nopacity = 0.9\n')
        self.write(self.cfg("bat/config"), '--theme="TwoDark"\n--style="numbers"\n')
        self.apply(["kakoune", "rio", "bat", "wofi"])
        kak = self.cfg("kak/kakrc").read_text()
        self.assertIn("# serpantinum-disabled: colorscheme gruvbox-dark", kak)
        self.assertIn("\ncolorscheme serpantinum\n", kak)
        rio = tomllib.loads(self.cfg("rio/config.toml").read_text())
        self.assertEqual(rio["theme"], "serpantinum")
        self.assertEqual(rio["window"]["opacity"], 0.9)
        bat = self.cfg("bat/config").read_text()
        self.assertIn('# serpantinum-disabled: --theme="TwoDark"', bat)
        self.assertIn('--theme="serpantinum"', bat)
        self.assertTrue(self.cfg("wofi/style.css").read_text().startswith("/* >>> serpantinum theme >>> */\n@import url(\"file://{}/wofi/serpantinum.css\");".format(self.cfg(""))))
        self.apply([])
        self.assertEqual(self.cfg("kak/kakrc").read_text(), "colorscheme gruvbox-dark\nset-option global tabstop 4\n")
        self.assertEqual(self.cfg("rio/config.toml").read_text(), 'theme = "dracula"\n\n[window]\nopacity = 0.9\n')
        self.assertEqual(self.cfg("bat/config").read_text(), '--theme="TwoDark"\n--style="numbers"\n')
        self.assertFalse(self.cfg("wofi/style.css").exists())

    def test_vscode_json_settings_roundtrip(self):
        self.install("code")
        original = '{\n  "editor.fontSize": 14,\n  "workbench.colorTheme": "One Dark Pro"\n}\n'
        self.write(self.cfg("Code/User/settings.json"), original)
        self.apply(["vscode"])
        data = json.loads(self.cfg("Code/User/settings.json").read_text())
        self.assertEqual(data["editor.fontSize"], 14)
        self.assertEqual(data["workbench.colorTheme"], "Default Dark Modern")
        self.assertIn("editor.background", data["workbench.colorCustomizations"])
        self.assertIn('\n  "editor.fontSize"', self.cfg("Code/User/settings.json").read_text())
        self.set_palette("light")
        self.apply(["vscode"])
        self.assertEqual(json.loads(self.cfg("Code/User/settings.json").read_text())["workbench.colorTheme"], "Default Light Modern")
        self.apply([])
        self.assertEqual(json.loads(self.cfg("Code/User/settings.json").read_text()), json.loads(original))
        self.assertFalse(self.cfg("VSCodium").exists())

    def test_json_undo_restores_original_bytes(self):
        self.install("code")
        for original in ['{\r\n  "a": 1\r\n}\r\n', '{\n\t"a": 1\n}', "{}", ""]:
            path = self.cfg("Code/User/settings.json")
            self.write(path, original)
            self.apply(["vscode"])
            self.set_palette("light")
            self.apply(["vscode"])
            self.set_palette("dark")
            self.apply([])
            self.assertEqual(path.read_bytes(), original.encode())

    def test_json_with_comments_is_left_alone(self):
        self.install("code")
        text = '{\n  // my settings\n  "editor.fontSize": 14,\n}\n'
        self.write(self.cfg("Code/User/settings.json"), text)
        res = self.apply(["vscode"])
        self.assertEqual([i["code"] for i in res["apps"]["vscode"]["issues"]], ["manual"])
        self.assertEqual(self.cfg("Code/User/settings.json").read_text(), text)

    def test_json_user_change_is_kept_on_undo(self):
        self.install("code")
        path = self.cfg("Code/User/settings.json")
        self.write(path, "{}\n")
        self.apply(["vscode"])
        self.assertEqual(json.loads(path.read_text())["workbench.colorTheme"], "Default Dark Modern")
        data = json.loads(path.read_text())
        data["workbench.colorTheme"] = "Monokai"
        self.write(path, json.dumps(data))
        self.apply([])
        self.assertEqual(json.loads(path.read_text())["workbench.colorTheme"], "Monokai")

    def test_each_profile_roundtrip(self):
        self.install("zen-browser")
        for name in ["a.default", "b.work"]:
            self.write(self.home / ".zen" / name / "prefs.js", "")
        self.write(self.home / ".zen/b.work/chrome/userChrome.css", "#folderTree { font-size: 12px; }\n")
        self.write(self.home / ".zen/b.work/user.js", 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n')
        self.apply(["zen-browser"])
        for name in ["a.default", "b.work"]:
            profile = self.home / ".zen" / name
            self.assertTrue((profile / "chrome/serpantinum.css").is_file())
            self.assertTrue((profile / "chrome/userChrome.css").read_text().startswith("/* >>> serpantinum theme >>> */"))
        self.assertIn("// serpantinum-disabled: user_pref", (self.home / ".zen/b.work/user.js").read_text())
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        self.assertEqual(len(listing["zen-browser"]["outputs"]), 2)
        self.apply([])
        self.assertFalse((self.home / ".zen/a.default/chrome/userChrome.css").exists())
        self.assertFalse((self.home / ".zen/a.default/user.js").exists())
        self.assertFalse((self.home / ".zen/a.default/chrome/serpantinum.css").exists())
        self.assertEqual((self.home / ".zen/b.work/chrome/userChrome.css").read_text(), "#folderTree { font-size: 12px; }\n")
        self.assertEqual((self.home / ".zen/b.work/user.js").read_text(),
                         'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n')

    def test_obsidian_vaults_from_json(self):
        self.install("obsidian")
        vault = self.home / "Documents/Vault"
        (vault / ".obsidian").mkdir(parents=True)
        self.write(vault / ".obsidian/appearance.json", '{\n  "cssTheme": "Minimal",\n  "enabledCssSnippets": ["mine"]\n}\n')
        self.write(self.cfg("obsidian/obsidian.json"), json.dumps({"vaults": {
            "a": {"path": str(vault)}, "b": {"path": str(self.home / "missing")}}}))
        self.apply(["obsidian"])
        self.assertTrue((vault / ".obsidian/snippets/serpantinum.css").is_file())
        appearance = json.loads((vault / ".obsidian/appearance.json").read_text())
        self.assertEqual(appearance["enabledCssSnippets"], ["mine", "serpantinum"])
        self.assertFalse((self.home / "missing").exists())
        self.apply(["obsidian"])
        self.assertEqual(json.loads((vault / ".obsidian/appearance.json").read_text())["enabledCssSnippets"], ["mine", "serpantinum"])
        self.apply([])
        self.assertEqual(json.loads((vault / ".obsidian/appearance.json").read_text()), {"cssTheme": "Minimal", "enabledCssSnippets": ["mine"]})
        self.assertFalse((vault / ".obsidian/snippets/serpantinum.css").exists())

    def test_starship_palette_before_first_table(self):
        self.install("starship")
        original = 'add_newline = false\npalette = "gruvbox"\n\n[character]\nsuccess_symbol = "[>](bold green)"\n'
        self.write(self.cfg("starship.toml"), original)
        self.apply(["starship"])
        text = self.cfg("starship.toml").read_text()
        data = tomllib.loads(text)
        self.assertEqual(data["palette"], "serpantinum")
        self.assertFalse(data["add_newline"])
        self.assertEqual(data["character"]["success_symbol"], "[>](bold green)")
        self.assertIn("green", data["palettes"]["serpantinum"])
        self.assertLess(text.index("[palettes.serpantinum]"), text.index("[character]"))
        self.set_palette("dark", "#b33b15")
        self.apply(["starship"])
        self.assertEqual(self.cfg("starship.toml").read_text().count("[palettes.serpantinum]"), 1)
        self.apply([])
        self.assertEqual(self.cfg("starship.toml").read_text(), original)

    def test_starship_undo_restores_table_directly_after_top_level(self):
        self.install("starship")
        original = 'palette = "mine"\n[palettes.mine]\nred = "#f00"\n'
        self.write(self.cfg("starship.toml"), original)
        self.apply(["starship"])
        tomllib.loads(self.cfg("starship.toml").read_text())
        self.set_palette("dark", "#b33b15")
        self.apply(["starship"])
        self.apply([])
        self.assertEqual(self.cfg("starship.toml").read_text(), original)

    def test_lazygit_block_and_existing_gui(self):
        self.install("lazygit", "yazi")
        self.apply(["lazygit", "yazi"])
        self.assertTrue(self.cfg("lazygit/config.yml").read_text().startswith("# >>> serpantinum theme >>>\ngui:\n  theme:"))
        self.assertTrue(self.cfg("yazi/flavors/serpantinum.yazi/tmtheme.xml").is_file())
        self.apply([])
        self.assertFalse(self.cfg("lazygit/config.yml").exists())
        self.assertFalse(self.cfg("yazi/theme.toml").exists())
        self.write(self.cfg("lazygit/config.yml"), "gui:\n  nerdFontsVersion: \"3\"\n")
        res = self.apply(["lazygit"])
        self.assertEqual([i["code"] for i in res["apps"]["lazygit"]["issues"]], ["manual"])
        self.assertEqual(self.cfg("lazygit/config.yml").read_text(), "gui:\n  nerdFontsVersion: \"3\"\n")

    def test_files_only_apps(self):
        files_only = ["neovim", "konsole", "fastfetch", "vim", "micro", "sublime", "fish"]
        self.install("nvim", "konsole", "fastfetch", "vim", "micro", "subl", "fish")
        res = self.apply(files_only)
        for app_id in files_only:
            self.assertTrue(res["apps"][app_id]["ok"], app_id)
            self.assertEqual(res["apps"][app_id]["issues"], [])
        self.assertTrue(self.cfg("nvim/colors/serpantinum.lua").is_file())
        self.assertFalse(self.cfg("nvim/init.lua").exists())
        self.assertTrue((self.home / ".vim/colors/serpantinum.vim").is_file())
        self.assertFalse((self.home / ".vimrc").exists())
        self.assertTrue(self.cfg("fish/conf.d/serpantinum.fish").is_file())
        self.assertFalse(self.cfg("fish/config.fish").exists())


class RobustnessTests(Sandbox):
    def test_not_installed_is_skipped_and_hidden_flag(self):
        res = self.apply(["alacritty"])
        self.assertNotIn("alacritty", res["apps"])
        self.assertFalse(self.cfg("alacritty").exists())
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        self.assertFalse(listing["alacritty"]["installed"])
        self.assertTrue(listing["gtk"]["installed"])

    def test_defaults_when_settings_absent(self):
        self.install("kitty", "cava")
        self.assertEqual(apptheme.enabled_ids(self.ctx, apptheme.load_apps(self.ctx)), {"kitty", "cava", "gtk", "qt"})
        self.write(self.ctx.settings, json.dumps({"theme": {"apps": ["alacritty"]}}))
        self.assertEqual(apptheme.enabled_ids(self.ctx, apptheme.load_apps(self.ctx)), {"alacritty"})
        res = apptheme.apply(self.ctx, None)
        self.assertEqual(set(res["apps"]), set())

    def test_read_only_symlink_untouched(self):
        self.install("kitty")
        store = self.tmp / "store"
        store.mkdir()
        target = store / "kitty.conf"
        target.write_text("font_size 10\n")
        target.chmod(0o444)
        store.chmod(0o555)
        self.cfg("kitty").mkdir(parents=True)
        os.symlink(target, self.cfg("kitty/kitty.conf"))
        try:
            res = self.apply(["kitty"])
            self.assertEqual(res["apps"]["kitty"]["issues"][0]["code"], "read_only")
            listed = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}["kitty"]["issues"][0]
            self.assertEqual(listed["display"], "~/.config/kitty/kitty.conf")
            self.assertTrue(listed["file"].startswith(str(self.home)))
            self.assertTrue(self.cfg("kitty/kitty.conf").is_symlink())
            self.assertEqual(target.read_text(), "font_size 10\n")
        finally:
            store.chmod(0o755)

    def test_writable_symlink_written_through(self):
        self.install("kitty")
        dotfiles = self.write(self.tmp / "dotfiles" / "kitty.conf", "font_size 10\n")
        self.cfg("kitty").mkdir(parents=True)
        os.symlink(dotfiles, self.cfg("kitty/kitty.conf"))
        self.apply(["kitty"])
        self.assertTrue(self.cfg("kitty/kitty.conf").is_symlink())
        self.assertIn("include themes/serpantinum.conf", dotfiles.read_text())
        self.apply([])
        self.assertEqual(dotfiles.read_text(), "font_size 10\n")

    def test_unwritable_output_dir_is_contained(self):
        self.install("kitty", "cava")
        self.write(self.cfg("kitty/kitty.conf"), "font_size 12\n")
        self.cfg("kitty").chmod(0o555)
        try:
            res = self.apply(["kitty", "cava"])
            self.assertFalse(res["apps"]["kitty"]["ok"])
            self.assertEqual(res["apps"]["kitty"]["error"], "write")
            self.assertIn("kitty/themes", res["apps"]["kitty"]["detail"])
            self.assertTrue(res["apps"]["cava"]["ok"])
            self.assertTrue(self.cfg("cava/themes/serpantinum").is_file())
            self.assertEqual(self.cfg("kitty/kitty.conf").read_text(), "font_size 12\n")
            listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
            self.assertIn("kitty/themes", listing["kitty"]["error"])
        finally:
            self.cfg("kitty").chmod(0o755)
        res = self.apply(["kitty", "cava"])
        self.assertTrue(res["apps"]["kitty"]["ok"])
        self.assertIn("include themes/serpantinum.conf", self.cfg("kitty/kitty.conf").read_text())

    def test_system_config_not_hidden(self):
        self.install("kitty")
        self.write(self.tmp / "etc-xdg" / "kitty" / "kitty.conf", "font_size 9\n")
        res = self.apply(["kitty"])
        self.assertEqual(res["apps"]["kitty"]["issues"][0]["code"], "system_config")
        self.assertFalse(self.cfg("kitty/kitty.conf").exists())

    def test_crlf_and_no_trailing_newline_preserved(self):
        self.install("kitty")
        original = "font_size 12\r\nmap ctrl+t new_tab"
        self.write(self.cfg("kitty/kitty.conf"), original)
        self.apply(["kitty"])
        raw = self.cfg("kitty/kitty.conf").read_bytes()
        self.assertNotIn(b"\n", raw.replace(b"\r\n", b""))
        self.apply([])
        self.assertEqual(self.cfg("kitty/kitty.conf").read_bytes(), original.encode())

    def test_file_mode_preserved(self):
        self.install("kitty")
        path = self.write(self.cfg("kitty/kitty.conf"), "font_size 12\n")
        path.chmod(0o600)
        self.apply(["kitty"])
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_non_utf8_bytes_survive(self):
        self.install("kitty")
        original = b"font_family \xff\xfe weird\n"
        self.cfg("kitty").mkdir(parents=True)
        self.cfg("kitty/kitty.conf").write_bytes(original)
        self.apply(["kitty"])
        self.assertIn(b"\xff\xfe", self.cfg("kitty/kitty.conf").read_bytes())
        self.apply([])
        self.assertEqual(self.cfg("kitty/kitty.conf").read_bytes(), original)

    def test_user_removed_block_is_readded_and_manual_line_respected(self):
        self.install("kitty")
        self.apply(["kitty"])
        path = self.cfg("kitty/kitty.conf")
        path.write_text("font_size 12\ninclude themes/serpantinum.conf\n")
        self.apply(["kitty"], force=True)
        self.assertEqual(path.read_text(), "font_size 12\ninclude themes/serpantinum.conf\n")
        path.write_text("font_size 12\n")
        self.apply(["kitty"], force=True)
        self.assertIn(">>> serpantinum theme >>>", path.read_text())

    def test_broken_user_template_is_isolated(self):
        self.install("kitty", "cava", "btop")
        user_btop = Path(apptheme.customize(self.ctx, "btop")["dir"])
        (user_btop / "serpantinum.theme").write_text("{{colors.does_not_exist.default.hex}}\n")
        res = self.apply(["kitty", "cava", "btop"])
        self.assertTrue(res["apps"]["kitty"]["ok"])
        self.assertTrue(res["apps"]["cava"]["ok"])
        self.assertFalse(res["apps"]["btop"]["ok"])
        self.assertEqual(res["apps"]["btop"]["error"], "render")
        self.assertTrue(res["apps"]["btop"]["detail"])
        self.assertFalse(self.cfg("btop/themes/serpantinum.theme").exists())
        self.assertFalse(self.cfg("btop/btop.conf").exists())
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        self.assertTrue(listing["btop"]["error"])
        self.apply(["kitty", "cava"])
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        self.assertEqual(listing["btop"]["error"], "")

    def test_invalid_user_overrides_never_applied(self):
        cases = {
            "kitty": None,
            "cava": {"name": "x", "templates": [{"input": "../../../../etc/passwd", "output": "$HOME/x"}]},
            "foot": {"name": "x", "templates": [{"input": "t", "output": "$NOPE/x"}]},
            "btop": {"name": "x", "templates": [{"input": "t", "output": "relative/x"}]},
            "tmux": {"name": "x", "templates": [{"input": "t", "output": "$HOME/x"}], "integrate": [{"type": "exec"}]},
            "zellij": {"name": "x", "templates": [{"input": "t", "output": "$HOME/x"}], "integrate": [{"type": "line", "file": "$HOME/f", "line": "a", "disable": "("}]},
        }
        self.install("kitty", "cava", "foot", "btop", "tmux", "zellij")
        for app_id, data in cases.items():
            d = self.ctx.user_dir / app_id
            d.mkdir(parents=True)
            (d / "t").write_text("x\n")
            (d / "app.json").write_text("{not json" if data is None else json.dumps(data))
        res = self.apply(list(cases))
        for app_id in cases:
            self.assertFalse(res["apps"][app_id]["ok"], app_id)
            self.assertEqual(res["apps"][app_id]["error"], "invalid", app_id)
        self.assertFalse((self.home / "x").exists())
        self.assertFalse((self.home / "f").exists())

    def test_unknown_user_folders_are_ignored(self):
        d = self.ctx.user_dir / "mine"
        d.mkdir(parents=True)
        (d / "t").write_text("{{colors.primary.default.hex}}\n")
        (d / "app.json").write_text(json.dumps({"name": "Mine", "templates": [{"input": "t", "output": "$XDG_CONFIG_HOME/mine/colors"}]}))
        self.assertNotIn("mine", apptheme.load_apps(self.ctx))
        self.assertNotIn("mine", [a["id"] for a in apptheme.list_apps(self.ctx)["apps"]])
        res = self.apply(["mine"])
        self.assertNotIn("mine", res["apps"])
        self.assertFalse(self.cfg("mine").exists())

    def test_missing_and_bad_palette(self):
        self.install("kitty")
        self.ctx.palette.unlink()
        self.assertEqual(self.apply(["kitty"])["error"], "no_palette")
        self.ctx.palette.write_text("{oops")
        self.assertEqual(self.apply(["kitty"])["error"], "bad_palette")
        self.assertFalse(self.cfg("kitty").exists())

    def test_missing_matugen_reports_error(self):
        self.install("kitty")
        os.environ["SERPANTINUM_MATUGEN"] = str(self.tmp / "nope" / "matugen")
        ctx = apptheme.Context()
        res = apptheme.apply(ctx, ["kitty"])
        self.assertFalse(res["apps"]["kitty"]["ok"])
        self.assertIn("matugen", res["apps"]["kitty"]["detail"])

    def test_undo_after_app_leaves_catalog(self):
        catalog = self.tmp / "catalog"
        shutil.copytree(BUILTIN, catalog)
        os.environ["SERPANTINUM_APPTHEME_BUILTIN"] = str(catalog)
        ctx = apptheme.Context()
        self.install("kitty", "cava")
        apptheme.apply(ctx, ["kitty", "cava"])
        self.assertTrue(self.cfg("kitty/themes/serpantinum.conf").exists())
        shutil.rmtree(catalog / "kitty")
        apptheme.apply(ctx, ["kitty", "cava"])
        self.assertTrue(self.cfg("kitty/themes/serpantinum.conf").exists())
        apptheme.apply(ctx, ["cava"])
        self.assertFalse(self.cfg("kitty/themes/serpantinum.conf").exists())
        self.assertFalse(self.cfg("kitty/kitty.conf").exists())
        self.assertTrue(self.cfg("cava/themes/serpantinum").exists())

    def test_customize_and_reset(self):
        out = apptheme.customize(self.ctx, "kitty")
        user_kitty = Path(out["dir"])
        self.assertTrue((user_kitty / "app.json").is_file())
        (user_kitty / "kitty.conf").write_text("foreground {{colors.primary.default.hex}}\n")
        self.install("kitty")
        self.apply(["kitty"])
        self.assertEqual(self.cfg("kitty/themes/serpantinum.conf").read_text().split()[0], "foreground")
        self.assertEqual(len(self.cfg("kitty/themes/serpantinum.conf").read_text().splitlines()), 1)
        listing = {a["id"]: a for a in apptheme.list_apps(self.ctx)["apps"]}
        self.assertTrue(listing["kitty"]["custom"] and listing["kitty"]["builtin"])
        self.assertEqual(apptheme.customize(self.ctx, "kitty")["dir"], str(user_kitty))
        backup = apptheme.reset(self.ctx, "kitty")["backup"]
        self.assertTrue(Path(backup, "kitty.conf").is_file())
        self.assertFalse(user_kitty.exists())
        self.apply(["kitty"])
        self.assertGreater(len(self.cfg("kitty/themes/serpantinum.conf").read_text().splitlines()), 10)
        with self.assertRaises(apptheme.AppError):
            apptheme.customize(self.ctx, "../etc")
        with self.assertRaises(apptheme.AppError):
            apptheme.customize(self.ctx, "unknown-app")

    def test_only_filter_keeps_others(self):
        self.install("kitty", "cava")
        self.apply(["kitty", "cava"])
        res = apptheme.apply(self.ctx, ["kitty"], only={"kitty"})
        self.assertIn("kitty", res["apps"])
        self.assertTrue(self.cfg("cava/themes/serpantinum").exists())

    def test_state_corruption_recovers(self):
        self.install("kitty")
        self.apply(["kitty"])
        self.ctx.state_file.write_text("{garbage")
        res = self.apply(["kitty"])
        self.assertTrue(res["apps"]["kitty"]["ok"])
        self.assertEqual(self.cfg("kitty/kitty.conf").read_text().count(">>> serpantinum theme >>>"), 1)

    def test_concurrent_cli_runs(self):
        self.install("kitty", "cava", "foot", "btop")
        self.write(self.cfg("kitty/kitty.conf"), "font_size 12\n")
        env = dict(os.environ, SERPANTINUM_APPTHEME_BUILTIN=str(BUILTIN))
        procs = [subprocess.Popen([sys.executable, str(ENGINE), "apply", "--enabled=kitty,cava,foot,btop"] + (["--force"] if i % 2 else []),
                                  env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for i in range(6)]
        for p in procs:
            out, err = p.communicate(timeout=120)
            self.assertEqual(p.returncode, 0, err)
            self.assertTrue(json.loads(out)["ok"])
        text = self.cfg("kitty/kitty.conf").read_text()
        self.assertEqual(text.count(">>> serpantinum theme >>>"), 1)
        self.assertEqual(json.loads(self.ctx.state_file.read_text())["applied"].keys(), {"kitty", "cava", "foot", "btop"})

    def test_cli_roundtrip(self):
        env = dict(os.environ)
        out = subprocess.run([sys.executable, str(ENGINE), "list"], env=env, capture_output=True, text=True, check=True)
        data = json.loads(out.stdout)
        self.assertTrue(data["ok"])
        self.assertEqual(sorted(a["id"] for a in data["apps"]), ALL_BUILTIN)
        bad = subprocess.run([sys.executable, str(ENGINE), "customize", "nope"], env=env, capture_output=True, text=True)
        self.assertEqual(bad.returncode, 1)
        self.assertFalse(json.loads(bad.stdout)["ok"])
        empty = subprocess.run([sys.executable, str(ENGINE), "apply", "--enabled="], env=env, capture_output=True, text=True)
        self.assertEqual(empty.returncode, 0, empty.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
