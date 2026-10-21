import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import "../reusables"
import "../"
import "../mc"

Rectangle {
    id: root

    property string moduleId: ""
    property string variant: ""
    property var barWindow: null
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool layoutAnimationsEnabled: true
    property bool suppressAnimation: false
    property bool isRightAligned: false
    property real contentWrapperWidth: 0
    readonly property real barOpacity: (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined ? (Config.rawSettings.bar.opacity / 100.0) : 1.0)

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    readonly property alias faceItem: faceLoader.item

    readonly property var helpButton: (faceLoader.item && faceLoader.item.helpButton) ? faceLoader.item.helpButton : null
    readonly property var volPill: (faceLoader.item && faceLoader.item.volPill) ? faceLoader.item.volPill : null
    readonly property var kbPill: (faceLoader.item && faceLoader.item.kbPill) ? faceLoader.item.kbPill : null
    readonly property var wifiPill: (faceLoader.item && faceLoader.item.wifiPill) ? faceLoader.item.wifiPill : null
    readonly property var btPill: (faceLoader.item && faceLoader.item.btPill) ? faceLoader.item.btPill : null
    readonly property var batPill: (faceLoader.item && faceLoader.item.batPill) ? faceLoader.item.batPill : null
    readonly property var recRow: (faceLoader.item && faceLoader.item.recRow) ? faceLoader.item.recRow : null

    property real targetX: 0

    readonly property real effectiveTargetWidth: {
        if (!moduleActive) return 0;
        if (!faceLoader.item) return 0;
        if (faceLoader.item.targetWidth !== undefined) {
            return faceLoader.item.targetWidth;
        }
        if (faceLoader.item.implicitWidth !== undefined && faceLoader.item.implicitWidth > 0) {
            return faceLoader.item.implicitWidth;
        }
        return faceLoader.item.width || 0;
    }

    property real targetWidth: effectiveTargetWidth

    x: targetX
    Behavior on x {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation && root.layoutAnimationsEnabled) : (!root.suppressAnimation && root.layoutAnimationsEnabled)
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    readonly property real targetHeight: height
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0

    radius: 0
    border.width: 0
    readonly property color capsuleColor: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.alpha(Qt.darker(ThemeBackend.surface0, 1.15), root.barOpacity) : "transparent") : Qt.alpha(ThemeBackend.base, root.barOpacity))
    color: "transparent"
    clip: true

    McPanel {
        anchors.fill: parent
        visible: root.capsuleColor.a > 0
        opacity: root.barOpacity
        bevel: 2
        fill: "#1d1d1d"
        light: "#4a4a4a"
        dark: "#0a0a0a"
    }

    width: targetWidth
    Behavior on width {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation) : !root.suppressAnimation
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property bool isFaceVisible: faceLoader.item ? (faceLoader.item.isFaceVisible !== undefined ? faceLoader.item.isFaceVisible : true) : true
    readonly property bool effectiveVisible: moduleActive && isFaceVisible && targetWidth > 0

    opacity: effectiveVisible ? 1.0 : 0.0
    visible: opacity > 0 && targetWidth > 0
    enabled: moduleActive

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Loader {
        id: faceLoader
        anchors.fill: parent
        source: BarModuleRegistry.faceFile(root.moduleId, root.variant, false)

        onLoaded: {
            if (item) {
                if (item.module !== undefined) item.module = root;
                if (item.widget !== undefined) item.widget = root;
                if (item.barModule !== undefined) item.barModule = root;
            }
        }
    }
}
