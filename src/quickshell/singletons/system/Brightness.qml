pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property int value: 0
    property string backend: ""
    property bool initialized: false
    readonly property bool isDdc: backend === "ddc"

    property int _pendingPercent: -1

    function _commitPending() {
        if (root._pendingPercent < 0) return;
        let pct = root._pendingPercent;
        root._pendingPercent = -1;
        Quickshell.execDetached(["serpantinum-core", "brightness", "set", String(pct)]);
    }

    function set(percent) {
        let pct = Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
        root.value = pct;
        root._pendingPercent = pct;
        if (!throttleTimer.running) throttleTimer.start();
    }

    function flush() {
        if (root._pendingPercent >= 0) {
            throttleTimer.stop();
            root._commitPending();
        }
    }

    function toggle() {
        throttleTimer.stop();
        root._pendingPercent = -1;
        let target = root.value > 0 ? 0 : 100;
        root.value = target;
        Quickshell.execDetached(["serpantinum-core", "brightness", "set", String(target)]);
    }

    function refresh() {
        if (!refreshProc.running) refreshProc.running = true;
    }

    Timer {
        id: throttleTimer
        interval: 120
        repeat: false
        onTriggered: root._commitPending()
    }

    JsonStreamProcess {
        id: watcher
        active: true
        command: ["serpantinum-core", "watch", "brightness"]
        onMessage: state => {
            root.backend = state.backend || "";
            let val = state.percent;
            if (typeof val !== "number" || val < 0) return;
            if (!root.initialized) root.initialized = true;
            root.value = val;
        }
    }

    Process {
        id: refreshProc
        running: false
        command: ["serpantinum-core", "brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(this.text.trim());
                if (!isNaN(val) && val >= 0) {
                    if (!root.initialized) root.initialized = true;
                    root.value = val;
                }
            }
        }
    }
}
