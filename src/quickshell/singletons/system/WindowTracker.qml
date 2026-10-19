pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../../"

Item {
    id: root

    property int subscribers: 0
    signal updated()

    property var windows: []
    property var groups: ({})
    property var groupOrder: []
    property var activeWorkspaceByOutput: ({})

    readonly property bool isNiri: Boolean(Quickshell.env("NIRI_SOCKET")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("niri") !== -1) : false)
    readonly property bool isSway: Boolean(Quickshell.env("SWAYSOCK")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("sway") !== -1) : false)
    readonly property bool isMango: Boolean(Quickshell.env("MANGO_INSTANCE_SIGNATURE")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("mango") !== -1) : false)
    readonly property bool isHyprland: Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("hyprland") !== -1) : false)

    property var _mruTimestamps: ({})
    property int _seqCounter: 0
    property var _swayWindowList: []

    Component.onCompleted: {
        if (isNiri && typeof NiriState !== "undefined") NiriState.subscribe();
        if (isMango) MangoState.subscribeClients();
        if (isSway) _syncSwayStream(true);
        _requestRebuild();
    }

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            if (isNiri && typeof NiriState !== "undefined") NiriState.subscribe();
            if (isMango) MangoState.subscribeClients();
            if (isSway) _syncSwayStream(true);
            _requestRebuild();
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            if (isNiri && typeof NiriState !== "undefined") NiriState.unsubscribe();
            if (isMango) MangoState.unsubscribeClients();
            if (isSway) _syncSwayStream(false);
        }
    }

    function _syncSwayStream(start) {
        if (!isSway) return;
        swaySubscriber.running = Boolean(start);
        if (start) {
            swayTreePoller.running = true;
        }
    }

    Process {
        id: swayTreePoller
        running: false
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let rootNode = JSON.parse(this.text);
                    let found = [];
                    root._parseSwayTree(rootNode, "", -1, "", found);
                    root._swayWindowList = found;
                    root._requestRebuild();
                } catch (e) {}
            }
        }
    }

    Process {
        id: swaySubscriber
        running: false
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"window\", \"workspace\"]"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line && line.trim().length > 0) {
                    if (!swayTreePoller.running) {
                        swayTreePoller.running = true;
                    }
                }
            }
        }
        onExited: {
            if (root.isSway && root.subscribers > 0) {
                swayRestartTimer.restart();
            }
        }
    }

    Timer {
        id: swayRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isSway && root.subscribers > 0) {
                swaySubscriber.running = true;
            }
        }
    }

    function _parseSwayTree(node, currentOutput, currentWsIdx, currentWsName, outList) {
        if (!node) return;

        let out = currentOutput;
        let wsIdx = currentWsIdx;
        let wsName = currentWsName;

        if (node.type === "output" && node.name) {
            out = node.name;
        } else if (node.type === "workspace") {
            wsName = node.name || "";
            let num = (node.num !== undefined && node.num > 0) ? node.num : parseInt(node.name);
            wsIdx = (!isNaN(num) && num > 0) ? (num - 1) : -1;
        }

        let isWindow = (node.type === "con" || node.type === "floating_con") && (node.app_id || (node.window_properties && node.window_properties.class));
        if (isWindow) {
            let rawApp = node.app_id || (node.window_properties ? node.window_properties.class : "") || "";
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + node.id));
            let isFoc = Boolean(node.focused);
            if (isFoc) root._recordFocus(node.id);

            outList.push({
                id: "sway:" + node.id,
                nativeId: node.id,
                seq: ++root._seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: node.name || "",
                workspace: wsIdx,
                workspaceLabel: wsName,
                output: out,
                focused: isFoc,
                lastFocus: root._getMru(node.id),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: null
            });
        }

        let nodes = node.nodes || [];
        for (let i = 0; i < nodes.length; i++) {
            _parseSwayTree(nodes[i], out, wsIdx, wsName, outList);
        }
        let floatingNodes = node.floating_nodes || [];
        for (let j = 0; j < floatingNodes.length; j++) {
            _parseSwayTree(floatingNodes[j], out, wsIdx, wsName, outList);
        }
    }

    Timer {
        id: debounceTimer
        interval: 40
        repeat: false
        onTriggered: root._rebuild()
    }

    function _requestRebuild() {
        if (!debounceTimer.running) {
            debounceTimer.restart();
        }
    }

    function _recordFocus(nativeId) {
        if (!nativeId) return;
        _mruTimestamps[String(nativeId)] = Date.now();
    }

    function _getMru(nativeId) {
        if (!nativeId) return 0;
        return _mruTimestamps[String(nativeId)] || 0;
    }

    function _rebuild() {
        let rawList = [];

        if (isNiri) {
            rawList = root._collectNiriWindows();
        } else if (isSway) {
            rawList = root._collectSwayWindows();
        } else if (isMango) {
            rawList = root._collectMangoWindows();
        } else if (isHyprland && typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
            rawList = root._collectHyprlandWindows();
        } else if (typeof ToplevelManager !== "undefined" && ToplevelManager.toplevels && ToplevelManager.toplevels.values) {
            rawList = root._collectWaylandWindows();
        }

        let newGroups = {};
        let newGroupOrder = [];

        for (let i = 0; i < rawList.length; i++) {
            let win = rawList[i];
            let gk = win.groupKey;
            if (!newGroups[gk]) {
                newGroups[gk] = {
                    groupKey: gk,
                    desktopId: win.desktopId,
                    appId: win.appId,
                    windows: [],
                    count: 0,
                    focused: false,
                    activeWindow: null
                };
                newGroupOrder.push(gk);
            }
            let grp = newGroups[gk];
            grp.windows.push(win);
            grp.count++;
            if (win.focused) {
                grp.focused = true;
            }
        }

        for (let k in newGroups) {
            let grp = newGroups[k];
            grp.windows.sort(function(a, b) {
                if (a.focused !== b.focused) return a.focused ? -1 : 1;
                return b.lastFocus - a.lastFocus;
            });
            grp.activeWindow = grp.windows.length > 0 ? grp.windows[0] : null;
        }

        root.windows = rawList;
        root.groups = newGroups;
        root.groupOrder = newGroupOrder;
        root.updated();
    }

    function _collectHyprlandWindows() {
        let list = [];
        let toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            let t = toplevels[i];
            if (!t) continue;
            let addr = t.address ? String(t.address) : String(i);
            let rawApp = (t.wayland && t.wayland.appId) ? t.wayland.appId : ((t.lastIpcObject && (t.lastIpcObject["class"] || t.lastIpcObject["initialClass"])) ? (t.lastIpcObject["class"] || t.lastIpcObject["initialClass"]) : "");
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + addr));
            let isFoc = Boolean(t.activated || (typeof Hyprland !== "undefined" && Hyprland.activeToplevel && Hyprland.activeToplevel.address === t.address));
            if (isFoc) _recordFocus(addr);

            let wsObj = t.workspace || (t.lastIpcObject ? t.lastIpcObject.workspace : null);
            let rawWsId = (wsObj && wsObj.id !== undefined) ? wsObj.id : -1;
            let wsId = (rawWsId > 0) ? (rawWsId - 1) : -1;
            let wsName = (wsObj && wsObj.name) ? String(wsObj.name) : (rawWsId >= 0 ? String(rawWsId) : "");
            let monName = (t.monitor && t.monitor.name) ? String(t.monitor.name) : ((t.lastIpcObject && t.lastIpcObject.monitor !== undefined) ? String(t.lastIpcObject.monitor) : "");

            list.push({
                id: "hypr:" + addr,
                nativeId: addr,
                seq: ++_seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: t.title || (t.lastIpcObject && t.lastIpcObject.title ? t.lastIpcObject.title : ""),
                workspace: wsId,
                workspaceLabel: wsName,
                output: monName,
                focused: isFoc,
                lastFocus: _getMru(addr),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: t
            });
        }
        return list;
    }

    function _collectWaylandWindows() {
        let list = [];
        let toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            let t = toplevels[i];
            if (!t) continue;
            let addr = String(i);
            let rawApp = t.appId || "";
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + addr));
            let isFoc = Boolean(t.activated);
            if (isFoc) _recordFocus(addr);

            let monName = "";
            if (t.screens && t.screens.length > 0 && t.screens[0]) {
                monName = t.screens[0].name || "";
            }

            list.push({
                id: "wayland:" + addr,
                nativeId: addr,
                seq: ++_seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: t.title || "",
                workspace: -1,
                workspaceLabel: "",
                output: monName,
                focused: isFoc,
                lastFocus: _getMru(addr),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: t
            });
        }
        return list;
    }

    function _collectNiriWindows() {
        let list = [];
        if (typeof NiriState === "undefined") return list;

        let wMap = NiriState.windowsMap || {};
        let wsMap = NiriState.workspacesMap || {};

        for (let winId in wMap) {
            let w = wMap[winId];
            if (!w) continue;

            let rawApp = w.app_id || "";
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + w.id));

            let ws = wsMap[w.workspace_id] || null;
            let wsIdx = -1;
            let wsLabel = "";
            let outName = "";
            let isWsFocused = false;

            if (ws) {
                wsIdx = (ws.idx !== undefined ? ws.idx : (ws.id !== undefined ? ws.id : 1)) - 1;
                wsLabel = String(ws.idx !== undefined ? ws.idx : (ws.id !== undefined ? ws.id : ""));
                outName = ws.output || "";
                isWsFocused = Boolean(ws.is_focused);
            }

            let isFoc = Boolean(w.is_focused) || (isWsFocused && ws && ws.active_window_id === w.id);
            if (isFoc) _recordFocus(w.id);

            list.push({
                id: "niri:" + w.id,
                nativeId: w.id,
                seq: ++_seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: w.title || "",
                workspace: wsIdx,
                workspaceLabel: wsLabel,
                output: outName,
                focused: isFoc,
                lastFocus: _getMru(w.id),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: null
            });
        }
        return list;
    }

    function _collectSwayWindows() {
        return root._swayWindowList || [];
    }

    function _collectMangoWindows() {
        let list = [];
        let clients = MangoState.clients || [];
        for (let i = 0; i < clients.length; i++) {
            let c = clients[i];
            if (!c || c.id === undefined || c.id === null) continue;

            let rawApp = c.appid || "";
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + c.id));
            let isFoc = Boolean(c.is_focused);
            if (isFoc) _recordFocus(c.id);

            let tagIdx = (Array.isArray(c.tags) && c.tags.length > 0) ? (c.tags[0] - 1) : -1;

            list.push({
                id: "mango:" + c.id,
                nativeId: c.id,
                seq: ++_seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: c.title || "",
                workspace: tagIdx,
                workspaceLabel: tagIdx >= 0 ? String(tagIdx + 1) : "",
                output: c.monitor || "",
                focused: isFoc,
                lastFocus: _getMru(c.id),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: null
            });
        }
        return list;
    }

    function _formatHyprAddress(nid) {
        if (!nid) return "";
        let s = String(nid).trim();
        if (s.startsWith("address:")) {
            s = s.substring(8).trim();
        }
        if (!s.startsWith("0x")) {
            s = "0x" + s;
        }
        return "address:" + s;
    }

    function _focusHyprland(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        let addr = root._formatHyprAddress(nid);
        if (typeof Hyprland !== "undefined") {
            if (Hyprland.usingLua !== false) {
                Hyprland.dispatch("hl.dsp.focus({ window = \"" + addr + "\" })");
            } else {
                Hyprland.dispatch("focuswindow " + addr);
            }
            return;
        }
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ window = \"" + addr + "\" })' 2>/dev/null || hyprctl dispatch focuswindow " + addr]);
    }

    function _closeHyprland(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        let addr = root._formatHyprAddress(nid);
        if (typeof Hyprland !== "undefined") {
            if (Hyprland.usingLua !== false) {
                Hyprland.dispatch("hl.dsp.window.close({ window = \"" + addr + "\" })");
            } else {
                Hyprland.dispatch("closewindow " + addr);
            }
            return;
        }
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.window.close({ window = \"" + addr + "\" })' 2>/dev/null || hyprctl dispatch closewindow " + addr]);
    }

    function focusWindow(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid) _recordFocus(nid);

        if (isNiri) {
            root._focusNiri(win);
            return;
        }

        if (isSway) {
            root._focusSway(win);
            return;
        }

        if (isMango) {
            root._focusMango(win);
            return;
        }

        if (isHyprland) {
            root._focusHyprland(win);
            return;
        }

        if (typeof win === "object" && win && win.native && typeof win.native.activate === "function") {
            win.native.activate();
            return;
        }
    }

    function activate(win) {
        root.focusWindow(win);
    }

    function activateWindow(win) {
        root.focusWindow(win);
    }

    function close(win) {
        if (!win) return;
        if (typeof win === "object" && win && win.native && typeof win.native.close === "function") {
            win.native.close();
            return;
        }
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (isHyprland) {
            root._closeHyprland(win);
            return;
        }
        if (isNiri && nid) {
            root._closeNiri(win);
            return;
        }
        if (isSway && nid) {
            root._closeSway(win);
            return;
        }
        if (isMango && nid) {
            root._closeMango(win);
            return;
        }
    }

    function _focusNiri(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        let ws = (typeof win === "object" && win.workspaceLabel !== undefined) ? win.workspaceLabel : "";
        if (!ws && typeof NiriState !== "undefined" && NiriState.windowsMap && NiriState.workspacesMap) {
            let nw = NiriState.windowsMap[nid];
            if (nw && nw.workspace_id !== undefined) {
                let nws = NiriState.workspacesMap[nw.workspace_id];
                if (nws) {
                    ws = String(nws.idx !== undefined ? nws.idx : (nws.id !== undefined ? nws.id : ""));
                }
            }
        }
        if (ws) {
            Quickshell.execDetached(["bash", "-c", "niri msg action focus-workspace \"" + ws + "\" && niri msg action focus-window --id " + nid]);
        } else {
            Quickshell.execDetached(["bash", "-c", "niri msg action focus-window --id " + nid]);
        }
    }

    function _closeNiri(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        Quickshell.execDetached(["bash", "-c", "niri msg action close-window --id " + nid]);
    }

    function _focusSway(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        Quickshell.execDetached(["bash", "-c", "swaymsg '[con_id=" + nid + "] focus'"]);
    }

    function _closeSway(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        Quickshell.execDetached(["bash", "-c", "swaymsg '[con_id=" + nid + "] kill'"]);
    }

    function _focusMango(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + nid]);
    }

    function _closeMango(win) {
        if (!win) return;
        let nid = (typeof win === "object") ? win.nativeId : win;
        if (nid === undefined || nid === null || nid === "") return;
        Quickshell.execDetached(["mmsg", "dispatch", "killclient", "client," + nid]);
    }

    Connections {
        target: (typeof ToplevelManager !== "undefined" && ToplevelManager.toplevels) ? ToplevelManager.toplevels : null
        function onValuesChanged() { root._requestRebuild(); }
    }

    Connections {
        target: (typeof ToplevelManager !== "undefined") ? ToplevelManager : null
        function onActiveToplevelChanged() { root._requestRebuild(); }
    }

    Connections {
        target: (typeof Hyprland !== "undefined" && Hyprland.toplevels) ? Hyprland.toplevels : null
        function onValuesChanged() { root._requestRebuild(); }
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null
        function onActiveToplevelChanged() { root._requestRebuild(); }
        function onFocusedMonitorChanged() { root._requestRebuild(); }
        function onFocusedWorkspaceChanged() { root._requestRebuild(); }
        function onRawEvent(event) {
            if (!event || !event.name) return;
            let n = event.name;
            if (n === "activewindow" || n === "activewindowv2" || n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "workspace" || n === "focusedmon") {
                root._requestRebuild();
            }
        }
    }

    Connections {
        target: AppMatcher
        function onIndexChanged() { root._requestRebuild(); }
    }

    Connections {
        target: (typeof NiriState !== "undefined") ? NiriState : null
        function onWindowsUpdated() {
            if (root.isNiri) root._requestRebuild();
        }
        function onWindowsMapChanged() {
            if (root.isNiri) root._requestRebuild();
        }
    }

    Connections {
        target: MangoState
        function onClientsUpdated() {
            if (root.isMango) root._requestRebuild();
        }
    }
}
