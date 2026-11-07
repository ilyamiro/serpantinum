#!/usr/bin/env bash
# Screenshots of the Display page (normal / naming / dirty / pending / confirmed) against a TEST
# compositor. Run ONLY through tests/display/page_shot.sh (it refuses otherwise).
set -eu
[ "${SANDBOX:-}" = 1 ] && [ "${SERPANTINUM_DISPLAY_VIRTUAL_ONLY:-}" = 1 ] || { echo "run it through tests/display/page_shot.sh" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT=${1:?output dir}
P=$HOME/qs; mkdir -p "$P"/{cfg,state,cache,qsstate,run,logs} "$OUT"
H=$ROOT/src/quickshell/_shot.qml
trap 'rm -f "$H"' EXIT
cat > "$H" <<QML
import QtQuick
import Quickshell
FloatingWindow {
    id: win
    implicitWidth: 960
    implicitHeight: 760
    color: "#101014"
    property int step: 0
    function find(item) {
        if (item.naming !== undefined && item.pick !== undefined) return item
        for (let i = 0; i < item.children.length; i++) { let r = find(item.children[i]); if (r) return r }
        return null
    }
    function shot(name) { fakeRoot.grabToImage(function(r) { r.saveToFile("$OUT/" + name + ".png") }) }
    Item {
        id: fakeRoot
        anchors.fill: parent
        property int currentTab: 0
        property int currentSubTab: 0
        function s(v) { return v }
        Loader { id: ld; anchors.fill: parent
            Component.onCompleted: setSource("guide/display/DisplayMainTab.qml", { "rootObj": fakeRoot, "tabIndex": 0 }) }
    }
    Timer {
        interval: 2500; running: true; repeat: true
        onTriggered: {
            win.step++
            let t = ld.item
            if (!t || !t.txnAvailable) return
            let bar = win.find(ld.item)
            let mons = t.txnState.monitors
            let m = mons[mons.length - 1]
            if (win.step === 2) win.shot("1-normal")
            if (win.step === 3) bar.naming = true
            if (win.step === 4) win.shot("2-naming")
            if (win.step === 5) { bar.naming = false; t.layoutSetPosition(m.name, m.x, m.y + 60) }
            if (win.step === 6) win.shot("3-dirty")
            if (win.step === 7) t.layoutApply()
            if (win.step === 9) win.shot("4-pending")
            if (win.step === 10) t.txnConfirm()
            if (win.step === 12) win.shot("5-confirmed")
            if (win.step === 13) Qt.quit()
        }
    }
}
QML
env QS_DIR="$ROOT/src/quickshell" QS_CACHE_DIR="$P/cache" QS_STATE_DIR="$P/qsstate" QS_RUN_DIR="$P/run" \
    QS_LOG_DIR="$P/logs" QS_SETTINGS="$P/cfg/settings.json" IPC_SOCKET="$P/run/serp.sock" \
    timeout 70 qs -p "$H" > "$P/log.txt" 2>&1 || true
sed 's/\x1b\[[0-9;]*m//g' "$P/log.txt" | grep -E 'ERROR|TypeError|ReferenceError|Unable to assign' | sort -u | head -n 5 || true
ls "$OUT"
