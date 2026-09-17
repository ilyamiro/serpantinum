import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../reusables"
import "../../../"

Rectangle {
    id: workspacesWidgetRoot

    property var barWindow
    property var paths
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isNiri: false
    property bool isSway: false

    property int niriActiveIndex: 0
    property var niriOccupiedMap: ({})

    property int swayActiveIndex: 0
    property var swayOccupiedMap: ({})

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { workspacesWidgetRoot.configRevision++; }
        function onRawSettingsChanged() { workspacesWidgetRoot.configRevision++; }
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.sideBar && Config.rawSettings.sideBar.workspacesStyle) return Config.rawSettings.sideBar.workspacesStyle;
            if (Config.rawSettings.bar && Config.rawSettings.bar.sideWorkspacesStyle) return Config.rawSettings.bar.sideWorkspacesStyle;
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspacesStyle) return Config.rawSettings.bar.workspacesStyle;
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaces && Config.rawSettings.bar.workspaces.style) return Config.rawSettings.bar.workspaces.style;
        }
        return "pills";
    }

    // Display count, independent of the group. When "follows count" is off the bar
    // shows what this monitor is configured to show, keyed by screen name the same
    // way the display settings key their per-monitor scale. A missing entry falls
    // through to the shared count, so unplugging a screen only ever costs the
    // override, never the block layout - that one lives in groupSize.
    readonly property var displayPerMonitor: {
        let dummy = configRevision;
        let bs = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings.bar : null;
        return (bs && bs.workspaceDisplayPerMonitor) ? bs.workspaceDisplayPerMonitor : ({});
    }

    readonly property bool displayFollowsCount: {
        let dummy = configRevision;
        let bs = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings.bar : null;
        return !(bs && bs.workspaceDisplayFollowsCount === false);
    }

    readonly property int displayOverride: {
        if (displayFollowsCount) return -1;
        if (!barWindow || !barWindow.screen) return -1;
        let v = displayPerMonitor[barWindow.screen.name];
        if (v === undefined || v === null) return -1;
        return Math.max(2, Math.min(10, v));
    }

    property int baseWorkspaceCount: {
        let dummy = configRevision;
        if (displayOverride > 0) return displayOverride;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.sideWorkspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.sideWorkspaceCount));
            }
            if (Config.rawSettings.sideBar && Config.rawSettings.sideBar.sideWorkspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.sideBar.sideWorkspaceCount));
            }
            if (Config.rawSettings.bar && Config.rawSettings.bar.sideWorkspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.sideWorkspaceCount));
            }
            if (Config.rawSettings.sideBar && Config.rawSettings.sideBar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.sideBar.workspaceCount));
            }
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }


    // The block size, shared by every bar and by qs_manager.sh. Deliberately not
    // baseWorkspaceCount: that one is per-bar and purely visual (the side bar has
    // its own sideWorkspaceCount), so using it as the stride would let a vertical
    // bar address a different block than the keybinds and the horizontal bar.
    readonly property int groupSize: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }

    // Workspaces split into one block of baseWorkspaceCount per monitor (1-N,
    // N+1-2N, ...). Without this, a bar on the second monitor never lights up and
    // switching on the primary makes both bars look like they moved.
    property bool workspaceGroupsPerMonitor: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar)
            ? (Config.rawSettings.bar.workspaceGroupsPerMonitor === true) : false;
    }

    // The stride is the configured count, not the grown one: workspaceCount can
    // expand past it to show an out-of-range workspace, and a moving stride would
    // shift every other monitor's block along with it.
    readonly property int groupOffset: {
        if (!workspaceGroupsPerMonitor) return 0;
        // Hyprland only: the niri and sway paths track their own active index and
        // dispatch plain numbers, so an offset would desync the pills from focus.
        if (isNiri || isSway) return 0;
        if (!barWindow || !barWindow.screen) return 0;
        // Ordered left to right, y breaking ties so stacked screens keep a stable
        // order. Matched by name rather than by x, because two screens can sit at
        // the same coordinate and would otherwise both claim the first group.
        let ordered = Quickshell.screens.map(sc => sc).sort((a, b) => (a.x - b.x) || (a.y - b.y));
        let i = ordered.findIndex(sc => sc.name === barWindow.screen.name);
        return (i < 0 ? 0 : i) * groupSize;
    }

    // Index inside this bar's own group, or -1 when another monitor is focused.
    readonly property int hlLocalIndex: {
        const fw = Hyprland.focusedWorkspace;
        if (!fw) return -1;
        const l = fw.id - groupOffset - 1;
        return (l >= 0 && l < groupSize) ? l : -1;
    }
    // When focus is on the other screen we keep the last local one, so an unfocused
    // monitor's bar still shows where that monitor stands instead of going blank.
    property int lastLocalIndex: -1
    onHlLocalIndexChanged: if (hlLocalIndex >= 0) lastLocalIndex = hlLocalIndex;

    ListModel {
        id: workspaceListModel
    }

    function syncModel() {
        // Growth is capped at the group with per-monitor groups on: a workspace past
        // it belongs to another monitor, so growing further would render that
        // monitor's ids here. Inside the group it still grows, which is what lets a
        // bar display fewer workspaces than the block actually spans.
        let want = (activeIndex >= baseWorkspaceCount) ? (activeIndex + 1) : baseWorkspaceCount;
        if (workspaceGroupsPerMonitor) want = Math.min(want, groupSize);
        let target = Math.max(2, want);

        while (workspaceListModel.count < target) {
            workspaceListModel.append({ "modelData": workspaceListModel.count });
        }
        while (workspaceListModel.count > target) {
            workspaceListModel.remove(workspaceListModel.count - 1);
        }
    }

    onActiveIndexChanged: syncModel()
    onBaseWorkspaceCountChanged: syncModel()
    onWorkspaceGroupsPerMonitorChanged: syncModel()
    onGroupSizeChanged: syncModel()

    property int workspaceCount: workspaceListModel.count > 0 ? workspaceListModel.count : baseWorkspaceCount

    function findRepeater(obj) {
        if (!obj) return null;
        if (obj.model !== undefined && obj.count !== undefined && typeof obj.itemAt === "function") {
            return obj;
        }
        if (obj.children) {
            for (let i = 0; i < obj.children.length; i++) {
                let res = findRepeater(obj.children[i]);
                if (res) return res;
            }
        }
        if (obj.data) {
            for (let j = 0; j < obj.data.length; j++) {
                let res = findRepeater(obj.data[j]);
                if (res) return res;
            }
        }
        return null;
    }

    function attachModel() {
        if (faceLoader.item) {
            faceLoader.item.widget = workspacesWidgetRoot;
            let rep = findRepeater(faceLoader.item);
            if (rep && rep.model !== workspaceListModel) {
                rep.model = workspaceListModel;
            }
        }
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function wsForId(id) {
        if (isNiri || isSway) return null;
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isOccupied(index) {
        if (isNiri) {
            return !!niriOccupiedMap[index];
        }
        if (isSway) {
            return !!swayOccupiedMap[index];
        }
        let ws = wsForId(index + 1 + groupOffset);
        return ws !== null && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0;
    }

    function focusWorkspace(index) {
        let wsId = index + 1;
        if (isNiri) {
            niriActiveIndex = index;
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
        } else if (isSway) {
            swayActiveIndex = index;
            Quickshell.execDetached(["swaymsg", "workspace", "number", wsId.toString()]);
        } else {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsId + groupOffset) + " })");
        }
    }

    property int activeIndex: {
        let idx = -1;
        if (isNiri) {
            idx = niriActiveIndex;
        } else if (isSway) {
            idx = swayActiveIndex;
        } else {
            // Sticky only makes sense with per-monitor groups; without them the
            // index stays absolute so the list can grow past the configured count.
            if (workspaceGroupsPerMonitor) return lastLocalIndex;
            const fw = Hyprland.focusedWorkspace;
            if (!fw) return -1;
            idx = fw.id - 1;
        }
        return idx >= 0 ? idx : -1;
    }

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        workspacesWidgetRoot.isNiri = de.indexOf("niri") !== -1;
        workspacesWidgetRoot.isSway = de.indexOf("sway") !== -1;
        if (workspacesWidgetRoot.isNiri && workspacesWidgetRoot.moduleActive) {
            niriPoller.running = true;
            niriEventStream.running = true;
        }
        if (workspacesWidgetRoot.isSway && workspacesWidgetRoot.moduleActive) {
            swayPoller.running = true;
        }
        syncModel();
    }

    onModuleActiveChanged: {
        if (!moduleActive) {
            if (isNiri) {
                niriPoller.running = false;
                niriDebounceTimer.stop();
                niriRestartTimer.stop();
                niriEventStream.running = false;
            }
            if (isSway) {
                swayPoller.running = false;
                swayWaiter.running = false;
            }
        } else {
            if (isNiri) {
                niriPoller.running = false;
                niriPoller.running = true;
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
            if (isSway) {
                swayPoller.running = false;
                swayPoller.running = true;
            }
        }
    }

    Timer {
        id: niriDebounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (workspacesWidgetRoot.moduleActive && workspacesWidgetRoot.isNiri) {
                niriPoller.running = false;
                niriPoller.running = true;
            }
        }
    }

    Timer {
        id: niriRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (workspacesWidgetRoot.moduleActive && workspacesWidgetRoot.isNiri) {
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
        }
    }

    Process {
        id: niriEventStream
        running: false
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().length > 0) {
                    niriDebounceTimer.restart();
                }
            }
        }
        onExited: {
            if (workspacesWidgetRoot.moduleActive && workspacesWidgetRoot.isNiri) {
                niriRestartTimer.restart();
            }
        }
    }

    Process {
        id: niriPoller
        running: false
        command: [
            "bash",
            "-c",
            "workspaces=$(niri msg -j workspaces 2>/dev/null || echo '[]'); windows=$(niri msg -j windows 2>/dev/null || echo '[]'); echo \"{\\\"workspaces\\\": $workspaces, \\\"windows\\\": $windows}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let wsList = data.workspaces || [];
                    let winList = data.windows || [];
                    let occ = {};
                    for (let i = 0; i < winList.length; i++) {
                        let win = winList[i];
                        if (win.workspace_id !== undefined && win.workspace_id !== null) {
                            occ[win.workspace_id] = true;
                        }
                    }
                    let activeIdx = 0;
                    for (let j = 0; j < wsList.length; j++) {
                        let w = wsList[j];
                        let idx = (w.idx !== undefined ? w.idx : (w.id !== undefined ? w.id : 1)) - 1;
                        if (w.is_focused || w.is_active) {
                            activeIdx = idx;
                        }
                        if (w.active_window_id !== null || occ[w.id] || occ[w.idx]) {
                            occ[idx] = true;
                        }
                    }
                    workspacesWidgetRoot.niriActiveIndex = activeIdx;
                    workspacesWidgetRoot.niriOccupiedMap = occ;
                } catch (e) {}
            }
        }
    }

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
                    workspacesWidgetRoot.swayActiveIndex = activeIdx;
                    workspacesWidgetRoot.swayOccupiedMap = occ;
                } catch (e) {}

                swayWaiter.running = false;
                if (workspacesWidgetRoot.moduleActive && workspacesWidgetRoot.isSway) {
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
            if (workspacesWidgetRoot.moduleActive && workspacesWidgetRoot.isSway) {
                swayPoller.running = true;
            }
        }
    }

    property real targetY: 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    readonly property real barThickness: {
        if (barWindow) {
            if (barWindow.barWidth !== undefined && barWindow.barWidth > 0) return barWindow.barWidth;
            if (barWindow.barThickness !== undefined && barWindow.barThickness > 0) return barWindow.barThickness;
            if (barWindow.barHeight !== undefined && barWindow.barHeight > 0) return barWindow.barHeight;
        }
        return s(isCompact ? 24 : 30);
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    width: isGrouped ? barThickness - 8 : ((isSolid && distinctPills) ? barThickness - 6 : barThickness)
    x: barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barThickness - width) / 2) : 0
    clip: true

    property real targetHeight: (moduleActive && workspaceCount > 0 && faceLoader.item) ? faceLoader.item.implicitHeight + s(isCompact ? 18 : 22) : 0
    height: targetHeight
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    opacity: (moduleActive && workspaceCount > 0) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property real wheelAccumulator: 0
    Timer {
        id: wsWheelTimer
        interval: 200
        onTriggered: workspacesWidgetRoot.wheelAccumulator = 0
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            wsWheelTimer.restart();
            workspacesWidgetRoot.wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(workspacesWidgetRoot.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(workspacesWidgetRoot.wheelAccumulator / threshold);
                workspacesWidgetRoot.wheelAccumulator = workspacesWidgetRoot.wheelAccumulator % threshold;

                if (workspacesWidgetRoot.workspaceCount > 1) {
                    let cur = workspacesWidgetRoot.activeIndex;
                    let nextIndex = 0;
                    if (cur < 0) {
                        nextIndex = steps > 0 ? (workspacesWidgetRoot.workspaceCount - 1) : 0;
                    } else {
                        if (steps > 0) {
                            nextIndex = (cur - 1 + workspacesWidgetRoot.workspaceCount) % workspacesWidgetRoot.workspaceCount;
                        } else if (steps < 0) {
                            nextIndex = (cur + 1) % workspacesWidgetRoot.workspaceCount;
                        }
                    }
                    if (nextIndex !== workspacesWidgetRoot.activeIndex) {
                        workspacesWidgetRoot.focusWorkspace(nextIndex);
                    }
                }
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.top: parent.top
        anchors.topMargin: s(isCompact ? 18 : 22) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
        source: {
            switch (workspacesWidgetRoot.workspacesStyle) {
                case "numbers": return Qt.resolvedUrl("faces/SideNumbersFace.qml");
                case "pacman": return Qt.resolvedUrl("faces/SidePacmanFace.qml");
                case "pills":
                default: return Qt.resolvedUrl("faces/SidePillsFace.qml");
            }
        }
        onLoaded: {
            if (item) {
                item.width = Qt.binding(function() { return item.implicitWidth; });
                item.height = Qt.binding(function() { return item.implicitHeight; });
                attachModel();
                Qt.callLater(attachModel);
            }
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: workspacesWidgetRoot
    }
}
