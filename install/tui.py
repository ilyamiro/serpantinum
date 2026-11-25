#!/usr/bin/env python3

import argparse
import collections
import dataclasses
import fcntl
import importlib.util
import json
import math
import os
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import threading
import time
import unicodedata


def _load_logo_pixel_module():
    path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "logo_pixel.py")
    if not os.path.isfile(path):
        return None
    try:
        spec = importlib.util.spec_from_file_location("serp_logo_pixel", path)
        if spec is None or spec.loader is None:
            return None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod
    except Exception:
        return None


LOGO_PIXEL_MOD = _load_logo_pixel_module()
LOGO_PNG_BYTES = LOGO_PIXEL_MOD.load_logo_png() if LOGO_PIXEL_MOD is not None else None
LOGO_RGBA_INFO = (
    LOGO_PIXEL_MOD.decode_png_rgba(LOGO_PNG_BYTES)
    if (LOGO_PIXEL_MOD is not None and LOGO_PNG_BYTES)
    else None
)


ANSI_RE = re.compile(r"\x1b(?:\][^\x07\x1b]*(?:\x07|\x1b\\)|\[[0-?]*[ -/]*[@-~]|[@-Z\\-_])")
WP_PROGRESS_RE = re.compile(r"(\d+)%\s*\((\d+)/(\d+)\)")
MISSING_COUNT_RE = re.compile(r"\b(\d+)\s+missing\b", re.IGNORECASE)
INSTALLING_PKG_RE = re.compile(r"(?:^::\s*|Installing\s+)([a-zA-Z0-9_.+-]+)")
SUDO_PROMPT_MARKER = "[serpantinum-sudo] "
PROMPT_RE = re.compile(r"(?:\[[yYnN]/[yYnN]\]|\(y/n\)|password[^:]*:\s*|import[^?]*\?\s*|proceed[^?]*\?\s*|:\s*$|\?\s*$)", re.IGNORECASE)

SPINNER_FRAMES = ("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")

WORDMARK_6 = (
    "█████╗ █████╗ █████╗ █████╗  █████╗ ███╗  ██╗██████╗██╗███╗  ██╗██╗  ██╗███╗   ███╗",
    "██╔══╝ ██╔══╝ ██╔═██╗██╔═██╗██╔══██╗████╗ ██║╚═██╔═╝██║████╗ ██║██║  ██║████╗ ████║",
    "█████╗ ████╗  █████╔╝█████╔╝███████║██╔██╗██║  ██║  ██║██╔██╗██║██║  ██║██╔████╔██║",
    "╚══██║ ██╔═╝  ██╔═██╗██╔══╝ ██╔══██║██║╚████║  ██║  ██║██║╚████║██║  ██║██║╚██╔╝██║",
    "█████║ █████╗ ██║ ██║██║    ██║  ██║██║ ╚███║  ██║  ██║██║ ╚███║╚█████╔╝██║ ╚═╝ ██║",
    "╚════╝ ╚════╝ ╚═╝ ╚═╝╚═╝    ╚═╝  ╚═╝╚═╝  ╚══╝  ╚═╝  ╚═╝╚═╝  ╚══╝ ╚════╝ ╚═╝     ╚═╝",
)

WORDMARK_5 = (
    "█████╗█████╗████╗ ████╗  ███╗ ██╗ ██╗██████╗██╗██╗ ██╗██╗ ██╗███╗ ███╗",
    "██╔══╝██╔══╝██╔██╗██╔██╗██╔██╗███╗██║╚═██╔═╝██║███╗██║██║ ██║████╗████║",
    "█████╗████╗ ████╔╝████╔╝█████║██████║  ██║  ██║██████║██║ ██║██╔███╔██║",
    "╚══██║██╔═╝ ██╔██╗██╔═╝ ██╔██║██╔███║  ██║  ██║██╔███║██║ ██║██║╚█╔╝██║",
    "█████║█████╗██║██║██║   ██║██║██║╚██║  ██║  ██║██║╚██║╚████╔╝██║ ╚╝ ██║",
    "╚════╝╚════╝╚═╝╚═╝╚═╝   ╚═╝╚═╝╚═╝ ╚═╝  ╚═╝  ╚═╝╚═╝ ╚═╝ ╚═══╝ ╚═╝    ╚═╝",
)

WORDMARK_3 = (
    "▄████ █████ ████▄ ████▄  ▄██▄  ██▄ ██ ██████ ██ ██▄ ██ ██ ██ ██▄ ▄██",
    "▀▀██▄ ██▀▀  ██▄█▀ ██▄█▀ ██▄▄██ ██▀███   ██   ██ ██▀███ ██ ██ ██▀█▀██",
    "████▀ █████ ██ ▀█ ██    ██  ██ ██  ██   ██   ██ ██  ██ ▀███▀ ██   ██",
)

WORDMARK_2 = (
    "█▀▀ █▀▀ █▀█ █▀█ ▄▀█ █▄░█ ▀█▀ █ █▄░█ █░█ █▀▄▀█",
    "▀▀█ █▀▀ █▀▄ █▀▀ █▀█ █░▀█ ░█░ █ █░▀█ █▄█ █░▀░█",
)

COMPOSITORS = (
    ("hyprland", "Hyprland"),
    ("niri", "Niri"),
    ("sway", "Sway"),
    ("mango", "Mango"),
    ("umbriel", "Umbriel"),
)

DEFAULT_REQUIRED_PKGS = (
    "kitty", "zbar", "tesseract", "tesseract-data-eng",
    "wl-clipboard", "qt6-multimedia",
    "cliphist", "jq", "ddcutil",
    "bluez", "networkmanager", "matugen",
    "pipewire", "wireplumber", "pipewire-pulse", "pipewire-alsa", "libpulse", "python",
    "imagemagick", "file",
    "ffmpeg", "fastfetch", "quickshell",
    "grim", "playerctl", "satty", "xdg-desktop-portal-gtk", "power-profiles-daemon", "qt6-wayland",
    "qt6ct", "adwaita-icon-theme", "gpu-screen-recorder", "wf-recorder", "adw-gtk-theme",
)


def strip_ansi(text):
    return ANSI_RE.sub("", text)


def char_width(ch):
    if ch == "\t":
        return 2
    if unicodedata.combining(ch):
        return 0
    cat = unicodedata.category(ch)
    if cat in ("Cc", "Cf"):
        return 0
    ea = unicodedata.east_asian_width(ch)
    if ea in ("W", "F"):
        return 2
    return 1


def display_width(text):
    plain = strip_ansi(text)
    return sum(char_width(ch) for ch in plain)


def truncate_plain(text, max_width):
    if max_width <= 0:
        return ""
    if display_width(text) <= max_width:
        return text
    if max_width == 1:
        return "…"
    out = []
    width = 0
    limit = max_width - 1
    for ch in text:
        cw = char_width(ch)
        if width + cw > limit:
            break
        out.append(ch)
        width += cw
    return "".join(out) + "…"


def truncate_styled(text, max_width):
    if max_width <= 0:
        return ""
    if display_width(text) <= max_width:
        return text
    out = []
    width = 0
    limit = max(0, max_width - 1)
    idx = 0
    length = len(text)
    has_ansi = False
    while idx < length:
        if text[idx] == "\x1b":
            m = ANSI_RE.match(text, idx)
            if m:
                out.append(m.group(0))
                has_ansi = True
                idx = m.end()
                continue
        ch = text[idx]
        cw = char_width(ch)
        if width + cw > limit:
            break
        out.append(ch)
        width += cw
        idx += 1
    if max_width >= 1:
        out.append("…")
    if has_ansi:
        out.append("\x1b[0m")
    return "".join(out)


def pad_right(text, width):
    vis = display_width(text)
    if vis > width:
        text = truncate_styled(text, width)
        vis = display_width(text)
    return text + (" " * max(0, width - vis))


def center_styled(text, width):
    vis = display_width(text)
    if vis >= width:
        return truncate_styled(text, width)
    left = (width - vis) // 2
    right = width - vis - left
    return (" " * left) + text + (" " * right)


def wrap_plain(text, width):
    if width <= 4:
        return [truncate_plain(text, max(1, width))]
    lines = []
    for paragraph in text.splitlines():
        words = paragraph.split()
        if not words:
            lines.append("")
            continue
        cur = words[0]
        cur_w = display_width(cur)
        for word in words[1:]:
            ww = display_width(word)
            if cur_w + 1 + ww <= width:
                cur = cur + " " + word
                cur_w += 1 + ww
            else:
                lines.append(cur)
                cur = word
                cur_w = ww
        lines.append(cur)
    return lines or [""]


def format_duration(seconds):
    total = max(0.0, seconds)
    if total < 60:
        return f"{total:4.1f}s"
    mins = int(total // 60)
    secs = int(total % 60)
    return f"{mins:02d}:{secs:02d}"


def format_mmss(seconds):
    total = max(0, int(seconds))
    return f"{total // 60:02d}:{total % 60:02d}"


def rgb_to_256(r, g, b):
    if r == g == b:
        if r < 8:
            return 16
        if r > 248:
            return 231
        return round(((r - 8) / 247) * 24) + 232
    ri = round(r / 255 * 5)
    gi = round(g / 255 * 5)
    bi = round(b / 255 * 5)
    return 16 + 36 * ri + 6 * gi + bi


class Theme:
    RESET = "\x1b[0m"
    BOLD = "\x1b[1m"
    DIM = "\x1b[2m"

    def __init__(self):
        self.no_color = bool(os.environ.get("NO_COLOR"))
        colorterm = os.environ.get("COLORTERM", "").lower()
        term = os.environ.get("TERM", "").lower()
        term_prog = os.environ.get("TERM_PROGRAM", "").lower()
        if self.no_color or term == "dumb":
            self.depth = 0
        elif colorterm in ("truecolor", "24bit") or any(
            k in term for k in ("kitty", "foot", "alacritty", "ghostty", "wezterm", "direct")
        ) or term_prog in ("wezterm", "ghostty", "iterm.app", "vscode", "hyper"):
            self.depth = 24
        elif "256color" in term:
            self.depth = 8
        else:
            self.depth = 4

        self.c_accent = (116, 199, 236)
        self.c_accent_hi = (137, 220, 235)
        self.c_gold = (216, 199, 112)
        self.c_lavender = (203, 166, 247)
        self.c_success = (166, 227, 161)
        self.c_warn = (250, 179, 135)
        self.c_danger = (243, 139, 168)
        self.c_text = (235, 238, 245)
        self.c_subtext = (166, 173, 200)
        self.c_muted = (108, 112, 134)
        self.c_border = (76, 82, 108)
        self.c_border_hi = (116, 199, 236)
        self.c_sel_bg = (31, 43, 60)
        self.c_pill_bg = (38, 42, 58)
        self.c_dark_fg = (17, 19, 26)
        self.c_track = (56, 60, 78)

        self.basic_map = {
            self.c_accent: 36,
            self.c_accent_hi: 96,
            self.c_gold: 33,
            self.c_lavender: 35,
            self.c_success: 32,
            self.c_warn: 33,
            self.c_danger: 31,
            self.c_text: 37,
            self.c_subtext: 37,
            self.c_muted: 90,
            self.c_border: 90,
            self.c_border_hi: 36,
            self.c_dark_fg: 30,
            self.c_track: 90,
        }
        self.basic_bg_map = {
            self.c_sel_bg: 44,
            self.c_pill_bg: 40,
            self.c_accent: 46,
            self.c_success: 42,
            self.c_warn: 43,
            self.c_danger: 41,
            self.c_gold: 43,
            self.c_lavender: 45,
        }

    def fg(self, rgb):
        if self.depth == 0:
            return ""
        if self.depth == 24:
            return f"\x1b[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"
        if self.depth == 8:
            return f"\x1b[38;5;{rgb_to_256(*rgb)}m"
        code = self.basic_map.get(rgb, 37)
        return f"\x1b[{code}m"

    def bg(self, rgb):
        if self.depth == 0:
            return ""
        if self.depth == 24:
            return f"\x1b[48;2;{rgb[0]};{rgb[1]};{rgb[2]}m"
        if self.depth == 8:
            return f"\x1b[48;5;{rgb_to_256(*rgb)}m"
        code = self.basic_bg_map.get(rgb, 44)
        return f"\x1b[{code}m"

    def style(self, text, fg=None, bg=None, bold=False, dim=False):
        if self.depth == 0:
            parts = []
            if bold:
                parts.append(self.BOLD)
            if dim:
                parts.append(self.DIM)
            if not parts:
                return text
            return "".join(parts) + text + self.RESET
        parts = []
        if bold:
            parts.append(self.BOLD)
        if dim:
            parts.append(self.DIM)
        if fg is not None:
            parts.append(self.fg(fg))
        if bg is not None:
            parts.append(self.bg(bg))
        if not parts:
            return text
        return "".join(parts) + text + self.RESET

    def fill_bg(self, styled_text, width, bg_rgb):
        padded = pad_right(styled_text, width)
        if self.depth == 0 or bg_rgb is None:
            return padded
        bg_code = self.bg(bg_rgb)
        reapplied = padded.replace(self.RESET, self.RESET + bg_code)
        return bg_code + reapplied + self.RESET

    def link(self, url, label, fg=None, bold=False):
        styled = self.style(label, fg=fg, bold=bold)
        if self.depth == 0:
            return styled
        return f"\x1b]8;;{url}\x07{styled}\x1b]8;;\x07"

    def gradient(self, text, stops, bold=False):
        if self.depth < 8 or len(stops) < 2:
            return self.style(text, fg=stops[0], bold=bold)
        length = len(text)
        if length <= 1:
            return self.style(text, fg=stops[0], bold=bold)
        segs = len(stops) - 1
        out = [self.BOLD] if bold else []
        for idx, ch in enumerate(text):
            if ch == " ":
                out.append(" ")
                continue
            pos = (idx / (length - 1)) * segs
            seg = min(segs - 1, int(pos))
            frac = pos - seg
            c1 = stops[seg]
            c2 = stops[seg + 1]
            r = int(c1[0] + (c2[0] - c1[0]) * frac)
            g = int(c1[1] + (c2[1] - c1[1]) * frac)
            b = int(c1[2] + (c2[2] - c1[2]) * frac)
            out.append(self.fg((r, g, b)) + ch)
        out.append(self.RESET)
        return "".join(out)

    def progress_bar(self, ratio, width, stops=None):
        width = max(6, width)
        clamped = max(0.0, min(1.0, ratio))
        if stops is None:
            stops = (self.c_accent, self.c_accent_hi, self.c_success)
        exact = clamped * width
        full = int(exact)
        rem = exact - full
        has_half = full < width and rem >= 0.35
        empty = width - full - (1 if has_half else 0)
        out = []
        segs = len(stops) - 1
        for idx in range(full):
            pos = (idx / max(1, width - 1)) * segs
            seg = min(segs - 1, int(pos))
            frac = pos - seg
            c1, c2 = stops[seg], stops[seg + 1]
            rgb = (
                int(c1[0] + (c2[0] - c1[0]) * frac),
                int(c1[1] + (c2[1] - c1[1]) * frac),
                int(c1[2] + (c2[2] - c1[2]) * frac),
            )
            out.append(self.fg(rgb) + "━")
        if has_half:
            pos = (full / max(1, width - 1)) * segs
            seg = min(segs - 1, int(pos))
            frac = pos - seg
            c1, c2 = stops[seg], stops[seg + 1]
            rgb = (
                int(c1[0] + (c2[0] - c1[0]) * frac),
                int(c1[1] + (c2[1] - c1[1]) * frac),
                int(c1[2] + (c2[2] - c1[2]) * frac),
            )
            out.append(self.fg(rgb) + "╸")
        if empty > 0:
            out.append(self.fg(self.c_track) + ("━" * empty))
        out.append(self.RESET)
        return "".join(out)


class I18n:
    def __init__(self, i18n_dir, lang_override=None):
        self.i18n_dir = i18n_dir
        self.lang = lang_override or self._detect_language()
        self.fallback = self._load_file("en")
        self.primary = self.fallback if self.lang == "en" else self._load_file(self.lang)

    def _detect_language(self):
        cfg_home = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
        settings_path = os.path.join(cfg_home, "serpantinum", "settings.json")
        if os.path.isfile(settings_path):
            try:
                with open(settings_path, "r", encoding="utf-8") as fh:
                    data = json.load(fh)
                saved = data.get("general", {}).get("language")
                if isinstance(saved, str) and saved and os.path.isfile(os.path.join(self.i18n_dir, f"{saved}.json")):
                    return saved
            except Exception:
                pass
        locale = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
        low = locale.lower()
        code = re.split(r"[_.@]", low)[0] if low else ""
        if code == "uk":
            code = "ua"
        elif code == "zh" and re.match(r"^zh_(tw|hk|mo)", low):
            code = "zh_tw"
        if code and os.path.isfile(os.path.join(self.i18n_dir, f"{code}.json")):
            return code
        return "en"

    def _load_file(self, lang):
        path = os.path.join(self.i18n_dir, f"{lang}.json")
        if not os.path.isfile(path):
            return {}
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return json.load(fh)
        except Exception:
            return {}

    def _lookup(self, store, key):
        cur = store
        for part in key.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return None
            cur = cur[part]
        return cur if isinstance(cur, str) else None

    def t(self, key, **kwargs):
        val = self._lookup(self.primary, key)
        if val is None:
            val = self._lookup(self.fallback, key)
        if val is None:
            val = key
        for k, v in kwargs.items():
            val = val.replace("{" + k + "}", str(v))
        return val


class Terminal:
    def __init__(self):
        self.in_fd = sys.stdin.fileno() if sys.stdin.isatty() else os.open("/dev/tty", os.O_RDONLY)
        self.owns_in = not sys.stdin.isatty()
        self.out_fd = sys.stdout.fileno() if sys.stdout.isatty() else os.open("/dev/tty", os.O_WRONLY)
        self.owns_out = not sys.stdout.isatty()
        self.orig_attrs = None
        self.resized = False
        self.cols = 80
        self.rows = 24
        self.cell_w = 9
        self.cell_h = 18
        self.graphics_proto = "blocks"
        self._last_kitty_placement = None
        self._buf = bytearray()
        self._prev_winch = None
        self.update_size()

    def update_size(self):
        try:
            packed = fcntl.ioctl(self.out_fd, termios.TIOCGWINSZ, b"\x00" * 8)
            rows, cols, xpixel, ypixel = struct.unpack("HHHH", packed)
            if cols > 0 and rows > 0:
                self.cols = cols
                self.rows = rows
                if xpixel > 0 and ypixel > 0:
                    self.cell_w = max(4, xpixel // cols)
                    self.cell_h = max(8, ypixel // rows)
                return
        except Exception:
            pass
        size = shutil.get_terminal_size((80, 24))
        self.cols = size.columns
        self.rows = size.lines

    def detect_graphics(self):
        if os.environ.get("NO_COLOR"):
            self.graphics_proto = "blocks"
            return self.graphics_proto
        term = os.environ.get("TERM", "").lower()
        if term in ("dumb", "linux", "vt100", "vt220", "cons25"):
            self.graphics_proto = "blocks"
            return self.graphics_proto

        reply = bytearray()
        try:
            self.write("\x1b_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\x1b\\\x1b[c")
            deadline = time.monotonic() + 0.08
            while time.monotonic() < deadline:
                rem = max(0.005, deadline - time.monotonic())
                ready, _, _ = select.select([self.in_fd], [], [], rem)
                if not ready:
                    break
                chunk = os.read(self.in_fd, 256)
                if not chunk:
                    break
                reply.extend(chunk)
                if b"\x1b[" in reply and reply.endswith(b"c"):
                    break
        except Exception:
            pass

        text = reply.decode("ascii", errors="ignore")
        if "i=31;OK" in text or "OK\x1b\\" in text:
            self.graphics_proto = "kitty"
            return self.graphics_proto

        da_match = re.search(r"\x1b\[\?([0-9;]+)c", text)
        if da_match and "4" in da_match.group(1).split(";"):
            self.graphics_proto = "sixel"
            return self.graphics_proto

        if os.environ.get("KITTY_WINDOW_ID") or "kitty" in term or os.environ.get("GHOSTTY_RESOURCES_DIR"):
            if not os.environ.get("TMUX"):
                self.graphics_proto = "kitty"
                return self.graphics_proto

        lang_env = (os.environ.get("LC_ALL") or os.environ.get("LC_CTYPE") or os.environ.get("LANG") or "").upper()
        enc = (getattr(sys.stdout, "encoding", "") or "").upper()
        if "UTF" in lang_env or "UTF" in enc:
            self.graphics_proto = "braille"
        else:
            self.graphics_proto = "blocks"
        return self.graphics_proto

    def _on_winch(self, _signum, _frame):
        self.resized = True
        self._last_kitty_placement = None
        self.update_size()

    def enter(self):
        self.orig_attrs = termios.tcgetattr(self.in_fd)
        raw = termios.tcgetattr(self.in_fd)
        raw[0] &= ~(termios.ICRNL | termios.IXON | termios.BRKINT | termios.INPCK | termios.ISTRIP)
        raw[2] |= termios.CS8
        raw[3] &= ~(termios.ECHO | termios.ICANON | termios.IEXTEN | termios.ISIG)
        raw[6][termios.VMIN] = 0
        raw[6][termios.VTIME] = 0
        termios.tcsetattr(self.in_fd, termios.TCSADRAIN, raw)
        self._prev_winch = signal.signal(signal.SIGWINCH, self._on_winch)
        self.update_size()
        self.write("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H")
        self.detect_graphics()

    def leave(self):
        try:
            if self._last_kitty_placement is not None and LOGO_PIXEL_MOD is not None:
                self.write(LOGO_PIXEL_MOD.build_kitty_clear_seq())
                self._last_kitty_placement = None
            self.write("\x1b[?2026l\x1b[0m\x1b[?25h\x1b[?1049l")
        except Exception:
            pass
        if self.orig_attrs is not None:
            try:
                termios.tcsetattr(self.in_fd, termios.TCSADRAIN, self.orig_attrs)
            except Exception:
                pass
            self.orig_attrs = None
        if self._prev_winch is not None:
            try:
                signal.signal(signal.SIGWINCH, self._prev_winch)
            except Exception:
                pass
            self._prev_winch = None
        if self.owns_in:
            try:
                os.close(self.in_fd)
            except Exception:
                pass
            self.owns_in = False
        if self.owns_out:
            try:
                os.close(self.out_fd)
            except Exception:
                pass
            self.owns_out = False

    def write(self, data):
        raw = data.encode("utf-8", errors="replace")
        view = memoryview(raw)
        sent = 0
        while sent < len(raw):
            try:
                n = os.write(self.out_fd, view[sent:])
                if n <= 0:
                    break
                sent += n
            except BlockingIOError:
                select.select([], [self.out_fd], [], 0.05)

    def render_lines(self, lines, graphic=None):
        parts = ["\x1b[?2026h\x1b[H"]
        total = self.rows
        for idx in range(total):
            line = lines[idx] if idx < len(lines) else ""
            parts.append(f"\x1b[{idx + 1};1H{line}\x1b[K")
        parts.append("\x1b[0m")

        if graphic is not None and graphic[0] == "kitty" and LOGO_PIXEL_MOD is not None and LOGO_PNG_BYTES:
            _, row, col, gcols, grows = graphic
            placement = (row, col, gcols, grows)
            if placement != self._last_kitty_placement:
                if self._last_kitty_placement is not None:
                    parts.append(LOGO_PIXEL_MOD.build_kitty_clear_seq())
                parts.append(LOGO_PIXEL_MOD.build_kitty_graphics_seq(LOGO_PNG_BYTES, row, col, gcols, grows))
                self._last_kitty_placement = placement
        else:
            if self._last_kitty_placement is not None and LOGO_PIXEL_MOD is not None:
                parts.append(LOGO_PIXEL_MOD.build_kitty_clear_seq())
                self._last_kitty_placement = None
            if graphic is not None and graphic[0] == "sixel":
                parts.append(graphic[1])

        parts.append("\x1b[?2026l")
        self.write("".join(parts))

    def _fill_buf(self, timeout):
        try:
            ready, _, _ = select.select([self.in_fd], [], [], timeout)
        except InterruptedError:
            return False
        if not ready:
            return False
        try:
            chunk = os.read(self.in_fd, 64)
        except (BlockingIOError, InterruptedError):
            return False
        if not chunk:
            return False
        self._buf.extend(chunk)
        return True

    def read_key(self, timeout=0.05):
        if not self._buf:
            if not self._fill_buf(timeout):
                return None
        b0 = self._buf[0]
        if b0 == 0x1B:
            if len(self._buf) == 1:
                self._fill_buf(0.025)
            if len(self._buf) == 1:
                del self._buf[0]
                return "ESC"
            b1 = self._buf[1]
            if b1 in (ord("["), ord("O")):
                if len(self._buf) < 3:
                    self._fill_buf(0.025)
                if len(self._buf) >= 3:
                    b2 = self._buf[2]
                    if b2 == ord("A"):
                        del self._buf[:3]
                        return "UP"
                    if b2 == ord("B"):
                        del self._buf[:3]
                        return "DOWN"
                    if b2 == ord("C"):
                        del self._buf[:3]
                        return "RIGHT"
                    if b2 == ord("D"):
                        del self._buf[:3]
                        return "LEFT"
                    if b2 == ord("Z"):
                        del self._buf[:3]
                        return "SHIFT_TAB"
                    if b2 == ord("H"):
                        del self._buf[:3]
                        return "HOME"
                    if b2 == ord("F"):
                        del self._buf[:3]
                        return "END"
                    if b1 == ord("[") and b2 in (ord("1"), ord("3"), ord("4"), ord("5"), ord("6"), ord("7"), ord("8")):
                        if len(self._buf) < 4:
                            self._fill_buf(0.025)
                        if len(self._buf) >= 4 and self._buf[3] == ord("~"):
                            del self._buf[:4]
                            return {
                                ord("1"): "HOME",
                                ord("3"): "DELETE",
                                ord("4"): "END",
                                ord("5"): "PGUP",
                                ord("6"): "PGDN",
                                ord("7"): "HOME",
                                ord("8"): "END",
                            }.get(b2, "ESC")
                end = 2
                while end < len(self._buf) and not (0x40 <= self._buf[end] <= 0x7E):
                    end += 1
                del self._buf[: min(len(self._buf), end + 1)]
                return "ESC"
            del self._buf[0]
            return "ESC"

        del self._buf[0]
        if b0 == 0x03:
            return "CTRL_C"
        if b0 in (0x0D, 0x0A):
            return "ENTER"
        if b0 == 0x09:
            return "TAB"
        if b0 in (0x7F, 0x08):
            return "BACKSPACE"
        if b0 == 0x20:
            return "SPACE"
        if b0 < 0x20:
            return None
        if b0 < 0x80:
            return chr(b0)

        need = 1
        if (b0 & 0xE0) == 0xC0:
            need = 2
        elif (b0 & 0xF0) == 0xE0:
            need = 3
        elif (b0 & 0xF8) == 0xF0:
            need = 4
        raw = bytearray([b0])
        while len(raw) < need:
            if not self._buf and not self._fill_buf(0.02):
                break
            if self._buf:
                raw.append(self._buf.pop(0))
        try:
            return raw.decode("utf-8")
        except UnicodeDecodeError:
            return None


@dataclasses.dataclass
class StepItem:
    id: str
    label: str
    status: str = "pending"
    duration: float = 0.0
    sub_ratio: float = -1.0
    sub_text: str = ""
    weight: float = 1.0


@dataclasses.dataclass
class InstallerState:
    preview: bool
    auth_demo: bool
    project_root: str
    modules_dir: str
    repo_slug: str
    install_state: str
    old_version: str
    target_version: str
    target_commit: str
    old_commit: str
    user_name: str
    os_name: str
    cpu_info: str
    gpu_info: str
    telemetry_id: str
    enable_telemetry: bool
    opt_sddm: bool
    replace_dm: bool
    sddm_wayland: bool
    install_full_wallpapers: bool
    selected_compositors: list
    detected_compositor_label: str
    multiple_compositors_detected: bool
    unsupported_compositor_detected: bool
    current_dm: str
    compositor_installed: dict
    required_pkgs: list
    pm_extra_pkgs: list
    sddm_pkgs: list
    sddm_needs_weston: bool
    package_installed: dict
    is_reinstall: bool = False
    do_uninstall: bool = False
    failed_pkgs: list = dataclasses.field(default_factory=list)
    action_result: str = "exit"
    log_path: str = ""

    def active_packages(self):
        pkgs = list(self.required_pkgs)
        for comp in self.selected_compositors:
            pkg = "mangowm" if comp == "mango" else comp
            if pkg not in pkgs:
                pkgs.append(pkg)
        if self.opt_sddm:
            for pkg in self.sddm_pkgs:
                if pkg not in pkgs:
                    pkgs.append(pkg)
            if self.sddm_wayland and self.sddm_needs_weston and "weston" not in pkgs:
                pkgs.append("weston")
        for pkg in self.pm_extra_pkgs:
            if pkg not in pkgs:
                pkgs.append(pkg)
        return pkgs


def build_preview_state(project_root, state_mode, auth_demo):
    version_file = os.path.join(project_root, "version.txt")
    target_version = "2.4.0"
    if os.path.isfile(version_file):
        try:
            with open(version_file, "r", encoding="utf-8") as fh:
                val = fh.read().strip()
                if val:
                    target_version = val
        except Exception:
            pass
    required = list(DEFAULT_REQUIRED_PKGS)
    simulated_missing = {"quickshell", "matugen", "satty", "cliphist", "gpu-screen-recorder", "adw-gtk-theme", "sddm"}
    pkg_status = {pkg: (pkg not in simulated_missing) for pkg in required}
    for comp in ("hyprland", "niri", "sway", "mangowm", "umbriel"):
        pkg_status[comp] = comp in ("hyprland", "niri")
    sddm_pkgs = ["sddm", "qt6-declarative", "qt6-svg"]
    for pkg in sddm_pkgs:
        pkg_status[pkg] = pkg != "sddm"
    pkg_status["weston"] = False
    user_name = os.environ.get("USER") or "serpantinum"
    return InstallerState(
        preview=True,
        auth_demo=auth_demo,
        project_root=project_root,
        modules_dir=os.path.join(project_root, "install", "modules"),
        repo_slug=os.environ.get("REPO_SLUG", "ilyamiro/serpantinum"),
        install_state=state_mode,
        old_version="2.3.8" if state_mode == "current" else "1.9.4",
        target_version=target_version,
        target_commit="9a311fd",
        old_commit="6bf19be" if state_mode == "current" else "",
        user_name=user_name,
        os_name="Arch Linux (Preview)",
        cpu_info="AMD Ryzen 9 7950X 16-Core Processor",
        gpu_info="AMD Radeon RX 7900 XTX",
        telemetry_id="00000000-0000-0000-0000-000000000000",
        enable_telemetry=True,
        opt_sddm=True,
        replace_dm=False,
        sddm_wayland=True,
        install_full_wallpapers=True,
        selected_compositors=["hyprland"],
        detected_compositor_label="hyprland",
        multiple_compositors_detected=False,
        unsupported_compositor_detected=False,
        current_dm="gdm",
        compositor_installed={
            "hyprland": True,
            "niri": True,
            "sway": False,
            "mango": False,
            "umbriel": False,
        },
        required_pkgs=required,
        pm_extra_pkgs=[],
        sddm_pkgs=sddm_pkgs,
        sddm_needs_weston=False,
        package_installed=pkg_status,
    )


def load_real_state(context_path):
    with open(context_path, "r", encoding="utf-8") as fh:
        d = json.load(fh)
    return InstallerState(
        preview=False,
        auth_demo=False,
        project_root=d["project_root"],
        modules_dir=d["modules_dir"],
        repo_slug=d.get("repo_slug", "ilyamiro/serpantinum"),
        install_state=d.get("install_state", "fresh"),
        old_version=d.get("old_version", ""),
        target_version=d.get("target_version", "2.0.0"),
        target_commit=d.get("target_commit", "unknown"),
        old_commit=d.get("old_commit", ""),
        user_name=d.get("user_name", ""),
        os_name=d.get("os_name", ""),
        cpu_info=d.get("cpu_info", ""),
        gpu_info=d.get("gpu_info", ""),
        telemetry_id=d.get("telemetry_id", ""),
        enable_telemetry=bool(d.get("enable_telemetry", True)),
        opt_sddm=bool(d.get("opt_sddm", True)),
        replace_dm=bool(d.get("replace_dm", False)),
        sddm_wayland=bool(d.get("sddm_wayland", False)),
        install_full_wallpapers=bool(d.get("install_full_wallpapers", True)),
        selected_compositors=list(d.get("selected_compositors", [])),
        detected_compositor_label=d.get("detected_compositor_label", ""),
        multiple_compositors_detected=bool(d.get("multiple_compositors_detected", False)),
        unsupported_compositor_detected=bool(d.get("unsupported_compositor_detected", False)),
        current_dm=d.get("current_dm", ""),
        compositor_installed=dict(d.get("compositor_installed", {})),
        required_pkgs=list(d.get("required_pkgs", DEFAULT_REQUIRED_PKGS)),
        pm_extra_pkgs=list(d.get("pm_extra_pkgs", [])),
        sddm_pkgs=list(d.get("sddm_pkgs", ["sddm", "qt6-declarative", "qt6-svg"])),
        sddm_needs_weston=bool(d.get("sddm_needs_weston", False)),
        package_installed=dict(d.get("package_installed", {})),
    )


class PreviewSimulator:
    def __init__(self, state, mode):
        self.state = state
        self.mode = mode
        self.step_scripts = self._build_scripts()

    def _build_scripts(self):
        if self.mode == "uninstall":
            return {
                "uninstall_stop": [
                    (0.20, "[ INFO ] Stopping serpantinumd...", -1, ""),
                    (0.25, "[ INFO ] Stopping serpantinum-core, audio, and gamma daemons...", -1, ""),
                    (0.20, "[ OK ] All Serpantinum services stopped.", -1, ""),
                ],
                "uninstall_reset": [
                    (0.20, "[ INFO ] Restoring GTK, Qt, and Kitty theme configs...", -1, ""),
                    (0.25, "[ INFO ] Resetting color-scheme and environment.d entries...", -1, ""),
                    (0.20, "[ OK ] System defaults restored.", -1, ""),
                ],
                "uninstall_remove": [
                    (0.22, "[ INFO ] Removing /usr/local/bin/serpantinum links...", -1, ""),
                    (0.24, "[ INFO ] Removing SDDM Material You theme and PAM rule...", -1, ""),
                    (0.24, "[ INFO ] Cleaning ~/.local/share/serpantinum and cache...", -1, ""),
                    (0.20, "[ OK ] Serpantinum has been uninstalled.", -1, ""),
                ],
            }

        missing = [p for p in self.state.active_packages() if not self.state.package_installed.get(p, False)]
        if not missing:
            missing = ["quickshell", "matugen", "satty"]
        dep_events = [(0.22, f"[ INFO ] Found {len(missing)} missing packages to install.", 0.05, "resolving")]
        for idx, pkg in enumerate(missing, 1):
            frac = 0.08 + (idx / (len(missing) + 1)) * 0.78
            dep_events.append((0.28, f":: Installing {pkg} ({idx}/{len(missing)})...", frac, f"{pkg} ({idx}/{len(missing)})"))
            dep_events.append((0.18, f"[ OK ] Successfully installed {pkg}", frac + 0.03, f"{pkg} ({idx}/{len(missing)})"))
        dep_events.append((0.25, "[ INFO ] Downloading Iosevka Nerd Font...", 0.92, "Iosevka Nerd Font"))
        dep_events.append((0.20, "[ OK ] Font cache and Qt icon theme configured.", 1.0, ""))

        wp_total = 24 if self.state.install_full_wallpapers else 3
        wp_events = [(0.24, "[ INFO ] Syncing shell-wallpapers repository...", 0.05, "syncing repo")]
        step_inc = max(1, wp_total // 6)
        for cur in range(step_inc, wp_total + 1, step_inc):
            c = min(cur, wp_total)
            wp_events.append((0.18, f"[ INFO ] Installing wallpapers ({c}/{wp_total})", c / wp_total, f"{c}/{wp_total}"))
        if wp_total % step_inc != 0:
            wp_events.append((0.15, f"[ INFO ] Installing wallpapers ({wp_total}/{wp_total})", 1.0, f"{wp_total}/{wp_total}"))

        comps = ", ".join(self.state.selected_compositors) or "hyprland"
        return {
            "prepare": [
                (0.25, "[ INFO ] Checking environment and release metadata...", -1, ""),
                (0.20, f"[ OK ] Target release {self.state.target_version} ({self.state.target_commit}) verified.", -1, ""),
            ],
            "migrate": [
                (0.25, "[ INFO ] Stopping legacy shell watchers...", -1, ""),
                (0.30, f"[ OK ] Backed up legacy configs for {comps}.", -1, ""),
            ],
            "backup": [
                (0.28, f"[ INFO ] Creating timestamped backup for {comps}...", -1, ""),
                (0.20, "[ OK ] Existing compositor configurations preserved.", -1, ""),
            ],
            "deps": dep_events,
            "ski": [
                (0.28, "[ INFO ] Fetching latest Ski release archive...", 0.35, "downloading"),
                (0.24, "[ INFO ] Verifying SHA256SUMS checksum...", 0.72, "verifying"),
                (0.22, "[ OK ] Installed Ski 0.9.4", 1.0, ""),
            ],
            "audio": [
                (0.26, "[ INFO ] Fetching serpantinum-audio prebuilt release...", 0.40, "downloading"),
                (0.26, "[ OK ] Installed Serpantinum audio engine 0.4.2", 1.0, ""),
            ],
            "gamma": [
                (0.24, "[ INFO ] Fetching serpantinum-gamma prebuilt release...", 0.45, "downloading"),
                (0.22, "[ OK ] Installed Serpantinum blue light filter 0.3.1", 1.0, ""),
            ],
            "core": [
                (0.24, "[ INFO ] Fetching serpantinum-core prebuilt release...", 0.45, "downloading"),
                (0.22, "[ OK ] Installed Serpantinum core services 0.5.0", 1.0, ""),
            ],
            "deploy": [
                (0.24, "[ INFO ] Deploying shell binaries and Quickshell modules...", 0.35, "shell"),
                (0.28, f"[ INFO ] Deploying compositor configs ({comps})...", 0.75, comps),
                (0.20, "[ OK ] PAM service and CLI symlinks updated.", 1.0, ""),
            ],
            "sddm": [
                (0.24, "[ INFO ] Installing Material You SDDM theme...", 0.40, "theme"),
                (0.24, f"[ INFO ] Writing /etc/sddm.conf.d/10-material-you.conf ({'wayland' if self.state.sddm_wayland else 'x11'})...", 0.75, "config"),
                (0.20, "[ OK ] SDDM Material You theme installed and service enabled.", 1.0, ""),
            ],
            "wallpapers": wp_events,
            "config": [
                (0.22, "[ INFO ] Merging ~/.config/serpantinum/settings.json...", 0.33, "settings"),
                (0.24, "[ INFO ] Configuring Ski XDG portal and MIME defaults...", 0.66, "portals"),
                (0.24, "[ OK ] PipeWire, NetworkManager, and power-profiles-daemon ready.", 1.0, ""),
            ],
            "finalize": [
                (0.22, "[ INFO ] Writing version state metadata...", -1, ""),
                (0.20, f"[ OK ] Serpantinum {self.state.target_version} ready.", -1, ""),
            ],
        }


class InstallerTUI:
    def __init__(self, state, i18n, term=None, logo_mode="auto"):
        self.state = state
        self.i18n = i18n
        self.theme = Theme()
        self.term = term or Terminal()
        self.logo_mode = logo_mode
        self._pending_graphic = None
        self._sixel_cache = {}
        self._braille_cache = {}
        self._pixel_logo_cache = {}

        self.screen = "main"
        self.main_focus_section = "config"
        self.main_config_idx = 0
        self.main_action_idx = 0

        self.toast_text = ""
        self.toast_kind = "info"
        self.toast_until = 0.0

        self.pkg_tab = 0
        self.pkg_cursor = 0
        self.pkg_scroll = 0
        self.pkg_query = ""
        self.pkg_searching = False

        self.comp_cursor = 0
        self.sddm_cursor = 0
        self.uninstall_cursor = 0

        self.auth_password = ""
        self.auth_error = ""
        self.auth_busy = False
        self.auth_next_mode = "install"
        self.sudo_password = ""
        self.sudo_keepalive_stop = threading.Event()
        self.sudo_keepalive_thread = None

        self.run_mode = "install"
        self.steps = []
        self.active_step_idx = 0
        self.display_progress = 0.0
        self.run_started_at = 0.0
        self.run_total_duration = 0.0
        self.log_lines = collections.deque(maxlen=400)
        self.log_expanded = False
        self.log_scroll = 0
        self.spinner_idx = 0
        self.last_spinner_tick = 0.0
        self.step_failed = False
        self.fail_btn_idx = 0
        self.waiting_input = False
        self.input_buffer = ""
        self.input_masked = False
        self.fast_forward = False
        self.complete_btn_idx = 0

        self.failed_pkgs_file = ""
        self.install_log_file = ""

    def t(self, key, **kwargs):
        return self.i18n.t(key, **kwargs)

    def set_toast(self, text, kind="info", duration=3.0):
        self.toast_text = text
        self.toast_kind = kind
        self.toast_until = time.monotonic() + duration

    def active_toast(self):
        if self.toast_text and time.monotonic() < self.toast_until:
            return self.toast_text, self.toast_kind
        self.toast_text = ""
        return "", "info"

    def main_actions(self):
        if self.state.install_state == "current":
            return [
                ("update", self.t("installer.ui.menu_update"), "primary"),
                ("reinstall", self.t("installer.ui.menu_reinstall"), "warn"),
                ("uninstall", self.t("installer.ui.menu_uninstall"), "danger"),
                ("exit", self.t("installer.ui.menu_exit"), "subtle"),
            ]
        return [
            ("install", self.t("installer.ui.menu_install"), "primary"),
            ("exit", self.t("installer.ui.menu_exit"), "subtle"),
        ]

    def sddm_rows(self):
        rows = ["install"]
        if self.state.current_dm and self.state.current_dm != "sddm":
            rows.append("replace")
        rows.append("wayland")
        rows.append("done")
        return rows

    def filtered_packages(self):
        active = self.state.active_packages()
        q = self.pkg_query.strip().lower()
        out = []
        for pkg in active:
            installed = bool(self.state.package_installed.get(pkg, False))
            if self.pkg_tab == 1 and installed:
                continue
            if self.pkg_tab == 2 and not installed:
                continue
            if q and q not in pkg.lower():
                continue
            out.append((pkg, installed))
        return out

    def toggle_compositor(self, comp_id):
        if comp_id in self.state.selected_compositors:
            self.state.selected_compositors.remove(comp_id)
        else:
            self.state.selected_compositors.append(comp_id)

    def frame_box(self, inner_lines, width, border_color=None, title=None, right_badge=None):
        th = self.theme
        bc = border_color or th.c_border
        inner_w = max(10, width - 2)
        if title or right_badge:
            left_part = f" {title} " if title else ""
            right_part = f" {right_badge} " if right_badge else ""
            left_w = display_width(left_part)
            right_w = display_width(right_part)
            fill = max(0, inner_w - left_w - right_w - 2)
            top = (
                th.style("╭─", fg=bc)
                + left_part
                + th.style("─" * fill, fg=bc)
                + right_part
                + th.style("─╮", fg=bc)
            )
        else:
            top = th.style("╭" + ("─" * inner_w) + "╮", fg=bc)
        bot = th.style("╰" + ("─" * inner_w) + "╯", fg=bc)
        vbar = th.style("│", fg=bc)
        out = [top]
        for line in inner_lines:
            if line == "__SEP__":
                out.append(th.style("├" + ("─" * inner_w) + "┤", fg=bc))
            elif isinstance(line, str) and line.startswith("__SEP_TOP__:"):
                pos = int(line.split(":", 1)[1])
                out.append(th.style("├" + ("─" * pos) + "┬" + ("─" * max(0, inner_w - pos - 1)) + "┤", fg=bc))
            elif isinstance(line, str) and line.startswith("__SEP_BOT__:"):
                pos = int(line.split(":", 1)[1])
                out.append(th.style("├" + ("─" * pos) + "┴" + ("─" * max(0, inner_w - pos - 1)) + "┤", fg=bc))
            else:
                out.append(vbar + pad_right(line, inner_w) + vbar)
        out.append(bot)
        return out

    def render_centered(self, box_lines, footer_line=""):
        cols = self.term.cols
        rows = self.term.rows
        min_cols, min_rows = 60, 18
        if cols < min_cols or rows < min_rows:
            msg = self.t("installer.ui.terminal_too_small", cols=min_cols, rows=min_rows)
            wrapped = wrap_plain(msg, max(10, cols - 4))
            top_pad = max(0, (rows - len(wrapped)) // 2)
            canvas = [""] * top_pad
            for ln in wrapped:
                canvas.append(center_styled(self.theme.style(ln, fg=self.theme.c_warn, bold=True), cols))
            return canvas

        total_h = len(box_lines) + (1 if footer_line else 0)
        top_pad = max(0, (rows - total_h) // 2)
        box_w = display_width(box_lines[0]) if box_lines else 0
        left_pad = " " * max(0, (cols - box_w) // 2)
        canvas = [""] * top_pad
        for ln in box_lines:
            canvas.append(left_pad + ln)
        if footer_line and len(canvas) < rows:
            canvas.append(center_styled(footer_line, cols))
        return canvas

    def render_key_hints(self, pairs):
        th = self.theme
        chunks = []
        for k, desc in pairs:
            chunks.append(th.style(k, fg=th.c_accent_hi, bold=True) + " " + th.style(desc, fg=th.c_muted))
        return ("   ").join(chunks)

    def render_pill_toggle(self, is_first_active, first_label, second_label, focused=False):
        th = self.theme
        bg = th.c_sel_bg if focused else None
        if is_first_active:
            left = th.style(f"● {first_label}", fg=th.c_success, bg=bg, bold=True)
            right = th.style(f"○ {second_label}", fg=th.c_muted, bg=bg)
        else:
            left = th.style(f"○ {first_label}", fg=th.c_muted, bg=bg)
            right = th.style(f"● {second_label}", fg=th.c_gold, bg=bg, bold=True)
        sep = th.style("  ", bg=bg)
        return left + sep + right

    def render_button(self, label, variant, focused, prefix=""):
        th = self.theme
        text = f" {prefix}{label} " if prefix else f" {label} "
        if focused:
            bg_map = {
                "primary": th.c_success,
                "accent": th.c_accent,
                "warn": th.c_warn,
                "danger": th.c_danger,
                "subtle": th.c_subtext,
            }
            bg = bg_map.get(variant, th.c_accent)
            return th.style(text, fg=th.c_dark_fg, bg=bg, bold=True)
        fg_map = {
            "primary": th.c_success,
            "accent": th.c_accent_hi,
            "warn": th.c_warn,
            "danger": th.c_danger,
            "subtle": th.c_subtext,
        }
        fg = fg_map.get(variant, th.c_subtext)
        return th.style("[", fg=th.c_border) + th.style(text, fg=fg, bold=(variant == "primary")) + th.style("]", fg=th.c_border)

    def effective_logo_mode(self):
        if self.logo_mode != "auto":
            mode = self.logo_mode
        else:
            mode = getattr(self.term, "graphics_proto", "braille")
        if mode == "kitty" and LOGO_PNG_BYTES is None:
            mode = "braille"
        if mode == "sixel" and LOGO_RGBA_INFO is None:
            mode = "braille"
        if mode == "braille" and self.theme.depth == 0:
            mode = "blocks"
        return mode

    def logo_block(self, max_rows):
        if LOGO_PIXEL_MOD is None or max_rows < 6:
            return [], None, 0
        mode = self.effective_logo_mode()

        if mode in ("kitty", "sixel"):
            grows = min(12, max(6, max_rows))
            cell_w = getattr(self.term, "cell_w", 9)
            cell_h = getattr(self.term, "cell_h", 18)
            img_w, img_h = (LOGO_RGBA_INFO[0], LOGO_RGBA_INFO[1]) if LOGO_RGBA_INFO else (256, 272)
            px_h = grows * cell_h
            px_w = max(cell_w * 8, int(round(px_h * (img_w / img_h))))
            gcols = max(12, min(26, int(round(px_w / cell_w))))
            return [" " * gcols] * grows, (mode, gcols, grows, px_w, px_h), gcols

        if mode == "braille":
            presets = (
                (24, 12),
                (22, 11),
                (20, 10),
                (18, 9),
                (16, 8),
                (14, 7),
                (12, 6),
            )
            chosen = None
            for c, r in presets:
                if r <= max_rows:
                    chosen = (c, r)
                    break
            if chosen is None:
                return [], None, 0
            key = (chosen, self.theme.depth)
            if key not in self._braille_cache:
                self._braille_cache[key] = LOGO_PIXEL_MOD.render_braille_logo_lines(
                    cols=chosen[0],
                    rows=chosen[1],
                    palette="installer",
                    color_depth=self.theme.depth,
                    rgba_info=LOGO_RGBA_INFO,
                )
            return self._braille_cache[key], None, chosen[0]

        lines = self.pixel_logo_lines(max_rows)
        w = display_width(lines[0]) if lines else 0
        return lines, None, w

    def pixel_logo_lines(self, max_rows):
        if LOGO_PIXEL_MOD is None or max_rows < 6:
            return []
        depth = self.theme.depth
        presets = (
            (24, 24, 0.42),
            (22, 22, 0.42),
            (20, 20, 0.44),
            (18, 18, 0.44),
            (16, 16, 0.44),
            (14, 14, 0.44),
            (12, 12, 0.44),
        )
        chosen = None
        for w, h, thresh in presets:
            if (h // 2) <= max_rows:
                chosen = (w, h, thresh)
                break
        if chosen is None:
            return []
        key = (chosen, depth)
        if key not in self._pixel_logo_cache:
            w, h, thresh = chosen
            self._pixel_logo_cache[key] = LOGO_PIXEL_MOD.render_scaled_logo_lines(
                width=w,
                height=h,
                palette="installer",
                color_depth=depth,
                threshold=thresh,
            )
        return self._pixel_logo_cache[key]

    def build_header_lockup(self, block_w, max_logo_rows, right_extra_lines):
        th = self.theme
        logo_stops = (th.c_accent_hi, th.c_accent, th.c_lavender, th.c_gold)
        logo_lines, graphic_spec, logo_w = self.logo_block(max_logo_rows)
        gap = 3
        avail_w = block_w - logo_w - gap if logo_lines else block_w
        allow_tall = len(logo_lines) >= 9 if logo_lines else max_logo_rows >= 9

        if allow_tall and len(WORDMARK_6[0]) <= avail_w:
            wm_raw = WORDMARK_6
        elif allow_tall and len(WORDMARK_5[0]) <= avail_w:
            wm_raw = WORDMARK_5
        elif len(WORDMARK_3[0]) <= avail_w:
            wm_raw = WORDMARK_3
        elif len(WORDMARK_2[0]) <= avail_w:
            wm_raw = WORDMARK_2
        else:
            wm_raw = ("◆  S E R P A N T I N U M  ◆",)

        wm_styled = [th.gradient(r, logo_stops, bold=True) for r in wm_raw]
        right_block = list(wm_styled)
        if right_extra_lines:
            if len(logo_lines) >= len(wm_styled) + len(right_extra_lines) + 1:
                right_block.append("")
            right_block.extend(right_extra_lines)

        if not logo_lines:
            return [center_styled(ln, block_w) for ln in right_block], None, 0

        max_right_w = max(display_width(ln) for ln in right_block)
        avail_right_w = max(10, block_w - logo_w - gap)
        right_w = min(max_right_w, avail_right_w)
        lockup_w = logo_w + gap + right_w
        left_margin = max(0, (block_w - lockup_w) // 2)

        total_rows = max(len(logo_lines), len(right_block))
        logo_top = (total_rows - len(logo_lines)) // 2
        right_top = (total_rows - len(right_block)) // 2

        out = []
        spacer = " " * gap
        prefix = " " * left_margin
        for i in range(total_rows):
            li = i - logo_top
            ri = i - right_top
            l_part = pad_right(logo_lines[li], logo_w) if 0 <= li < len(logo_lines) else (" " * logo_w)
            r_part = truncate_styled(right_block[ri], right_w) if 0 <= ri < len(right_block) else ""
            out.append(prefix + l_part + spacer + r_part)
        return out, graphic_spec, (left_margin, logo_top)

    def _build_graphic_payload(self, graphic_spec, top_pad, left_pad_len, graphic_pos):
        if graphic_spec is None or LOGO_PIXEL_MOD is None:
            return None
        mode, gcols, grows, px_w, px_h = graphic_spec
        col_off, row_off = graphic_pos
        row = top_pad + row_off + 1
        col = max(1, 1 + left_pad_len + col_off)
        if mode == "kitty":
            return ("kitty", row, col, gcols, grows)
        if mode == "sixel":
            skey = (px_w, px_h, row, col)
            if skey not in self._sixel_cache:
                self._sixel_cache[skey] = LOGO_PIXEL_MOD.build_sixel_seq(LOGO_RGBA_INFO, px_w, px_h, row, col)
            return ("sixel", self._sixel_cache[skey])
        return None

    def render_centered_block(self, content_lines, width, footer_line="", graphic_spec=None, graphic_pos=(0, 0)):
        cols = self.term.cols
        rows = self.term.rows
        min_cols, min_rows = 60, 18
        if cols < min_cols or rows < min_rows:
            self._pending_graphic = None
            msg = self.t("installer.ui.terminal_too_small", cols=min_cols, rows=min_rows)
            wrapped = wrap_plain(msg, max(10, cols - 4))
            top_pad = max(0, (rows - len(wrapped)) // 2)
            canvas = [""] * top_pad
            for ln in wrapped:
                canvas.append(center_styled(self.theme.style(ln, fg=self.theme.c_warn, bold=True), cols))
            return canvas

        total_h = len(content_lines) + (1 if footer_line else 0)
        top_pad = max(0, (rows - total_h) // 2)
        left_pad_len = max(0, (cols - width) // 2)
        self._pending_graphic = self._build_graphic_payload(graphic_spec, top_pad, left_pad_len, graphic_pos)
        left_pad = " " * left_pad_len
        canvas = [""] * top_pad
        for ln in content_lines:
            canvas.append(left_pad + ln if ln else "")
        if footer_line and len(canvas) < rows:
            canvas.append(center_styled(footer_line, cols))
        return canvas

    def render_main_screen(self):
        th = self.theme
        cols = self.term.cols
        rows = self.term.rows
        block_w = min(max(62, cols - 4), 102)
        show_cards = block_w >= 76 and rows >= 24
        base_body_h = (15 if show_cards else 10) + (2 if rows >= 32 else 0)
        avail_logo_rows = max(0, rows - base_body_h)

        tagline = th.style(self.t("installer.ui.tagline"), fg=th.c_subtext)
        commit_s = th.style(f" ({self.state.target_commit})", fg=th.c_muted)
        if self.state.install_state == "current":
            mode_pill = th.style(self.t("installer.ui.mode_current"), fg=th.c_accent_hi, bold=True)
            if self.state.old_version:
                ver_part = (
                    mode_pill
                    + "  "
                    + th.style(f"v{self.state.old_version}", fg=th.c_muted)
                    + th.style(" → ", fg=th.c_border)
                    + th.style(f"v{self.state.target_version}", fg=th.c_gold, bold=True)
                    + commit_s
                )
            else:
                ver_part = mode_pill + "  " + th.style(f"v{self.state.target_version}", fg=th.c_gold, bold=True) + commit_s
        elif self.state.install_state == "legacy":
            ver_part = (
                th.style(self.t("installer.ui.mode_legacy"), fg=th.c_warn, bold=True)
                + "  "
                + th.style(f"v{self.state.target_version}", fg=th.c_gold, bold=True)
                + commit_s
            )
        else:
            ver_part = th.style(f"v{self.state.target_version}", fg=th.c_gold, bold=True) + commit_s

        header_lines, graphic_spec, graphic_pos = self.build_header_lockup(
            block_w,
            min(12, avail_logo_rows),
            [tagline, ver_part],
        )
        lines = list(header_lines)
        if rows >= 31:
            lines.append("")

        if show_cards:
            gap_w = 2
            left_card_w = (block_w - gap_w) // 2 + 1
            right_card_w = block_w - gap_w - left_card_w
            left_in = left_card_w - 2
            right_in = right_card_w - 2

            def kv(lbl, val, w):
                l_col = 7
                l_txt = th.style(pad_right(truncate_plain(lbl, l_col - 1), l_col), fg=th.c_muted)
                v_txt = truncate_plain(val, max(6, w - l_col - 4))
                return "  " + l_txt + th.style(v_txt, fg=th.c_text)

            sys_rows = [
                kv(self.t("installer.ui.user").rstrip(":"), self.state.user_name, left_in),
                kv(self.t("installer.ui.os").rstrip(":"), self.state.os_name, left_in),
                kv(self.t("installer.ui.cpu").rstrip(":"), self.state.cpu_info, left_in),
                kv(self.t("installer.ui.gpu").rstrip(":"), self.state.gpu_info, left_in),
            ]

            gh_url = f"https://github.com/{self.state.repo_slug}"
            tg_url = "https://t.me/serpantinum_git"
            tw_url = "https://twitter.com/ilyamirox"
            rd_url = "https://reddit.com/u/ilyamiro1"
            kf_url = "https://ko-fi.com/ilyamiro"

            def lk(lbl, link_str):
                l_col = 10
                l_txt = th.style(pad_right(truncate_plain(lbl, l_col - 1), l_col), fg=th.c_muted)
                return "  " + l_txt + link_str

            social_links = (
                th.link(tw_url, "@ilyamirox", fg=th.c_accent_hi)
                + th.style(" · ", fg=th.c_muted)
                + th.link(rd_url, "u/ilyamiro1", fg=th.c_warn)
            )
            link_rows = [
                lk(self.t("installer.ui.github").rstrip(":"), th.link(gh_url, truncate_plain(f"github.com/{self.state.repo_slug}", max(8, right_in - 13)), fg=th.c_success)),
                lk(self.t("installer.ui.telegram").rstrip(":"), th.link(tg_url, "t.me/serpantinum_git", fg=th.c_accent)),
                lk(self.t("installer.ui.social").rstrip(":"), social_links),
                lk(self.t("installer.ui.donate").rstrip(":"), th.link(kf_url, "ko-fi.com/ilyamiro", fg=th.c_lavender, bold=True)),
            ]

            sys_box = self.frame_box(sys_rows, left_card_w, border_color=th.c_border, title=th.style(self.t("installer.ui.section_system"), fg=th.c_accent, bold=True))
            link_box = self.frame_box(link_rows, right_card_w, border_color=th.c_border, title=th.style(self.t("installer.ui.section_links"), fg=th.c_accent, bold=True))
            spacer = " " * gap_w
            for l_ln, r_ln in zip(sys_box, link_box):
                lines.append(l_ln + spacer + r_ln)
        else:
            info_line = f"{self.state.user_name} · {self.state.os_name} · {self.state.cpu_info}"
            lines.append(center_styled(th.style(truncate_plain(info_line, block_w - 4), fg=th.c_subtext), block_w))

        if rows >= 35:
            lines.append("")

        cfg_in = block_w - 2
        active_pkgs = self.state.active_packages()
        missing_count = sum(1 for p in active_pkgs if not self.state.package_installed.get(p, False))
        pkg_meta = (
            th.style(f"{self.t('installer.ui.pkg_count_short', count=len(active_pkgs))} · ", fg=th.c_subtext)
            + (
                th.style(self.t("installer.ui.status_missing_count", missing=missing_count), fg=th.c_warn, bold=True)
                if missing_count > 0
                else th.style(self.t("installer.ui.status_all_installed"), fg=th.c_success)
            )
        )

        if self.state.selected_compositors:
            comp_names = ", ".join(
                dict(COMPOSITORS).get(c, c.title()) for c in self.state.selected_compositors
            )
            comp_meta = th.style(comp_names, fg=th.c_success, bold=True)
        else:
            comp_meta = th.style(f"! {self.t('installer.ui.status_none_selected')}", fg=th.c_danger, bold=True)

        if self.state.opt_sddm:
            backend = self.t("installer.ui.status_wayland") if self.state.sddm_wayland else self.t("installer.ui.status_x11")
            sddm_meta = th.style(f"● {self.t('installer.ui.status_enabled')}", fg=th.c_success, bold=True) + th.style(f" · {backend}", fg=th.c_subtext)
        else:
            sddm_meta = th.style(f"○ {self.t('installer.ui.status_disabled')}", fg=th.c_muted)

        config_rows = [
            (self.t("installer.ui.packages_row"), pkg_meta, f"{self.t('installer.ui.action_inspect')} ›"),
            (self.t("installer.ui.compositors_row"), comp_meta, f"{self.t('installer.ui.action_configure')} ›"),
            (self.t("installer.ui.menu_sddm"), sddm_meta, f"{self.t('installer.ui.action_configure')} ›"),
            (
                self.t("installer.ui.menu_wallpapers"),
                self.render_pill_toggle(
                    self.state.install_full_wallpapers,
                    self.t("installer.ui.status_full_pack"),
                    self.t("installer.ui.status_random_pack"),
                    focused=(self.main_focus_section == "config" and self.main_config_idx == 3),
                ),
                self.t("installer.ui.action_toggle"),
            ),
            (
                self.t("installer.ui.menu_telemetry"),
                self.render_pill_toggle(
                    self.state.enable_telemetry,
                    self.t("installer.ui.status_enabled"),
                    self.t("installer.ui.status_disabled"),
                    focused=(self.main_focus_section == "config" and self.main_config_idx == 4),
                ),
                self.t("installer.ui.action_toggle"),
            ),
        ]

        label_w = 24 if cfg_in >= 72 else 20
        action_w = 13
        meta_w = max(14, cfg_in - label_w - action_w - 5)

        cfg_lines = []
        for idx, (label, meta, act) in enumerate(config_rows):
            focused = self.main_focus_section == "config" and self.main_config_idx == idx
            if focused:
                bg = th.c_sel_bg
                bar = th.style(" ▎", fg=th.c_accent_hi, bg=bg, bold=True)
                l_s = th.style(pad_right(truncate_plain(label, label_w), label_w), fg=th.c_text, bg=bg, bold=True)
                m_s = th.fill_bg(" " + meta, meta_w + 1, bg)
                a_s = th.style(f"{act:>{action_w}} ", fg=th.c_accent_hi, bg=bg, bold=True)
                row_str = th.fill_bg(bar + l_s + m_s + a_s, cfg_in, bg)
            else:
                bar = "  "
                l_s = th.style(pad_right(truncate_plain(label, label_w), label_w), fg=th.c_text)
                m_s = pad_right(meta, meta_w)
                a_s = th.style(f"{act:>{action_w}} ", fg=th.c_muted)
                row_str = bar + l_s + " " + m_s + a_s
            cfg_lines.append(row_str)

        cfg_bc = th.c_border_hi if self.main_focus_section == "config" else th.c_border
        preview_badge = th.style(f"◆ {self.t('installer.ui.preview_badge')}", fg=th.c_gold, bold=True) if self.state.preview else None
        cfg_box = self.frame_box(cfg_lines, block_w, border_color=cfg_bc, title=th.style(self.t("installer.ui.section_config"), fg=th.c_accent, bold=True), right_badge=preview_badge)
        lines.extend(cfg_box)

        toast_txt, toast_kind = self.active_toast()
        if toast_txt:
            tc = th.c_danger if toast_kind == "error" else (th.c_warn if toast_kind == "warn" else th.c_accent_hi)
            prefix = "! " if toast_kind in ("error", "warn") else "◆ "
            lines.append(center_styled(th.style(prefix + truncate_plain(toast_txt, block_w - 6), fg=tc, bold=True), block_w))
        elif rows >= 35:
            lines.append("")

        actions = self.main_actions()
        btn_parts = []
        for idx, (_aid, alabel, variant) in enumerate(actions):
            focused = self.main_focus_section == "actions" and self.main_action_idx == idx
            pref = "▸ " if variant == "primary" else ""
            btn_parts.append(self.render_button(alabel, variant, focused, prefix=pref))
        lines.append(center_styled("   ".join(btn_parts), block_w))
        if rows >= 37:
            lines.append("")

        hints = [
            ("↑↓", self.t("installer.ui.hint_navigate")),
            ("←→", self.t("installer.ui.hint_switch")),
            ("Enter", self.t("installer.ui.hint_select")),
        ]
        if self.state.preview:
            hints.append(("s", self.t("installer.ui.preview_state_hint")))
        hints.append(("q", self.t("installer.ui.hint_quit")))
        return self.render_centered_block(lines, block_w, self.render_key_hints(hints), graphic_spec=graphic_spec, graphic_pos=graphic_pos)

    def render_packages_screen(self):
        th = self.theme
        cols = self.term.cols
        rows = self.term.rows
        frame_w = min(max(62, cols - 4), 84)
        inner_w = frame_w - 2

        all_pkgs = self.state.active_packages()
        installed_total = sum(1 for p in all_pkgs if self.state.package_installed.get(p, False))
        missing_total = len(all_pkgs) - installed_total
        filtered = self.filtered_packages()
        if self.pkg_cursor >= len(filtered):
            self.pkg_cursor = max(0, len(filtered) - 1)

        list_h = max(6, min(16, rows - 12))
        if self.pkg_cursor < self.pkg_scroll:
            self.pkg_scroll = self.pkg_cursor
        elif self.pkg_cursor >= self.pkg_scroll + list_h:
            self.pkg_scroll = self.pkg_cursor - list_h + 1

        lines = []
        summary = self.t("installer.ui.pkg_summary", total=len(all_pkgs), installed=installed_total, missing=missing_total)
        lines.append("  " + th.style(summary, fg=th.c_subtext))

        tabs = [
            f"{self.t('installer.ui.pkg_tab_all')} ({len(all_pkgs)})",
            f"{self.t('installer.ui.pkg_tab_missing')} ({missing_total})",
            f"{self.t('installer.ui.pkg_tab_installed')} ({installed_total})",
        ]
        tab_parts = []
        for idx, lbl in enumerate(tabs):
            if idx == self.pkg_tab:
                tab_parts.append(th.style(f" {lbl} ", fg=th.c_dark_fg, bg=th.c_accent, bold=True))
            else:
                tab_parts.append(th.style(f" {lbl} ", fg=th.c_subtext))
        lines.append("  " + "  ".join(tab_parts))

        if self.pkg_searching or self.pkg_query:
            cursor_sym = th.style("▎", fg=th.c_accent_hi, bold=True) if self.pkg_searching else ""
            search_line = th.style("  / ", fg=th.c_accent_hi, bold=True) + th.style(self.pkg_query, fg=th.c_text) + cursor_sym
        else:
            search_line = th.style("  / " + self.t("installer.ui.pkg_search_placeholder"), fg=th.c_muted)
        lines.append(search_line)
        lines.append("__SEP__")

        total_items = len(filtered)
        if total_items == 0:
            pad_top = list_h // 2
            for i in range(list_h):
                if i == pad_top:
                    lines.append(center_styled(th.style(self.t("installer.ui.pkg_search_empty"), fg=th.c_muted), inner_w))
                else:
                    lines.append("")
        else:
            thumb_h = max(1, int(list_h * (list_h / max(list_h, total_items))))
            max_scroll = max(1, total_items - list_h)
            thumb_top = int((self.pkg_scroll / max_scroll) * max(0, list_h - thumb_h)) if total_items > list_h else 0

            badge_w = 16
            name_w = max(16, inner_w - badge_w - 10)
            for row_i in range(list_h):
                item_i = self.pkg_scroll + row_i
                sb_char = (
                    th.style("┃", fg=th.c_accent)
                    if total_items > list_h and thumb_top <= row_i < thumb_top + thumb_h
                    else (th.style("│", fg=th.c_border) if total_items > list_h else " ")
                )
                if item_i < total_items:
                    pkg, is_inst = filtered[item_i]
                    focused = item_i == self.pkg_cursor
                    icon = "✓" if is_inst else "↓"
                    icon_col = th.c_success if is_inst else th.c_warn
                    badge_txt = self.t("installer.ui.pkg_badge_installed") if is_inst else self.t("installer.ui.pkg_badge_missing")
                    if focused:
                        bg = th.c_sel_bg
                        row_str = (
                            th.style(" ▎", fg=th.c_accent_hi, bg=bg, bold=True)
                            + th.style(f"{icon} ", fg=icon_col, bg=bg, bold=True)
                            + th.style(pad_right(truncate_plain(pkg, name_w), name_w), fg=th.c_text, bg=bg, bold=True)
                            + th.style(f"{badge_txt:>{badge_w}}", fg=icon_col, bg=bg, bold=True)
                            + th.style("  ", bg=bg)
                            + sb_char
                            + " "
                        )
                    else:
                        row_str = (
                            "  "
                            + th.style(f"{icon} ", fg=icon_col)
                            + th.style(pad_right(truncate_plain(pkg, name_w), name_w), fg=th.c_text)
                            + th.style(f"{badge_txt:>{badge_w}}", fg=icon_col if not is_inst else th.c_muted)
                            + "  "
                            + sb_char
                            + " "
                        )
                    lines.append(row_str)
                else:
                    lines.append(" " * (inner_w - 2) + sb_char + " ")

        title = th.style(self.t("installer.ui.pkg_title"), fg=th.c_accent_hi, bold=True)
        box = self.frame_box(lines, frame_w, border_color=th.c_border_hi, title=title)
        hints = [
            ("↑↓", self.t("installer.ui.hint_scroll")),
            ("←→", self.t("installer.ui.hint_filter")),
            ("/", self.t("installer.ui.hint_search")),
            ("Esc", self.t("installer.ui.hint_back")),
        ]
        return self.render_centered(box, self.render_key_hints(hints))

    def render_compositors_screen(self):
        th = self.theme
        frame_w = min(max(58, self.term.cols - 6), 68)
        inner_w = frame_w - 2

        lines = []
        sub = self.t("installer.ui.compositors_subtitle", count=len(self.state.selected_compositors))
        lines.append("  " + th.style(sub, fg=th.c_subtext) + "   " + th.style(self.t("installer.ui.compositors_hint"), fg=th.c_muted))
        lines.append("__SEP__")

        name_w = max(16, inner_w - 25)
        for idx, (cid, cname) in enumerate(COMPOSITORS):
            selected = cid in self.state.selected_compositors
            installed = bool(self.state.compositor_installed.get(cid, False))
            focused = self.comp_cursor == idx
            chk = "[✓]" if selected else "[ ]"
            chk_col = th.c_success if selected else th.c_muted
            st_txt = self.t("installer.ui.installed").strip().strip("()") if installed else self.t("installer.ui.not_installed").strip().strip("()")
            st_col = th.c_success if installed else th.c_muted

            if focused:
                bg = th.c_sel_bg
                row = th.fill_bg(
                    th.style(" ▎", fg=th.c_accent_hi, bg=bg, bold=True)
                    + th.style(f"{chk} ", fg=chk_col, bg=bg, bold=True)
                    + th.style(pad_right(cname, name_w), fg=th.c_text, bg=bg, bold=True)
                    + th.style(f"{st_txt:>16}  ", fg=st_col, bg=bg),
                    inner_w,
                    bg,
                )
            else:
                row = (
                    "  "
                    + th.style(f"{chk} ", fg=chk_col)
                    + th.style(pad_right(cname, name_w), fg=th.c_text)
                    + th.style(f"{st_txt:>16}  ", fg=st_col)
                )
            lines.append(row)

        lines.append("__SEP__")
        done_focused = self.comp_cursor == len(COMPOSITORS)
        lines.append(center_styled(self.render_button(self.t("installer.ui.done"), "primary", done_focused, prefix="✓ "), inner_w))

        raw_title = self.t("installer.ui.compositors_title").strip("= ")
        title = th.style(raw_title, fg=th.c_accent_hi, bold=True)
        box = self.frame_box(lines, frame_w, border_color=th.c_border_hi, title=title)
        hints = [
            ("↑↓", self.t("installer.ui.hint_navigate")),
            ("Space / Enter", self.t("installer.ui.action_toggle")),
            ("Esc", self.t("installer.ui.hint_back")),
        ]
        return self.render_centered(box, self.render_key_hints(hints))

    def render_sddm_screen(self):
        th = self.theme
        frame_w = min(max(60, self.term.cols - 6), 76)
        inner_w = frame_w - 2

        lines = []
        if self.state.current_dm:
            dm_msg = self.t("installer.ui.sddm_detected_active", dm=self.state.current_dm)
            lines.append("  " + th.style(truncate_plain(dm_msg, inner_w - 4), fg=th.c_warn, bold=True))
        else:
            lines.append("  " + th.style(truncate_plain(self.t("installer.ui.sddm_detected_none"), inner_w - 4), fg=th.c_subtext))
        lines.append("  " + th.style(self.t("installer.ui.sddm_hint"), fg=th.c_muted))
        lines.append("__SEP__")

        rows = self.sddm_rows()
        if self.sddm_cursor >= len(rows):
            self.sddm_cursor = len(rows) - 1

        toggle_w = 24
        label_w = max(20, inner_w - toggle_w - 7)
        for idx, row_id in enumerate(rows):
            if row_id == "done":
                continue
            focused = self.sddm_cursor == idx
            if row_id == "install":
                lbl = self.t("installer.ui.sddm_opt_install")
                tog = self.render_pill_toggle(self.state.opt_sddm, self.t("installer.ui.status_enabled"), self.t("installer.ui.status_disabled"), focused)
            elif row_id == "replace":
                lbl = self.t("installer.ui.sddm_opt_disable", dm=self.state.current_dm)
                tog = self.render_pill_toggle(self.state.replace_dm, self.t("installer.ui.status_yes"), self.t("installer.ui.status_no"), focused)
            else:
                lbl = self.t("installer.ui.sddm_opt_wayland")
                tog = self.render_pill_toggle(self.state.sddm_wayland, self.t("installer.ui.status_wayland"), self.t("installer.ui.status_x11"), focused)

            if focused:
                bg = th.c_sel_bg
                lines.append(
                    th.fill_bg(
                        th.style(" ▎", fg=th.c_accent_hi, bg=bg, bold=True)
                        + th.style(pad_right(truncate_plain(lbl, label_w), label_w), fg=th.c_text, bg=bg, bold=True)
                        + "  "
                        + pad_right(tog, toggle_w),
                        inner_w,
                        bg,
                    )
                )
            else:
                lines.append("  " + th.style(pad_right(truncate_plain(lbl, label_w), label_w), fg=th.c_text) + "  " + pad_right(tog, toggle_w))

        lines.append("__SEP__")
        done_focused = rows[self.sddm_cursor] == "done"
        lines.append(center_styled(self.render_button(self.t("installer.ui.done"), "primary", done_focused, prefix="✓ "), inner_w))

        raw_title = self.t("installer.ui.sddm_title").strip("= ")
        title = th.style(raw_title, fg=th.c_accent_hi, bold=True)
        box = self.frame_box(lines, frame_w, border_color=th.c_border_hi, title=title)
        hints = [
            ("↑↓", self.t("installer.ui.hint_navigate")),
            ("←→ / Enter", self.t("installer.ui.action_toggle")),
            ("Esc", self.t("installer.ui.hint_back")),
        ]
        return self.render_centered(box, self.render_key_hints(hints))

    def render_uninstall_confirm_screen(self):
        th = self.theme
        frame_w = min(max(58, self.term.cols - 6), 74)
        inner_w = frame_w - 2

        lines = [""]
        lines.append(center_styled(th.style("!  " + self.t("installer.ui.uninstall_title"), fg=th.c_danger, bold=True), inner_w))
        lines.append("")
        for ln in wrap_plain(self.t("installer.ui.uninstall_removes"), inner_w - 6):
            lines.append("   " + th.style(ln, fg=th.c_text))
        lines.append("")
        for ln in wrap_plain(self.t("installer.ui.uninstall_keeps"), inner_w - 6):
            lines.append("   " + th.style(ln, fg=th.c_subtext))
        lines.append("")
        lines.append("__SEP__")

        b_cancel = self.render_button(self.t("installer.ui.uninstall_cancel"), "subtle", self.uninstall_cursor == 0)
        b_confirm = self.render_button(self.t("installer.ui.uninstall_confirm"), "danger", self.uninstall_cursor == 1, prefix="✗ ")
        lines.append(center_styled(b_cancel + "    " + b_confirm, inner_w))

        title = th.style(self.t("installer.ui.menu_uninstall"), fg=th.c_danger, bold=True)
        box = self.frame_box(lines, frame_w, border_color=th.c_danger, title=title)
        hints = [
            ("←→", self.t("installer.ui.hint_switch")),
            ("Enter", self.t("installer.ui.hint_select")),
            ("Esc", self.t("installer.ui.hint_back")),
        ]
        return self.render_centered(box, self.render_key_hints(hints))

    def render_auth_screen(self):
        th = self.theme
        frame_w = min(max(54, self.term.cols - 8), 64)
        inner_w = frame_w - 2

        lines = [""]
        lines.append(center_styled(th.style(self.t("installer.auth.prompt"), fg=th.c_text), inner_w))
        lines.append("")
        masked = "•" * len(self.auth_password)
        field_w = min(36, inner_w - 10)
        cursor_ch = th.style("▎", fg=th.c_accent_hi, bold=True) if not self.auth_busy else ""
        shown = masked[-(field_w - 3):] if len(masked) > field_w - 3 else masked
        field = th.style(" " + pad_right(shown + cursor_ch, field_w) + " ", fg=th.c_text, bg=th.c_sel_bg, bold=True)
        lines.append(center_styled(field, inner_w))
        lines.append("")
        if self.auth_busy:
            sp = SPINNER_FRAMES[self.spinner_idx % len(SPINNER_FRAMES)]
            lines.append(center_styled(th.style(f"{sp} {self.t('installer.auth.verifying')}", fg=th.c_accent_hi), inner_w))
        elif self.auth_error:
            lines.append(center_styled(th.style("! " + self.auth_error, fg=th.c_danger, bold=True), inner_w))
        else:
            lines.append(center_styled(th.style(self.t("installer.auth.hint"), fg=th.c_muted), inner_w))
        lines.append("")

        title = th.style(self.t("installer.auth.title"), fg=th.c_gold, bold=True)
        box = self.frame_box(lines, frame_w, border_color=th.c_gold, title=title)
        hints = [
            ("Enter", self.t("installer.ui.hint_select")),
            ("Esc", self.t("installer.ui.hint_back")),
        ]
        return self.render_centered(box, self.render_key_hints(hints))

    def target_progress(self):
        if not self.steps:
            return 0.0
        total_w = sum(s.weight for s in self.steps)
        if total_w <= 0:
            return 0.0
        acc = 0.0
        for s in self.steps:
            if s.status in ("done", "skipped"):
                acc += s.weight
            elif s.status == "running":
                sub = s.sub_ratio if s.sub_ratio >= 0 else 0.35
                acc += s.weight * max(0.05, min(0.95, sub))
        return max(0.0, min(1.0, acc / total_w))

    def render_progress_screen(self):
        th = self.theme
        cols = self.term.cols
        rows = self.term.rows
        block_w = min(max(64, cols - 4), 92)
        inner_w = block_w - 2

        target_p = self.target_progress()
        self.display_progress += (target_p - self.display_progress) * 0.25
        if abs(target_p - self.display_progress) < 0.004:
            self.display_progress = target_p
        pct = int(round(self.display_progress * 100))

        mode_title_key = {
            "install": "installer.ui.progress_installing",
            "update": "installer.ui.progress_updating",
            "reinstall": "installer.ui.progress_reinstalling",
            "uninstall": "installer.ui.progress_uninstalling",
        }.get(self.run_mode, "installer.ui.progress_installing")
        elapsed = time.monotonic() - self.run_started_at if self.run_started_at else 0.0

        active_step = self.steps[self.active_step_idx] if self.active_step_idx < len(self.steps) else None
        cur_num = min(len(self.steps), self.active_step_idx + 1)

        lines = []
        hdr_left = th.gradient(self.t(mode_title_key), (th.c_accent_hi, th.c_accent, th.c_lavender), bold=True)
        ver_label = (
            f"v{self.state.old_version} → v{self.state.target_version}"
            if self.run_mode == "update" and self.state.old_version
            else f"v{self.state.target_version}"
        )
        hdr_right = th.style(ver_label, fg=th.c_gold) + th.style(f" · {format_mmss(elapsed)}", fg=th.c_muted)
        if self.state.preview:
            hdr_right += th.style(f" · ◆ {self.t('installer.ui.preview_badge')}", fg=th.c_gold)
        gap = max(1, block_w - display_width(hdr_left) - display_width(hdr_right))
        lines.append(hdr_left + (" " * gap) + hdr_right)

        cur_label = active_step.label if active_step else ""
        bar_w = max(16, block_w - 7)
        bar_stops = (th.c_danger, th.c_warn) if self.step_failed else (th.c_accent, th.c_accent_hi, th.c_success)
        bar = th.progress_bar(self.display_progress, bar_w, stops=bar_stops)
        pct_s = th.style(f"{pct:3d}%", fg=th.c_danger if self.step_failed else th.c_success, bold=True)
        lines.append(f"{bar}  {pct_s}")

        step_meta = self.t("installer.ui.progress_step_of", current=cur_num, total=len(self.steps))
        if cur_label:
            step_meta += f"  ·  {cur_label}"
        if active_step and active_step.sub_text:
            step_meta += f" ({active_step.sub_text})"
        lines.append(th.style(truncate_plain(step_meta, block_w), fg=th.c_subtext))
        if rows >= 26:
            lines.append("")

        bc = th.c_danger if self.step_failed else (th.c_warn if self.waiting_input else th.c_border_hi)

        if not self.log_expanded:
            step_lines = []
            max_step_rows = max(4, min(len(self.steps) + 1, rows - 16))
            start_i = 0
            if len(self.steps) > max_step_rows - 1:
                start_i = max(0, min(self.active_step_idx - 2, len(self.steps) - (max_step_rows - 1)))
            shown_rows = 0
            for idx in range(start_i, len(self.steps)):
                if shown_rows >= max_step_rows:
                    break
                st = self.steps[idx]
                if st.status == "done":
                    icon = th.style("✓", fg=th.c_success, bold=True)
                    lbl_s = th.style(truncate_plain(st.label, inner_w - 18), fg=th.c_subtext)
                    dur_s = th.style(format_duration(st.duration), fg=th.c_muted)
                elif st.status == "running":
                    sp = SPINNER_FRAMES[self.spinner_idx % len(SPINNER_FRAMES)]
                    icon = th.style(sp, fg=th.c_accent_hi, bold=True)
                    lbl_s = th.style(truncate_plain(st.label, inner_w - 18), fg=th.c_text, bold=True)
                    dur_s = th.style(format_duration(st.duration), fg=th.c_accent_hi)
                elif st.status == "skipped":
                    icon = th.style("−", fg=th.c_muted)
                    lbl_s = th.style(truncate_plain(st.label, inner_w - 22), fg=th.c_muted)
                    dur_s = th.style(self.t("installer.ui.progress_skipped"), fg=th.c_muted)
                elif st.status == "failed":
                    icon = th.style("✗", fg=th.c_danger, bold=True)
                    lbl_s = th.style(truncate_plain(st.label, inner_w - 18), fg=th.c_danger, bold=True)
                    dur_s = th.style(format_duration(st.duration), fg=th.c_danger)
                else:
                    icon = th.style("○", fg=th.c_border)
                    lbl_s = th.style(truncate_plain(st.label, inner_w - 18), fg=th.c_muted)
                    dur_s = ""
                left = f"  {icon}  {lbl_s}"
                right = f"{dur_s}  "
                sp_gap = max(1, inner_w - display_width(left) - display_width(right))
                step_lines.append(left + (" " * sp_gap) + right)
                shown_rows += 1
                if st.status == "running" and st.sub_ratio >= 0 and shown_rows < max_step_rows:
                    sub_bar_w = min(36, max(12, inner_w - 34))
                    s_bar = th.progress_bar(st.sub_ratio, sub_bar_w, stops=(th.c_gold, th.c_accent_hi))
                    s_pct = th.style(f"{int(round(st.sub_ratio * 100)):3d}%", fg=th.c_gold)
                    s_txt = th.style(truncate_plain(st.sub_text, max(8, inner_w - sub_bar_w - 18)), fg=th.c_muted)
                    step_lines.append(f"     {s_bar}  {s_pct}  {s_txt}")
                    shown_rows += 1
            lines.extend(
                self.frame_box(
                    step_lines,
                    block_w,
                    border_color=bc,
                    title=th.style(self.t("installer.ui.progress_steps_title"), fg=th.c_accent, bold=True),
                )
            )

        extra_bottom = 3 if (self.step_failed or self.waiting_input) else 0
        avail_log = max(3, rows - len(lines) - 5 - extra_bottom) if self.log_expanded else max(3, min(5, rows - len(lines) - 5 - extra_bottom))
        all_logs = list(self.log_lines)
        if self.log_expanded:
            max_off = max(0, len(all_logs) - avail_log)
            self.log_scroll = max(0, min(self.log_scroll, max_off))
            end_i = len(all_logs) - self.log_scroll
            start_i = max(0, end_i - avail_log)
            visible_logs = all_logs[start_i:end_i]
        else:
            visible_logs = all_logs[-avail_log:]

        log_card_lines = []
        for idx in range(avail_log):
            if idx < len(visible_logs):
                raw_ln = truncate_plain(visible_logs[idx], inner_w - 4)
                low = raw_ln.lower()
                if "[ ok ]" in low or "successfully" in low:
                    c = th.c_success
                elif "[ failed ]" in low or "[ error ]" in low:
                    c = th.c_danger
                elif "[ warn ]" in low:
                    c = th.c_warn
                else:
                    c = th.c_subtext
                log_card_lines.append("  " + th.style(raw_ln, fg=c))
            else:
                log_card_lines.append("")

        if self.waiting_input:
            log_card_lines.append("__SEP__")
            log_card_lines.append("  " + th.style("! " + self.t("installer.ui.progress_waiting_input"), fg=th.c_warn, bold=True))
            log_card_lines.append("  " + th.style("› ", fg=th.c_accent_hi, bold=True) + th.style("•" * len(self.input_buffer) if self.input_masked else self.input_buffer, fg=th.c_text) + th.style("▎", fg=th.c_accent_hi))

        lines.extend(
            self.frame_box(
                log_card_lines,
                block_w,
                border_color=th.c_warn if self.waiting_input else th.c_border,
                title=th.style(self.t("installer.ui.progress_output_title"), fg=th.c_accent, bold=True),
                right_badge=th.style("[l] " + self.t("installer.ui.hint_toggle_log"), fg=th.c_muted),
            )
        )

        if self.step_failed:
            btns = [
                self.render_button(self.t("installer.ui.progress_retry"), "primary", self.fail_btn_idx == 0),
                self.render_button(self.t("installer.ui.progress_continue"), "warn", self.fail_btn_idx == 1),
                self.render_button(self.t("installer.ui.progress_abort"), "danger", self.fail_btn_idx == 2),
            ]
            lines.append(center_styled("   ".join(btns), block_w))

        hints = [("l", self.t("installer.ui.hint_toggle_log"))]
        if self.log_expanded:
            hints.append(("↑↓", self.t("installer.ui.hint_scroll")))
        if self.state.preview and not self.step_failed:
            hints.append(("f", self.t("installer.ui.hint_fast_forward")))
        return self.render_centered_block(lines, block_w, self.render_key_hints(hints))

    def complete_buttons(self):
        if self.run_mode == "uninstall":
            btns = [("exit", self.t("installer.ui.btn_exit"), "primary")]
        else:
            btns = [
                ("exit", self.t("installer.ui.btn_exit"), "accent"),
                ("reboot", self.t("installer.ui.btn_restart"), "primary"),
            ]
        if self.state.preview:
            btns.append(("menu", self.t("installer.ui.btn_return_menu"), "subtle"))
        return btns

    def render_complete_screen(self):
        th = self.theme
        block_w = min(max(62, self.term.cols - 4), 100)
        inner_w = block_w - 2

        title_key = {
            "install": "installer.ui.complete_title_install",
            "update": "installer.ui.complete_title_update",
            "reinstall": "installer.ui.complete_title_reinstall",
            "uninstall": "installer.ui.complete_title_uninstall",
        }.get(self.run_mode, "installer.ui.complete_title_install")

        compact = self.term.rows < 26
        body_est = 7 if self.run_mode == "uninstall" else (16 if not self.state.failed_pkgs else 19)
        avail_logo_rows = max(0, self.term.rows - body_est - (1 if not compact else 0))

        status_line = th.style("✓  ", fg=th.c_success, bold=True) + th.style(self.t(title_key), fg=th.c_text, bold=True)
        tag_line = th.style(self.t("installer.ui.tagline"), fg=th.c_subtext)

        header_lines, graphic_spec, graphic_pos = self.build_header_lockup(
            block_w,
            min(12, avail_logo_rows),
            [status_line, tag_line],
        )
        lines = list(header_lines)
        if self.term.rows >= 31:
            lines.append("")

        preview_badge = th.style(f"◆ {self.t('installer.ui.preview_badge')}", fg=th.c_gold, bold=True) if self.state.preview else None
        if self.run_mode == "uninstall":
            card_lines = []
            for ln in wrap_plain(self.t("installer.uninstall.done"), inner_w - 6):
                card_lines.append("  " + th.style(ln, fg=th.c_text))
            lines.extend(
                self.frame_box(
                    card_lines,
                    block_w,
                    border_color=th.c_success,
                    title=th.style(self.t("installer.ui.complete_summary"), fg=th.c_accent, bold=True),
                    right_badge=preview_badge,
                )
            )
        else:
            card_lines = []
            success_msg = self.t("installer.ui.installed_success", ver=self.state.target_version, commit=self.state.target_commit)
            card_lines.append("  " + th.style(truncate_plain(success_msg, inner_w - 4), fg=th.c_success, bold=True))
            if not compact:
                card_lines.append("")

            comps = ", ".join(dict(COMPOSITORS).get(c, c.title()) for c in self.state.selected_compositors) or "-"
            sddm_s = (
                f"{self.t('installer.ui.status_enabled')} ({self.t('installer.ui.status_wayland') if self.state.sddm_wayland else self.t('installer.ui.status_x11')})"
                if self.state.opt_sddm
                else self.t("installer.ui.status_disabled")
            )
            wp_s = self.t("installer.ui.status_full_pack") if self.state.install_full_wallpapers else self.t("installer.ui.status_random_pack")
            summary_rows = [
                (self.t("installer.ui.complete_version"), f"v{self.state.target_version} ({self.state.target_commit})"),
                (self.t("installer.ui.complete_compositors"), comps),
                (self.t("installer.ui.complete_sddm"), sddm_s),
                (self.t("installer.ui.complete_wallpapers"), wp_s),
                (self.t("installer.ui.complete_duration"), format_duration(self.run_total_duration).strip()),
            ]
            for k, v in summary_rows:
                card_lines.append("  " + th.style(f"{k:<16}", fg=th.c_muted) + th.style(truncate_plain(v, inner_w - 20), fg=th.c_text))

            if self.state.failed_pkgs:
                card_lines.append("__SEP__")
                card_lines.append("  " + th.style("! " + self.t("installer.ui.failed_packages"), fg=th.c_danger, bold=True))
                failed_str = ", ".join(self.state.failed_pkgs)
                for ln in wrap_plain(failed_str, inner_w - 6):
                    card_lines.append("  " + th.style(ln, fg=th.c_warn))

            lines.extend(
                self.frame_box(
                    card_lines,
                    block_w,
                    border_color=th.c_success,
                    title=th.style(self.t("installer.ui.complete_summary"), fg=th.c_accent, bold=True),
                    right_badge=preview_badge,
                )
            )

            kf_link = th.link("https://ko-fi.com/ilyamiro", "https://ko-fi.com/ilyamiro", fg=th.c_lavender, bold=True)
            coffee = self.t("installer.ui.buy_coffee")
            sup_lines = [
                "  " + th.style(truncate_plain(coffee, inner_w - 4), fg=th.c_subtext),
                "  " + th.style("Ko-fi: ", fg=th.c_muted) + kf_link,
            ]
            lines.extend(
                self.frame_box(
                    sup_lines,
                    block_w,
                    border_color=th.c_border,
                    title=th.style("♥ " + self.t("installer.ui.support_creator").rstrip(":"), fg=th.c_gold, bold=True),
                )
            )

        if self.run_mode != "uninstall":
            lines.append(center_styled(th.style(self.t("installer.ui.restart_prompt"), fg=th.c_subtext), block_w))

        toast_txt, toast_kind = self.active_toast()
        if toast_txt:
            tc = th.c_gold if toast_kind == "warn" else th.c_accent_hi
            lines.append(center_styled(th.style("◆ " + toast_txt, fg=tc, bold=True), block_w))
        elif not compact:
            lines.append("")

        btns = self.complete_buttons()
        if self.complete_btn_idx >= len(btns):
            self.complete_btn_idx = 0
        btn_str = "   ".join(
            self.render_button(lbl, var, self.complete_btn_idx == idx)
            for idx, (_bid, lbl, var) in enumerate(btns)
        )
        lines.append(center_styled(btn_str, block_w))

        hints = [
            ("←→", self.t("installer.ui.hint_switch")),
            ("Enter", self.t("installer.ui.hint_select")),
            ("q", self.t("installer.ui.hint_quit")),
        ]
        return self.render_centered_block(lines, block_w, self.render_key_hints(hints), graphic_spec=graphic_spec, graphic_pos=graphic_pos)

    def draw(self):
        self._pending_graphic = None
        if self.screen == "main":
            canvas = self.render_main_screen()
        elif self.screen == "packages":
            canvas = self.render_packages_screen()
        elif self.screen == "compositors":
            canvas = self.render_compositors_screen()
        elif self.screen == "sddm":
            canvas = self.render_sddm_screen()
        elif self.screen == "uninstall_confirm":
            canvas = self.render_uninstall_confirm_screen()
        elif self.screen == "auth":
            canvas = self.render_auth_screen()
        elif self.screen == "progress":
            canvas = self.render_progress_screen()
        else:
            canvas = self.render_complete_screen()
        try:
            self.term.render_lines(canvas, graphic=self._pending_graphic)
        except TypeError:
            self.term.render_lines(canvas)

    def build_steps(self, mode):
        if mode == "uninstall":
            return [
                StepItem("uninstall_stop", self.t("installer.steps.uninstall_stop"), weight=1.0),
                StepItem("uninstall_reset", self.t("installer.steps.uninstall_reset"), weight=1.0),
                StepItem("uninstall_remove", self.t("installer.steps.uninstall_remove"), weight=2.0),
            ]
        steps = [StepItem("prepare", self.t("installer.steps.prepare"), weight=0.6)]
        if self.state.install_state == "legacy":
            steps.append(StepItem("migrate", self.t("installer.steps.migrate"), weight=1.0))
        elif self.state.install_state == "fresh" or self.state.is_reinstall:
            steps.append(StepItem("backup", self.t("installer.steps.backup"), weight=0.8))
        steps.extend([
            StepItem("deps", self.t("installer.steps.deps"), weight=4.5),
            StepItem("ski", self.t("installer.steps.ski"), weight=1.2),
            StepItem("audio", self.t("installer.steps.audio"), weight=1.2),
            StepItem("gamma", self.t("installer.steps.gamma"), weight=1.0),
            StepItem("core", self.t("installer.steps.core"), weight=1.0),
            StepItem("deploy", self.t("installer.steps.deploy"), weight=1.5),
            StepItem(
                "sddm",
                self.t("installer.steps.sddm"),
                status="pending" if self.state.opt_sddm else "skipped",
                weight=1.0,
            ),
            StepItem("wallpapers", self.t("installer.steps.wallpapers"), weight=2.0),
            StepItem("config", self.t("installer.steps.config"), weight=1.2),
            StepItem("finalize", self.t("installer.steps.finalize"), weight=0.6),
        ])
        return steps

    def begin_action(self, mode):
        if mode in ("install", "update", "reinstall"):
            if not self.state.selected_compositors:
                self.set_toast(self.t("installer.ui.error_no_compositor"), kind="error", duration=4.0)
                self.main_focus_section = "config"
                self.main_config_idx = 1
                return
            self.state.is_reinstall = mode == "reinstall"
            self.state.do_uninstall = False
        elif mode == "uninstall":
            self.state.do_uninstall = True

        self.auth_next_mode = mode
        if self.state.preview:
            if self.state.auth_demo:
                self.auth_password = ""
                self.auth_error = ""
                self.screen = "auth"
                return
            self.start_pipeline(mode)
            return

        check = subprocess.run(["sudo", "-n", "true"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        if check.returncode == 0:
            self._start_sudo_keepalive()
            self.start_pipeline(mode)
        else:
            self.auth_password = ""
            self.auth_error = ""
            self.screen = "auth"

    def _start_sudo_keepalive(self):
        self.sudo_keepalive_stop.clear()

        def worker():
            while not self.sudo_keepalive_stop.wait(45.0):
                subprocess.run(["sudo", "-n", "-v"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self.sudo_keepalive_thread = threading.Thread(target=worker, daemon=True)
        self.sudo_keepalive_thread.start()

    def _stop_sudo_keepalive(self):
        self.sudo_keepalive_stop.set()

    def verify_sudo_password(self):
        if self.state.preview:
            self.auth_busy = True
            self.draw()
            time.sleep(0.35)
            self.auth_busy = False
            self.auth_password = ""
            self.start_pipeline(self.auth_next_mode)
            return

        self.auth_busy = True
        self.auth_error = ""
        self.draw()
        proc = subprocess.run(
            ["sudo", "-S", "-k", "-v"],
            input=(self.auth_password + "\n").encode("utf-8"),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if proc.returncode == 0:
            self.sudo_password = self.auth_password
        self.auth_password = ""
        self.auth_busy = False
        if proc.returncode == 0:
            self._start_sudo_keepalive()
            self.start_pipeline(self.auth_next_mode)
        else:
            self.auth_error = self.t("installer.auth.error_failed")

    def start_pipeline(self, mode):
        self.run_mode = mode
        self.steps = self.build_steps(mode)
        self.active_step_idx = 0
        self.display_progress = 0.0
        self.run_started_at = time.monotonic()
        self.log_lines.clear()
        self.log_scroll = 0
        self.step_failed = False
        self.waiting_input = False
        self.input_buffer = ""
        self.fast_forward = False
        self.state.failed_pkgs = []
        self.screen = "progress"

        if not self.state.preview:
            cache_base = os.path.join(
                os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
                "serpantinum-installer",
            )
            os.makedirs(cache_base, exist_ok=True)
            self.failed_pkgs_file = os.path.join(cache_base, f".failed_pkgs.{os.getpid()}")
            self.install_log_file = os.path.join(cache_base, "install.log")
            self.state.log_path = self.install_log_file
            with open(self.failed_pkgs_file, "w", encoding="utf-8") as fh:
                fh.write("")
            with open(self.install_log_file, "w", encoding="utf-8") as fh:
                fh.write("")

        self.execute_pipeline()

    def _step_env(self):
        env = os.environ.copy()
        env.update({
            "PROJECT_ROOT": self.state.project_root,
            "SERPANTINUM_DIR": os.path.join(self.state.project_root, "src"),
            "I18N_DIR": self.i18n.i18n_dir,
            "REPO_SLUG": self.state.repo_slug,
            "INSTALL_STATE": self.state.install_state,
            "OLD_VERSION": self.state.old_version,
            "TARGET_VERSION": self.state.target_version,
            "TARGET_COMMIT": self.state.target_commit,
            "OLD_COMMIT": self.state.old_commit,
            "TELEMETRY_ID": self.state.telemetry_id,
            "ENABLE_TELEMETRY": "true" if self.state.enable_telemetry else "false",
            "OPT_SDDM": "true" if self.state.opt_sddm else "false",
            "REPLACE_DM": "true" if self.state.replace_dm else "false",
            "SDDM_WAYLAND": "true" if self.state.sddm_wayland else "false",
            "INSTALL_FULL_WALLPAPERS": "true" if self.state.install_full_wallpapers else "false",
            "IS_REINSTALL": "true" if self.state.is_reinstall else "false",
            "DO_UNINSTALL": "true" if self.state.do_uninstall else "false",
            "SELECTED_COMPOSITORS_STR": " ".join(self.state.selected_compositors),
            "SERP_FAILED_PKGS_FILE": self.failed_pkgs_file,
            "SERPANTINUM_INSTALLER": "1",
            "SUDO_PROMPT": SUDO_PROMPT_MARKER,
        })
        return env

    def _append_log(self, line):
        clean = strip_ansi(line).rstrip()
        if not clean:
            return
        self.log_lines.append(clean)
        if not self.state.preview and self.install_log_file:
            try:
                with open(self.install_log_file, "a", encoding="utf-8") as fh:
                    fh.write(clean + "\n")
            except Exception:
                pass

    def _parse_step_progress(self, step, line, tracker):
        clean = strip_ansi(line).strip()
        if not clean:
            return
        wp_match = WP_PROGRESS_RE.search(clean)
        if wp_match:
            cur = int(wp_match.group(2))
            tot = max(1, int(wp_match.group(3)))
            step.sub_ratio = cur / tot
            step.sub_text = f"{cur}/{tot}"
            return
        if step.id == "deps":
            mc = MISSING_COUNT_RE.search(clean)
            if mc:
                tracker["total"] = max(1, int(mc.group(1)))
                tracker["done"] = 0
                step.sub_ratio = 0.05
                step.sub_text = f"0/{tracker['total']}"
                return
            if "Installing " in clean or clean.startswith(":: "):
                pm = INSTALLING_PKG_RE.search(clean)
                if pm:
                    pkg = pm.group(1)
                    if pkg.lower() not in ("system", "the"):
                        tracker["current"] = pkg
                        tot = tracker.get("total", 0)
                        done = tracker.get("done", 0)
                        step.sub_text = f"{pkg} ({done}/{tot})" if tot > 0 else pkg
            if "[ OK ]" in clean or "[ FAILED ]" in clean:
                tot = tracker.get("total", 0)
                if tot > 0:
                    tracker["done"] = min(tot, tracker.get("done", 0) + 1)
                    step.sub_ratio = min(0.95, tracker["done"] / tot)
                    cur_pkg = tracker.get("current", "")
                    step.sub_text = f"{cur_pkg} ({tracker['done']}/{tot})" if cur_pkg else f"{tracker['done']}/{tot}"

    def _handle_progress_key(self, key, master_fd=None):
        if key is None:
            return
        if self.waiting_input and master_fd is not None:
            if key == "ENTER":
                os.write(master_fd, (self.input_buffer + "\n").encode("utf-8"))
                if not self.input_masked:
                    self._append_log("> " + self.input_buffer)
                self.input_buffer = ""
                self.input_masked = False
                self.waiting_input = False
            elif key == "BACKSPACE":
                self.input_buffer = self.input_buffer[:-1]
            elif key == "CTRL_C":
                os.write(master_fd, b"\x03")
                self.input_buffer = ""
                self.input_masked = False
                self.waiting_input = False
            elif len(key) == 1 and ord(key) >= 32:
                self.input_buffer += key
            return
        if key in ("l", "L"):
            self.log_expanded = not self.log_expanded
            self.log_scroll = 0
        elif self.log_expanded and key in ("UP", "k", "K"):
            self.log_scroll += 1
        elif self.log_expanded and key in ("DOWN", "j", "J"):
            self.log_scroll = max(0, self.log_scroll - 1)
        elif self.log_expanded and key == "PGUP":
            self.log_scroll += 8
        elif self.log_expanded and key == "PGDN":
            self.log_scroll = max(0, self.log_scroll - 8)
        elif self.state.preview and key in ("f", "F"):
            self.fast_forward = True

    def _run_preview_step(self, step, events):
        step_start = time.monotonic()
        for delay, msg, sub_ratio, sub_text in events:
            step.sub_ratio = sub_ratio
            if sub_text:
                step.sub_text = sub_text
            self._append_log(msg)
            wait_until = time.monotonic() + (0.02 if self.fast_forward else delay)
            while time.monotonic() < wait_until:
                step.duration = time.monotonic() - step_start
                now = time.monotonic()
                if now - self.last_spinner_tick >= 0.08:
                    self.spinner_idx += 1
                    self.last_spinner_tick = now
                self.draw()
                key = self.term.read_key(timeout=0.04)
                self._handle_progress_key(key)
                if self.fast_forward:
                    break
        step.duration = time.monotonic() - step_start
        return 0

    def _wait_for_echo_off(self, fd, timeout=2.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                if not termios.tcgetattr(fd)[3] & termios.ECHO:
                    return True
            except termios.error:
                return False
            time.sleep(0.01)
        return False

    def _run_real_step(self, step):
        runner = os.path.join(self.state.modules_dir, "step_runner.sh")
        master_fd, slave_fd = pty.openpty()
        try:
            winsize = struct.pack("HHHH", max(24, self.term.rows), max(80, self.term.cols), 0, 0)
            fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, winsize)
        except Exception:
            pass

        proc = subprocess.Popen(
            ["bash", runner, step.id],
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            env=self._step_env(),
            close_fds=True,
            start_new_session=True,
        )
        os.close(slave_fd)
        flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
        fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        partial = ""
        pending_cr = False
        last_output_at = time.monotonic()
        step_start = time.monotonic()
        tracker = {}

        try:
            while True:
                step.duration = time.monotonic() - step_start
                now = time.monotonic()
                if now - self.last_spinner_tick >= 0.08:
                    self.spinner_idx += 1
                    self.last_spinner_tick = now

                rlist = [master_fd, self.term.in_fd]
                try:
                    ready, _, _ = select.select(rlist, [], [], 0.05)
                except InterruptedError:
                    ready = []

                if master_fd in ready:
                    try:
                        chunk = os.read(master_fd, 4096)
                    except OSError:
                        chunk = b""
                    if chunk:
                        last_output_at = time.monotonic()
                        self.waiting_input = False
                        text = chunk.decode("utf-8", errors="replace")
                        for ch in text:
                            if pending_cr:
                                pending_cr = False
                                if ch != "\n" and partial:
                                    self._parse_step_progress(step, partial, tracker)
                                    partial = ""
                            if ch == "\n":
                                self._append_log(partial)
                                self._parse_step_progress(step, partial, tracker)
                                partial = ""
                            elif ch == "\r":
                                pending_cr = True
                            else:
                                partial += ch
                        if SUDO_PROMPT_MARKER in partial:
                            partial = partial.replace(SUDO_PROMPT_MARKER, "")
                            if self.sudo_password and self._wait_for_echo_off(master_fd):
                                os.write(master_fd, (self.sudo_password + "\n").encode("utf-8"))
                            else:
                                self._append_log(self.t("installer.auth.prompt"))
                                self.input_buffer = ""
                                self.input_masked = True
                                self.waiting_input = True

                if self.term.in_fd in ready:
                    key = self.term.read_key(timeout=0.0)
                    self._handle_progress_key(key, master_fd=master_fd)

                if partial and not pending_cr and (time.monotonic() - last_output_at) > 1.2:
                    clean_partial = strip_ansi(partial).strip()
                    if clean_partial and PROMPT_RE.search(clean_partial):
                        if not self.waiting_input:
                            self._append_log(clean_partial)
                            self.input_masked = "password" in clean_partial.lower()
                            self.waiting_input = True

                self.draw()

                if proc.poll() is not None:
                    while True:
                        try:
                            rem = os.read(master_fd, 4096)
                            if not rem:
                                break
                            partial += rem.decode("utf-8", errors="replace")
                        except OSError:
                            break
                    for line in partial.splitlines():
                        self._append_log(line)
                        self._parse_step_progress(step, line, tracker)
                    break
        finally:
            try:
                os.close(master_fd)
            except OSError:
                pass

        step.duration = time.monotonic() - step_start
        self.waiting_input = False
        return proc.returncode

    def _await_failure_decision(self):
        self.step_failed = True
        self.log_expanded = True
        self.fail_btn_idx = 0
        while True:
            self.draw()
            key = self.term.read_key(timeout=0.08)
            if key is None:
                continue
            if key in ("LEFT", "h", "H", "SHIFT_TAB"):
                self.fail_btn_idx = (self.fail_btn_idx - 1) % 3
            elif key in ("RIGHT", "l", "L", "TAB"):
                self.fail_btn_idx = (self.fail_btn_idx + 1) % 3
            elif key in ("UP", "k", "K"):
                self.log_scroll += 1
            elif key in ("DOWN", "j", "J"):
                self.log_scroll = max(0, self.log_scroll - 1)
            elif key in ("ENTER", "SPACE"):
                self.step_failed = False
                return ("retry", "continue", "abort")[self.fail_btn_idx]
            elif key in ("ESC", "q", "Q", "CTRL_C"):
                self.step_failed = False
                return "abort"

    def execute_pipeline(self):
        simulator = PreviewSimulator(self.state, self.run_mode) if self.state.preview else None
        idx = 0
        aborted = False
        while idx < len(self.steps):
            step = self.steps[idx]
            self.active_step_idx = idx
            if step.status == "skipped":
                idx += 1
                continue
            step.status = "running"
            step.sub_ratio = -1.0
            step.sub_text = ""
            self.draw()
            if self.state.preview:
                rc = self._run_preview_step(step, simulator.step_scripts.get(step.id, []))
            else:
                rc = self._run_real_step(step)
            if rc == 0:
                step.status = "done"
                step.sub_ratio = 1.0
                idx += 1
            else:
                step.status = "failed"
                decision = self._await_failure_decision()
                if decision == "retry":
                    step.status = "pending"
                    continue
                if decision == "continue":
                    idx += 1
                    continue
                aborted = True
                break

        self.run_total_duration = time.monotonic() - self.run_started_at
        self._stop_sudo_keepalive()
        self.sudo_password = ""

        if not self.state.preview and self.failed_pkgs_file and os.path.isfile(self.failed_pkgs_file):
            try:
                with open(self.failed_pkgs_file, "r", encoding="utf-8") as fh:
                    self.state.failed_pkgs = [ln.strip() for ln in fh if ln.strip()]
                os.remove(self.failed_pkgs_file)
            except Exception:
                pass

        if aborted:
            self.state.action_result = "aborted"
            return

        self.display_progress = 1.0
        self.draw()
        if not self.fast_forward:
            time.sleep(0.25)
        self.complete_btn_idx = 0
        self.screen = "complete"

    def handle_main_key(self, key):
        actions = self.main_actions()
        if key in ("CTRL_C", "ESC", "q", "Q"):
            self.state.action_result = "exit"
            return False

        if self.state.preview and key in ("s", "S"):
            order = ("current", "fresh", "legacy")
            nxt = order[(order.index(self.state.install_state) + 1) % len(order)] if self.state.install_state in order else "current"
            self.state.install_state = nxt
            self.main_action_idx = 0
            mode_label = self.t(f"installer.ui.mode_{nxt}")
            self.set_toast(self.t("installer.ui.preview_mode_switched", mode=mode_label), kind="info", duration=2.2)
            return True

        if key == "1":
            self.open_packages()
            return True
        if key == "2":
            self.comp_cursor = 0
            self.screen = "compositors"
            return True
        if key == "3":
            self.sddm_cursor = 0
            self.screen = "sddm"
            return True
        if key == "4":
            self.main_focus_section = "config"
            self.main_config_idx = 3
            self.state.install_full_wallpapers = not self.state.install_full_wallpapers
            return True
        if key == "5":
            self.main_focus_section = "config"
            self.main_config_idx = 4
            self.state.enable_telemetry = not self.state.enable_telemetry
            return True
        if key == "6":
            self.begin_action("update" if self.state.install_state == "current" else "install")
            return self.state.action_result != "aborted"
        if key == "7":
            if self.state.install_state == "current":
                self.begin_action("reinstall")
                return self.state.action_result != "aborted"
            self.state.action_result = "exit"
            return False
        if key == "8" and self.state.install_state == "current":
            self.state.action_result = "exit"
            return False
        if key == "9" and self.state.install_state == "current":
            self.uninstall_cursor = 0
            self.screen = "uninstall_confirm"
            return True

        if self.main_focus_section == "config":
            if key in ("UP", "k", "K"):
                if self.main_config_idx > 0:
                    self.main_config_idx -= 1
                else:
                    self.main_focus_section = "actions"
                    self.main_action_idx = min(self.main_action_idx, len(actions) - 1)
            elif key in ("DOWN", "j", "J"):
                if self.main_config_idx < 4:
                    self.main_config_idx += 1
                else:
                    self.main_focus_section = "actions"
                    self.main_action_idx = min(self.main_action_idx, len(actions) - 1)
            elif key == "TAB":
                self.main_focus_section = "actions"
                self.main_action_idx = 0
            elif key in ("LEFT", "RIGHT", "h", "H", "l", "L"):
                if self.main_config_idx == 3:
                    self.state.install_full_wallpapers = not self.state.install_full_wallpapers
                elif self.main_config_idx == 4:
                    self.state.enable_telemetry = not self.state.enable_telemetry
                elif key in ("RIGHT", "l", "L"):
                    self._activate_main_config()
            elif key in ("ENTER", "SPACE"):
                self._activate_main_config()
        else:
            if key in ("UP", "k", "K"):
                self.main_focus_section = "config"
                self.main_config_idx = 4
            elif key in ("DOWN", "j", "J"):
                self.main_focus_section = "config"
                self.main_config_idx = 0
            elif key in ("LEFT", "h", "H", "SHIFT_TAB"):
                self.main_action_idx = (self.main_action_idx - 1) % len(actions)
            elif key in ("RIGHT", "l", "L", "TAB"):
                self.main_action_idx = (self.main_action_idx + 1) % len(actions)
            elif key in ("ENTER", "SPACE"):
                aid = actions[self.main_action_idx][0]
                if aid == "exit":
                    self.state.action_result = "exit"
                    return False
                if aid == "uninstall":
                    self.uninstall_cursor = 0
                    self.screen = "uninstall_confirm"
                else:
                    self.begin_action(aid)
                    if self.state.action_result == "aborted":
                        return False
        return True

    def _activate_main_config(self):
        if self.main_config_idx == 0:
            self.open_packages()
        elif self.main_config_idx == 1:
            self.comp_cursor = 0
            self.screen = "compositors"
        elif self.main_config_idx == 2:
            self.sddm_cursor = 0
            self.screen = "sddm"
        elif self.main_config_idx == 3:
            self.state.install_full_wallpapers = not self.state.install_full_wallpapers
        elif self.main_config_idx == 4:
            self.state.enable_telemetry = not self.state.enable_telemetry

    def open_packages(self):
        self.pkg_tab = 0
        self.pkg_cursor = 0
        self.pkg_scroll = 0
        self.pkg_query = ""
        self.pkg_searching = False
        self.screen = "packages"

    def handle_packages_key(self, key):
        if self.pkg_searching:
            if key == "ESC":
                if self.pkg_query:
                    self.pkg_query = ""
                    self.pkg_cursor = 0
                    self.pkg_scroll = 0
                else:
                    self.pkg_searching = False
                return True
            if key == "ENTER":
                self.pkg_searching = False
                return True
            if key == "BACKSPACE":
                self.pkg_query = self.pkg_query[:-1]
                self.pkg_cursor = 0
                self.pkg_scroll = 0
                return True
            if key == "CTRL_C":
                self.pkg_searching = False
                self.screen = "main"
                return True
            if len(key) == 1 and ord(key) >= 32:
                self.pkg_query += key
                self.pkg_cursor = 0
                self.pkg_scroll = 0
                return True
            return True

        filtered = self.filtered_packages()
        if key in ("ESC", "q", "Q", "ENTER"):
            self.screen = "main"
        elif key == "/":
            self.pkg_searching = True
        elif key in ("LEFT", "h", "H", "SHIFT_TAB"):
            self.pkg_tab = (self.pkg_tab - 1) % 3
            self.pkg_cursor = 0
            self.pkg_scroll = 0
        elif key in ("RIGHT", "l", "L", "TAB"):
            self.pkg_tab = (self.pkg_tab + 1) % 3
            self.pkg_cursor = 0
            self.pkg_scroll = 0
        elif key in ("UP", "k", "K"):
            if filtered:
                self.pkg_cursor = max(0, self.pkg_cursor - 1)
        elif key in ("DOWN", "j", "J"):
            if filtered:
                self.pkg_cursor = min(len(filtered) - 1, self.pkg_cursor + 1)
        elif key == "PGUP":
            if filtered:
                self.pkg_cursor = max(0, self.pkg_cursor - 8)
        elif key == "PGDN":
            if filtered:
                self.pkg_cursor = min(len(filtered) - 1, self.pkg_cursor + 8)
        elif key == "HOME":
            self.pkg_cursor = 0
        elif key == "END" and filtered:
            self.pkg_cursor = len(filtered) - 1
        elif key == "BACKSPACE" and self.pkg_query:
            self.pkg_query = self.pkg_query[:-1]
            self.pkg_cursor = 0
            self.pkg_scroll = 0
        return True

    def handle_compositors_key(self, key):
        total = len(COMPOSITORS) + 1
        if key in ("ESC", "q", "Q"):
            self.screen = "main"
        elif key in ("UP", "k", "K"):
            self.comp_cursor = (self.comp_cursor - 1) % total
        elif key in ("DOWN", "j", "J"):
            self.comp_cursor = (self.comp_cursor + 1) % total
        elif key in ("1", "2", "3", "4", "5"):
            idx = int(key) - 1
            self.comp_cursor = idx
            self.toggle_compositor(COMPOSITORS[idx][0])
        elif key == "6":
            self.screen = "main"
        elif key in ("ENTER", "SPACE", "LEFT", "RIGHT"):
            if self.comp_cursor == len(COMPOSITORS):
                if key in ("ENTER", "SPACE"):
                    self.screen = "main"
            else:
                self.toggle_compositor(COMPOSITORS[self.comp_cursor][0])
        return True

    def handle_sddm_key(self, key):
        rows = self.sddm_rows()
        if key in ("ESC", "q", "Q"):
            self.screen = "main"
        elif key in ("UP", "k", "K"):
            self.sddm_cursor = (self.sddm_cursor - 1) % len(rows)
        elif key in ("DOWN", "j", "J"):
            self.sddm_cursor = (self.sddm_cursor + 1) % len(rows)
        elif key in ("ENTER", "SPACE", "LEFT", "RIGHT"):
            row_id = rows[self.sddm_cursor]
            if row_id == "install":
                self.state.opt_sddm = not self.state.opt_sddm
                if self.state.opt_sddm and self.state.current_dm and self.state.current_dm != "sddm":
                    self.state.replace_dm = True
            elif row_id == "replace":
                self.state.replace_dm = not self.state.replace_dm
            elif row_id == "wayland":
                self.state.sddm_wayland = not self.state.sddm_wayland
            elif row_id == "done" and key in ("ENTER", "SPACE"):
                self.screen = "main"
        return True

    def handle_uninstall_confirm_key(self, key):
        if key in ("ESC", "q", "Q", "n", "N", "1"):
            self.screen = "main"
        elif key in ("LEFT", "RIGHT", "UP", "DOWN", "h", "H", "l", "L", "j", "J", "k", "K", "TAB", "SHIFT_TAB"):
            self.uninstall_cursor = 1 - self.uninstall_cursor
        elif key == "2":
            self.begin_action("uninstall")
            return self.state.action_result != "aborted"
        elif key in ("ENTER", "SPACE"):
            if self.uninstall_cursor == 1:
                self.begin_action("uninstall")
                return self.state.action_result != "aborted"
            self.screen = "main"
        return True

    def handle_auth_key(self, key):
        if key in ("ESC", "CTRL_C"):
            self.auth_password = ""
            self.auth_error = ""
            self.screen = "main"
        elif key == "ENTER":
            self.verify_sudo_password()
            if self.state.action_result == "aborted":
                return False
        elif key == "BACKSPACE":
            self.auth_password = self.auth_password[:-1]
            self.auth_error = ""
        elif len(key) == 1 and ord(key) >= 32:
            self.auth_password += key
            self.auth_error = ""
        return True

    def handle_complete_key(self, key):
        btns = self.complete_buttons()
        if key in ("ESC", "q", "Q", "CTRL_C", "n", "N"):
            self.state.action_result = "exit"
            return False
        if key in ("y", "Y") and self.run_mode != "uninstall":
            if self.state.preview:
                self.set_toast(self.t("installer.ui.preview_reboot_notice"), kind="warn", duration=3.0)
                return True
            self.state.action_result = "reboot"
            return False
        if key in ("LEFT", "h", "H", "SHIFT_TAB"):
            self.complete_btn_idx = (self.complete_btn_idx - 1) % len(btns)
        elif key in ("RIGHT", "l", "L", "TAB"):
            self.complete_btn_idx = (self.complete_btn_idx + 1) % len(btns)
        elif key in ("ENTER", "SPACE"):
            bid = btns[self.complete_btn_idx][0]
            if bid == "exit":
                self.state.action_result = "exit"
                return False
            if bid == "menu":
                self.screen = "main"
                self.main_focus_section = "config"
                self.main_config_idx = 0
                return True
            if bid == "reboot":
                if self.state.preview:
                    self.set_toast(self.t("installer.ui.preview_reboot_notice"), kind="warn", duration=3.0)
                    return True
                self.state.action_result = "reboot"
                return False
        return True

    def run(self):
        self.term.enter()
        try:
            running = True
            dirty = True
            while running:
                if self.term.resized:
                    self.term.resized = False
                    dirty = True
                if self.toast_text and time.monotonic() >= self.toast_until:
                    self.toast_text = ""
                    dirty = True
                if dirty:
                    self.draw()
                    dirty = False
                key = self.term.read_key(timeout=0.08)
                if key is None:
                    continue
                dirty = True
                if self.screen == "main":
                    running = self.handle_main_key(key)
                elif self.screen == "packages":
                    running = self.handle_packages_key(key)
                elif self.screen == "compositors":
                    running = self.handle_compositors_key(key)
                elif self.screen == "sddm":
                    running = self.handle_sddm_key(key)
                elif self.screen == "uninstall_confirm":
                    running = self.handle_uninstall_confirm_key(key)
                elif self.screen == "auth":
                    running = self.handle_auth_key(key)
                elif self.screen == "complete":
                    running = self.handle_complete_key(key)
        finally:
            self._stop_sudo_keepalive()
            self.term.leave()
        return self.state.action_result


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Serpantinum interactive terminal installer")
    parser.add_argument("--context", help="Path to JSON context file from install.sh")
    parser.add_argument("--result", help="Path to write JSON result payload")
    parser.add_argument("--preview", action="store_true", help="Run safe visual-only preview replica with zero system changes")
    parser.add_argument("--state", choices=("current", "fresh", "legacy"), default="current", help="Initial simulated install state in preview mode")
    parser.add_argument("--lang", help="Override display language code (e.g. en, ru, de, ua)")
    parser.add_argument("--auth-demo", action="store_true", help="Also preview the sudo authentication modal in preview mode")
    parser.add_argument("--logo-mode", choices=("auto", "kitty", "sixel", "braille", "blocks"), default="auto", help="Logo rendering tier")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_root = os.path.dirname(script_dir)

    if args.preview:
        state = build_preview_state(project_root, args.state, args.auth_demo)
        i18n_dir = os.path.join(project_root, "src", "assets", "languages")
    elif args.context:
        state = load_real_state(args.context)
        i18n_dir = os.environ.get("I18N_DIR") or os.path.join(state.project_root, "src", "assets", "languages")
    else:
        state = build_preview_state(project_root, args.state, args.auth_demo)
        i18n_dir = os.path.join(project_root, "src", "assets", "languages")

    i18n = I18n(i18n_dir, lang_override=args.lang)
    app = InstallerTUI(state, i18n, logo_mode=args.logo_mode)
    action = app.run()

    if args.result and not state.preview:
        payload = {
            "action": action,
            "failed_pkgs": state.failed_pkgs,
            "log_path": state.log_path,
        }
        try:
            with open(args.result, "w", encoding="utf-8") as fh:
                json.dump(payload, fh)
        except Exception:
            pass

    if action == "aborted":
        if state.log_path:
            print(i18n.t("installer.ui.progress_log_saved", path=state.log_path), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
