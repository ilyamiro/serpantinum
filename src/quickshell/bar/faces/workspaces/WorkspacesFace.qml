import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root

    property var module: null
    property var widget: root

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool moduleActive: module ? module.moduleActive : true

    readonly property string myOutput: (barWindow && barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : ""
    readonly property int niriActiveIndex: NiriState.activeIndexFor(myOutput)
    readonly property var niriOccupiedMap: NiriState.occupiedMap
    readonly property var niriExistingMap: NiriState.existingMap
    readonly property int niriMaxWorkspaceIndex: NiriState.maxWorkspaceIndex
    property bool niriSubscribed: false

    function syncNiriSubscription() {
        let want = Compositor.name === "niri" && moduleActive;
        if (want === niriSubscribed) return;
        niriSubscribed = want;
        if (want) NiriState.subscribe();
        else NiriState.unsubscribe();
    }

    readonly property int mangoActiveIndex: MangoState.activeIndexFor(myOutput)
    readonly property var mangoOccupiedMap: MangoState.occupiedByOutput
    readonly property int mangoTagCount: MangoState.tagCount
    property bool mangoSubscribed: false

    function syncMangoSubscription() {
        let want = Compositor.name === "mango" && moduleActive;
        if (want === mangoSubscribed) return;
        mangoSubscribed = want;
        if (want) MangoState.subscribe();
        else MangoState.unsubscribe();
    }
    readonly property int swayActiveIndex: SwayState.activeIndexFor(myOutput)
    readonly property var swayOccupiedMap: SwayState.occupiedMap
    property bool swaySubscribed: false

    function syncSwaySubscription() {
        let want = Compositor.name === "sway" && moduleActive;
        if (want === swaySubscribed) return;
        swaySubscribed = want;
        if (want) SwayState.subscribe();
        else SwayState.unsubscribe();
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        if (isVertical) {
            let bs = (typeof Config !== "undefined") ? Config.getSetting("bar", {}) : {};
            if (bs && bs.workspacesStyle) return bs.workspacesStyle;
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.workspacesStyle) return Config.rawSettings.bar.workspacesStyle;
            if (Config.rawSettings.bar.workspaces && Config.rawSettings.bar.workspaces.style) return Config.rawSettings.bar.workspaces.style;
        }
        return "pills";
    }

    property int baseWorkspaceCount: {
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

    readonly property var workspacesSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.workspaces)
            return Config.rawSettings.bar.workspaces;
        return {};
    }

    readonly property bool perMonitorNumbering: Compositor.name === "hyprland" && workspacesSettings.perMonitorNumbering === true
    readonly property var monitorBlock: {
        let m = workspacesSettings.monitors;
        return (perMonitorNumbering && m && m[myOutput]) ? m[myOutput] : null;
    }
    readonly property int blockSize: {
        let n = monitorBlock ? Math.floor(Number(monitorBlock.count)) : 0;
        return n >= 1 ? n : 0;
    }
    readonly property int hyprBase: {
        let n = monitorBlock ? Math.floor(Number(monitorBlock.first)) : 0;
        return (blockSize > 0 && n >= 1) ? n - 1 : 0;
    }

    readonly property int hyprActiveId: {
        if (Compositor.name !== "hyprland") return -1;
        const mon = Hyprland.monitors.values.find(m => m.name === myOutput);
        const ws = (mon && mon.activeWorkspace) ? mon.activeWorkspace : Hyprland.focusedWorkspace;
        return ws ? ws.id : -1;
    }

    property int workspaceCount: {
        let base = baseWorkspaceCount;
        let act = activeIndex;
        let count = base;
        if (act >= count) count = act + 1;
        if (Compositor.name === "niri" && niriMaxWorkspaceIndex >= count) count = niriMaxWorkspaceIndex + 1;
        if (Compositor.name === "mango" && mangoTagCount > 0) count = Math.min(count, mangoTagCount);
        if (blockSize > 0) count = Math.min(count, blockSize);
        return Math.max(2, count);
    }

    property bool hideEmptyWorkspaces: {
        let dummy = configRevision;
        if (isVertical) {
            let bs = (typeof Config !== "undefined") ? Config.getSetting("bar", {}) : {};
            if (bs && bs.hideEmptyWorkspaces !== undefined) return Boolean(bs.hideEmptyWorkspaces);
        } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.hideEmptyWorkspaces !== undefined)
                return Boolean(Config.rawSettings.bar.hideEmptyWorkspaces);
        }
        return false;
    }

    ListModel {
        id: workspaceListModel
    }

    function syncModel() {
        let target = workspaceCount;
        while (workspaceListModel.count < target) {
            workspaceListModel.append({ "modelData": workspaceListModel.count });
        }
        while (workspaceListModel.count > target) {
            workspaceListModel.remove(workspaceListModel.count - 1);
        }
    }

    onWorkspaceCountChanged: syncModel()

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
            faceLoader.item.widget = root;
            let rep = findRepeater(faceLoader.item);
            if (rep && rep.model !== workspaceListModel) {
                rep.model = workspaceListModel;
            }
        }
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.cs(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function wsForId(id) {
        if (Compositor.name !== "hyprland") return null;
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isOccupied(index) {
        if (Compositor.name === "niri") return !!(niriExistingMap[index] && niriOccupiedMap[index]);
        if (Compositor.name === "sway") return !!swayOccupiedMap[index];
        if (Compositor.name === "mango") return !!(mangoOccupiedMap && MangoState.isOccupied(myOutput, index));
        let ws = wsForId(hyprBase + index + 1);
        return ws !== null && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0;
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces) return true;
        return index === activeIndex || isOccupied(index);
    }

    function focusWorkspace(index) {
        let wsId = (Compositor.name !== "hyprland" ? 0 : hyprBase) + index + 1;
        if (Compositor.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
        } else if (Compositor.name === "sway") {
            SwayState.focusWorkspace(index);
        } else if (Compositor.name === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", "view," + wsId]);
        } else if (Compositor.name === "hyprland") {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
        }
    }

    property int activeIndex: {
        let idx = -1;
        if (Compositor.name === "niri") {
            idx = (niriExistingMap[niriActiveIndex] || Object.keys(niriExistingMap).length === 0) ? niriActiveIndex : -1;
        } else if (Compositor.name === "sway") {
            idx = swayActiveIndex;
        } else if (Compositor.name === "mango") {
            idx = mangoActiveIndex;
        } else {
            if (hyprActiveId < 0) return -1;
            idx = hyprActiveId - 1 - hyprBase;
            if (blockSize > 0 && idx >= blockSize) idx = -1;
        }
        return idx >= 0 ? idx : -1;
    }

    Component.onCompleted: {
        syncNiriSubscription();
        syncMangoSubscription();
        syncSwaySubscription();
        syncModel();
    }

    Component.onDestruction: {
        if (niriSubscribed) NiriState.unsubscribe();
        if (mangoSubscribed) MangoState.unsubscribe();
        if (swaySubscribed) SwayState.unsubscribe();
    }

    onModuleActiveChanged: {
        syncNiriSubscription();
        syncMangoSubscription();
        syncSwaySubscription();
    }

    Connections {
        target: Compositor
        function onNameChanged() { root.syncSwaySubscription(); }
    }

    property real targetLength: (moduleActive && workspaceCount > 0 && faceLoader.item) ? (isVertical ? faceLoader.item.implicitHeight : faceLoader.item.implicitWidth) + s(isCompact ? 18 : 22) : 0
    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    property real wheelAccumulator: 0
    Timer {
        id: wsWheelTimer
        interval: 200
        onTriggered: root.wheelAccumulator = 0
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            wsWheelTimer.restart();
            root.wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(root.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(root.wheelAccumulator / threshold);
                root.wheelAccumulator = root.wheelAccumulator % threshold;

                if (root.workspaceCount > 1) {
                    if (Compositor.name === "niri") {
                        if (steps > 0) {
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-up"]);
                        } else if (steps < 0) {
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
                        }
                    } else {
                        let cur = root.activeIndex;
                        let nextIndex = 0;
                        if (cur < 0) {
                            nextIndex = steps > 0 ? (root.workspaceCount - 1) : 0;
                        } else {
                            if (steps > 0) {
                                nextIndex = (cur - 1 + root.workspaceCount) % root.workspaceCount;
                            } else if (steps < 0) {
                                nextIndex = (cur + 1) % root.workspaceCount;
                            }
                        }
                        if (nextIndex !== root.activeIndex) {
                            root.focusWorkspace(nextIndex);
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.left: root.isVertical ? undefined : parent.left
        anchors.leftMargin: root.isVertical ? 0 : s(isCompact ? 18 : 22) / 2
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.top: root.isVertical ? parent.top : undefined
        anchors.topMargin: root.isVertical ? s(isCompact ? 18 : 22) / 2 : 0
        anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
        source: BarModuleRegistry.variantFaceFile("workspaces", root.workspacesStyle)
        onLoaded: {
            attachModel();
            attachTimer.restart();
        }
    }

    Timer {
        id: attachTimer
        interval: 0
        onTriggered: root.attachModel()
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
