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
import "../../"

BarPillFaceBase {
    id: root

    property string volStyle: String(readSetting("volStyle", "vol.style", "button"))
    property bool showIcon: Boolean(readSetting("volShowIcon", "vol.showIcon", true))
    property bool showPercent: Boolean(readSetting("volShowPercent", "vol.showPercent", true))

    pillStyle: volStyle
    revealDelay: isVertical ? 0 : 100
    acceptedTextButtons: Qt.LeftButton | Qt.RightButton
    pillSourceComponent: root.isVertical ? sideButtonComponent : topButtonComponent

    property real sysVolume: isPreview ? 65 : (Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0)
    property bool isMuted: isPreview ? false : (Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false)
    property string volPercent: sysVolume + "%"
    property string volIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
    property bool sysMuted: isMuted

    property bool isDraggingVol: false
    property bool isSoundActive: !isMuted && sysVolume > 0
    readonly property var volPill: pillLoader.item

    WheelStepper {
        id: volWheel
        threshold: 120
        resetInterval: 200
        onStepped: delta => {
            if (root.isPreview || !Audio.defaultSink) return;
            let newVol = Math.max(0, Math.min(100, root.sysVolume + (delta * 5)));
            Audio.setVolume(Audio.defaultSink, newVol);
        }
    }

    onTextClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            if (Audio.defaultSink) Audio.toggleMute(Audio.defaultSink);
        } else {
            root.togglePanel("volume");
        }
    }

    onTextWheel: wheel => volWheel.feed(wheel.angleDelta.y)

    Item {
        visible: root.showIcon
        width: root.isVertical ? textIcon.implicitWidth : s(root.isCompact ? 18 : 20)
        height: root.isVertical ? textIcon.implicitHeight : width

        Text {
            id: textIcon
            anchors.centerIn: parent
            text: root.volIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(root.isCompact ? 14 : 15)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.15) : (root.isSoundActive ? ThemeBackend.mauve : ThemeBackend.subtext0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Text {
        visible: root.showPercent
        text: root.volPercent
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.isVertical ? s(root.isCompact ? 9 : 10) : s(root.isCompact ? 11 : 12)
        font.bold: true
        color: root.textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Component {
        id: topButtonComponent

        ClickButton {
            id: volPill
            property bool initAnimTrigger: root.isPreview
            property bool isActive: root.isSoundActive

            height: s(root.isCompact ? 28 : 30)
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
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            onClicked: root.togglePanel("volume")
            onRightClicked: if (!root.isPreview && Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)
            onWheel: wheel => volWheel.feed(wheel.angleDelta.y)
        }
    }

    Component {
        id: sideButtonComponent

        IconButton {
            width: s(root.isCompact ? 28 : 30)
            height: (root.showIcon || root.showPercent) ? s(root.isCompact ? 28 : 30) : 0
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
            buttonIcon: root.showIcon ? root.volIcon : ""
            iconFontSize: s(root.isCompact ? 14 : 15)
            accentColor: root.isSoundActive ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.12) : ThemeBackend.surface1)
            textColor: root.isSoundActive ? ThemeBackend.base : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)
            onClicked: root.togglePanel("volume")
        }
    }
}
