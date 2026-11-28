import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables/canvas/CanvasGeometry.js" as CanvasGeometry

PanelWindow {
    id: root
    color: "transparent"

    property string wId: Quickshell.env("QS_WIDGET_ID") || "preview"
    property string wType: WidgetRegistry.defaultType
    property string wVariant: ""
    property string wImagePath: ""
    property real wX: 0
    property real wY: 0
    property real wWidth: 250
    property real wHeight: 120
    property real wOpacity: 1.0
    property real wRotation: 0

    property var customProps: ({})

    property Region passthroughRegion: Region {
        item: (faceLoader.item && faceLoader.item.inputItem) ? faceLoader.item.inputItem : null
    }
    mask: (faceLoader.item && faceLoader.item.inputPassthrough === true) ? passthroughRegion : null

    readonly property real auraMargin: 8

    readonly property bool isSelected: typeof DesktopMenuController !== "undefined"
        && DesktopMenuController.isVisible
        && DesktopMenuController.mode === "widget"
        && DesktopMenuController.targetWidgetId === String(root.wId)
        && (!DesktopMenuController.screen || !root.screen || !DesktopMenuController.screen.name || !root.screen.name || DesktopMenuController.screen.name === root.screen.name)

    function applyVariantAndCustomProps() {
        let it = faceLoader.item;
        if (!it) return;
        let vProps = WidgetRegistry.variantProps(root.wType, root.wVariant);
        if (vProps) CanvasGeometry.applyCustomProps(it, vProps);
        CanvasGeometry.applyCustomProps(it, root.customProps);
    }

    onCustomPropsChanged: applyVariantAndCustomProps()
    onWVariantChanged: {
        applyVariantAndCustomProps();
        updateEffectiveSize();
    }

    property bool isRedacting: false
    property bool initialized: false

    property bool wantsKeyboardFocus: false
    readonly property bool effectiveKeyboardFocus: wantsKeyboardFocus || (faceLoader.item && faceLoader.item.wantsKeyboardFocus === true) || false

    property real animX: wX
    property real animY: wY
    Behavior on animX {
        enabled: root.initialized && !root.isRedacting
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on animY {
        enabled: root.initialized && !root.isRedacting
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    property real effectiveWidth: wWidth
    property real effectiveHeight: wHeight

    onWWidthChanged: updateEffectiveSize()
    onWHeightChanged: updateEffectiveSize()
    onWTypeChanged: updateEffectiveSize()

    WlrLayershell.namespace: "qs-widget-" + wType + "-" + wId
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: effectiveKeyboardFocus ? Compositor.interactiveKeyboardFocus : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    focusable: effectiveKeyboardFocus

    onEffectiveKeyboardFocusChanged: {
        if (effectiveKeyboardFocus && typeof root.requestActivate === "function") {
            root.requestActivate();
        }
    }

    anchors.top: true
    anchors.left: true
    margins.left: animX - root.auraMargin
    margins.top: animY - root.auraMargin

    implicitWidth: ((Math.round(wRotation || 0) % 180 === 0) ? effectiveWidth : effectiveHeight) + (root.auraMargin * 2)
    implicitHeight: ((Math.round(wRotation || 0) % 180 === 0) ? effectiveHeight : effectiveWidth) + (root.auraMargin * 2)

    Component.onCompleted: {
        Qt.callLater(() => {
            root.initialized = true;
        });
    }

    Component.onDestruction: {
        visible = false;
        faceLoader.active = false;
        faceLoader.source = "";
    }

    function updateEffectiveSize() {
        if (!faceLoader.item) {
            root.effectiveWidth = root.wWidth;
            root.effectiveHeight = root.wHeight;
            return;
        }
        let clamped = CanvasGeometry.clampResize(faceLoader.item, root.wWidth, root.wHeight, 0, 0, true);
        root.effectiveWidth = clamped.w;
        root.effectiveHeight = clamped.h;
    }

    Loader {
        id: faceLoader
        visible: root.visible
        source: WidgetRegistry.faceFile(root.wType, root.wVariant)
        width: root.effectiveWidth
        height: root.effectiveHeight
        anchors.centerIn: parent
        rotation: root.wRotation || 0
        opacity: root.wOpacity
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        onLoaded: {
            if (item) {
                try {
                    item.visible = Qt.binding(() => root.visible);
                    if (item.widgetId !== undefined) {
                        item.widgetId = Qt.binding(() => String(root.wId));
                    }
                    if (item.imagePath !== undefined) {
                        item.imagePath = Qt.binding(() => root.wImagePath);
                    }
                } catch (e) {}
            }
            root.applyVariantAndCustomProps();
            root.updateEffectiveSize();
        }
    }

    Item {
        id: auraContainer
        width: faceLoader.width + (root.auraMargin * 2)
        height: faceLoader.height + (root.auraMargin * 2)
        anchors.centerIn: faceLoader
        rotation: faceLoader.rotation
        visible: opacity > 0.001
        opacity: root.isSelected ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        SelectionOutline {
            anchors.fill: parent
            running: root.isSelected && auraContainer.opacity > 0.001
        }
    }

    MouseArea {
        id: widgetMenuArea
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | (DesktopMenuController.isVisible ? Qt.LeftButton : 0)
        enabled: !root.isRedacting
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                DesktopMenuController.toggle(root.screen, (root.animX - root.auraMargin) + mouse.x, (root.animY - root.auraMargin) + mouse.y, "widget", root.wId);
            } else {
                DesktopMenuController.hide();
            }
        }
    }
}
