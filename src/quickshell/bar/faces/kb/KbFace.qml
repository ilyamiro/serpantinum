import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"
import "../../"

BarPillFaceBase {
    id: root

    property string kbStyle: String(readSetting("kbStyle", "kb.style", "button"))
    property bool showIcon: Boolean(readSetting("kbShowIcon", "kb.showIcon", true))

    pillStyle: kbStyle
    revealDelay: 100
    textSpacingVertical: s(isCompact ? 5 : 6)
    pillSourceComponent: root.isVertical ? sideButtonComponent : topButtonComponent

    readonly property bool lockLook: activeTarget ? activeTarget.lockLook === true : false
    readonly property string kbLayout: KeyboardLayout.layout
    readonly property var kbPill: pillLoader.item
    readonly property bool wantsLayout: !root.isPreview && (!module || module.moduleActive)

    SubscriptionGate {
        target: KeyboardLayout
        wanted: root.wantsLayout
    }

    function markLoaded() {
        if (barWindow && KeyboardLayout.ready) barWindow.fastPollerLoaded = true;
    }

    function switchLayout() {
        if (root.isPreview) return;
        KeyboardLayout.switchNext();
    }

    onBarWindowChanged: markLoaded()

    Component.onCompleted: markLoaded()

    Connections {
        target: KeyboardLayout
        function onReadyChanged() { root.markLoaded(); }
        function onLayoutChanged() { root.markLoaded(); }
    }

    onTextClicked: root.switchLayout()

    Item {
        visible: root.showIcon && !root.isVertical
        width: s(root.isCompact ? 18 : 20)
        height: width

        Text {
            anchors.centerIn: parent
            text: "󰌌"
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(root.isCompact ? 14 : 15)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.subtext0
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Text {
        text: root.kbLayout
        font.family: ThemeBackend.fontFamily
        font.pixelSize: s(root.isCompact ? 11 : 12)
        font.bold: true
        color: root.textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Component {
        id: topButtonComponent

        ClickButton {
            id: kbPill
            property bool initAnimTrigger: root.isPreview
            height: s(root.lockLook ? 36 : (root.isCompact ? 28 : 30))
            maxWidth: s(root.isCompact ? 96 : 100)
            cornerRadius: root.lockLook ? ThemeBackend.borderRadius : Math.max(0, ThemeBackend.borderRadius - s(2))
            horizontalPadding: s(root.isCompact ? 10 : 12)
            buttonIcon: root.showIcon ? "󰌌" : ""
            iconFontSize: s(root.isCompact ? 14 : 15)
            buttonText: root.kbLayout
            textFontSize: s(root.isCompact ? 11 : 12)
            accentColor: root.lockLook ? Qt.lighter(ThemeBackend.surface0, 1.28) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: Math.max(s(root.isCompact ? (root.showIcon ? 48 : 32) : (root.showIcon ? 52 : 36)), implicitWidth)
            width: targetWidth

            Behavior on width {
                enabled: barWindow && barWindow.startupCascadeFinished
                NumberAnimation { duration: 480; easing.type: Easing.OutQuint }
            }

            Timer { running: !root.isPreview && (!module || module.moduleActive) && root.showLayout && !kbPill.initAnimTrigger; interval: 70; onTriggered: kbPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: kbPill.initAnimTrigger ? 0 : s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            onClicked: root.switchLayout()
        }
    }

    Component {
        id: sideButtonComponent

        ClickButton {
            width: s(root.isCompact ? 28 : 30)
            height: s(root.isCompact ? 28 : 30)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
            horizontalPadding: 0
            buttonText: root.kbLayout
            textFontSize: s(root.isCompact ? 11 : 12)
            accentColor: root.lockLook ? Qt.lighter(ThemeBackend.surface0, 1.28) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            onClicked: root.switchLayout()
        }
    }
}
