import QtQuick
import "../../"
import ".."

QtObject {
    id: historyStore

    required property var redactorMode

    property var historyStack: []
    property int historyIndex: -1

    function snapshotModel() {
        let out = [];
        for (let i = 0; i < redactorMode.activeWidgetsModel.count; i++) {
            let row = redactorMode.activeWidgetsModel.get(i);
            let o = {};
            for (let k in row) {
                if (!k || typeof k !== "string" || k === "objectName" || k.endsWith("Changed") || k.startsWith("on") || typeof row[k] === "function" || row[k] === undefined) continue;
                o[k] = row[k];
            }
            out.push(o);
        }
        return JSON.stringify(out);
    }

    function resetHistory() {
        historyStack = [snapshotModel()];
        historyIndex = 0;
    }

    function commitHistory() {
        if (redactorMode.isInitializing || !redactorMode.isReady || historyIndex < 0) return;
        let snap = snapshotModel();
        if (historyStack[historyIndex] === snap) return;
        let stack = historyStack.slice(0, historyIndex + 1);
        stack.push(snap);
        if (stack.length > 100) stack.shift();
        historyStack = stack;
        historyIndex = stack.length - 1;
    }

    function stepHistory(delta) {
        if (redactorMode.isInitializing || historyIndex < 0) return;
        redactorMode.saveConfig();
        commitHistory();
        let target = historyIndex + delta;
        if (target < 0 || target >= historyStack.length) return;
        historyIndex = target;
        restoreSnapshot(historyStack[target]);
    }

    function undo() {
        stepHistory(-1);
    }

    function redo() {
        stepHistory(1);
    }

    function customKeys(entry) {
        return Object.keys(entry).filter(k => !WidgetRegistry.standardKeys.includes(k));
    }

    function restoreSnapshot(text) {
        let target = JSON.parse(text);
        let current = JSON.parse(snapshotModel());
        let mon = redactorMode.redactorWindow.safeMonitorName;
        let currentById = {};
        let targetById = {};
        for (let i = 0; i < current.length; i++) currentById[String(current[i].wId)] = current[i];
        for (let i = 0; i < target.length; i++) targetById[String(target[i].wId)] = target[i];

        redactorMode.isInitializing = true;

        for (let id in currentById) {
            if (!targetById[id]) WidgetSync.removeWidget(mon, id);
        }

        for (let i = 0; i < target.length; i++) {
            let e = target[i];
            let id = String(e.wId);
            let old = currentById[id];
            if (!old) {
                WidgetSync.addWidget(mon, id, e.wType, e.wX, e.wY, e.wWidth, e.wHeight, e.wOpacity, e.wImagePath || "", e.wRotation, e.wVariant);
                let keys = customKeys(e);
                for (let j = 0; j < keys.length; j++) WidgetSync.setProperty(mon, id, keys[j], e[keys[j]]);
                continue;
            }
            if (old.wX !== e.wX || old.wY !== e.wY || old.wWidth !== e.wWidth || old.wHeight !== e.wHeight || old.wOpacity !== e.wOpacity || old.wRotation !== e.wRotation) {
                WidgetSync.setGeometry(mon, id, e.wX, e.wY, e.wWidth, e.wHeight, e.wOpacity, e.wRotation);
            }
            if (old.wVariant !== e.wVariant) WidgetSync.setVariant(mon, id, e.wVariant);
            if ((old.wImagePath || "") !== (e.wImagePath || "")) WidgetSync.setImagePath(mon, id, e.wImagePath || "");
            let keys = customKeys(e);
            for (let j = 0; j < keys.length; j++) {
                if (JSON.stringify(old[keys[j]]) !== JSON.stringify(e[keys[j]])) WidgetSync.setProperty(mon, id, keys[j], e[keys[j]]);
            }
        }

        if (redactorMode.selectedId !== "" && !targetById[redactorMode.selectedId]) {
            redactorMode.selectedId = "";
            redactorMode.host.targetSelectedWidgetId = "";
        }

        redactorMode.activeWidgetsModel.clear();
        for (let i = 0; i < target.length; i++) redactorMode.activeWidgetsModel.append(target[i]);
        redactorMode.updateToolbarObscured();
        redactorMode.initTimer.restart();
    }
}
