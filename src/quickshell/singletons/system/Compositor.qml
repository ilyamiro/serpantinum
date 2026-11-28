pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

Item {
    id: root

    readonly property string name: {
        const desktop = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        if (Quickshell.env("NIRI_SOCKET") || desktop.indexOf("niri") !== -1) return "niri";
        if (Quickshell.env("MANGO_INSTANCE_SIGNATURE") || desktop.indexOf("mango") !== -1) return "mango";
        if (Quickshell.env("UMBRIEL_SOCKET") || desktop.indexOf("umbriel") !== -1) return "umbriel";
        if (Quickshell.env("SWAYSOCK") || desktop.indexOf("sway") !== -1) return "sway";
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || desktop.indexOf("hyprland") !== -1) return "hyprland";
        return "unknown";
    }

    readonly property int interactiveKeyboardFocus: name === "mango" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    readonly property bool requiresBottomExclusionLayer: name === "mango"
    readonly property bool supportsPerMonitorWorkspaceNumbering: name === "hyprland"
    readonly property bool hasOverviewBackdrop: name === "niri"

    property int workspacesRevision: 0
    property int _fullscreenRevision: 0
    property bool _ready: false

    Component.onCompleted: _ready = true

    function _stateSingleton() {
        if (root.name === "niri") return NiriState;
        if (root.name === "sway") return SwayState;
        if (root.name === "mango") return MangoState;
        if (root.name === "umbriel") return UmbrielState;
        return null;
    }

    function _screensList() {
        let out = [];
        try {
            let screens = Quickshell.screens;
            if (!screens) return out;
            let len = screens.length !== undefined ? screens.length : (screens.count !== undefined ? screens.count : 0);
            for (let i = 0; i < len; i++) {
                let s = screens[i] !== undefined ? screens[i] : (typeof screens.get === "function" ? screens.get(i) : null);
                if (s) out.push(s);
            }
        } catch (e) {}
        return out;
    }

    function _sanitizeName(screenName) {
        return String(screenName || "").trim().replace(/[^a-zA-Z0-9_-]/g, "_");
    }

    function _shellQuote(val) {
        return "'" + String(val || "").replace(/'/g, "'\\''") + "'";
    }

    function subscribe() {
        let s = _stateSingleton();
        if (s) s.subscribe();
    }

    function unsubscribe() {
        let s = _stateSingleton();
        if (s) s.unsubscribe();
    }

    function screenByName(screenName) {
        if (screenName === undefined || screenName === null) return null;
        let raw = String(screenName).trim();
        if (raw === "") return null;
        let safeRaw = _sanitizeName(raw);
        let screens = _screensList();

        for (let i = 0; i < screens.length; i++) {
            let s = screens[i];
            if (!s || !s.name) continue;
            let nm = String(s.name).trim();
            let safeNm = _sanitizeName(nm);
            if (nm === raw || safeNm === raw || safeNm === safeRaw) return s;
        }

        let rawLower = raw.toLowerCase();
        let safeLower = safeRaw.toLowerCase();
        for (let i = 0; i < screens.length; i++) {
            let s = screens[i];
            if (!s || !s.name) continue;
            let nmLower = String(s.name).trim().toLowerCase();
            let safeNmLower = _sanitizeName(nmLower).toLowerCase();
            if (nmLower === rawLower || safeNmLower === rawLower || safeNmLower === safeLower) return s;
        }

        return null;
    }

    function focusedScreen() {
        try {
            if (root.name === "hyprland" && typeof Hyprland !== "undefined") {
                let monName = "";
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                    monName = Hyprland.focusedMonitor.name;
                } else if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor && Hyprland.focusedWorkspace.monitor.name) {
                    monName = Hyprland.focusedWorkspace.monitor.name;
                }
                if (monName !== "") {
                    let s = screenByName(monName);
                    if (s) return s;
                }
            }
        } catch (e) {}

        try {
            if (root.name === "umbriel" && UmbrielState.focusedOutput) {
                let s = screenByName(UmbrielState.focusedOutput);
                if (s) return s;
            }
        } catch (e) {}

        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.screens && ToplevelManager.activeToplevel.screens.length > 0) {
                let s = ToplevelManager.activeToplevel.screens[0];
                if (s) return s;
            }
        } catch (e) {}

        try {
            if (Quickshell.cursorScreen) return Quickshell.cursorScreen;
        } catch (e) {}

        try {
            if (Quickshell.primaryScreen) return Quickshell.primaryScreen;
        } catch (e) {}

        let screens = _screensList();
        return screens.length > 0 ? screens[0] : null;
    }

    function resolveTargetScreen(preferred) {
        if (preferred === undefined || preferred === null || preferred === "") {
            return focusedScreen();
        }

        let screens = _screensList();

        if (typeof preferred === "object") {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i] === preferred) return screens[i];
            }
            if (preferred.name) {
                let byName = screenByName(preferred.name);
                if (byName) return byName;
            }
            return preferred;
        }

        if (typeof preferred === "number") {
            let idx = Math.floor(preferred);
            if (idx >= 0 && idx < screens.length) return screens[idx];
            return focusedScreen();
        }

        if (typeof preferred === "string") {
            let byName = screenByName(preferred);
            if (byName) return byName;
        }

        return focusedScreen();
    }

    function isFullscreenOn(screen) {
        let rev = root._fullscreenRevision + root.workspacesRevision;
        if (rev < 0) return false;

        let target = (typeof screen === "object" && screen !== null) ? screen : (typeof screen === "string" ? screenByName(screen) : null);
        let targetName = (target && target.name) ? String(target.name) : (typeof screen === "string" ? String(screen).trim() : "");

        try {
            if (typeof ToplevelManager !== "undefined") {
                let active = ToplevelManager.activeToplevel;
                if (active && active.fullscreen) {
                    if (active.screens && active.screens.length > 0) {
                        if (!target && targetName === "") return true;
                        for (let i = 0; i < active.screens.length; i++) {
                            let s = active.screens[i];
                            if (s === target || (targetName !== "" && s && s.name === targetName)) {
                                return true;
                            }
                        }
                    } else {
                        if (!target && targetName === "") return true;
                        let allScreens = _screensList();
                        if (allScreens.length <= 1) return true;
                        let foc = focusedScreen();
                        if (foc && (foc === target || (targetName !== "" && foc.name === targetName))) {
                            return true;
                        }
                    }
                }
            }
        } catch (e) {}

        try {
            if (root.name === "hyprland" && typeof Hyprland !== "undefined") {
                let mon = null;
                if (targetName !== "" && Hyprland.monitors && Hyprland.monitors.values) {
                    let mons = Hyprland.monitors.values;
                    for (let i = 0; i < mons.length; i++) {
                        if (mons[i] && mons[i].name === targetName) {
                            mon = mons[i];
                            break;
                        }
                    }
                }
                if (mon) {
                    if (mon.activeWorkspace && mon.activeWorkspace.hasFullscreen) return true;
                    let actTop = Hyprland.activeToplevel;
                    if (actTop && actTop.fullscreen) {
                        let topMon = "";
                        if (actTop.monitor && actTop.monitor.name) topMon = actTop.monitor.name;
                        else if (actTop.workspace && actTop.workspace.monitor && actTop.workspace.monitor.name) topMon = actTop.workspace.monitor.name;
                        if (topMon === targetName) return true;
                    }
                    return false;
                }
                if (targetName === "") {
                    if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen) return true;
                    if (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen) return true;
                }
            }
        } catch (e) {}

        return false;
    }

    function activeWorkspaceIndexFor(outputName) {
        let rev = root.workspacesRevision;
        if (rev < 0) return -1;

        if (root.name === "niri") {
            let idx = NiriState.activeIndexFor(outputName);
            let existing = NiriState.existingMap || {};
            let valid = (existing[idx] || Object.keys(existing).length === 0) ? idx : -1;
            return valid >= 0 ? valid : -1;
        }
        if (root.name === "sway") {
            let idx = SwayState.activeIndexFor(outputName);
            return idx >= 0 ? idx : -1;
        }
        if (root.name === "mango") {
            let idx = MangoState.activeIndexFor(outputName);
            return idx >= 0 ? idx : -1;
        }
        if (root.name === "umbriel") {
            let idx = UmbrielState.activeIndexFor(outputName);
            return idx >= 0 ? idx : -1;
        }
        if (root.name === "hyprland" && typeof Hyprland !== "undefined") {
            let mon = null;
            if (outputName && Hyprland.monitors && Hyprland.monitors.values) {
                mon = Hyprland.monitors.values.find(m => m && m.name === outputName) || null;
            }
            let ws = (mon && mon.activeWorkspace) ? mon.activeWorkspace : Hyprland.focusedWorkspace;
            return (ws && ws.id !== undefined && ws.id > 0) ? (ws.id - 1) : -1;
        }
        return -1;
    }

    function isWorkspaceOccupied(outputName, index) {
        let rev = root.workspacesRevision;
        if (rev < 0 || index < 0) return false;

        if (root.name === "niri") {
            let existing = NiriState.existingMap || {};
            let occupied = NiriState.occupiedMap || {};
            if (Object.keys(existing).length > 0) return Boolean(existing[index] && occupied[index]);
            return Boolean(occupied[index]);
        }
        if (root.name === "sway") {
            return Boolean(SwayState.occupiedMap && SwayState.occupiedMap[index]);
        }
        if (root.name === "mango") {
            return MangoState.isOccupied(outputName, index);
        }
        if (root.name === "umbriel") {
            return UmbrielState.isOccupied(outputName, index);
        }
        if (root.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.workspaces && Hyprland.workspaces.values) {
            let wsId = index + 1;
            let ws = Hyprland.workspaces.values.find(w => w && w.id === wsId) || null;
            if (!ws) return false;
            if (ws.toplevels && ws.toplevels.values) return ws.toplevels.values.length > 0;
            if (ws.windows !== undefined) return ws.windows > 0;
            return false;
        }
        return false;
    }

    function workspaceCountFor(outputName, fallbackCount) {
        let rev = root.workspacesRevision;
        if (rev < 0) return 2;

        let base = (fallbackCount !== undefined && fallbackCount !== null && Number(fallbackCount) > 0) ? Math.floor(Number(fallbackCount)) : 8;
        let act = activeWorkspaceIndexFor(outputName);
        let count = base;
        if (act >= count) count = act + 1;
        if (root.name === "niri" && NiriState.maxWorkspaceIndex >= count) count = NiriState.maxWorkspaceIndex + 1;
        if (root.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.workspaces && Hyprland.workspaces.values) {
            for (let ws of Hyprland.workspaces.values) {
                if (!ws || ws.id <= count) continue;
                if (outputName && (!ws.monitor || ws.monitor.name !== outputName)) continue;
                if (root.isWorkspaceOccupied(outputName, ws.id - 1)) count = ws.id;
            }
        }
        if (root.name === "sway") {
            let occupied = SwayState.occupiedMap || {};
            for (let key in occupied) {
                let idx = Number(key);
                if (occupied[key] && idx >= count) count = idx + 1;
            }
        }
        if (root.name === "mango" && MangoState.tagCount > 0) count = Math.min(count, MangoState.tagCount);
        if (root.name === "umbriel") {
            let uc = UmbrielState.countFor(outputName);
            if (uc >= count) count = uc;
        }
        return Math.max(2, count);
    }

    function focusWorkspace(outputName, index) {
        let wsId = Math.floor(Number(index)) + 1;
        if (isNaN(wsId) || wsId < 1) return;

        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(wsId)]);
        } else if (root.name === "sway") {
            SwayState.focusWorkspace(wsId - 1);
        } else if (root.name === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", "view," + wsId]);
        } else if (root.name === "umbriel") {
            UmbrielState.dispatch("workspace-switch", outputName ? [String(wsId), "--output", outputName] : [String(wsId)]);
        } else if (root.name === "hyprland") {
            if (typeof Hyprland !== "undefined") {
                if (Hyprland.usingLua !== false) {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
                } else {
                    Hyprland.dispatch("workspace " + wsId);
                }
            } else {
                Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + wsId + " })' 2>/dev/null || hyprctl dispatch workspace " + wsId]);
            }
        }
    }

    function stepWorkspace(outputName, delta, count) {
        if (!delta) return;
        let step = delta > 0 ? 1 : -1;
        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", step > 0 ? "focus-workspace-down" : "focus-workspace-up"]);
            return;
        }
        let total = (count !== undefined && count !== null && Number(count) > 0) ? Math.floor(Number(count)) : workspaceCountFor(outputName, 8);
        if (total <= 1) return;
        let cur = activeWorkspaceIndexFor(outputName);
        let nextIndex = 0;
        if (cur < 0) {
            nextIndex = step > 0 ? 0 : (total - 1);
        } else {
            nextIndex = (cur + step + total) % total;
        }
        if (nextIndex !== cur) {
            focusWorkspace(outputName, nextIndex);
        }
    }

    function dpmsCommand(enabled) {
        if (root.name === "niri") {
            return enabled ? "niri msg action power-on-monitors" : "niri msg action power-off-monitors";
        }
        if (root.name === "sway") {
            return enabled ? 'swaymsg "output * power on"' : 'swaymsg "output * power off"';
        }
        if (root.name === "mango") {
            return enabled
                ? "mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]?.name' | while read -r mon; do mmsg dispatch \"wakeup_monitor,$mon\"; done"
                : "mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]?.name' | while read -r mon; do mmsg dispatch \"sleep_monitor,$mon\"; done";
        }
        if (root.name === "umbriel") {
            return enabled ? "umbriel msg dpms-on" : "umbriel msg dpms-off";
        }
        if (root.name === "hyprland") {
            return enabled
                ? "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })' 2>/dev/null || hyprctl dispatch dpms on"
                : "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })' 2>/dev/null || hyprctl dispatch dpms off";
        }
        return "";
    }

    function setDpms(enabled) {
        let cmd = dpmsCommand(enabled);
        if (cmd !== "") {
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    function outputQueryCommand() {
        if (root.name === "niri") return "niri msg -j outputs 2>/dev/null";
        if (root.name === "sway") return "swaymsg -t get_outputs -r 2>/dev/null";
        if (root.name === "mango") return "mmsg get all-monitors 2>/dev/null | jq -c '.monitors' 2>/dev/null";
        if (root.name === "umbriel") return "umbriel outputs --json 2>/dev/null";
        if (root.name === "hyprland") return "hyprctl monitors all -j 2>/dev/null || hyprctl monitors -j 2>/dev/null";
        return "echo '[]'";
    }

    function outputEnableCommand(name, enabled, modeStr, scaleVal) {
        if (!name) return "";
        if (root.name === "niri") {
            return "niri msg output " + _shellQuote(name) + (enabled ? " on" : " off");
        }
        if (root.name === "sway") {
            return "swaymsg output " + _shellQuote(name) + (enabled ? " enable" : " disable");
        }
        if (root.name === "mango") {
            return "mmsg dispatch " + _shellQuote((enabled ? "wakeup_monitor," : "sleep_monitor,") + name);
        }
        if (root.name === "umbriel") {
            let act = enabled ? "output-enable" : "output-disable";
            return "umbriel msg " + act + " " + _shellQuote(name) + " 2>/dev/null || umbriel msg " + _shellQuote(act + ":" + name);
        }
        if (root.name === "hyprland") {
            let safeName = String(name).replace(/"/g, '\\"');
            if (enabled) {
                let mode = modeStr || "preferred";
                let sc = (scaleVal !== undefined && scaleVal !== null) ? Number(scaleVal) : 1.0;
                let safeMode = String(mode).replace(/"/g, '\\"');
                let luaCmd = 'hl.monitor({ output = "' + safeName + '", mode = "' + safeMode + '", position = "auto", scale = ' + sc.toString() + ', disabled = false })';
                return "hyprctl eval " + _shellQuote(luaCmd) + " 2>/dev/null || hyprctl keyword monitor " + _shellQuote(name + "," + mode + ",auto," + sc.toString());
            }
            let luaCmd = 'hl.monitor({ output = "' + safeName + '", disabled = true })';
            return "hyprctl eval " + _shellQuote(luaCmd) + " 2>/dev/null || hyprctl keyword monitor " + _shellQuote(name + ",disable");
        }
        return "";
    }

    function outputScaleCommand(name, scale, modeStr) {
        if (!name || !scale) return "";
        let sc = String(scale);
        if (root.name === "niri") {
            return "niri msg output " + _shellQuote(name) + " scale " + _shellQuote(sc);
        }
        if (root.name === "sway") {
            return "swaymsg output " + _shellQuote(name) + " scale " + _shellQuote(sc);
        }
        if (root.name === "umbriel") {
            return "umbriel config set " + _shellQuote('output."' + name + '".scale') + " " + _shellQuote(sc);
        }
        if (root.name === "hyprland") {
            let mode = modeStr || "preferred";
            let safeName = String(name).replace(/"/g, '\\"');
            let safeMode = String(mode).replace(/"/g, '\\"');
            let luaCmd = 'hl.monitor({ output = "' + safeName + '", mode = "' + safeMode + '", position = "auto", scale = ' + sc + ' })';
            return "hyprctl eval " + _shellQuote(luaCmd) + " 2>/dev/null || hyprctl keyword monitor " + _shellQuote(name + "," + mode + ",auto," + sc);
        }
        return "";
    }

    function switchKeyboardLayout() {
        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (root.name === "sway") {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else if (root.name === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        } else if (root.name === "umbriel") {
            Quickshell.execDetached(["umbriel", "msg", "keyboard-layout-next"]);
        } else if (root.name === "hyprland") {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    Connections {
        target: root._ready && root.name === "niri" ? NiriState : null
        function onActiveIndexChanged() { root.workspacesRevision++; }
        function onActiveIndicesByOutputChanged() { root.workspacesRevision++; }
        function onOccupiedMapChanged() { root.workspacesRevision++; }
        function onExistingMapChanged() { root.workspacesRevision++; }
        function onMaxWorkspaceIndexChanged() { root.workspacesRevision++; }
        function onWorkspacesMapChanged() { root.workspacesRevision++; }
    }

    Connections {
        target: root._ready && root.name === "sway" ? SwayState : null
        function onActiveIndexChanged() { root.workspacesRevision++; }
        function onActiveIndicesByOutputChanged() { root.workspacesRevision++; }
        function onOccupiedMapChanged() { root.workspacesRevision++; }
    }

    Connections {
        target: root._ready && root.name === "mango" ? MangoState : null
        function onActiveIndexChanged() { root.workspacesRevision++; }
        function onActiveIndicesByOutputChanged() { root.workspacesRevision++; }
        function onOccupiedMapChanged() { root.workspacesRevision++; }
        function onOccupiedByOutputChanged() { root.workspacesRevision++; }
        function onTagCountChanged() { root.workspacesRevision++; }
    }

    Connections {
        target: root._ready && root.name === "umbriel" ? UmbrielState : null
        function onActiveIndexChanged() { root.workspacesRevision++; }
        function onActiveIndicesByOutputChanged() { root.workspacesRevision++; }
        function onOccupiedMapChanged() { root.workspacesRevision++; }
        function onOccupiedByOutputChanged() { root.workspacesRevision++; }
        function onCountByOutputChanged() { root.workspacesRevision++; }
        function onWorkspaceCountChanged() { root.workspacesRevision++; }
        function onFocusedOutputChanged() { root.workspacesRevision++; }
    }

    Connections {
        target: (root._ready && root.name === "hyprland" && typeof Hyprland !== "undefined") ? Hyprland : null
        function onFocusedWorkspaceChanged() { root.workspacesRevision++; root._fullscreenRevision++; }
        function onFocusedMonitorChanged() { root.workspacesRevision++; root._fullscreenRevision++; }
        function onActiveToplevelChanged() { root._fullscreenRevision++; }
        function onRawEvent(event) {
            if (!event || !event.name) return;
            let n = event.name;
            if (n === "workspace" || n === "workspacev2" || n === "createworkspace" || n === "destroyworkspace" || n === "moveworkspace" || n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "focusedmon" || n === "activespecial") {
                root.workspacesRevision++;
            }
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2" || n === "workspace" || n === "workspacev2" || n === "focusedmon") {
                root._fullscreenRevision++;
            }
        }
    }

    Connections {
        target: (root._ready && root.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.workspaces) ? Hyprland.workspaces : null
        function onValuesChanged() { root.workspacesRevision++; }
    }

    Connections {
        target: (root._ready && root.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.monitors) ? Hyprland.monitors : null
        function onValuesChanged() { root.workspacesRevision++; root._fullscreenRevision++; }
    }

    Connections {
        target: (root._ready && root.name === "hyprland" && typeof Hyprland !== "undefined" && Hyprland.toplevels) ? Hyprland.toplevels : null
        function onValuesChanged() { root.workspacesRevision++; root._fullscreenRevision++; }
    }

    Connections {
        target: (root._ready && typeof ToplevelManager !== "undefined") ? ToplevelManager : null
        function onActiveToplevelChanged() { root._fullscreenRevision++; }
    }

    Connections {
        target: (root._ready && typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) ? ToplevelManager.activeToplevel : null
        ignoreUnknownSignals: true
        function onFullscreenChanged() { root._fullscreenRevision++; }
        function onScreensChanged() { root._fullscreenRevision++; }
    }
}
