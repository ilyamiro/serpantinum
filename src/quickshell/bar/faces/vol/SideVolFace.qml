import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
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

    readonly property real sysVolume: isPreview ? 65 : (Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0)
    readonly property bool isMuted: isPreview ? false : (Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false)
    property string volPercent: sysVolume + "%"
    property string volIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
    property bool isSoundActive: !isMuted && sysVolume > 0

    property bool showLayout: (!barWindow || isPreview) ? true : ((!module || module.moduleActive) && barWindow.isStartupReady && barWindow.isDataReady)
    property alias volPill: volBtn

    property real targetHeight: {
        if (module && !module.moduleActive) return 0;
        if (root.volStyle === "text") {
            return (sideTextCol.implicitHeight > 0) ? (sideTextCol.implicitHeight + s(root.isCompact ? 14 : 16)) : 0;
        }
        return (volBtn.height > 0) ? (volBtn.height + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    MouseArea {
        id: sideTextMouseArea
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
            onTriggered: sideTextMouseArea.wheelAccumulator = 0
        }

        onWheel: wheel => {
            textWheelTimer.restart()
            sideTextMouseArea.wheelAccumulator += wheel.angleDelta.y
            const threshold = 120
            if (Math.abs(sideTextMouseArea.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(sideTextMouseArea.wheelAccumulator / threshold)
                sideTextMouseArea.wheelAccumulator = sideTextMouseArea.wheelAccumulator % threshold
                if (steps !== 0 && Audio.defaultSink) {
                    let newVol = Math.max(0, Math.min(Audio.maxVolume, root.sysVolume + (steps * 5)))
                    Audio.setVolume(Audio.defaultSink, newVol)
                }
            }
        }
    }

    Column {
        id: sideTextCol
        visible: root.volStyle === "text"
        anchors.centerIn: parent
        spacing: s(root.isCompact ? 2 : 3)
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
            visible: root.showIcon
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.volIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(root.isCompact ? 14 : 15)
            color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.15) : (root.isSoundActive ? ThemeBackend.mauve : ThemeBackend.subtext0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: root.showPercent
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.volPercent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(root.isCompact ? 9 : 10)
            font.bold: true
            color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    IconButton {
        id: volBtn
        visible: root.volStyle !== "text"
        anchors.centerIn: parent
        width: s(root.isCompact ? 28 : 30)
        height: (root.showIcon || root.showPercent) ? s(root.isCompact ? 28 : 30) : 0
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
        buttonIcon: root.showIcon ? root.volIcon : ""
        iconFontSize: s(root.isCompact ? 14 : 15)
        accentColor: root.isSoundActive ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.12) : ThemeBackend.surface1)
        textColor: root.isSoundActive ? ThemeBackend.base : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)
        onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
    }
}
