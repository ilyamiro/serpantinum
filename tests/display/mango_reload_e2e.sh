#!/usr/bin/env bash
# usage: mango_reload_e2e.sh [both|first]
# Starts a HEADLESS mango (2 outputs) whose config lives in a throw-away HOME and runs
# mango_reload_e2e.py against it through sandbox.sh. "both": the include line first AND last
# (recommended); "first": only first (mango's reload then lets the user's rules win, which
# the engine has to undo). Nothing here touches the real session.
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANT=${1:-both}
RUNTIME="${XDG_RUNTIME_DIR:?}"
D=$(mktemp -d "${TMPDIR:-/tmp}/mango-reload.XXXXXX")
mkdir -p "$D/home/.config/mango/serpantinum"
# The watcher of a running mango covers files that existed when it started: seed the file like a
# second session would have it (on a first-ever run the file does not exist, nothing reloads).
printf '%s\n' 'monitor_rule=name:^HEADLESS\-1$,width:1920,height:1080,refresh:60.000,x:0,y:0,scale:1.0,rr:0' \
    'monitor_rule=name:^HEADLESS\-2$,width:1920,height:1080,refresh:60.000,x:1920,y:0,scale:1.0,rr:0' \
    > "$D/home/.config/mango/serpantinum/monitors.conf"
LINE='source_optional=./serpantinum/monitors.conf'
{
  echo "$LINE"
  echo 'monitor_rule=name:HEADLESS-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1'
  echo 'monitor_rule=name:HEADLESS-2,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1'
  [ "$VARIANT" = both ] && echo "$LINE"
} > "$D/home/.config/mango/config.conf"
env -i PATH="$PATH" XDG_RUNTIME_DIR="$RUNTIME" HOME="$D/home" WLR_BACKENDS=headless \
    WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman setsid mango >"$D/mango.log" 2>&1 &
PID=$!
cleanup() {
  if [ -r "/proc/$PID/cmdline" ] && tr '\0' ' ' < "/proc/$PID/cmdline" | grep -q '^mango'; then kill "$PID" 2>/dev/null || true; fi
  rm -rf "$D"
}
trap cleanup EXIT
SOCK="$RUNTIME/mango-$PID.sock"
for _ in $(seq 40); do [ -S "$SOCK" ] && break; sleep 0.25; done
[ -S "$SOCK" ] || { echo "mango did not start"; cat "$D/mango.log"; exit 1; }
sleep 1
# the wayland display is the socket served by OUR mango (owner pid), not "the new one"
WL=$(python3 - "$RUNTIME" "$PID" <<'PY'
import os, re, socket, struct, sys
run, pid = sys.argv[1], int(sys.argv[2])
for n in sorted(os.listdir(run)):
    if re.match(r"^wayland-\d+$", n):
        s = socket.socket(socket.AF_UNIX)
        try:
            s.connect(os.path.join(run, n))
            if struct.unpack("3i", s.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[0] == pid:
                print(n); break
        except OSError:
            pass
        finally:
            s.close()
PY
)
[ -n "$WL" ] || { echo "no wayland display served by mango $PID"; exit 1; }
echo "variant=$VARIANT mango=$PID display=$WL"
SANDBOX_EXTRA="HOME=$D/home" "$HERE/sandbox.sh" mango "$SOCK" "$WL" -- python3 "$HERE/mango_reload_e2e.py"
