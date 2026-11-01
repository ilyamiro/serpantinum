import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    readonly property bool isNiri: NiriState.isNiri
    property bool isSway: false
    readonly property string myOutput: (barWindow && barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : ""
    readonly property int niriActiveIndex: NiriState.activeIndexFor(myOutput)
    readonly property var niriOccupiedMap: NiriState.occupiedMap
    readonly property var niriExistingMap: NiriState.existingMap
    readonly property int niriMaxWorkspaceIndex: NiriState.maxWorkspaceIndex
    property bool niriSubscribed: false

    function syncNiriSubscription() {
        let want = isNiri && moduleActive;
        if (want === niriSubscribed) return;
        niriSubscribed = want;
        if (want) NiriState.subscribe();
        else NiriState.unsubscribe();
    }

    readonly property bool isMango: MangoState.isMango
    readonly property int mangoActiveIndex: MangoState.activeIndexFor(myOutput)
    readonly property var mangoOccupiedMap: MangoState.occupiedByOutput
    readonly property int mangoTagCount: MangoState.tagCount
    property bool mangoSubscribed: false

    function syncMangoSubscription() {
        let want = isMango && moduleActive;
        if (want === mangoSubscribed) return;
        mangoSubscribed = want;
        if (want) MangoState.subscribe();
        else MangoState.unsubscribe();
    }
    property int swayActiveIndex: 0
    property var swayOccupiedMap: ({})

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

    property int workspaceCount: {
        let base = baseWorkspaceCount;
        let act = activeIndex;
        let count = base;
        if (act >= count) count = act + 1;
        if (isNiri && niriMaxWorkspaceIndex >= count) count = niriMaxWorkspaceIndex + 1;
        if (isMango && mangoTagCount > 0) count = Math.min(count, mangoTagCount);
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
        if (isNiri || isSway || isMango) return null;
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isOccupied(index) {
        if (isNiri) return !!(niriExistingMap[index] && niriOccupiedMap[index]);
        if (isSway) return !!swayOccupiedMap[index];
        if (isMango) return !!(mangoOccupiedMap && MangoState.isOccupied(myOutput, index));
        let ws = wsForId(index + 1);
        return ws !== null && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0;
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces) return true;
        return index === activeIndex || isOccupied(index);
    }

    function focusWorkspace(index) {
        let wsId = index + 1;
        if (isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
        } else if (isSway) {
            swayActiveIndex = index;
            Quickshell.execDetached(["swaymsg", "workspace", "number", wsId.toString()]);
        } else if (isMango) {
            Quickshell.execDetached(["mmsg", "dispatch", "view," + wsId]);
        } else {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
        }
    }

    property int activeIndex: {
        let idx = -1;
        if (isNiri) {
            idx = (niriExistingMap[niriActiveIndex] || Object.keys(niriExistingMap).length === 0) ? niriActiveIndex : -1;
        } else if (isSway) {
            idx = swayActiveIndex;
        } else if (isMango) {
            idx = mangoActiveIndex;
        } else {
            const fw = Hyprland.focusedWorkspace;
            if (!fw) return -1;
            idx = fw.id - 1;
        }
        return idx >= 0 ? idx : -1;
    }

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isSway = de.indexOf("sway") !== -1;
        syncNiriSubscription();
        syncMangoSubscription();
        if (root.isSway && root.moduleActive) {
            swayPoller.running = true;
        }
        syncModel();
    }

    Component.onDestruction: {
        if (niriSubscribed) NiriState.unsubscribe();
        if (mangoSubscribed) MangoState.unsubscribe();
    }

    onModuleActiveChanged: {
        syncNiriSubscription();
        syncMangoSubscription();
        if (!moduleActive) {
            if (isSway) {
                swayPoller.running = false;
                swayWaiter.running = false;
            }
        } else {
            if (isSway) {
                swayPoller.running = false;
                swayPoller.running = true;
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
                    root.swayActiveIndex = activeIdx;
                    root.swayOccupiedMap = occ;
                } catch (e) {}

                swayWaiter.running = false;
                if (root.moduleActive && root.isSway) {
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
            if (root.moduleActive && root.isSway) {
                swayPoller.running = true;
            }
        }
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
                    if (root.isNiri) {
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
