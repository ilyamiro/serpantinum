import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"

PanelWindow {
    id: osdWindow

    screen: OsdController.screen

    WlrLayershell.namespace: "osd"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        item: (osdWindow.isVisible || osdContainer.animProgress > 0.001) ? osdContainer : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    readonly property color briColor: Qt.lighter(ThemeBackend.mauve, 1.1)
    readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.5)
    readonly property color micColor: Qt.lighter(ThemeBackend.mauve, 1.3)
    readonly property color capsColor: Qt.lighter(ThemeBackend.peach, 1.2)
    readonly property color numColor: Qt.lighter(ThemeBackend.sapphire, 1.4)
    readonly property color airColor: Qt.lighter(ThemeBackend.red, 1.2)
    readonly property color layoutColor: Qt.lighter(ThemeBackend.teal, 1.2)

    readonly property string kind: OsdController.kind
    readonly property int briVal: OsdController.briVal
    readonly property string stateVal: OsdController.stateVal

    readonly property int volVal: Audio.sinkVolumePercent
    readonly property bool isMuted: Audio.sinkMuted
    readonly property int micVal: Audio.sourceVolumePercent
    readonly property bool isMicMuted: Audio.sourceMuted

    readonly property string layoutCode: (kind === "layout" && stateVal !== "") ? stateVal : KeyboardLayout.layout

    readonly property string layoutTitle: {
        let name = OsdController.layoutName || KeyboardLayout.fullLayout || "";
        if (name !== "" && name.toUpperCase() !== osdWindow.layoutCode.toUpperCase()) return name;
        return I18n.t("osd.keyboard_layout", "Keyboard layout");
    }

    readonly property var osdKinds: ({
        "volume": {
            toggle: false,
            allowed: true,
            color: osdWindow.volColor,
            muted: osdWindow.isMuted,
            value: osdWindow.volVal,
            icon: osdWindow.isMuted || osdWindow.volVal === 0 ? "󰖁" : (osdWindow.volVal > 50 ? "󰕾" : "󰖀"),
            title: ""
        },
        "mic": {
            toggle: false,
            allowed: true,
            color: osdWindow.micColor,
            muted: osdWindow.isMicMuted,
            value: osdWindow.micVal,
            icon: osdWindow.isMicMuted || osdWindow.micVal === 0 ? "󰍭" : "󰍬",
            title: ""
        },
        "brightness": {
            toggle: false,
            allowed: true,
            color: osdWindow.briColor,
            muted: false,
            value: osdWindow.briVal,
            icon: osdWindow.briVal > 66 ? "󰃠" : (osdWindow.briVal > 33 ? "󰃟" : "󰃞"),
            title: ""
        },
        "capslock": {
            toggle: true,
            allowed: osdWindow.showCapsLock,
            color: osdWindow.capsColor,
            muted: false,
            value: 0,
            icon: "󰬈",
            title: I18n.t("osd.capslock", "Caps lock")
        },
        "numlock": {
            toggle: true,
            allowed: osdWindow.showNumLock,
            color: osdWindow.numColor,
            muted: false,
            value: 0,
            icon: "󰎠",
            title: I18n.t("osd.numlock", "Num lock")
        },
        "airplane": {
            toggle: true,
            allowed: osdWindow.showAirplane,
            color: osdWindow.airColor,
            muted: false,
            value: 0,
            icon: "󰀝",
            title: I18n.t("osd.airplane_mode", "Airplane mode")
        },
        "layout": {
            toggle: true,
            allowed: osdWindow.showKeyboardLayout,
            color: osdWindow.layoutColor,
            muted: false,
            value: 0,
            icon: "󰌌",
            title: osdWindow.layoutTitle
        }
    })

    readonly property var currentKind: osdKinds[kind] || osdKinds["brightness"]
    readonly property bool isToggleKind: Boolean(currentKind.toggle)
    readonly property bool isToggleActive: kind === "layout" || stateVal === "on" || stateVal === "true" || stateVal === "1"
    readonly property bool isToggleAllowed: !isToggleKind || (!isVerticalLayout && Boolean(currentKind.allowed))
    readonly property bool isVisible: OsdController.isVisible && isToggleAllowed
    readonly property color toggleActiveColor: currentKind.color || ThemeBackend.mauve
    readonly property string toggleTitle: currentKind.title || ""
    readonly property string toggleStatus: kind === "layout" ? layoutCode : (isToggleActive ? I18n.t("osd.on", "On") : I18n.t("osd.off", "Off"))
    readonly property bool isMutedState: Boolean(currentKind.muted)
    readonly property int currentVal: Number(currentKind.value) || 0

    function triggerPrimaryAction() {
        OsdController.restartTimer();
        if (osdWindow.kind === "volume") {
            if (Audio.effectiveSink) Audio.toggleMute(Audio.effectiveSink);
        } else if (osdWindow.kind === "mic") {
            if (Audio.effectiveSource) Audio.toggleMute(Audio.effectiveSource);
        } else if (osdWindow.kind === "airplane") {
            Connectivity.toggleAirplaneMode();
        } else if (osdWindow.kind === "layout") {
            KeyboardLayout.switchNext();
        } else if (osdWindow.kind === "brightness") {
            Brightness.toggle();
            OsdController.briVal = Brightness.value;
        }
    }

    function applySliderValue(val) {
        OsdController.restartTimer();
        let pct = Math.max(0, Math.min(100, Math.round(val)));
        if (osdWindow.kind === "brightness") {
            OsdController.briVal = pct;
            Brightness.set(pct);
        } else if (osdWindow.kind === "volume") {
            if (Audio.effectiveSink) Audio.setVolumeAndUnmute(Audio.effectiveSink, pct, true);
        } else if (osdWindow.kind === "mic") {
            if (Audio.effectiveSource) Audio.setVolumeAndUnmute(Audio.effectiveSource, pct, true);
        }
    }

    function finishSliderDrag() {
        OsdController.restartTimer();
        if (osdWindow.kind === "brightness") {
            Brightness.flush();
        } else if (osdWindow.kind === "volume" || osdWindow.kind === "mic") {
            Audio.flushVolume();
        }
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            OsdController.hide();
            osdWindow.configRevision++;
        }
    }

    property var defaultOsdSettings: ({
        "horizontalPosition": 50,
        "verticalPosition": 90,
        "orientation": "horizontal",
        "showCapsLock": true,
        "showNumLock": true,
        "showAirplane": true,
        "showKeyboardLayout": false,
        "attachToBar": true
    })

    property var osdSettings: {
        let dummy = configRevision;
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["osd"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("osd", defaultOsdSettings);
        }
        return defaultOsdSettings;
    }

    readonly property string orientation: osdSettings.orientation !== undefined ? osdSettings.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"
    readonly property bool attachToBar: osdSettings.attachToBar !== undefined ? osdSettings.attachToBar : true
    readonly property real horizontalPosition: osdSettings.horizontalPosition !== undefined ? osdSettings.horizontalPosition : 50
    readonly property real verticalPosition: osdSettings.verticalPosition !== undefined ? osdSettings.verticalPosition : 90
    readonly property bool showCapsLock: osdSettings.showCapsLock !== undefined ? osdSettings.showCapsLock : true
    readonly property bool showNumLock: osdSettings.showNumLock !== undefined ? osdSettings.showNumLock : true
    readonly property bool showAirplane: osdSettings.showAirplane !== undefined ? osdSettings.showAirplane : true
    readonly property bool showKeyboardLayout: osdSettings.showKeyboardLayout !== undefined ? osdSettings.showKeyboardLayout : false

    onAttachToBarChanged: OsdController.hide()

    readonly property bool barAutohide: SurfaceRegistry.barAutohide
    onBarAutohideChanged: OsdController.hide()

    readonly property string barStyle: SurfaceRegistry.barStyle
    onBarStyleChanged: OsdController.hide()

    readonly property string barPosition: SurfaceRegistry.barPosition
    readonly property bool isFullscreen: Compositor.isFullscreenOn(osdWindow.screen)
    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreen || !SurfaceRegistry.isBarEnabledOnScreen(osdWindow.screen)
    readonly property bool isSideBar: SurfaceRegistry.isSideBar
    readonly property bool isRightBar: barPosition === "right"
    readonly property bool isBottomBar: barPosition === "bottom"
    readonly property bool isFill: SurfaceRegistry.isFillBar
    readonly property bool isSolid: SurfaceRegistry.isSolidBar || SurfaceRegistry.isFillBar
    readonly property bool isAttached: attachToBar && isSolid && !isBarEffectivelyHidden && (!isSideBar || !isToggleKind) && (isSideBar ? isVertical : !isVertical)
    readonly property bool isVerticalLayout: isAttached ? isSideBar : isVertical

    readonly property real barHeight: s(SurfaceRegistry.barRawHeight)
    readonly property real cornerRadius: ThemeBackend.borderRadius || s(12)
    readonly property real menuMargin: isAttached ? 0 : s(20)

    readonly property real osdWidth: isVerticalLayout ? s(58) : s(296)
    readonly property real osdHeight: isVerticalLayout ? s(296) : s(58)
    readonly property real collapsedWidth: s(58)

    visible: isVisible || osdContainer.animProgress > 0.001

    readonly property real clampedX: {
        if (isAttached) {
            if (isSideBar) {
                return isRightBar ? (osdWindow.width - barHeight - osdWidth) : barHeight;
            }
            return (osdWindow.width - osdWidth) / 2;
        }
        return (osdWindow.width - osdWidth) * (horizontalPosition / 100.0);
    }

    readonly property real clampedY: {
        if (isAttached) {
            if (isSideBar) {
                return (osdWindow.height - osdHeight) / 2;
            }
            return isBottomBar ? (osdWindow.height - barHeight - osdHeight) : barHeight;
        }
        return (osdWindow.height - osdHeight) * (verticalPosition / 100.0);
    }

    component OsdIconButton : IconButton {
        cornerRadius: osdWindow.s(8)
        buttonIcon: osdWindow.currentKind.icon
        iconFontSize: osdWindow.s(15)
        accentColor: ThemeBackend.surface1
        textColor: {
            if (isHoveredOrHighlighted) return ThemeBackend.text;
            if (osdWindow.isMutedState) return ThemeBackend.overlay0;
            if (osdWindow.isToggleKind) return osdWindow.isToggleActive ? osdWindow.toggleActiveColor : ThemeBackend.overlay0;
            return osdWindow.currentKind.color;
        }
        onClicked: osdWindow.triggerPrimaryAction()
    }

    component OsdSlider : Draggable {
        from: 0.0
        to: 100.0
        value: osdWindow.currentVal
        backgroundColor: ThemeBackend.surface1
        showValueBubble: false

        readonly property color activeColor: osdWindow.isMutedState ? ThemeBackend.surface2 : osdWindow.currentKind.color

        accentColor: activeColor
        gradColor1: activeColor
        gradColor2: Qt.lighter(activeColor, 1.05)
        gradColor3: Qt.lighter(activeColor, 1.10)
        cornerRadius: osdWindow.s(5)
        handleSize: osdWindow.s(22)

        handleColor: osdWindow.isMutedState ? ThemeBackend.overlay0 : Qt.lighter(activeColor, 1.15)
        handleHoverColor: osdWindow.isMutedState ? ThemeBackend.subtext0 : Qt.lighter(activeColor, 1.5)
        handleDragColor: osdWindow.isMutedState ? ThemeBackend.text : Qt.lighter(activeColor, 1.45)
        handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

        onDragStarted: OsdController.cancelHide()
        onDragFinished: osdWindow.finishSliderDrag()
        onMoved: val => osdWindow.applySliderValue(val)
    }

    AttachedSurface {
        kind: "osd"
        visible: osdContainer.opacity > 0.001 && osdContainer.width > 0 && osdContainer.height > 0
        opacity: osdContainer.opacity
        rects: [{ x: osdContainer.x, y: osdContainer.y, w: osdContainer.width, h: osdContainer.height, r: [osdBox.topLeftRadius, osdBox.topRightRadius, osdBox.bottomRightRadius, osdBox.bottomLeftRadius] }]
        filletRadius: (osdWindow.isAttached && osdContainer.dynamicCornerRadius > 0.5) ? osdContainer.dynamicCornerRadius : 0
        attachTo: osdWindow.isAttached ? ["bar"] : []
        publishShape: osdWindow.isAttached
    }

    Item {
        id: osdContainer

        property real animProgress: osdWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: osdWindow.isVisible ? 450 : 300
                easing.type: osdWindow.isVisible ? Easing.OutQuint : Easing.InCubic
            }
        }

        property real dynamicCornerRadius: osdWindow.isAttached ? Math.max(0, Math.min(osdWindow.cornerRadius, (osdWindow.isSideBar ? width : height))) : 0

        x: {
            if (osdWindow.isAttached) {
                if (osdWindow.isSideBar && osdWindow.isRightBar) {
                    return (osdWindow.clampedX + osdWindow.osdWidth) - width;
                }
                return osdWindow.clampedX;
            }
            return (osdWindow.width - width) * (osdWindow.horizontalPosition / 100.0);
        }
        y: {
            if (osdWindow.isAttached) {
                if (!osdWindow.isSideBar && osdWindow.isBottomBar) {
                    return (osdWindow.clampedY + osdWindow.osdHeight) - height;
                }
                return osdWindow.clampedY;
            }
            return (osdWindow.height - height) * (osdWindow.verticalPosition / 100.0);
        }
        width: {
            if (osdWindow.isAttached) {
                return osdWindow.isSideBar ? (osdWindow.osdWidth * animProgress) : osdWindow.osdWidth;
            }
            if (osdWindow.isVerticalLayout) return osdWindow.osdWidth;
            return osdWindow.collapsedWidth + (osdWindow.osdWidth - osdWindow.collapsedWidth) * animProgress;
        }
        height: {
            if (osdWindow.isAttached) {
                return !osdWindow.isSideBar ? (osdWindow.osdHeight * animProgress) : osdWindow.osdHeight;
            }
            if (osdWindow.isVerticalLayout) {
                return osdWindow.collapsedWidth + (osdWindow.osdHeight - osdWindow.collapsedWidth) * animProgress;
            }
            return osdWindow.osdHeight;
        }
        opacity: osdWindow.isAttached ? ((osdWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0) : Math.max(0.0, Math.min(1.0, animProgress * 1.5))

        transformOrigin: {
            if (osdWindow.isAttached) {
                if (osdWindow.isSideBar) return osdWindow.isRightBar ? Item.Right : Item.Left;
                return osdWindow.isBottomBar ? Item.Bottom : Item.Top;
            }
            return Item.Center;
        }

        Rectangle {
            id: osdBox
            anchors.fill: parent
            color: "transparent"
            radius: osdWindow.cornerRadius
            readonly property bool flatTop: osdWindow.isAttached && !osdWindow.isSideBar && !osdWindow.isBottomBar
            readonly property bool flatBottom: osdWindow.isAttached && !osdWindow.isSideBar && osdWindow.isBottomBar
            readonly property bool flatLeft: osdWindow.isAttached && osdWindow.isSideBar && !osdWindow.isRightBar
            readonly property bool flatRight: osdWindow.isAttached && osdWindow.isSideBar && osdWindow.isRightBar
            topLeftRadius: (flatTop || flatLeft) ? 0 : osdWindow.cornerRadius
            topRightRadius: (flatTop || flatRight) ? 0 : osdWindow.cornerRadius
            bottomLeftRadius: (flatBottom || flatLeft) ? 0 : osdWindow.cornerRadius
            bottomRightRadius: (flatBottom || flatRight) ? 0 : osdWindow.cornerRadius
            clip: true

            HoverHandler {
                id: osdHoverHandler
                onHoveredChanged: {
                    OsdController.isHovered = hovered;
                    if (hovered) OsdController.cancelHide();
                    else OsdController.requestHide();
                }
            }

            ColumnLayout {
                visible: osdWindow.isVerticalLayout
                anchors.fill: parent
                anchors.topMargin: osdWindow.s(14)
                anchors.bottomMargin: osdWindow.s(14)
                anchors.leftMargin: osdWindow.s(10)
                anchors.rightMargin: osdWindow.s(10)
                spacing: osdWindow.s(10)

                OsdIconButton {
                    Layout.alignment: Qt.AlignHCenter
                    size: osdWindow.s(26)
                }

                Rectangle {
                    visible: osdWindow.isToggleKind
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: osdWindow.s(28)
                    Layout.preferredHeight: osdWindow.s(22)
                    radius: osdWindow.s(6)
                    color: osdWindow.isToggleActive ? Qt.rgba(osdWindow.toggleActiveColor.r, osdWindow.toggleActiveColor.g, osdWindow.toggleActiveColor.b, 0.2) : ThemeBackend.surface1

                    Text {
                        anchors.centerIn: parent
                        text: osdWindow.toggleStatus
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: osdWindow.s(10)
                        font.bold: true
                        color: osdWindow.isToggleActive ? osdWindow.toggleActiveColor : ThemeBackend.overlay0
                    }
                }

                OsdSlider {
                    id: verticalSlider
                    visible: !osdWindow.isToggleKind
                    vertical: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: osdWindow.s(16)
                    Layout.alignment: Qt.AlignHCenter
                }

                Item {
                    id: verticalValueContainer
                    visible: !osdWindow.isToggleKind
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: osdWindow.s(26)
                    Layout.preferredHeight: osdWindow.s(26)

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(verticalSlider.effectiveValue).toString()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: osdWindow.s(13)
                        font.bold: true
                        color: osdWindow.isMutedState ? ThemeBackend.overlay0 : ThemeBackend.text
                    }
                }
            }

            Item {
                visible: !osdWindow.isVerticalLayout
                anchors.fill: parent

                Item {
                    width: osdWindow.s(58)
                    height: parent.height
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    OsdIconButton {
                        anchors.centerIn: parent
                        size: osdWindow.s(30)
                    }
                }

                RowLayout {
                    visible: osdWindow.isToggleKind
                    anchors.left: parent.left
                    anchors.leftMargin: osdWindow.s(58)
                    anchors.right: parent.right
                    anchors.rightMargin: osdWindow.s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.max(0.0, Math.min(1.0, (osdContainer.animProgress - 0.2) / 0.8))
                    spacing: osdWindow.s(8)

                    Text {
                        Layout.fillWidth: true
                        text: osdWindow.toggleTitle
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: osdWindow.s(14)
                        font.bold: true
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                    }

                    ClickButton {
                        id: toggleBtn
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: osdWindow.s(24)
                        Layout.preferredWidth: implicitWidth
                        height: osdWindow.s(24)
                        cornerRadius: osdWindow.s(6)
                        horizontalPadding: osdWindow.s(10)
                        buttonText: osdWindow.toggleStatus
                        textFontSize: osdWindow.s(11)
                        accentColor: osdWindow.isToggleActive ? osdWindow.toggleActiveColor : ThemeBackend.surface1
                        textColor: osdWindow.isToggleActive ? ThemeBackend.base : ThemeBackend.subtext0

                        onClicked: {
                            OsdController.restartTimer();
                            if (osdWindow.kind === "airplane") {
                                Connectivity.toggleAirplaneMode();
                            } else if (osdWindow.kind === "layout") {
                                KeyboardLayout.switchNext();
                            }
                        }
                    }
                }

                OsdSlider {
                    id: horizontalSlider
                    width: Math.max(0, osdContainer.width - osdWindow.s(116))
                    height: osdWindow.s(18)
                    anchors.left: parent.left
                    anchors.leftMargin: osdWindow.s(58)
                    anchors.right: parent.right
                    anchors.rightMargin: osdWindow.s(58)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.max(0.0, Math.min(1.0, (osdContainer.animProgress - 0.2) / 0.8))
                    visible: !osdWindow.isToggleKind && opacity > 0.01
                }

                Item {
                    id: horizontalValueContainer
                    width: osdWindow.s(58)
                    height: parent.height
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.max(0.0, Math.min(1.0, (osdContainer.animProgress - 0.2) / 0.8))
                    visible: !osdWindow.isToggleKind && opacity > 0.01

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(horizontalSlider.effectiveValue).toString()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: osdWindow.s(13)
                        font.bold: true
                        color: osdWindow.isMutedState ? ThemeBackend.overlay0 : ThemeBackend.text
                    }
                }
            }
        }
    }
}
