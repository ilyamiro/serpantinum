"""Export Serpantinum appearance into a fixed, non-executable greeter snapshot."""
import hashlib
import fcntl
import json
import math
import os
from datetime import datetime
from pathlib import Path
import pwd
import re
import stat
import subprocess
import time
from tempfile import NamedTemporaryFile, TemporaryDirectory

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "serpantinum"
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "serpantinum"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "serpantinum"
OUTPUT = Path(os.environ.get("SERP_GREETER_STATE", "/var/lib/serpantinum-greeter"))
COLORS = ("base", "mantle", "crust", "text", "subtext0", "surface0", "surface1",
          "surface2", "blue", "mauve", "sapphire", "red")
TYPES = {"clock", "avatar", "user", "lockstatus", "password", "keyboard", "battery", "notifications"}
TYPES.update(f"widget:{name}" for name in ("weather", "cpu", "ram", "disk", "temp", "music"))
OUTPUT_NAME = re.compile(r"[a-zA-Z0-9][a-zA-Z0-9.-]{0,63}")


def read(path, limit=262144):
    try:
        with path.open("rb") as source:
            raw = source.read(limit + 1)
        return raw.decode("utf-8") if len(raw) <= limit else ""
    except (OSError, UnicodeError):
        return ""


def obj(value):
    return value if isinstance(value, dict) else {}


def data(path):
    try:
        return obj(json.loads(read(path)))
    except ValueError:
        return {}


def number(value, default, low, high):
    return min(high, max(low, value)) if type(value) in (int, float) and math.isfinite(value) else default


def string(value, default="", length=96):
    return value if isinstance(value, str) and len(value) <= length and value.isprintable() else default


def hex_color(value):
    return value if isinstance(value, str) and re.fullmatch(r"#[a-fA-F0-9]{6}", value) else ""


def weather_icon(value):
    if not isinstance(value, str) or len(value) != 1:
        return ""
    code = ord(value)
    return value if 0xE000 <= code <= 0xF8FF or 0xF0000 <= code <= 0xFFFFD else ""


def temperature_text(value):
    if type(value) in (float, int) and math.isfinite(value):
        value = str(value)
    return value if isinstance(value, str) and re.fullmatch(r"-?\d{1,3}(?:\.\d{1,2})?", value) else ""


def wallpaper_screens(directory):
    """Prefer the selected screen, then connected internal panels, then other cached displays."""
    selected = os.environ.get("SERP_GREETER_SCREEN", "")
    connected = set()
    for connector in Path("/sys/class/drm").glob("card*-*"):
        name = connector.name.split("-", 1)[-1]
        if OUTPUT_NAME.fullmatch(name) and read(connector / "status", 32).strip() == "connected":
            connected.add(name)

    cached = {}
    for pointer in directory.glob("current_*"):
        name = pointer.name.removeprefix("current_")
        if not OUTPUT_NAME.fullmatch(name) or name == "wallpaper.png":
            continue
        try:
            cached[name] = pointer.stat().st_mtime_ns
        except OSError:
            continue

    screens = sorted(connected | cached.keys(), key=lambda name: (
        name not in connected,
        not name.startswith(("eDP-", "LVDS-", "DSI-")),
        -cached.get(name, 0),
        name,
    ))
    return list(dict.fromkeys(([selected] if OUTPUT_NAME.fullmatch(selected) else []) + screens))


def wallpaper_media(lock):
    directory = CACHE / "wallpaper"
    custom = string(lock.get("customBackground"), length=4096)
    if lock.get("backgroundMode") == "custom" and (name := media(custom, "wallpaper")):
        return name
    candidates = []
    for screen in wallpaper_screens(directory):
        candidates.append(read(directory / f"current_{screen}", 4096).strip())
        candidates.append(str(directory / f"current_wallpaper_{screen}.png"))
    candidates.append(str(directory / "current_wallpaper.png"))
    return next((name for path in candidates if (name := media(path, "wallpaper"))), "")


def weather_snapshot(city):
    cached = data(CACHE / "weather/weather.json")
    fetched = number(cached.get("fetched_at"), 0, 0, time.time())
    unit = string(cached.get("unit_sym"), length=8)
    snapshot = {
        "fetched": fetched,
        "temp": string(cached.get("current_temp_formatted"), length=20),
        "city": string(city),
        "icon": weather_icon(cached.get("current_icon")),
        "color": hex_color(cached.get("current_hex")),
        "unit": unit,
        "feelsLike": "",
        "hourly": [],
    }
    days = cached.get("forecast")
    if not fetched or not isinstance(days, list):
        return snapshot

    now = datetime.now()
    today = (now.date() - datetime.fromtimestamp(fetched).date()).days
    if not 0 <= today < len(days):
        return snapshot
    first_day = obj(days[today])
    if (feels_like := temperature_text(first_day.get("feels_like"))):
        snapshot["feelsLike"] = f"{round(float(feels_like))}{unit}"
    for index, day in enumerate(days[today:today + 2]):
        hours = obj(day).get("hourly")
        for entry in hours[:24] if isinstance(hours, list) else []:
            entry = obj(entry)
            hour = string(entry.get("time"), length=5)
            if not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", hour):
                continue
            if index == 0 and hour < now.strftime("%H:00"):
                continue
            temperature = temperature_text(entry.get("temp"))
            if not temperature:
                continue
            snapshot["hourly"].append({
                "time": hour,
                "temp": temperature + unit,
                "icon": weather_icon(entry.get("icon")),
                "color": hex_color(entry.get("hex")),
            })
            if len(snapshot["hourly"]) == 4:
                return snapshot
    return snapshot


def layout():
    raw = data(STATE / "lockscreen/layout.json")
    if raw.get("version") != 3:
        return {}
    ref, panel = obj(raw.get("ref")), obj(raw.get("panel"))
    result = {
        "ref": {"w": number(ref.get("w"), 1920, 640, 16384), "h": number(ref.get("h"), 1080, 480, 8640)},
        "panel": {k: number(panel.get(k), v, {"x": -1, "y": -1, "w": 240, "h": 160, "opacity": 0}[k],
                            1 if k == "opacity" else 16384)
                  for k, v in {"x": -1, "y": -1, "w": 1280, "h": 566, "opacity": 1}.items()},
    }
    for scope in ("screen", "items"):
        entries = raw.get(scope)
        result[scope] = []
        for item in entries[:48] if isinstance(entries, list) else []:
            item = obj(item)
            kind = string(item.get("itype"))
            if kind not in TYPES:
                continue
            result[scope].append({
                "type": kind, "variant": string(item.get("ivariant")),
                "x": number(item.get("ix"), 0, -16384, 16384),
                "y": number(item.get("iy"), 0, -8640, 8640),
                "w": number(item.get("iw"), 0, 0, 16384),
                "h": number(item.get("ih"), 0, 0, 8640),
                "opacity": number(item.get("iopacity"), 1, 0, 1),
                "rotation": number(item.get("irotation"), 0, -360, 360),
            })
    return result


def write_atomic(path, contents):
    if path.is_file() and not path.is_symlink() and path.stat().st_size == len(contents):
        if path.read_bytes() == contents:
            return
    with NamedTemporaryFile(dir=OUTPUT, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(contents)
            stream.flush()
            os.fchmod(stream.fileno(), 0o644)
            os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def media(raw, role):
    if not raw:
        return ""
    path = Path(raw).expanduser()
    if not path.is_absolute() or path.is_symlink():
        return ""
    try:
        info = path.stat()
    except OSError:
        return ""
    if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= 256 * 1024 * 1024:
        return ""
    video = role == "wallpaper" and path.suffix.lower() in (".mp4", ".mkv", ".mov", ".webm")
    extension = "mp4" if video else "png"
    identity = hashlib.sha256(f"v1:{path}:{info.st_size}:{info.st_mtime_ns}".encode()).hexdigest()[:20]
    name = f"{role}-{identity}.{extension}"
    target = OUTPUT / name
    if target.is_file() and not target.is_symlink():
        return name
    with TemporaryDirectory(dir=OUTPUT) as temporary:
        result = Path(temporary) / name
        if video:
            command = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-i", str(path),
                       "-t", "120", "-map", "0:v:0", "-an", "-sn", "-dn", "-vf",
                       "scale=-2:min(720\\,ih),fps=30", "-c:v", "libx264", "-threads", "2",
                       "-preset", "veryfast", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(result)]
        else:
            size = "384x384>" if role == "avatar" else "2560x1440>"
            command = ["magick", "-limit", "memory", "128MiB", "-limit", "map", "256MiB",
                       "-limit", "disk", "256MiB", str(path) + "[0]", "-auto-orient",
                       "-resize", size, "-strip", "PNG32:" + str(result)]
        try:
            subprocess.run(command, check=True, timeout=120 if video else 20,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (subprocess.SubprocessError, OSError):
            return ""
        result.chmod(0o644)
        os.replace(result, target)
    return name


def main():
    settings = data(CONFIG / "settings.json")
    if not settings:
        return
    theme, lock = obj(settings.get("theme")), obj(settings.get("lockscreen"))
    palette = data(STATE / "qs_colors.json") or obj(theme.get("colors"))
    user = obj(settings.get("general"))
    background = wallpaper_media(lock)
    avatar = next((name for path in (
        str(CACHE / "avatar/avatar_cropped.png"),
        string(user.get("avatarPath"), length=4096),
        str(HOME / ".face"),
        str(HOME / ".face.icon"),
        f"/var/lib/AccountsService/icons/{HOME.name}",
    ) if (name := media(path, "avatar"))), "")
    snapshot = {
        "version": 1,
        "user": pwd.getpwuid(os.getuid()).pw_name,
        "colors": {k: color for k in COLORS if (color := hex_color(palette.get(k)))},
        "font": string(theme.get("fontFamily"), "Inter"),
        "mode": "light" if theme.get("mode") == "light" else "dark",
        "radius": number(theme.get("borderRadius"), 10, 0, 50),
        "opacity": number(theme.get("elementOpacity"), 85, 0, 100) / 100,
        "effect": ("glass" if theme.get("blurStyle") in ("glass", "liquidGlass", "liquid-glass", "liquid")
                   else "blur") if theme.get("blurBackground", True) else "off",
        "clock": string(obj(obj(settings.get("bar")).get("time")).get("format"), "h:mm:ss AP", 40),
        "language": string(user.get("language"), "en", 16),
        "sfxMuted": user.get("muteSfx") is True,
        "sfxVolume": number(user.get("sfxVolume"), 100, 0, 100) / 100,
        "passwordReveal": obj(settings.get("inputs")).get("passwordReveal") is True,
        "showEmptyGraphic": obj(settings.get("notifications")).get("showEmptyGraphic") is not False,
        "background": background,
        "avatar": avatar,
        "layout": layout(),
        "passwordLimit": number(lock.get("passwordMaxAttempts"), 5, 1, 30)
        if lock.get("attemptLimitEnabled") is True else 0,
        "weather": weather_snapshot(obj(user.get("location")).get("city")),
    }
    write_atomic(OUTPUT / "appearance.json", (json.dumps(snapshot, sort_keys=True) + "\n").encode())
    for path in OUTPUT.iterdir():
        if re.fullmatch(r"(?:wallpaper|avatar)-[0-9a-f]{20}\.(?:png|mp4)", path.name):
            if path.name not in (snapshot["background"], snapshot["avatar"]):
                path.unlink(missing_ok=True)


if __name__ == "__main__":
    with (OUTPUT / ".sync.lock").open("a") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            pass
        else:
            main()
