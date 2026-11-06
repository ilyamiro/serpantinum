#!/usr/bin/env bash
# Try the Display settings page of this branch without touching the real screens.
#
# Opens a nested Hyprland (a normal window on your desktop) with two virtual
# monitors and loads the Display page inside it. Drag the monitors on the map,
# change resolution/refresh/scale and use Keep / Revert: every change only
# affects the virtual outputs. Close the page window (or press Ctrl+C here) to stop.
#
# Isolation: HOME, config, cache, state, IPC socket and the display transaction
# files all point to a temporary directory that is deleted on exit. Your running
# Serpantinum, ~/.config/hypr and ~/.config/serpantinum are never read or written.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QS_SRC="$ROOT/src/quickshell"
HARNESS="$QS_SRC/_try_ui.qml"

for tool in Hyprland hyprctl qs python3; do
    command -v "$tool" >/dev/null || { echo "Falta '$tool' en el PATH." >&2; exit 1; }
done
[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "Ejecútalo dentro de tu sesión Wayland." >&2; exit 1; }

REAL_SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"
REAL_WAYLAND="$WAYLAND_DISPLAY"
RUNTIME="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR no está definido}"
TMP="$(mktemp -d)"
NESTED_PID=""

cleanup() {
    [ -n "$NESTED_PID" ] && kill "$NESTED_PID" 2>/dev/null || true
    rm -f "$HARNESS"
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP"/{home,config,state,cache,run}

cat > "$TMP/nested.lua" <<'LUA'
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
LUA

cat > "$HARNESS" <<'QML'
import QtQuick
import Quickshell

// Temporary test window (removed on exit): hosts the Display page.
FloatingWindow {
    implicitWidth: 900
    implicitHeight: 1000
    Item {
        id: fakeRoot
        anchors.fill: parent
        property int currentTab: 0
        property int currentSubTab: 0
        function s(v) { return v }
        Loader {
            anchors.fill: parent
            Component.onCompleted: setSource("guide/display/DisplayMainTab.qml", { "rootObj": fakeRoot, "tabIndex": 0 })
        }
    }
}
QML

before_sockets="$(ls "$RUNTIME" | grep -E '^wayland-[0-9]+$' | sort || true)"
( cd "$TMP" && exec Hyprland -c "$TMP/nested.lua" >"$TMP/nested.log" 2>&1 ) &
NESTED_PID=$!

NESTED_SIG=""
for _ in $(seq 1 60); do
    kill -0 "$NESTED_PID" 2>/dev/null || { echo "Hyprland anidado no arrancó:" >&2; tail -n 5 "$TMP/nested.log" >&2; exit 1; }
    cand="$(ls -t "$RUNTIME/hypr/" 2>/dev/null | grep -vxF "$REAL_SIG" | head -n1 || true)"
    if [ -n "$cand" ] && HYPRLAND_INSTANCE_SIGNATURE="$cand" hyprctl -j monitors >/dev/null 2>&1; then
        NESTED_SIG="$cand"; break
    fi
    sleep 0.3
done
[ -n "$NESTED_SIG" ] || { echo "No encontré la instancia anidada." >&2; exit 1; }
[ "$NESTED_SIG" != "$REAL_SIG" ] || { echo "ABORTADO: la instancia anidada coincide con tu sesión real." >&2; exit 1; }

after_sockets="$(ls "$RUNTIME" | grep -E '^wayland-[0-9]+$' | sort || true)"
NESTED_WAYLAND="$(comm -13 <(echo "$before_sockets") <(echo "$after_sockets") | head -n1)"
[ -n "$NESTED_WAYLAND" ] && [ "$NESTED_WAYLAND" != "$REAL_WAYLAND" ] || { echo "No encontré el socket Wayland anidado." >&2; exit 1; }

export HYPRLAND_INSTANCE_SIGNATURE="$NESTED_SIG"
hyprctl output create headless >/dev/null
hyprctl output create headless >/dev/null
echo "Hyprland anidado: $NESTED_SIG ($NESTED_WAYLAND)"
hyprctl -j monitors all | python3 -c 'import json,sys; [print("  ",m["name"],"%dx%d"%(m["width"],m["height"]),"en",m["x"],m["y"]) for m in json.load(sys.stdin)]'
echo "Abriendo la página de Pantalla... (cierra su ventana para terminar)"

env HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/state" XDG_CACHE_HOME="$TMP/cache" \
    SERPANTINUM_DIR="$ROOT/src" QS_DIR="$QS_SRC" QS_CACHE_DIR="$TMP/cache" QS_STATE_DIR="$TMP/state" \
    QS_RUN_DIR="$TMP/run" QS_LOG_DIR="$TMP/run/logs" QS_SETTINGS="$TMP/config/settings.json" \
    IPC_SOCKET="$TMP/run/serp.sock" SERPANTINUM_DISPLAY_RUNTIME="$TMP/run/display" \
    HYPRLAND_INSTANCE_SIGNATURE="$NESTED_SIG" WAYLAND_DISPLAY="$NESTED_WAYLAND" \
    qs -p "$HARNESS"
