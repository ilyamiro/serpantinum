import QtQuick

QtObject {
    id: history

    property int maxEntries: 100
    property int debounceMs: 400
    property bool enabled: true
    property var snapshotFn: null
    property var restoreFn: null
    property var beforeStepFn: null

    property var stack: []
    property int currentIndex: -1

    readonly property bool canUndo: history.currentIndex > 0
    readonly property bool canRedo: history.currentIndex >= 0 && history.currentIndex < history.stack.length - 1

    property Timer _debounceTimer: Timer {
        interval: history.debounceMs
        repeat: false
        onTriggered: history.commit()
    }

    function clear() {
        _debounceTimer.stop();
        history.stack = [];
        history.currentIndex = -1;
    }

    function reset() {
        _debounceTimer.stop();
        if (typeof history.snapshotFn !== "function") {
            history.stack = [];
            history.currentIndex = -1;
            return;
        }
        history.stack = [history.snapshotFn()];
        history.currentIndex = 0;
    }

    function scheduleCommit() {
        if (!history.enabled || history.currentIndex < 0) return;
        _debounceTimer.restart();
    }

    function commit() {
        _debounceTimer.stop();
        if (!history.enabled || history.currentIndex < 0 || typeof history.snapshotFn !== "function") return;
        let snap = history.snapshotFn();
        if (history.stack[history.currentIndex] === snap) return;
        let next = history.stack.slice(0, history.currentIndex + 1);
        next.push(snap);
        if (next.length > history.maxEntries) next.shift();
        history.stack = next;
        history.currentIndex = next.length - 1;
    }

    function step(delta) {
        if (!history.enabled || history.currentIndex < 0 || typeof history.restoreFn !== "function") return;
        if (typeof history.beforeStepFn === "function") history.beforeStepFn();
        history.commit();
        let target = history.currentIndex + delta;
        if (target < 0 || target >= history.stack.length) return;
        let prev = history.currentIndex;
        history.currentIndex = target;
        let result = history.restoreFn(history.stack[target]);
        if (result === false) {
            history.currentIndex = prev;
            return;
        }
        if (typeof result === "string") {
            let updated = history.stack.slice();
            updated[target] = result;
            history.stack = updated;
        }
    }

    function undo() {
        history.step(-1);
    }

    function redo() {
        history.step(1);
    }
}
