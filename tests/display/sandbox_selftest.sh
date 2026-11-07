#!/usr/bin/env bash
# Self-test of sandbox.sh with a FAKE hyprctl and a fake runtime dir: nothing real is touched.
# Checks: refusals, that the guard sees only virtual outputs, and that a change of the "real"
# session during the command is detected, printed and restored.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$ROOT/tests/display/sandbox.sh"
TMP=$(mktemp -d); trap 'kill $SLEEP 2>/dev/null; rm -rf "$TMP"' EXIT
export XDG_RUNTIME_DIR="$TMP/run"; mkdir -p "$XDG_RUNTIME_DIR/hypr/real" "$XDG_RUNTIME_DIR/hypr/nested" "$TMP/bin"
sleep 120 & SLEEP=$!
echo $SLEEP > "$XDG_RUNTIME_DIR/hypr/real/hyprland.lock"
python3 - "$XDG_RUNTIME_DIR/wayland-9" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1)
import os; os.fork() or (__import__("time").sleep(120), os._exit(0))
PY
# fake hyprctl: the "real" session reads $TMP/real.json (a command may change it), the nested one is virtual
cat > "$TMP/bin/hyprctl" <<'FAKE'
#!/bin/sh
case "$1 $2" in
  "-j monitors")
    if [ "$HYPRLAND_INSTANCE_SIGNATURE" = "nested" ]; then
      echo '[{"name":"HEADLESS-1","description":"","width":1920,"height":1080,"refreshRate":60.0,"x":0,"y":0,"scale":1,"transform":0,"disabled":false,"availableModes":["1920x1080@60.00Hz"],"focused":true}]'
    else cat "$FAKE_REAL"; fi ;;
  "eval "*|"eval "|eval*) echo "$@" >> "$FAKE_LOG"; cp "$FAKE_REAL.orig" "$FAKE_REAL"; echo ok ;;
esac
FAKE
chmod +x "$TMP/bin/hyprctl"
export PATH="$TMP/bin:$PATH" FAKE_REAL="$TMP/real.json" FAKE_LOG="$TMP/eval.log" HYPRLAND_INSTANCE_SIGNATURE=real WAYLAND_DISPLAY=wayland-1
echo '[{"name":"eDP-1","description":"x","width":1920,"height":1080,"refreshRate":60.061,"x":0,"y":0,"scale":1,"transform":0,"disabled":false,"availableModes":[],"focused":true}]' > "$TMP/real.json"
cp "$TMP/real.json" "$TMP/real.json.orig"
fail=0; ok() { echo "PASS $1"; }; bad() { echo "FAIL $1"; fail=1; }

"$T" hyprland real wayland-9 -- true >/dev/null 2>&1; [ $? -eq 2 ] && ok "refuses the real signature" || bad "refuses the real signature"
"$T" hyprland nested wayland-1 -- true >/dev/null 2>&1; [ $? -eq 2 ] && ok "refuses the real wayland display" || bad "refuses the real wayland display"
mkdir -p "$XDG_RUNTIME_DIR/hypr/bogus"
"$T" hyprland bogus wayland-9 -- true >/dev/null 2>&1; [ $? -eq 2 ] && ok "refuses a compositor whose outputs are not virtual / unreadable" || bad "refuses non-virtual"
"$T" hyprland nested wayland-9 -- true >/dev/null 2>&1; [ $? -eq 0 ] && ok "accepts a virtual nested compositor and runs the command" || bad "accepts nested"
SANDBOX_EXTRA="FAKE_REAL=$TMP/real.json FAKE_LOG=$TMP/eval.log" "$T" hyprland nested wayland-9 -- sh -c 'echo changed > /dev/null; sed -i "s/\"x\":0/\"x\":1920/" "$FAKE_REAL"' >/dev/null 2>"$TMP/err"
rc=$?
[ $rc -eq 3 ] && ok "detects a change of the real session (exit 3)" || bad "detects change (rc=$rc)"
grep -q "THE REAL SESSION CHANGED" "$TMP/err" && ok "prints before/after" || bad "prints before/after"
[ -s "$FAKE_LOG" ] && grep -q 'hl.monitor' "$FAKE_LOG" && ok "restores the real session from the saved snapshot" || bad "restore"
grep -q '"x":0' "$TMP/real.json" && ok "real snapshot is back to 'before'" || bad "real back"
exit $fail
