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

    property alias helpButton: helpBtn

    property real targetHeight: (module && module.moduleActive) ? (helpBtn.height + (barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8))) : 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    IconButton {
        mcStyle: true
        id: helpBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        buttonIcon: "󰒓"
        iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        bgOpacity: root.barOpacity
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
    }
}
