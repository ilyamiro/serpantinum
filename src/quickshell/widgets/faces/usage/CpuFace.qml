import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceBase {
    id: root

    property real rawCpu: isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageCard {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        value: root.cpuUsage
        colorBase: ThemeBackend.surface0
        colorFill: Qt.lighter(ThemeBackend.mauve, 1.35)
        icon: String.fromCodePoint(0xF035B)
        title: I18n.t("quickactions.systemusage.cpu")
        valueText: Math.round(root.cpuUsage * 100) + "%"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
