"""Two actual QML engines sharing Config; private D-Bus and synthetic MPRIS."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from gi.repository import GLib
from mpris_fixture import Control

root = Path(sys.argv[1])
control = Control()
request = root / "request.json"
result = root / "result.json"
env = os.environ.copy()
env.update(MEDIA_TEST_REQUEST=str(request), MEDIA_TEST_RESULT=str(result))
request.write_text('{"step":-1}')
processes = []
handles = []
cases = [
    ("automatic", False, False, "Playing", "Playing", "Brave", True, True, True),
    ("desktop:spotify", True, True, "Playing", "Playing", "Spotify", True, True, True),
    ("desktop:spotify", True, True, "Paused", "Playing", "Spotify", True, True, True),
    ("automatic", True, True, "Paused", "Playing", "Brave", True, True, True),
    ("desktop:brave", True, True, "Playing", "Paused", "Brave", True, True, True),
    ("desktop:brave", False, True, "Playing", "Paused", "Brave", True, True, True),
    ("desktop:spotify", True, True, "Stopped", "Playing", "Spotify", False, False, False),
    ("desktop:spotify", False, False, "Stopped", "Playing", "Spotify", True, True, False),
    ("desktop:spotify", True, True, "Playing", "Playing", "Spotify", True, True, True),
]
index = -1
deadline = time.monotonic() + 8
failure = None
last = None
loop = GLib.MainLoop()


def advance():
    global index, deadline
    index += 1
    if index == len(cases):
        loop.quit()
        return
    mode, idle, hide, spotify, browser, *_ = cases[index]
    control.Change("spotify", spotify)
    control.Change("browser", browser)
    temp = request.with_suffix('.tmp')
    temp.write_text(json.dumps(dict(step=index, mode=mode, idle=idle, lyrics=hide)))
    temp.replace(request)
    deadline = time.monotonic() + 8


def tick():
    global failure, last
    if any(p.poll() is not None for p in processes):
        failure = "A test process exited unexpectedly"
    elif index < 0:
        if result.exists():
            advance()
    else:
        try:
            last = json.loads(result.read_text())
            mode, idle, hide, spotify, browser, source, media, visible, found = cases[index]
            expected = dict(step=index, mode=mode, idle=idle, hideLyrics=hide, source=source,
                            mediaVisible=media, lyricsVisible=visible, hasLyrics=found,
                            subscribers=1, lyricSource=source,
                            playing=(spotify if source == "Spotify" else browser) == "Playing")
            if all(last.get(k) == v for k, v in expected.items()) and (last['width'] > 0 if media else last['width'] == 0):
                print(f"PASS: cross-process native settings case {index + 1}: {mode}", flush=True)
                advance()
                return index < len(cases)
        except (FileNotFoundError, ValueError):
            pass
    if time.monotonic() > deadline:
        failure = f"Timed out at case {index}: {last}"
    if failure:
        loop.quit()
        return False
    return True


try:
    for name in ("settings_reader", "settings_writer"):
        handle = (root / (name + '.log')).open('w')
        handles.append(handle)
        processes.append(subprocess.Popen(['quickshell', '--no-color', '-p', str(root / (name + '.qml'))],
                                          env=env, stdout=handle, stderr=subprocess.STDOUT))
    GLib.timeout_add(80, tick)
    loop.run()
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()  # exact owned child only
    for process in processes:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    for handle in handles:
        handle.close()
    for name in ("settings_reader", "settings_writer"):
        log = (root / (name + '.log')).read_text()
        print(log)
        if any(word in log for word in ("FAIL", "Binding loop", "TypeError", "ReferenceError", "Failed to load configuration")):
            failure = failure or "Runtime QML error"
if failure:
    sys.exit('FAIL: ' + failure)
print('PASS: Cross-process Config (9 native-control cases; actual Media/Lyrics reactions)')
