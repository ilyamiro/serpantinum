#!/usr/bin/env python3
"""Isolated Media source and visibility tests; never launches the desktop shell."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
qt_tests = shutil.which("qmltestrunner6")
if not qt_tests and Path("/usr/lib/qt6/bin/qmltestrunner").exists():
    qt_tests = "/usr/lib/qt6/bin/qmltestrunner"
if not qt_tests:
    raise SystemExit("Qt 6 qmltestrunner is required")

work = Path(tempfile.mkdtemp(prefix="serpantinum-media-tests-"))
env = os.environ.copy()
for name in list(env):
    if name.startswith("QS_") or name in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
        env.pop(name)
for name in ("HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR"):
    directory = work / name.lower()
    directory.mkdir(mode=0o700)
    env[name] = str(directory)
settings = work / "settings.json"
settings.write_text("{}\n")
# Quickshell restricts QML types to the entrypoint's configuration tree.
shutil.copytree(ROOT / "src/quickshell", work / "src/quickshell")
for directory in ("languages", "fonts", "shaders"):
    shutil.copytree(ROOT / "src/assets" / directory, work / "src/assets" / directory)
palette_dir = Path(env["HOME"]) / ".local/state/serpantinum"
palette_dir.mkdir(parents=True)
for filename in ("qs_colors.json", "qs_matugen_colors.json"):
    (palette_dir / filename).write_text("{}\n")
for filename in ("lyrics.qml", "lyrics_io.qml", "components.qml", "persistence.qml", "mpris.qml",
                 "settings_reader.qml", "settings_writer.qml", "wayland_imports.qml", "source_settings.qml"):
    source = (ROOT / "tests/media" / filename).read_text()
    (work / filename).write_text(source.replace('"../../src/quickshell', '"src/quickshell'))
env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_FORCE_STDERR_LOGGING="1",
           QS_SETTINGS=str(settings), SERPANTINUM_DIR=str(work / "src"), QS_DIR=str(work / "src/quickshell"))
cache = Path(env["XDG_CACHE_HOME"]) / "serpantinum/lyrics"
cache.mkdir(parents=True)
for title, artist, text in (("Cached A", "Test", "Cached A"), ("Cached B", "Test", "Cached B"), ("Track", "Artist", "Track")):
    key = hashlib.md5((artist + " - " + title).encode()).hexdigest()
    (cache / (key + ".json")).write_text(json.dumps([{"time": 0, "text": text, "words": []}]))
local_file = work / "local.lrc"
local_file.write_text("[00:00.00]Local lyrics\n")
env["MEDIA_TEST_LRC"] = str(local_file)
env["MEDIA_TEST_PERSISTENCE_TOKEN"] = work.name


def run(label, command, marker=None):
    if len(sys.argv) > 1 and label not in sys.argv[1:]:
        return
    process = subprocess.Popen(["dbus-run-session", "--", *command], cwd=ROOT, env=env,
                               text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    try:
        output, _ = process.communicate(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        output, _ = process.communicate(timeout=5)
        (work / (label + ".txt")).write_text(output)
        raise SystemExit(f"{label} timed out; diagnostics: {work}")
    (work / (label + ".txt")).write_text(output)
    print(output)
    if process.returncode or "FAIL" in output or (marker and marker not in output):
        raise SystemExit(f"{label} failed; diagnostics: {work}")
    if any(word in output for word in ("Binding loop", "ReferenceError", "TypeError")):
        raise SystemExit(f"{label} had QML errors; diagnostics: {work}")


run("selection", [qt_tests, "-input", "tests/media/tst_selection.qml", "-o", "-,txt"])
run("lyrics", ["quickshell", "--no-color", "-p", str(work / "lyrics.qml")], "PASS: LyricsContexts")
run("lyrics-io", ["quickshell", "--no-color", "-p", str(work / "lyrics_io.qml")], "PASS: Lyrics IO")
run("components", ["quickshell", "--no-color", "-p", str(work / "components.qml")], "PASS: Components")
run("mpris", [sys.executable, str(ROOT / "tests/media/mpris_fixture.py"), str(work / "mpris.qml")], "PASS: MPRIS integration")
run("source-settings", [sys.executable, str(ROOT / "tests/media/source_settings.py"), str(work / "source_settings.qml")], "PASS: Source settings")
run("cross-process", [sys.executable, str(ROOT / "tests/media/cross_process.py"), str(work)], "PASS: Cross-process Config")
run("persistence", ["quickshell", "--no-color", "-p", str(work / "persistence.qml")], "PASS: Settings saved")
env["MEDIA_TEST_READ"] = "1"
run("persistence", ["quickshell", "--no-color", "-p", str(work / "persistence.qml")], "PASS: Settings restored")
if "wayland-imports" in sys.argv[1:]:
    display = os.environ.get("WAYLAND_DISPLAY", "")
    if not display:
        raise SystemExit("Wayland import check requested without WAYLAND_DISPLAY")
    socket = Path(display) if Path(display).is_absolute() else Path(os.environ["XDG_RUNTIME_DIR"]) / display
    env.update(QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY=str(socket))
    run("wayland-imports", ["quickshell", "--no-color", "-p", str(work / "wayland_imports.qml")], "PASS: Wayland component imports")
print(f"Diagnostics (outside the repository): {work}")
