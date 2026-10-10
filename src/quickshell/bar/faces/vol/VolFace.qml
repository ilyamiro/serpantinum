import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
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

    property string volStyle: {
        if (widget && widget !== root && widget.volStyle !== undefined) return widget.volStyle;
        if (module && module.volStyle !== undefined) return module.volStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.volStyle) return bs.volStyle;
            if (bs.vol && bs.vol.style) return bs.vol.style;
        }
        return "button";
    }

    property bool showIcon: {
        if (widget && widget !== root && widget.volShowIcon !== undefined) return widget.volShowIcon;
        if (widget && widget !== root && widget.showIcon !== undefined) return widget.showIcon;
        if (module && module.volShowIcon !== undefined) return module.volShowIcon;
        if (module && module.showIcon !== undefined) return module.showIcon;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.volShowIcon !== undefined) return Boolean(bs.volShowIcon);
            if (bs.vol && bs.vol.showIcon !== undefined) return Boolean(bs.vol.showIcon);
        }
        return true;
    }

    property bool showPercent: {
        if (widget && widget !== root && widget.volShowPercent !== undefined) return widget.volShowPercent;
        if (widget && widget !== root && widget.showPercent !== undefined) return widget.showPercent;
        if (module && module.volShowPercent !== undefined) return module.volShowPercent;
        if (module && module.showPercent !== undefined) return module.showPercent;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.volShowPercent !== undefined) return Boolean(bs.volShowPercent);
            if (bs.vol && bs.vol.showPercent !== undefined) return Boolean(bs.vol.showPercent);
        }
        return true;
    }

    property real sysVolume: isPreview ? 65 : (Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0)
    property bool isMuted: isPreview ? false : (Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false)
    property string volPercent: sysVolume + "%"
    property string volIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
    property bool sysMuted: isMuted

    property bool isDraggingVol: false
    property bool isSoundActive: !isMuted && sysVolume > 0
    property bool showLayout: (!barWindow || isPreview) ? true : false
    property alias volPill: volPill

    property real targetWidth: {
        if (module && !module.moduleActive) return 0;
        if (root.volStyle === "text") {
            return (textRow.implicitWidth > 0) ? (textRow.implicitWidth + s(root.isCompact ? 16 : 20)) : 0;
        }
        return (sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Timer {
        running: !root.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: textMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.volStyle === "text" && !root.isPreview
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)
            } else {
                Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
            }
        }

        property real wheelAccumulator: 0
        Timer {
            id: textWheelTimer
            interval: 200
            onTriggered: textMouseArea.wheelAccumulator = 0
        }

        onWheel: wheel => {
            textWheelTimer.restart()
            textMouseArea.wheelAccumulator += wheel.angleDelta.y
            const threshold = 120
            if (Math.abs(textMouseArea.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(textMouseArea.wheelAccumulator / threshold)
                textMouseArea.wheelAccumulator = textMouseArea.wheelAccumulator % threshold
                if (steps !== 0 && Audio.defaultSink) {
                    let newVol = Math.max(0, Math.min(Audio.maxVolume, root.sysVolume + (steps * 5)))
                    Audio.setVolume(Audio.defaultSink, newVol)
                }
            }
        }
    }

    Row {
        id: textRow
        visible: root.volStyle === "text"
        anchors.centerIn: parent
        spacing: s(root.isCompact ? 5 : 6)
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
            visible: root.showIcon
            text: root.volIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(root.isCompact ? 14 : 15)
            color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.15) : (root.isSoundActive ? ThemeBackend.mauve : ThemeBackend.subtext0)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: root.showPercent
            text: root.volPercent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(root.isCompact ? 11 : 12)
            font.bold: true
            color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Row {
        id: sysLayout
        visible: root.volStyle !== "text"
        anchors.centerIn: parent
        property int pillHeight: s(root.isCompact ? 28 : 30)

        ClickButton {
            id: volPill
            property bool initAnimTrigger: root.isPreview
            property bool isActive: root.isSoundActive

            height: sysLayout.pillHeight
            maxWidth: s(root.isCompact ? 96 : 100)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
            horizontalPadding: s(root.isCompact ? 10 : 12)
            buttonIcon: root.showIcon ? root.volIcon : ""
            iconFontSize: s(root.isCompact ? 14 : 15)
            buttonText: root.showPercent ? root.volPercent : ""
            textFontSize: s(root.isCompact ? 11 : 12)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            accentColor: isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.12) : ThemeBackend.surface1)
            textColor: isActive ? ThemeBackend.base : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)

            property real targetWidth: (root.showIcon || root.showPercent) ? implicitWidth : 0
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            Timer { running: !root.isPreview && (!module || module.moduleActive) && root.showLayout && !volPill.initAnimTrigger; interval: 250; onTriggered: volPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: volPill.initAnimTrigger ? 0 : s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
            onRightClicked: if (!root.isPreview && Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)

            property real wheelAccumulator: 0
            Timer {
                id: volWheelTimer
                interval: 200
                onTriggered: volPill.wheelAccumulator = 0
            }

            onWheel: wheel => {
                if (root.isPreview) return;
                volWheelTimer.restart()
                volPill.wheelAccumulator += wheel.angleDelta.y
                const threshold = 120
                if (Math.abs(volPill.wheelAccumulator) >= threshold) {
                    let steps = Math.trunc(volPill.wheelAccumulator / threshold)
                    volPill.wheelAccumulator = volPill.wheelAccumulator % threshold
                    if (steps !== 0 && Audio.defaultSink) {
                        let newVol = Math.max(0, Math.min(Audio.maxVolume, root.sysVolume + (steps * 5)))
                        Audio.setVolume(Audio.defaultSink, newVol)
                    }
                }
            }
        }
    }
}
