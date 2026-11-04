pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

Item {
    id: root

    property int subscribers: 0
    signal updated()

    property var windows: []
    property var groups: ({})
    property var groupOrder: []
    property var activeWorkspaceByOutput: ({})


    property var _mruTimestamps: ({})
    property int _seqCounter: 0

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            if (Compositor.name === "niri" && typeof NiriState !== "undefined") NiriState.subscribe();
            if (Compositor.name === "mango") MangoState.subscribeClients();
            if (Compositor.name === "sway") SwayState.subscribeWindows();
            _requestRebuild();
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            if (Compositor.name === "niri" && typeof NiriState !== "undefined") NiriState.unsubscribe();
            if (Compositor.name === "mango") MangoState.unsubscribeClients();
            if (Compositor.name === "sway") SwayState.unsubscribeWindows();
        }
    }

    Timer {
        id: debounceTimer
        interval: 40
        repeat: false
        onTriggered: root._rebuild()
    }

    function _requestRebuild() {
        if (root.subscribers <= 0) return;
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

        if (Compositor.name === "niri") {
            rawList = root._collectNiriWindows();
        } else if (Compositor.name === "sway") {
            rawList = root._collectSwayWindows();
        } else if (Compositor.name === "mango") {
            rawList = root._collectMangoWindows();
        } else if (Compositor.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
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
        let list = [];
        let wins = SwayState.windows || [];
        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            let rawApp = w.appId;
            let appKey = AppMatcher.normalizeKey(rawApp);
            let dId = AppMatcher.resolve(rawApp);
            let cid = dId !== "" ? AppMatcher.canonicalId(dId) : AppMatcher.canonicalId(rawApp);
            let gKey = cid !== "" ? cid : (appKey !== "" ? appKey : ("win:" + w.id));
            if (w.focused) _recordFocus(w.id);

            list.push({
                id: "sway:" + w.id,
                nativeId: w.id,
                seq: ++_seqCounter,
                appId: rawApp,
                appKey: appKey,
                title: w.title,
                workspace: w.workspace,
                workspaceLabel: w.workspaceLabel,
                output: w.output,
                focused: w.focused,
                lastFocus: _getMru(w.id),
                desktopId: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : ""),
                canonicalId: cid,
                groupKey: gKey,
                native: null
            });
        }
        return list;
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

        if (Compositor.name === "niri") {
            root._focusNiri(win);
            return;
        }

        if (Compositor.name === "sway") {
            root._focusSway(win);
            return;
        }

        if (Compositor.name === "mango") {
            root._focusMango(win);
            return;
        }

        if (Compositor.name === "hyprland") {
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
        if (Compositor.name === "hyprland") {
            root._closeHyprland(win);
            return;
        }
        if (Compositor.name === "niri" && nid) {
            root._closeNiri(win);
            return;
        }
        if (Compositor.name === "sway" && nid) {
            root._closeSway(win);
            return;
        }
        if (Compositor.name === "mango" && nid) {
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
            if (Compositor.name === "niri") root._requestRebuild();
        }
        function onWindowsMapChanged() {
            if (Compositor.name === "niri") root._requestRebuild();
        }
    }

    Connections {
        target: SwayState
        function onWindowsUpdated() {
            if (Compositor.name === "sway") root._requestRebuild();
        }
    }

    Connections {
        target: MangoState
        function onClientsUpdated() {
            if (Compositor.name === "mango") root._requestRebuild();
        }
    }
}
