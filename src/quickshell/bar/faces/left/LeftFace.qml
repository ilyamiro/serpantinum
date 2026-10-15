import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool showLayout: barWindow ? Boolean(barWindow.isStartupReady) : true
    readonly property real barOpacity: (module && module.barOpacity !== undefined) ? module.barOpacity : (barWindow && barWindow.barOpacity !== undefined ? barWindow.barOpacity : (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined ? (Config.rawSettings.bar.opacity / 100.0) : 1.0))

    property alias helpButton: helpButton

    property real targetWidth: (module && module.moduleActive) ? (leftLayout.width + (barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8))) : 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Row {
        id: leftLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
        spacing: barWindow ? barWindow.s(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6)

        property int pillHeight: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)

        IconButton {
            id: helpButton
            height: leftLayout.pillHeight
            width: barWindow ? barWindow.s(root.isCompact ? 30 : 32) : (root.isCompact ? 30 : 32)
            visible: true
            iconOffsetX: 0

            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: "󰒓"
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)

            opacity: root.showLayout ? 1.0 : 0.0
            transform: Translate {
                y: root.showLayout ? 0 : (barWindow ? barWindow.s(15) : 15)
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
        }
    }
}
