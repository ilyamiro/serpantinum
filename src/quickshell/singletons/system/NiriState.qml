pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property bool isNiri: Boolean(Quickshell.env("NIRI_SOCKET")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("niri") !== -1) : false)

    property int activeIndex: 0
    property var activeIndicesByOutput: ({})
    property var occupiedMap: ({})
    property var existingMap: ({})
    property int maxWorkspaceIndex: 0
    property var windowsMap: ({})
    property var workspacesMap: ({})
    signal windowsUpdated()

    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0
    property bool keyboardReady: false
    readonly property string keyboardLayout: (keyboardLayouts && keyboardLayouts.length > keyboardLayoutIndex && keyboardLayouts[keyboardLayoutIndex]) ? keyboardLayouts[keyboardLayoutIndex] : ""
    readonly property string shortKeyboardLayout: keyboardLayout ? keyboardLayout.substring(0, 2).toUpperCase() : "US"

    property int subscribers: 0

    function subscribe() {
        subscribers++;
        _syncStream();
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        _syncStream();
    }

    function _syncStream() {
        let want = isNiri && subscribers > 0;
        if (want) {
            niriWindowsPoller.running = true;
            niriWorkspacesPoller.running = true;
        }
        if (eventStream.running !== want) {
            eventStream.running = want;
        }
    }

    function refreshWindows() {
        if (isNiri) {
            niriWindowsPoller.running = true;
            niriWorkspacesPoller.running = true;
        }
    }

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }

    property var _workspaces: ({})
    property var _windows: ({})

    function _byId(list) {
        let map = {};
        if (Array.isArray(list)) {
            for (let i = 0; i < list.length; i++) {
                let item = list[i];
                if (item && item.id !== undefined) {
                    map[item.id] = item;
                }
            }
        }
        return map;
    }

    function _recompute() {
        let withWindows = {};
        for (let winId in _windows) {
            let win = _windows[winId];
            if (win && win.workspace_id !== undefined && win.workspace_id !== null) {
                withWindows[win.workspace_id] = true;
            }
        }

        let occ = {};
        let existing = {};
        let maxIdx = 0;
        let outputFocused = {};
        let outputActive = {};
        let outputFirst = {};
        let globalFocusedIdx = -1;
        let globalActiveIdx = -1;
        let firstIdx = -1;

        for (let id in _workspaces) {
            let w = _workspaces[id];
            if (!w) continue;
            let idx = (w.idx !== undefined ? w.idx : (w.id !== undefined ? w.id : 1)) - 1;
            if (idx >= 0) {
                existing[idx] = true;
                if (idx > maxIdx) maxIdx = idx;
                if (firstIdx < 0) firstIdx = idx;

                if ((w.active_window_id !== null && w.active_window_id !== undefined) || withWindows[w.id]) {
                    occ[idx] = true;
                }

                let out = w.output || "";
                if (out) {
                    if (outputFirst[out] === undefined) outputFirst[out] = idx;
                    if (w.is_focused) outputFocused[out] = idx;
                    else if (w.is_active && outputActive[out] === undefined) outputActive[out] = idx;
                }

                if (w.is_focused) globalFocusedIdx = idx;
                else if (w.is_active && globalActiveIdx < 0) globalActiveIdx = idx;
            }
        }

        let nextGlobalActive = globalFocusedIdx >= 0 ? globalFocusedIdx : (globalActiveIdx >= 0 ? globalActiveIdx : (firstIdx >= 0 ? firstIdx : 0));
        if (root.activeIndex !== nextGlobalActive) {
            root.activeIndex = nextGlobalActive;
        }

        let nextOutputMap = {};
        for (let out in outputFirst) {
            if (outputFocused[out] !== undefined) {
                nextOutputMap[out] = outputFocused[out];
            } else if (outputActive[out] !== undefined) {
                nextOutputMap[out] = outputActive[out];
            } else {
                nextOutputMap[out] = outputFirst[out];
            }
        }

        if (JSON.stringify(nextOutputMap) !== JSON.stringify(root.activeIndicesByOutput)) {
            root.activeIndicesByOutput = nextOutputMap;
        }
        if (JSON.stringify(occ) !== JSON.stringify(root.occupiedMap)) {
            root.occupiedMap = occ;
        }
        if (JSON.stringify(existing) !== JSON.stringify(root.existingMap)) {
            root.existingMap = existing;
        }
        if (root.maxWorkspaceIndex !== maxIdx) {
            root.maxWorkspaceIndex = maxIdx;
        }
        root.windowsMap = Object.assign({}, _windows);
        root.workspacesMap = Object.assign({}, _workspaces);
        root.windowsUpdated();
    }

    function _handle(ev) {
        if (!ev || typeof ev !== "object") return;
        let p;
        if ((p = ev.WorkspacesChanged)) {
            _workspaces = _byId(p.workspaces || []);
        } else if ((p = ev.WorkspaceActivated)) {
            let target = _workspaces[p.id];
            if (target) {
                for (let id in _workspaces) {
                    let w = _workspaces[id];
                    if (w.output === target.output) {
                        w.is_active = (w.id === p.id);
                        if (p.focused !== false) w.is_focused = (w.id === p.id);
                    } else if (p.focused !== false) {
                        w.is_focused = false;
                    }
                }
            }
        } else if ((p = ev.WorkspaceActiveWindowChanged)) {
            let w = _workspaces[p.workspace_id];
            if (!w) return;
            w.active_window_id = p.active_window_id;
        } else if ((p = ev.WindowsChanged)) {
            _windows = _byId(p.windows || []);
        } else if ((p = ev.WindowOpenedOrChanged)) {
            if (p.window && p.window.id !== undefined) {
                let wCopy = Object.assign({}, _windows);
                wCopy[p.window.id] = p.window;
                _windows = wCopy;
            }
        } else if ((p = ev.WindowClosed)) {
            if (p.id !== undefined) {
                let wCopy = Object.assign({}, _windows);
                delete wCopy[p.id];
                _windows = wCopy;
            }
        } else if ((p = ev.WindowFocusChanged)) {
            let focusedId = (p.id !== undefined && p.id !== null) ? Number(p.id) : -1;
            let wCopy = Object.assign({}, _windows);
            for (let wid in wCopy) {
                let cur = wCopy[wid];
                if (cur) {
                    cur.is_focused = (Number(wid) === focusedId);
                }
            }
            _windows = wCopy;
        } else if ((p = ev.KeyboardLayoutsChanged)) {
            let kl = p.keyboard_layouts || {};
            keyboardLayouts = kl.names || [];
            keyboardLayoutIndex = kl.current_idx || 0;
            keyboardReady = true;
            return;
        } else if ((p = ev.KeyboardLayoutSwitched)) {
            keyboardLayoutIndex = p.idx || 0;
            keyboardReady = true;
            return;
        } else {
            return;
        }
        Qt.callLater(_recompute);
    }

    Process {
        id: niriWindowsPoller
        running: false
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(this.text);
                    root._windows = root._byId(list);
                    root._recompute();
                } catch (e) {}
            }
        }
    }

    Process {
        id: niriWorkspacesPoller
        running: false
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(this.text);
                    root._workspaces = root._byId(list);
                    root._recompute();
                } catch (e) {}
            }
        }
    }

    Process {
        id: eventStream
        running: false
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed.length > 0) {
                    try {
                        root._handle(JSON.parse(trimmed));
                    } catch (e) {}
                }
            }
        }
        onExited: {
            if (root.isNiri && root.subscribers > 0) restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isNiri && root.subscribers > 0) {
                eventStream.running = false;
                eventStream.running = true;
            }
        }
    }
}
