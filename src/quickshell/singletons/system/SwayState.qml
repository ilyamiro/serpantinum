pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root


    property int activeIndex: 0
    property var activeIndicesByOutput: ({})
    property var occupiedMap: ({})

    property var windows: []
    signal windowsUpdated()

    property string keyboardLayout: ""
    property bool keyboardReady: false
    readonly property string shortKeyboardLayout: keyboardLayout ? keyboardLayout.substring(0, 2).toUpperCase() : "US"

    property int workspaceSubscribers: 0
    property int windowSubscribers: 0
    property int keyboardSubscribers: 0

    property string _eventSpec: ""

    function subscribe() {
        workspaceSubscribers++;
        _sync();
        if (workspaceSubscribers === 1) {
            _requestWorkspaces();
            _requestTree();
        }
    }

    function unsubscribe() {
        workspaceSubscribers = Math.max(0, workspaceSubscribers - 1);
        _sync();
    }

    function subscribeWindows() {
        windowSubscribers++;
        _sync();
        if (windowSubscribers === 1) _requestTree();
    }

    function unsubscribeWindows() {
        windowSubscribers = Math.max(0, windowSubscribers - 1);
        _sync();
    }

    function subscribeKeyboard() {
        keyboardSubscribers++;
        _sync();
        if (keyboardSubscribers === 1) _requestInputs();
    }

    function unsubscribeKeyboard() {
        keyboardSubscribers = Math.max(0, keyboardSubscribers - 1);
        _sync();
    }

    function refreshKeyboard() {
        if (keyboardSubscribers > 0) _requestInputs();
    }

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }

    function focusWorkspace(index) {
        Quickshell.execDetached(["swaymsg", "workspace", "number", String(index + 1)]);
    }

    Connections {
        target: Compositor
        function onNameChanged() {
            root._sync();
            root._refreshAll();
        }
    }

    function _sync() {
        let types = [];
        if (workspaceSubscribers > 0 || windowSubscribers > 0) types.push("workspace", "window");
        if (workspaceSubscribers > 0) types.push("output");
        if (keyboardSubscribers > 0) types.push("input");
        let spec = (Compositor.name === "sway" && types.length > 0) ? JSON.stringify(types) : "";
        if (spec === root._eventSpec) return;
        root._eventSpec = spec;
        eventStream.running = false;
        if (spec !== "") {
            eventStream.running = true;
            _refreshAll();
        }
    }

    function _refreshAll() {
        if (workspaceSubscribers > 0) _requestWorkspaces();
        if (workspaceSubscribers > 0 || windowSubscribers > 0) _requestTree();
        if (keyboardSubscribers > 0) _requestInputs();
    }

    property bool _workspacesPending: false
    property bool _treePending: false
    property bool _inputsPending: false

    function _requestWorkspaces() {
        if (Compositor.name !== "sway") return;
        if (workspacesProc.running) {
            root._workspacesPending = true;
            return;
        }
        workspacesProc.running = true;
    }

    function _requestTree() {
        if (Compositor.name !== "sway") return;
        if (treeProc.running) {
            root._treePending = true;
            return;
        }
        treeProc.running = true;
    }

    function _requestInputs() {
        if (Compositor.name !== "sway") return;
        if (inputsProc.running) {
            root._inputsPending = true;
            return;
        }
        inputsProc.running = true;
    }

    function _handleEvent(line) {
        let ev = null;
        let change = "";
        let kind = "";
        let m = /^\{\s*"change":\s*"([a-z_]+)",\s*"(container|old|current|input)"/.exec(line);
        if (m) {
            change = m[1];
            kind = m[2] === "container" ? "window" : (m[2] === "input" ? "input" : "workspace");
        } else {
            try {
                ev = JSON.parse(line);
            } catch (e) {
                return;
            }
            if (!ev || typeof ev.change !== "string") return;
            change = ev.change;
            if (ev.container) kind = "window";
            else if (ev.input) kind = "input";
            else if (ev.current !== undefined || ev.old !== undefined) kind = "workspace";
            else kind = "output";
        }

        if (kind === "workspace") {
            if (change === "focus") {
                if (workspaceSubscribers > 0) {
                    if (!ev) {
                        try {
                            ev = JSON.parse(line);
                        } catch (e) {
                            ev = null;
                        }
                    }
                    let idx = (ev && ev.current) ? _workspaceIndex(ev.current, -1) : -1;
                    let output = (ev && ev.current && ev.current.output) ? String(ev.current.output) : "";
                    if (idx >= 0 && output !== "") {
                        if (root.activeIndex !== idx) root.activeIndex = idx;
                        if (root.activeIndicesByOutput[output] !== idx) {
                            let map = Object.assign({}, root.activeIndicesByOutput);
                            map[output] = idx;
                            root.activeIndicesByOutput = map;
                        }
                    } else {
                        _requestWorkspaces();
                    }
                }
                if (windowSubscribers > 0) _requestTree();
            } else if (change === "move" || change === "rename" || change === "reload") {
                if (workspaceSubscribers > 0) _requestWorkspaces();
                _requestTree();
            }
        } else if (kind === "output") {
            if (workspaceSubscribers > 0) _requestWorkspaces();
            if (windowSubscribers > 0) _requestTree();
        } else if (kind === "window") {
            if (change === "new" || change === "close" || change === "move") {
                _requestTree();
            } else if (windowSubscribers > 0 && (change === "title" || change === "focus")) {
                if (!ev) {
                    try {
                        ev = JSON.parse(line);
                    } catch (e) {
                        _requestTree();
                        return;
                    }
                }
                _applyWindowChange(change, ev ? ev.container : null);
            }
        } else if (kind === "input") {
            if (keyboardSubscribers > 0 && (change === "xkb_layout" || change === "xkb_keymap" || change === "added" || change === "removed")) _requestInputs();
        }
    }

    function _appIdOf(node) {
        return node.app_id || (node.window_properties ? node.window_properties.class : "") || "";
    }

    function _applyWindowChange(change, con) {
        if (!con || con.id === undefined || treeProc.running) {
            _requestTree();
            return;
        }
        let list = root.windows;
        let pos = -1;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === con.id) {
                pos = i;
                break;
            }
        }
        if (pos < 0) {
            _requestTree();
            return;
        }

        let next = list.slice();
        if (change === "title") {
            next[pos] = Object.assign({}, list[pos], {
                appId: _appIdOf(con) || list[pos].appId,
                title: con.name || ""
            });
        } else {
            for (let j = 0; j < next.length; j++) {
                let focused = next[j].id === con.id;
                if (next[j].focused !== focused) next[j] = Object.assign({}, next[j], { focused: focused });
            }
        }
        root.windows = next;
        root.windowsUpdated();
    }

    function _workspaceIndex(ws, fallback) {
        let num = (ws.num !== undefined && ws.num > 0) ? ws.num : parseInt(ws.name);
        return (!isNaN(num) && num > 0) ? num - 1 : fallback;
    }

    function _applyWorkspaces(list) {
        let activeIdx = 0;
        let byOutput = {};
        for (let i = 0; i < list.length; i++) {
            let ws = list[i];
            if (!ws) continue;
            let idx = _workspaceIndex(ws, i);
            if (ws.focused) activeIdx = idx;
            if (ws.visible && ws.output) byOutput[ws.output] = idx;
        }
        if (root.activeIndex !== activeIdx) root.activeIndex = activeIdx;
        if (JSON.stringify(byOutput) !== JSON.stringify(root.activeIndicesByOutput)) root.activeIndicesByOutput = byOutput;
    }

    function _collectTree(node, output, wsIdx, wsName, out, occ) {
        if (!node) return;
        if (node.type === "output" && node.name) {
            output = node.name;
        } else if (node.type === "workspace") {
            wsName = node.name || "";
            wsIdx = _workspaceIndex(node, -1);
            let count = (node.nodes ? node.nodes.length : 0) + (node.floating_nodes ? node.floating_nodes.length : 0);
            if (wsIdx >= 0 && count > 0) occ[wsIdx] = true;
        }

        let appId = _appIdOf(node);
        if ((node.type === "con" || node.type === "floating_con") && appId) {
            out.push({
                id: node.id,
                appId: appId,
                title: node.name || "",
                workspace: wsIdx,
                workspaceLabel: wsName,
                output: output,
                focused: Boolean(node.focused)
            });
        }

        let nodes = node.nodes || [];
        for (let i = 0; i < nodes.length; i++) _collectTree(nodes[i], output, wsIdx, wsName, out, occ);
        let floating = node.floating_nodes || [];
        for (let j = 0; j < floating.length; j++) _collectTree(floating[j], output, wsIdx, wsName, out, occ);
    }

    function _applyInputs(list) {
        let name = "";
        for (let i = 0; i < list.length; i++) {
            let dev = list[i];
            if (dev && dev.type === "keyboard" && dev.xkb_active_layout_name !== null && dev.xkb_active_layout_name !== undefined) {
                name = String(dev.xkb_active_layout_name);
                break;
            }
        }
        if (name === "" || name === "null") name = "US";
        if (root.keyboardLayout !== name) root.keyboardLayout = name;
        root.keyboardReady = true;
    }

    Process {
        id: eventStream
        running: false
        command: ["swaymsg", "-t", "subscribe", "-m", root._eventSpec || "[]"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.length > 0) root._handleEvent(data);
            }
        }
        onExited: {
            if (root._eventSpec !== "") restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root._eventSpec !== "" && !eventStream.running) {
                eventStream.running = true;
                root._refreshAll();
            }
        }
    }

    Process {
        id: workspacesProc
        running: false
        command: ["swaymsg", "-r", "-t", "get_workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(this.text);
                    if (Array.isArray(list)) root._applyWorkspaces(list);
                } catch (e) {}
            }
        }
        onExited: {
            if (root._workspacesPending) {
                root._workspacesPending = false;
                root._requestWorkspaces();
            }
        }
    }

    Process {
        id: treeProc
        running: false
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let tree = JSON.parse(this.text);
                    let found = [];
                    let occ = {};
                    root._collectTree(tree, "", -1, "", found, occ);
                    if (JSON.stringify(occ) !== JSON.stringify(root.occupiedMap)) root.occupiedMap = occ;
                    root.windows = found;
                    root.windowsUpdated();
                } catch (e) {}
            }
        }
        onExited: {
            if (root._treePending) {
                root._treePending = false;
                root._requestTree();
            }
        }
    }

    Process {
        id: inputsProc
        running: false
        command: ["swaymsg", "-r", "-t", "get_inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(this.text);
                    if (Array.isArray(list)) root._applyInputs(list);
                } catch (e) {}
            }
        }
        onExited: {
            if (root._inputsPending) {
                root._inputsPending = false;
                root._requestInputs();
            }
        }
    }
}
