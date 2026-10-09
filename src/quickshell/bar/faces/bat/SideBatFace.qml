import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
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

    property bool showLayout: (!barWindow || isPreview) ? true : false
    property alias batPill: batBtn

    property bool isDesktop: isPreview ? false : (UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop)
    readonly property int batCap: isPreview ? 82 : (UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0)
    readonly property string batPercent: batCap + "%"
    readonly property bool isCharging: isPreview ? false : (UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged))
    readonly property bool isActivelyCharging: isCharging && UPower.displayDevice.changeRate > 0.5
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
        running: root.visible && (!root.isDesktop) && root.batStyle !== "text" && (typeof batBtn !== "undefined" && batBtn ? (batBtn.fillRatio > 0.0 && batBtn.fillRatio < 1.0) : false) && root.isActivelyCharging
    }

    onIsChargingChanged: {
        if (isCharging && visible && !isDesktop && root.batStyle !== "text" && typeof batBtn !== "undefined" && batBtn && batBtn.fillRatio > 0.0 && batBtn.fillRatio < 1.0) {
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
        } else if (isActivelyCharging && !isDesktop && root.batStyle !== "text" && typeof batBtn !== "undefined" && batBtn && batBtn.fillRatio > 0.0 && batBtn.fillRatio < 1.0) {
            waveAnimation.start();
        }
    }

    property color batDynamicColor: {
        if (isDesktop) return ThemeBackend.red;
        if (isCharging) return ThemeBackend.green;
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

    property real targetHeight: {
        if (module && !module.moduleActive) return 0;
        if (root.batStyle === "text") {
            return (sideTextCol.implicitHeight > 0) ? (sideTextCol.implicitHeight + (isPreview ? 0 : s(isCompact ? 14 : 16))) : 0;
        }
        return (sysSideLayout.implicitHeight > 0) ? (sysSideLayout.implicitHeight + (isPreview ? 0 : s(isCompact ? 8 : 10))) : 0;
    }
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: (parent && parent.width > 0) ? parent.width : batBtn.width

    Timer {
        running: !root.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        y: root.showLayout ? 0 : s(60)
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: sideTextMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.batStyle === "text" && !root.isPreview
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle system"])
    }

    Column {
        id: sideTextCol
        visible: root.batStyle === "text"
        anchors.centerIn: parent
        spacing: s(root.isCompact ? 2 : 3)
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
            visible: root.effectiveShowIcon
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.batIcon
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.isDesktop ? s(root.isCompact ? 15 : 16) : s(root.isCompact ? 13 : 14)
            color: sideTextMouseArea.containsMouse ? Qt.lighter(root.batDynamicColor, 1.15) : root.batDynamicColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: !root.isDesktop && root.effectiveShowPercent
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.batPercent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(root.isCompact ? 9 : 10)
            font.bold: true
            color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Column {
        id: sysSideLayout
        visible: root.batStyle !== "text"
        anchors.centerIn: parent
        spacing: 0

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
            color: batMouseArea.pressed ? Qt.darker(baseColor, 1.15) : (batMouseArea.containsMouse ? Qt.lighter(baseColor, 1.08) : baseColor)
            Behavior on color { ColorAnimation { duration: 150 } }
            property color baseBorderColor: root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1
            border.color: batMouseArea.containsMouse ? ThemeBackend.surface2 : baseBorderColor
            Behavior on border.color { ColorAnimation { duration: 150 } }
            border.width: 1
            clip: true

            scale: batMouseArea.pressed ? 0.94 : (batMouseArea.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            property real value: root.isDesktop ? 0.0 : (root.isPreview ? 0.82 : (UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0.0))
            property color baseAccentColor: root.batDynamicColor
            property color accentColor: batMouseArea.pressed ? Qt.darker(baseAccentColor, 1.15) : (batMouseArea.containsMouse ? Qt.lighter(baseAccentColor, 1.08) : baseAccentColor)
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
                    color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.85)
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
    }
}
