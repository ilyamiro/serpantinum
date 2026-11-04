pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property var apps: []
    property string userDir: ""
    property bool loaded: false
    readonly property bool busy: applyProcess.running
    readonly property bool listing: listProcess.running

    property bool _applyPending: false
    property bool _forcePending: false
    property bool _listPending: false
    property string _pendingEnabled: ""

    readonly property string scriptPath: ((typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : (Quickshell.env("HOME") + "/.local/share/serpantinum/src")) + "/scripts/theming/apptheme.py"
    readonly property var processEnv: ({
        "QS_STATE_DIR": (typeof Caching !== "undefined" && Caching.stateDir) ? Caching.stateDir : (Quickshell.env("HOME") + "/.local/state/serpantinum"),
        "QS_SETTINGS": Config.settingsJsonPath
    })

    signal applied(var result)

    function _enabledList() {
        let out = [];
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].enabled) out.push(apps[i].id);
        }
        return out;
    }

    function apply(force) {
        if (force) _forcePending = true;
        if (applyProcess.running) {
            _applyPending = true;
            return;
        }
        _startApply();
    }

    function _startApply() {
        let cmd = ["python3", scriptPath, "apply"];
        if (_pendingEnabled !== "") {
            cmd.push("--enabled=" + (_pendingEnabled === "-" ? "" : _pendingEnabled));
            _pendingEnabled = "";
        }
        if (_forcePending) {
            cmd.push("--force");
            _forcePending = false;
        }
        _applyPending = false;
        applyProcess.command = cmd;
        applyProcess.running = true;
    }

    function refresh() {
        if (listProcess.running) {
            _listPending = true;
            return;
        }
        listProcess.running = true;
    }

    function setEnabled(appId, on) {
        let enabled = _enabledList().filter(id => id !== appId);
        if (on) enabled.push(appId);
        enabled.sort();
        let next = [];
        for (let i = 0; i < apps.length; i++) {
            let entry = Object.assign({}, apps[i]);
            if (entry.id === appId) entry.enabled = on;
            next.push(entry);
        }
        apps = next;
        let theme = Config.getSetting("theme", {});
        theme.apps = enabled;
        Config.setSetting("theme", theme);
        _pendingEnabled = enabled.length > 0 ? enabled.join(",") : "-";
        apply(false);
    }

    function openFolder(path) {
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "_", path || userDir]);
    }

    function _runAction(kind, args) {
        if (actionProcess.running) return false;
        actionProcess.kind = kind;
        actionProcess.command = ["python3", scriptPath].concat(args);
        actionProcess.running = true;
        return true;
    }

    function customize(appId) {
        _runAction("customize", ["customize", appId]);
    }

    function reset(appId) {
        _runAction("reset", ["reset", appId]);
    }


    Process {
        id: applyProcess
        environment: root.processEnv
        stdout: StdioCollector {
            id: applyOut
            onStreamFinished: {
                let result = null;
                try { result = JSON.parse(applyOut.text); } catch (e) {}
                root.applied(result);
            }
        }
        onExited: {
            if (root._applyPending || root._forcePending) {
                root._startApply();
            } else if (root.loaded) {
                root.refresh();
            }
        }
    }

    Process {
        id: listProcess
        command: ["python3", root.scriptPath, "list"]
        environment: root.processEnv
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    let data = JSON.parse(listOut.text);
                    if (data && Array.isArray(data.apps)) {
                        root.apps = data.apps;
                        root.userDir = data.userDir || "";
                        root.loaded = true;
                    }
                } catch (e) {}
            }
        }
        onExited: {
            if (root._listPending) {
                root._listPending = false;
                listProcess.running = true;
            }
        }
    }

    Process {
        id: actionProcess
        property string kind: ""
        environment: root.processEnv
        stdout: StdioCollector {
            id: actionOut
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(actionOut.text); } catch (e) {}
                if (data && data.ok) {
                    if (actionProcess.kind === "customize") root.openFolder(data.dir);
                    root.apply(true);
                }
            }
        }
    }
}
