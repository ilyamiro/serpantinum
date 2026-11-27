import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    readonly property string myOutput: (barWindow && barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : ""

    SubscriptionGate {
        target: Compositor
        wanted: root.moduleActive
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        return String(readSetting("workspacesStyle", "workspaces.style", "pills"));
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

    readonly property bool perMonitorNumbering: Compositor.supportsPerMonitorWorkspaceNumbering && workspacesSettings.perMonitorNumbering === true
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

    property int activeIndex: {
        let rev = Compositor.workspacesRevision;
        if (rev < 0) return -1;
        let idx = Compositor.activeWorkspaceIndexFor(myOutput);
        if (idx < 0) return -1;
        if (perMonitorNumbering) {
            idx -= hyprBase;
            if (blockSize > 0 && idx >= blockSize) return -1;
        }
        return idx >= 0 ? idx : -1;
    }

    property int workspaceCount: {
        let rev = Compositor.workspacesRevision;
        if (rev < 0) return 2;
        let count = Compositor.workspaceCountFor(myOutput, baseWorkspaceCount);
        if (blockSize > 0) count = Math.min(count, blockSize);
        return Math.max(2, count);
    }

    readonly property ListModel slotModel: ListModel {}

    function syncSlots() {
        while (slotModel.count < workspaceCount) slotModel.append({ slot: slotModel.count });
        while (slotModel.count > workspaceCount) slotModel.remove(slotModel.count - 1);
    }

    onWorkspaceCountChanged: syncSlots()
    Component.onCompleted: syncSlots()

    property bool hideEmptyWorkspaces: Boolean(readSetting("hideEmptyWorkspaces", "", false))

    function isOccupied(index) {
        let rev = Compositor.workspacesRevision;
        if (rev < 0) return false;
        return Compositor.isWorkspaceOccupied(myOutput, (perMonitorNumbering ? hyprBase : 0) + index);
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces) return true;
        return index === activeIndex || isOccupied(index);
    }

    readonly property var shownIndices: {
        let rev = Compositor.workspacesRevision;
        if (rev < 0) return [];
        let _a = activeIndex;
        let _c = workspaceCount;
        let _h = hideEmptyWorkspaces;
        let ids = [];
        for (let i = 0; i < _c; i++) {
            if (isShown(i)) ids.push(i);
        }
        return ids;
    }
    readonly property int shownCount: shownIndices.length

    function focusWorkspace(index) {
        Compositor.focusWorkspace(myOutput, (perMonitorNumbering ? hyprBase : 0) + index);
    }

    property real targetLength: (moduleActive && workspaceCount > 0 && faceLoader.item) ? (isVertical ? faceLoader.item.implicitHeight : faceLoader.item.implicitWidth) + s(isCompact ? 18 : 22) : 0
    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    WheelStepper {
        id: wsWheel
        threshold: 120
        resetInterval: 200
        onStepped: delta => {
            if (root.workspaceCount <= 1) return;
            if (root.perMonitorNumbering) {
                let cur = root.activeIndex;
                let nextIndex = cur < 0
                    ? (delta > 0 ? (root.workspaceCount - 1) : 0)
                    : (delta > 0 ? ((cur - 1 + root.workspaceCount) % root.workspaceCount) : ((cur + 1) % root.workspaceCount));
                if (nextIndex !== root.activeIndex) {
                    root.focusWorkspace(nextIndex);
                }
            } else {
                Compositor.stepWorkspace(root.myOutput, -delta, root.workspaceCount);
            }
        }
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => wsWheel.feed(wheel.angleDelta.y)
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
            if (item) item.widget = root;
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
