import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"

PanelWindow {
    id: dockWindow
    required property var modelData
    screen: modelData

    property int configRevision: 0
    property bool initialized: false

    readonly property real screenWidth: (dockWindow.screen && dockWindow.screen.width > 0) ? dockWindow.screen.width : (modelData && modelData.width > 0 ? modelData.width : 0)
    readonly property real screenHeight: (dockWindow.screen && dockWindow.screen.height > 0) ? dockWindow.screen.height : (modelData && modelData.height > 0 ? modelData.height : 0)
    readonly property real effectiveWindowWidth: dockWindow.width > 0 ? dockWindow.width : screenWidth
    readonly property real effectiveWindowHeight: dockWindow.height > 0 ? dockWindow.height : screenHeight

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { dockWindow.configRevision++; }
        function onDataReadyChanged() { dockWindow.configRevision++; }
        function onRawSettingsChanged() { dockWindow.configRevision++; }
    }

    property var defaultDockSettings: ({
        "enabled": true,
        "position": "bottom",
        "onTop": true,
        "elementSize": 44,
        "floating": false,
        "background": true,
        "exclusive": false,
        "autohide": false,
        "smartAutohide": true,
        "autohideTimeout": 1000,
        "editing": false,
        "apps": [],
        "overrideBoundsCorrection": false,
        "enableScrolling": false,
        "visibleElements": 7,
        "scrollingElements": 7,
        "maxVisibleElements": 7,
        "maxElements": 7,
        "hoverScale": 120,
        "cascadeScale": false,
        "focusRunning": true,
        "showRunningIndicators": true,
        "showRunningApps": false,
        "runningScope": "auto"
    })

    property var rawDockSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock) {
            return Config.rawSettings.dock;
        }
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("dock", defaultDockSettings);
        }
        return defaultDockSettings;
    }

    property var defaultLauncherSettings: ({
        "position": "top",
        "width": 600,
        "itemCount": 6,
        "terminalCommand": "kitty -e",
        "smartRanking": true
    })

    property var rawLauncherSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.launcher) {
            return Config.rawSettings.launcher;
        }
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("launcher", defaultLauncherSettings);
        }
        return defaultLauncherSettings;
    }

    property real launcherCustomWidth: (rawLauncherSettings && rawLauncherSettings.width !== undefined && !isNaN(rawLauncherSettings.width) && rawLauncherSettings.width > 0) ? rawLauncherSettings.width : 600
    property int launcherCustomItemCount: (rawLauncherSettings && rawLauncherSettings.itemCount !== undefined && !isNaN(rawLauncherSettings.itemCount) && rawLauncherSettings.itemCount > 0) ? rawLauncherSettings.itemCount : 6

    property bool dockEnabled: rawDockSettings.enabled !== undefined ? rawDockSettings.enabled : true
    property string dockPosition: rawDockSettings.position !== undefined ? rawDockSettings.position : "bottom"
    property bool dockOnTop: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.onTop !== undefined) {
            val = rawDockSettings.onTop;
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.onTop"] !== undefined) {
            val = Config.rawSettings["dock.onTop"];
        }
        if (val === undefined || val === null) return true;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }
    property bool editMode: rawDockSettings.editing !== undefined ? rawDockSettings.editing : false
    property int rawElementSize: rawDockSettings.elementSize !== undefined ? rawDockSettings.elementSize : 44
    property bool overrideBoundsCorrection: rawDockSettings.overrideBoundsCorrection !== undefined ? Boolean(rawDockSettings.overrideBoundsCorrection) : false

    property bool dockExclusive: {
        let val = undefined;
        if (rawDockSettings) {
            val = rawDockSettings.exclusive !== undefined ? rawDockSettings.exclusive : rawDockSettings.exclusiveMode;
        }
        if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
            val = Config.rawSettings["dock.exclusive"] !== undefined ? Config.rawSettings["dock.exclusive"] : Config.rawSettings["dock.exclusiveMode"];
        }
        if (val === undefined || val === null) return false;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property bool smartAutohide: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.smartAutohide !== undefined) {
            val = rawDockSettings.smartAutohide;
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.smartAutohide"] !== undefined) {
            val = Config.rawSettings["dock.smartAutohide"];
        }
        if (val === undefined || val === null) return true;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property bool isNiri: false
    property bool isSway: false
    property bool isHyprland: false
    readonly property bool isMango: MangoState.isMango
    readonly property string myOutput: (dockWindow.screen && dockWindow.screen.name) ? dockWindow.screen.name : ""
    readonly property int niriActiveIndex: NiriState.activeIndexFor(myOutput)
    readonly property var niriOccupiedMap: NiriState.occupiedMap
    readonly property int mangoActiveIndex: MangoState.activeIndexFor(myOutput)
    readonly property var mangoOccupiedMap: MangoState.occupiedByOutput
    property int swayActiveIndex: 0
    property var swayOccupiedMap: ({})

    property int activeIndex: {
        let idx = -1;
        if (isNiri) {
            idx = niriActiveIndex;
        } else if (isSway) {
            idx = swayActiveIndex;
        } else if (isMango) {
            idx = mangoActiveIndex;
        } else if (isHyprland || typeof Hyprland !== "undefined") {
            const fw = (typeof Hyprland !== "undefined") ? Hyprland.focusedWorkspace : null;
            if (!fw) return -1;
            idx = fw.id - 1;
        }
        return idx >= 0 ? idx : -1;
    }

    readonly property bool isWorkspaceBusy: {
        if (isNiri) {
            return !!niriOccupiedMap[activeIndex];
        }
        if (isSway) {
            return !!swayOccupiedMap[activeIndex];
        }
        if (isMango) {
            return !!(mangoOccupiedMap && MangoState.isOccupied(myOutput, activeIndex));
        }
        if (typeof Hyprland !== "undefined") {
            let ws = null;
            if (dockWindow.screen && Hyprland.monitors && Hyprland.monitors.values) {
                let mon = Hyprland.monitors.values.find(m => m.name === dockWindow.screen.name);
                if (mon && mon.activeWorkspace) {
                    ws = mon.activeWorkspace;
                }
            }
            if (!ws && Hyprland.focusedWorkspace) {
                ws = Hyprland.focusedWorkspace;
            }
            if (!ws && activeIndex >= 0 && Hyprland.workspaces && Hyprland.workspaces.values) {
                ws = Hyprland.workspaces.values.find(w => w.id === activeIndex + 1) ?? null;
            }
            if (ws) {
                if (ws.toplevels && ws.toplevels.values) {
                    return ws.toplevels.values.length > 0;
                }
                if (ws.windows !== undefined) {
                    return ws.windows > 0;
                }
            }
        }
        return false;
    }

    property bool autohide: rawDockSettings.autohide !== undefined ? rawDockSettings.autohide : false
    readonly property bool effectiveAutohide: smartAutohide ? isWorkspaceBusy : autohide


    property alias swayPoller: swayPoller

    Process {
        id: swayPoller
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t get_workspaces -r 2>/dev/null || echo '[]'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let wsList = JSON.parse(this.text) || [];
                    let occ = {};
                    let activeIdx = 0;
                    for (let i = 0; i < wsList.length; i++) {
                        let w = wsList[i];
                        let num = (w.num !== undefined && w.num > 0) ? w.num : parseInt(w.name);
                        let idx = (!isNaN(num) && num > 0) ? num - 1 : i;
                        if (w.focused) {
                            activeIdx = idx;
                        }
                        occ[idx] = true;
                    }
                    dockWindow.swayActiveIndex = activeIdx;
                    dockWindow.swayOccupiedMap = occ;
                } catch (e) {}

                swayWaiter.running = false;
                if (dockWindow.isSway) {
                    swayWaiter.running = true;
                }
            }
        }
    }

    Process {
        id: swayWaiter
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t subscribe -m '[\"workspace\", \"window\"]' 2>/dev/null | grep -m 1 -E '\"change\"'"
        ]
        onExited: {
            swayPoller.running = false;
            if (dockWindow.isSway) {
                swayPoller.running = true;
            }
        }
    }

    property real dockHoverScaleMultiplier: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.hoverScale !== undefined) {
            val = rawDockSettings.hoverScale;
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.hoverScale"] !== undefined) {
            val = Config.rawSettings["dock.hoverScale"];
        }
        let parsed = parseFloat(val);
        if (isNaN(parsed) || parsed < 100) return 1.20;
        return parsed / 100.0;
    }

    property bool dockCascadeScale: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.cascadeScale !== undefined) {
            val = rawDockSettings.cascadeScale;
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.cascadeScale"] !== undefined) {
            val = Config.rawSettings["dock.cascadeScale"];
        }
        if (val === undefined || val === null) return false;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property bool focusRunning: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.focusRunning !== undefined) val = rawDockSettings.focusRunning;
        else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.focusRunning"] !== undefined) val = Config.rawSettings["dock.focusRunning"];
        if (val === undefined || val === null) return true;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property bool showRunningIndicators: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.showRunningIndicators !== undefined) val = rawDockSettings.showRunningIndicators;
        else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.showRunningIndicators"] !== undefined) val = Config.rawSettings["dock.showRunningIndicators"];
        if (val === undefined || val === null) return true;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property bool showRunningApps: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.showRunningApps !== undefined) val = rawDockSettings.showRunningApps;
        else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.showRunningApps"] !== undefined) val = Config.rawSettings["dock.showRunningApps"];
        if (val === undefined || val === null) return true;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        return Boolean(val);
    }

    property string runningScopeSetting: {
        let val = undefined;
        if (rawDockSettings && rawDockSettings.runningScope !== undefined) val = rawDockSettings.runningScope;
        else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.runningScope"] !== undefined) val = Config.rawSettings["dock.runningScope"];
        return (typeof val === "string" && val !== "") ? val : "auto";
    }

    readonly property string effectiveRunningScope: {
        if (runningScopeSetting === "auto") {
            return "all";
        }
        return runningScopeSetting;
    }

    property bool enableScrolling: {
        let val = undefined;
        if (rawDockSettings) {
            val = rawDockSettings.enableScrolling !== undefined ? rawDockSettings.enableScrolling :
                  (rawDockSettings.scrollingEnabled !== undefined ? rawDockSettings.scrollingEnabled :
                  (rawDockSettings.scrollEnabled !== undefined ? rawDockSettings.scrollEnabled :
                  (rawDockSettings.scrolling !== undefined ? rawDockSettings.scrolling : undefined)));
        }
        if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
            val = Config.rawSettings["dock.enableScrolling"] !== undefined ? Config.rawSettings["dock.enableScrolling"] :
                  (Config.rawSettings["dock.scrollingEnabled"] !== undefined ? Config.rawSettings["dock.scrollingEnabled"] :
                  (Config.rawSettings["enableScrolling"] !== undefined ? Config.rawSettings["enableScrolling"] : undefined));
        }
        if (val === undefined || val === null) return false;
        if (typeof val === "boolean") return val;
        if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
        if (typeof val === "number") return val !== 0;
        return Boolean(val);
    }

    property int dockVisibleElements: {
        let val = undefined;
        if (rawDockSettings) {
            val = rawDockSettings.visibleElements !== undefined ? rawDockSettings.visibleElements :
                  (rawDockSettings.scrollingElements !== undefined ? rawDockSettings.scrollingElements :
                  (rawDockSettings.maxVisibleElements !== undefined ? rawDockSettings.maxVisibleElements :
                  (rawDockSettings.maxElements !== undefined ? rawDockSettings.maxElements :
                  (rawDockSettings.visibleItems !== undefined ? rawDockSettings.visibleItems :
                  (rawDockSettings.scrollElements !== undefined ? rawDockSettings.scrollElements :
                  (rawDockSettings.scrollingLimit !== undefined ? rawDockSettings.scrollingLimit :
                  (rawDockSettings.scrollingItemCount !== undefined ? rawDockSettings.scrollingItemCount :
                  (rawDockSettings.itemCount !== undefined ? rawDockSettings.itemCount : undefined))))))));
        }
        if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
            val = Config.rawSettings["dock.visibleElements"] !== undefined ? Config.rawSettings["dock.visibleElements"] :
                  (Config.rawSettings["dock.scrollingElements"] !== undefined ? Config.rawSettings["dock.scrollingElements"] :
                  (Config.rawSettings["visibleElements"] !== undefined ? Config.rawSettings["visibleElements"] : undefined));
        }
        let parsed = parseInt(val);
        return (!isNaN(parsed) && parsed > 0) ? parsed : 7;
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }

    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false
    property real barHeight: (rawBarSettings && rawBarSettings.height !== undefined) ? s(rawBarSettings.height) : s(40)

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }
    readonly property bool isBarSolid: barStyle === "solid" || barStyle === "fill"

    readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false
    readonly property bool isToplevelFullscreen: {
        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                let atl = ToplevelManager.activeToplevel;
                if (atl.screens && atl.screens.length > 0) {
                    return atl.screens.indexOf(dockWindow.screen) !== -1;
                }
                return true;
            }
        } catch (e) {}
        return false;
    }
    readonly property bool isHyprlandFullscreen: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }
    readonly property bool isFullscreenActive: isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive
    readonly property bool sameSideAsBar: (dockPosition === barPosition) && !isBarEffectivelyHidden
    readonly property real barMarginOffset: (!isBarSolid && !barAutohide) ? s(4) : 0
    readonly property real barOffset: sameSideAsBar ? (barHeight + barMarginOffset) : 0

    readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius
}
