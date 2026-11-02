"""Native Settings selection, cross-process updates and restart persistence."""
import json
import os
from pathlib import Path
import subprocess
import sys
from gi.repository import GLib
from mpris_fixture import Control

control = Control()
loop = GLib.MainLoop()
processes = []
restoring = False
failed = False


def launch(role):
    entrypoint = Path(sys.argv[1]).with_name("source_settings_" + role + ".qml")
    entrypoint.write_text(Path(sys.argv[1]).read_text())
    process = subprocess.Popen(["quickshell", "--no-color", "-p", str(entrypoint)],
                               env=dict(os.environ, MEDIA_TEST_ROLE=role))
    processes.append(process)


def tick():
    global restoring, failed
    if any(p.poll() is None for p in processes):
        return True
    if any(p.returncode for p in processes):
        failed = True
        loop.quit()
        return False
    if not restoring:
        with open(os.environ["QS_SETTINGS"]) as file:
            media = json.load(file)["media"]
        if media.get("musicSource") != "desktop:brave" or media.get("musicSourceName") != "Brave":
            failed = True
            loop.quit()
            return False
        restoring = True
        launch("restore")
        return True
    loop.quit()
    return False


launch("reader")
launch("writer")
GLib.timeout_add(100, tick)
loop.run()
if failed:
    sys.exit("FAIL: source settings process or persisted preference")
print("PASS: Source settings (native controls, cross-process update, unavailable selection, restart)")
