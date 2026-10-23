import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.cs(val);
        if (activeTarget && typeof activeTarget.s === "function") return activeTarget.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string batStyle: {
        if (widget && widget !== root && widget.batStyle !== undefined) return widget.batStyle;
        if (module && module.batStyle !== undefined) return module.batStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.batStyle) return bs.batStyle;
            if (bs.bat && bs.bat.style) return bs.bat.style;
        }
        return "classic";
    }

    property bool showPercent: {
        if (widget && widget !== root && widget.batShowPercent !== undefined) return widget.batShowPercent;
        if (widget && widget !== root && widget.showPercent !== undefined) return widget.showPercent;
        if (module && module.batShowPercent !== undefined) return module.batShowPercent;
        if (module && module.showPercent !== undefined) return module.showPercent;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.batShowPercent !== undefined) return Boolean(bs.batShowPercent);
            if (bs.bat && bs.bat.showPercent !== undefined) return Boolean(bs.bat.showPercent);
        }
        return true;
    }

    property bool showIcon: {
        if (widget && widget !== root && widget.batShowIcon !== undefined) return widget.batShowIcon;
        if (widget && widget !== root && widget.showIcon !== undefined) return widget.showIcon;
        if (module && module.batShowIcon !== undefined) return module.batShowIcon;
        if (module && module.showIcon !== undefined) return module.showIcon;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.batShowIcon !== undefined) return Boolean(bs.batShowIcon);
            if (bs.bat && bs.bat.showIcon !== undefined) return Boolean(bs.bat.showIcon);
        }
        return true;
    }

    readonly property bool effectiveShowPercent: root.isDesktop ? false : showPercent
    readonly property bool effectiveShowIcon: root.isDesktop ? true : showIcon

    property bool isDesktop: isPreview ? false : (UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop)
    readonly property int batCap: isPreview ? 82 : (UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0)
    readonly property string batPercent: batCap + "%"
    readonly property bool isCharging: isPreview ? false : (UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged))
    readonly property bool isActivelyCharging: isCharging && UPower.displayDevice.changeRate > 0.5

    readonly property string batStatus: isPreview ? "Discharging" : (UPower.displayDevice.ready ? (UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? "Full" : (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging" : "Unknown")) : "Unknown")
    readonly property string batIcon: isDesktop ? "󰐥" : (isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃"))

    property real wavePhase: 0.8

    Timer {
        id: waveSettleTimer
        interval: root.isCharging ? 30000 : 1800
        repeat: false
        onTriggered: {
            if (!root.isActivelyCharging) waveAnimation.stop();
        }
    }

    NumberAnimation {
        id: waveAnimation
        target: root
        property: "wavePhase"
        from: 0
        to: Math.PI * 2
        duration: root.isCharging ? 1200 : 2200
        loops: Animation.Infinite
        running: root.visible && (!root.isDesktop) && root.batStyle !== "text" && (typeof batPill !== "undefined" && batPill ? (batPill.fillRatio > 0.0 && batPill.fillRatio < 1.0) : false) && root.isActivelyCharging
    }

    onIsChargingChanged: {
        if (isCharging && visible && !isDesktop && root.batStyle !== "text" && typeof batPill !== "undefined" && batPill && batPill.fillRatio > 0.0 && batPill.fillRatio < 1.0) {
            waveAnimation.start();
            waveSettleTimer.restart();
        } else if (!isCharging) {
            waveSettleTimer.restart();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            waveAnimation.stop();
            waveSettleTimer.stop();
        } else if (isActivelyCharging && !isDesktop && root.batStyle !== "text" && typeof batPill !== "undefined" && batPill && batPill.fillRatio > 0.0 && batPill.fillRatio < 1.0) {
            waveAnimation.start();
        }
    }

    property color batDynamicColor: {
        if (isDesktop) return ThemeBackend.red;
        if (isCharging) return isVertical ? ThemeBackend.green : Qt.lighter(ThemeBackend.green, 1.15);
        if (batCap <= 15) return ThemeBackend.red;
        if (batCap <= 25) return ThemeBackend.peach;
        return ThemeBackend.teal;
    }

    property color calmBatFillColor: {
        if (isDesktop) return ThemeBackend.subtext0;
        if (isCharging) return ThemeBackend.green;
        if (batCap <= 15) return ThemeBackend.red;
        if (batCap <= 25) return ThemeBackend.peach;
        return ThemeBackend.teal;
    }

    property color calmBatBorderColor: {
        if (isDesktop) return ThemeBackend.subtext0;
        if (isCharging) return ThemeBackend.green;
        if (batCap <= 15) return ThemeBackend.red;
        if (batCap <= 25) return ThemeBackend.peach;
        return ThemeBackend.subtext0;
    }

    property bool showLayout: (!barWindow || isPreview) ? true : false
    readonly property var batPill: pillLoader.item ? pillLoader.item.pill : null
    readonly property bool lockLook: activeTarget ? activeTarget.lockLook === true : false
    readonly property int pillHeight: s(lockLook ? 36 : (root.isCompact ? 28 : 30))
    readonly property color lockBatColor: {
        if (isDesktop) return ThemeBackend.red;
        if (isCharging) return ThemeBackend.green;
        if (batCap <= 15) return ThemeBackend.red;
        if (batCap <= 25) return ThemeBackend.peach;
        return ThemeBackend.text;
    }

    readonly property real pillLength: pillLoader.item ? (isVertical ? pillLoader.item.implicitHeight : pillLoader.item.implicitWidth) : 0
    readonly property real textLength: isVertical ? textLayout.implicitHeight : textLayout.implicitWidth

    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (root.batStyle === "text") {
            return (textLength > 0) ? (textLength + (isPreview ? 0 : s(isCompact ? (isVertical ? 14 : 12) : 16))) : 0;
        }
        return (pillLength > 0) ? (pillLength + (isPreview ? 0 : s(isCompact ? 8 : 10))) : 0;
    }
    property bool isFaceVisible: showLayout && targetLength > 0

    function syncImplicitSize() {
        let cross = module ? module.thickness : (parent ? (isVertical ? parent.width : parent.height) : 0);
        implicitWidth = isVertical ? cross : targetLength;
        implicitHeight = isVertical ? targetLength : cross;
    }

    onTargetLengthChanged: syncImplicitSize()
    onIsVerticalChanged: syncImplicitSize()
    onModuleChanged: syncImplicitSize()
    onParentChanged: syncImplicitSize()

    Timer {
        running: true
        interval: 0
        onTriggered: root.syncImplicitSize()
    }

    Timer {
        running: !root.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: (root.isVertical || root.showLayout) ? 0 : s(60)
        y: (!root.isVertical || root.showLayout) ? 0 : s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: textMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.batStyle === "text" && !root.isPreview
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle system"])
    }

    AxisFlow {
        id: textLayout
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        visible: root.batStyle === "text"
        anchors.centerIn: parent
        spacing: root.isVertical ? s(root.isCompact ? 2 : 3) : (root.isDesktop ? 0 : s(root.isCompact ? 5 : 6))
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Item {
            visible: root.effectiveShowIcon
            width: root.isVertical ? textIcon.implicitWidth : s(root.isCompact ? 18 : 20)
            height: root.isVertical ? textIcon.implicitHeight : width

            Text {
                id: textIcon
                anchors.centerIn: parent
                text: root.batIcon
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.isVertical ? (root.isDesktop ? s(root.isCompact ? 15 : 16) : s(root.isCompact ? 13 : 14)) : s(root.isCompact ? 14 : 15)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: textMouseArea.containsMouse ? Qt.lighter(root.batDynamicColor, 1.15) : root.batDynamicColor
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        Text {
            visible: !root.isDesktop && root.effectiveShowPercent
            text: root.batPercent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.isVertical ? s(root.isCompact ? 9 : 10) : s(root.isCompact ? 11 : 12.6)
            font.bold: true
            color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Loader {
        id: pillLoader
        visible: root.batStyle !== "text"
        anchors.centerIn: parent
        sourceComponent: root.batStyle === "button" ? buttonLayoutComponent : (root.isVertical ? sideLayoutComponent : topLayoutComponent)
    }

    Component {
        id: buttonLayoutComponent

        Item {
            id: buttonLayout
            readonly property var pill: null
            implicitWidth: batButton.width
            implicitHeight: batButton.height

            ClickButton {
                id: batButton
                height: root.pillHeight
                width: root.isVertical ? height : Math.max(s(root.isCompact ? 32 : 36), implicitWidth)
                cornerRadius: root.lockLook ? ThemeBackend.borderRadius : Math.max(0, ThemeBackend.borderRadius - s(2))
                horizontalPadding: s(root.isCompact ? 10 : 12)
                buttonIcon: root.effectiveShowIcon ? root.batIcon : ""
                iconFontSize: s(root.isCompact ? 14 : 15)
                buttonText: (!root.isVertical && root.effectiveShowPercent) ? root.batPercent : ""
                textFontSize: s(root.isCompact ? 11 : 12)
                accentColor: Qt.lighter(ThemeBackend.surface0, root.isCompact && !root.lockLook ? 1.18 : 1.28)
                textColor: root.lockLook ? root.lockBatColor : root.batDynamicColor
                onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle system"])
            }
        }
    }

    Component {
        id: topLayoutComponent

        Row {
            id: sysLayout
            spacing: 0
            readonly property var pill: batPill

            Rectangle {
                id: batPill
                property bool initAnimTrigger: root.isPreview

                property real value: root.isDesktop ? 0.0 : (root.isPreview ? 0.82 : (UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0.0))
                property real animValue: value
                Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))
                property real fillWidth: width * fillRatio

                readonly property real maxWaveAmp: root.isCharging ? root.s(4.5) : root.s(2.5)
                readonly property real waveAmp: (fillRatio < 0.99 && fillRatio > 0.01) ? maxWaveAmp * Math.sin(fillRatio * Math.PI) : 0
                onFillRatioChanged: {
                    if (root.visible && (!root.isDesktop) && fillRatio > 0.0 && fillRatio < 1.0) {
                        if (!waveAnimation.running) waveAnimation.start();
                        if (!root.isActivelyCharging) waveSettleTimer.restart();
                    }
                }

                property color baseAccentColor: root.batDynamicColor
                property color accentColor: batMouseArea.pressed ? Qt.darker(baseAccentColor, 1.15) : (batMouseArea.containsMouse ? Qt.lighter(baseAccentColor, 1.08) : baseAccentColor)

                Text {
                    id: dummyPercentMetrics
                    visible: false
                    text: root.batPercent ? root.batPercent : "100%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 11 : 12.6)
                    font.bold: true
                }

                Text {
                    id: dummyIconMetrics
                    visible: false
                    text: (!root.isDesktop && root.batStyle === "minimal" && root.isCharging) ? "󱐋" : (root.batIcon ? root.batIcon : "󰁹")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.isDesktop ? s(root.isCompact ? 15 : 16) : s(root.isCompact ? 12 : 13.5)
                }

                property real fullWidthWithPercent: dummyIconMetrics.implicitWidth + s(root.isCompact ? 5 : 6) + dummyPercentMetrics.implicitWidth + s(root.isCompact ? 16 : 18)

                height: root.pillHeight
                property real targetWidth: root.isDesktop ? s(root.isCompact ? 30 : 32) : (root.effectiveShowPercent ? Math.max(fullWidthWithPercent, contentRow.implicitWidth + s(root.isCompact ? 16 : 18)) : fullWidthWithPercent)
                width: targetWidth
                Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

                scale: batMouseArea.pressed ? 0.94 : (batMouseArea.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                radius: Math.max(0, ThemeBackend.borderRadius - s(2))
                property color baseColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                color: batPillGlass.active ? "transparent" : (batMouseArea.pressed ? Qt.darker(baseColor, 1.15) : (batMouseArea.containsMouse ? Qt.lighter(baseColor, 1.08) : baseColor))
                Behavior on color { ColorAnimation { duration: 150 } }
                property color baseBorderColor: root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1
                border.color: batMouseArea.containsMouse ? ThemeBackend.surface2 : baseBorderColor
                Behavior on border.color { ColorAnimation { duration: 150 } }
                border.width: ThemeBackend.liquidGlass ? 0 : 1

                GlassFill {
                    id: batPillGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: parent.baseColor
                    tintAmount: 0.3
                    press: batMouseArea.pressed ? 1 : (batMouseArea.containsMouse ? 0.25 : 0)
                    Behavior on press { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                clip: true

                Timer {
                    running: !root.isPreview && (!module || module.moduleActive) && root.showLayout && !batPill.initAnimTrigger
                    interval: 150
                    onTriggered: batPill.initAnimTrigger = true
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    y: batPill.initAnimTrigger ? 0 : s(15)
                    Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                FluidWave {
                    id: pillWave
                    anchors.fill: parent
                    visible: !root.isDesktop && batPill.fillRatio > 0.001
                    radius: batPill.radius
                    fillLevel: batPill.fillRatio
                    waveAmp: (batPill.fillRatio < 0.99 && batPill.waveAmp > 0) ? Math.min(batPill.waveAmp, Math.min(width * batPill.fillRatio, width * (1.0 - batPill.fillRatio))) : 0
                    phase: root.wavePhase
                    vertical: 0.0
                    color1: (root.batStyle === "minimal") ? root.calmBatFillColor : Qt.lighter(batPill.accentColor, 1.20)
                    color2: (root.batStyle === "minimal") ? root.calmBatFillColor : batPill.accentColor
                    opacity: batPillGlass.active ? 0.0 : 1.0
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: root.isDesktop ? 0 : s(root.isCompact ? 5 : 6)

                    Text {
                        id: batIconText
                        visible: root.effectiveShowIcon
                        text: (!root.isDesktop && root.batStyle === "minimal" && root.isCharging) ? "󱐋" : root.batIcon
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.isDesktop ? s(root.isCompact ? 15 : 16) : s(root.isCompact ? 12 : 13.5)
                        color: root.isDesktop ? ThemeBackend.red : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: batPercentText
                        visible: !root.isDesktop && root.effectiveShowPercent
                        text: root.batPercent
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(root.isCompact ? 11 : 12.6)
                        font.bold: true
                        color: ThemeBackend.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    id: waveClipBox
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width, Math.max(0, batPill.fillWidth))
                    clip: true
                    visible: !root.isDesktop && batPill.fillRatio > 0

                    Row {
                        x: contentRow.x
                        y: contentRow.y
                        spacing: contentRow.spacing

                        Text {
                            visible: batIconText.visible
                            text: batIconText.text
                            font.family: batIconText.font.family
                            font.pixelSize: batIconText.font.pixelSize
                            color: batPillGlass.active ? ThemeBackend.text : Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.85)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: batPercentText.visible
                            text: batPercentText.text
                            font.family: batPercentText.font.family
                            font.pixelSize: batPercentText.font.pixelSize
                            font.bold: batPercentText.font.bold
                            color: batPillGlass.active ? ThemeBackend.text : ThemeBackend.crust
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    id: batMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.isPreview
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle system"])
                }
            }

            Item {
                id: batCapBox
                visible: !root.isDesktop && root.batStyle === "minimal"
                width: visible ? s(root.isCompact ? 4 : 5) : 0
                height: root.pillHeight

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: s(root.isCompact ? 3 : 4)
                    height: Math.round(root.pillHeight * 0.38)
                    radius: s(1.5)
                    color: batPill.border.color
                }
            }
        }
    }

    Component {
        id: sideLayoutComponent

        Column {
            id: sysSideLayout
            spacing: 0
            readonly property var pill: batBtn

            Item {
                id: sideBatCapBox
                visible: !root.isDesktop && root.batStyle === "minimal"
                width: batBtn.width
                height: visible ? s(root.isCompact ? 3 : 4) : 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: Math.round(batBtn.width * 0.38)
                    height: s(root.isCompact ? 2.5 : 3)
                    radius: s(1)
                    color: batBtn.border.color
                }
            }

            Rectangle {
                id: batBtn
                width: s(root.isCompact ? (root.isDesktop ? 28 : 26) : (root.isDesktop ? 30 : 28))
                height: root.isDesktop ? width : s(root.isCompact ? 36 : 40)
                Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

                radius: Math.max(0, ThemeBackend.borderRadius - s(2))
                property color baseColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                color: batBtnGlass.active ? "transparent" : (sideBatMouseArea.pressed ? Qt.darker(baseColor, 1.15) : (sideBatMouseArea.containsMouse ? Qt.lighter(baseColor, 1.08) : baseColor))
                Behavior on color { ColorAnimation { duration: 150 } }

                GlassFill {
                    id: batBtnGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: parent.baseColor
                    tintAmount: 0.3
                    press: sideBatMouseArea.pressed ? 1 : (sideBatMouseArea.containsMouse ? 0.25 : 0)
                    Behavior on press { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                property color baseBorderColor: root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1
                border.color: sideBatMouseArea.containsMouse ? ThemeBackend.surface2 : baseBorderColor
                Behavior on border.color { ColorAnimation { duration: 150 } }
                border.width: ThemeBackend.liquidGlass ? 0 : 1
                clip: true

                scale: sideBatMouseArea.pressed ? 0.94 : (sideBatMouseArea.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                property real value: root.isDesktop ? 0.0 : (root.isPreview ? 0.82 : (UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0.0))
                property color baseAccentColor: root.batDynamicColor
                property color accentColor: sideBatMouseArea.pressed ? Qt.darker(baseAccentColor, 1.15) : (sideBatMouseArea.containsMouse ? Qt.lighter(baseAccentColor, 1.08) : baseAccentColor)
                property bool initAnimTrigger: root.isPreview

                property real animValue: value
                Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))
                property real fillY: height * (1.0 - fillRatio)

                readonly property real maxWaveAmp: root.isCharging ? root.s(4.5) : root.s(2.5)
                readonly property real waveAmp: (fillRatio < 0.99 && fillRatio > 0.01) ? maxWaveAmp * Math.sin(fillRatio * Math.PI) : 0

                onFillRatioChanged: {
                    if (root.visible && (!root.isDesktop) && fillRatio > 0.0 && fillRatio < 1.0) {
                        if (!waveAnimation.running) waveAnimation.start();
                        if (!root.isActivelyCharging) waveSettleTimer.restart();
                    }
                }

                Timer {
                    running: !root.isPreview && (!module || module.moduleActive) && root.showLayout && !batBtn.initAnimTrigger
                    interval: 150
                    onTriggered: batBtn.initAnimTrigger = true
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: batBtn.initAnimTrigger ? 0 : s(15)
                    Behavior on x { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                FluidWave {
                    id: sideBatWave
                    anchors.fill: parent
                    visible: !root.isDesktop && batBtn.fillRatio > 0.001
                    radius: batBtn.radius
                    fillLevel: batBtn.fillRatio
                    waveAmp: (batBtn.fillRatio < 0.99 && batBtn.waveAmp > 0) ? Math.min(batBtn.waveAmp, Math.min(height * batBtn.fillRatio, height * (1.0 - batBtn.fillRatio))) : 0
                    phase: root.wavePhase
                    vertical: 1.0
                    color1: (root.batStyle === "minimal") ? root.calmBatFillColor : Qt.lighter(batBtn.accentColor, 1.20)
                    color2: (root.batStyle === "minimal") ? root.calmBatFillColor : batBtn.accentColor
                    opacity: batBtnGlass.active ? 0.0 : 1.0
                }

                Item {
                    id: sideContentBox
                    anchors.centerIn: parent
                    visible: root.effectiveShowIcon
                    width: sideBatIconText.implicitWidth
                    height: sideBatIconText.implicitHeight

                    Text {
                        id: sideBatIconText
                        anchors.centerIn: parent
                        text: (!root.isDesktop && root.batStyle === "minimal" && root.isCharging) ? "󱐋" : root.batIcon
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.isDesktop ? s(root.isCompact ? 15 : 16) : s(root.isCompact ? 12 : 13)
                        color: root.isDesktop ? ThemeBackend.red : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)
                    }
                }

                Item {
                    id: sideWaveClipBox
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.min(parent.height, Math.max(0, parent.height - batBtn.fillY))
                    clip: true
                    visible: !root.isDesktop && root.effectiveShowIcon && batBtn.fillRatio > 0

                    Text {
                        x: sideContentBox.x
                        y: sideContentBox.y - batBtn.fillY
                        text: sideBatIconText.text
                        font.family: sideBatIconText.font.family
                        font.pixelSize: sideBatIconText.font.pixelSize
                        color: batBtnGlass.active ? ThemeBackend.text : Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.85)
                    }
                }

                MouseArea {
                    id: sideBatMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.isPreview
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle system"])
                }
            }
        }
    }
}
