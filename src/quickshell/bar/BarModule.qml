import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import "../reusables"
import "../"

Rectangle {
    id: root

    property string orientation: "horizontal"
    readonly property bool isVertical: orientation === "vertical"

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
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false
    property real contentWrapperWidth: 0
    readonly property real barOpacity: ThemeBackend.elementOpacity

    function s(val) {
        if (barWindow && typeof barWindow.cs === "function") return barWindow.cs(val);
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property Item providedBackdrop: null
    property Item glassBackdropItem: null
    readonly property alias faceItem: faceLoader.item

    readonly property var helpButton: (faceLoader.item && faceLoader.item.helpButton) ? faceLoader.item.helpButton : null
    readonly property var volPill: (faceLoader.item && faceLoader.item.volPill) ? faceLoader.item.volPill : null
    readonly property var kbPill: (faceLoader.item && faceLoader.item.kbPill) ? faceLoader.item.kbPill : null
    readonly property var wifiPill: (faceLoader.item && faceLoader.item.wifiPill) ? faceLoader.item.wifiPill : null
    readonly property var btPill: (faceLoader.item && faceLoader.item.btPill) ? faceLoader.item.btPill : null
    readonly property var batPill: (faceLoader.item && faceLoader.item.batPill) ? faceLoader.item.batPill : null
    readonly property var recRow: (faceLoader.item && faceLoader.item.recRow) ? faceLoader.item.recRow : null
    readonly property var recCol: (faceLoader.item && faceLoader.item.recCol) ? faceLoader.item.recCol : null

    property real targetX: isVertical ? (barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barWindow.barHeight - width) / 2) : 0) : 0
    property real targetY: 0

    readonly property real thickness: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))

    readonly property real effectiveTargetLength: {
        if (!moduleActive) return 0;
        if (!faceLoader.item) return 0;
        if (faceLoader.item.targetLength !== undefined) {
            return faceLoader.item.targetLength;
        }
        let implicitLength = isVertical ? faceLoader.item.implicitHeight : faceLoader.item.implicitWidth;
        if (implicitLength !== undefined && implicitLength > 0) {
            return implicitLength;
        }
        return (isVertical ? faceLoader.item.height : faceLoader.item.width) || 0;
    }

    property real targetWidth: isVertical ? width : effectiveTargetLength
    property real targetHeight: isVertical ? effectiveTargetLength : height

    x: targetX
    Behavior on x {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation && root.layoutAnimationsEnabled) : (!root.suppressAnimation && root.layoutAnimationsEnabled)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    y: isVertical ? targetY : (barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0)
    Behavior on y {
        enabled: root.isVertical && (barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation && root.layoutAnimationsEnabled) : (!root.suppressAnimation && root.layoutAnimationsEnabled))
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    width: isVertical ? thickness : targetWidth
    Behavior on width {
        enabled: !root.isVertical && (barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation) : !root.suppressAnimation)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    height: isVertical ? targetHeight : thickness
    Behavior on height {
        enabled: root.isVertical && (barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && !root.suppressAnimation) : !root.suppressAnimation)
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    radius: ThemeBackend.borderRadius
    color: isGrouped || pillGlass.active ? "transparent" : (isSolid ? (distinctPills ? Qt.alpha(Qt.darker(ThemeBackend.surface0, 1.15), root.barOpacity) : "transparent") : Qt.alpha(ThemeBackend.base, root.barOpacity))
    clip: true

    WallpaperBlur {
        id: ownBlur
        z: -1
        anchors.fill: parent
        radius: root.radius
        surfaceEnabled: !root.isGrouped && !root.isSolid
        standalone: true
    }

    GlassFill {
        id: pillGlass
        anchors.fill: parent
        z: -1
        radius: root.radius
        allowed: !root.isGrouped && root.isSolid && root.distinctPills
        tintColor: ThemeBackend.surface0
        tintAmount: 0.3
    }

    readonly property bool isFaceVisible: faceLoader.item ? (faceLoader.item.isFaceVisible !== undefined ? faceLoader.item.isFaceVisible : true) : true
    readonly property bool effectiveVisible: moduleActive && isFaceVisible && (isVertical ? targetHeight : targetWidth) > 0

    opacity: effectiveVisible ? 1.0 : 0.0
    visible: false
    function updateVisible() {
        visible = opacity > 0 && (isVertical ? targetHeight : targetWidth) > 0;
    }
    onOpacityChanged: updateVisible()
    onTargetWidthChanged: updateVisible()
    onTargetHeightChanged: updateVisible()
    onIsVerticalChanged: updateVisible()
    enabled: moduleActive

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    readonly property url faceSource: BarModuleRegistry.faceFile(moduleId, variant)

    property url loadedFaceSource: ""
    readonly property bool faceWanted: moduleActive && (!barWindow || barWindow.barConfigReady !== false)

    function loadFace() {
        if (!faceWanted) return;
        if (loadedFaceSource === faceSource && faceLoader.item) return;
        loadedFaceSource = faceSource;
        faceLoader.setSource(faceSource, { "module": root });
    }

    onFaceSourceChanged: loadFace()
    onFaceWantedChanged: loadFace()
    Component.onCompleted: {
        glassBackdropItem = Qt.binding(() => providedBackdrop ? providedBackdrop : ((!isGrouped && !isSolid) ? ownBlur : null));
        loadFace();
        updateVisible();
    }

    Loader {
        id: faceLoader
        anchors.fill: parent

        onLoaded: {
            if (item) {
                if (item.module !== undefined) item.module = root;
                if (item.widget !== undefined) item.widget = root;
                if (item.barModule !== undefined) item.barModule = root;
            }
        }
    }
}
