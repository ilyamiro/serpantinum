import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceBase {
    id: root

    property real rawDisk: isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property string diskUsedText: SysData.diskGb > 0 ? (SysData.diskGb.toFixed(1) + "G") : "..."
    property string diskTotalText: SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : ""

    SystemUsageCard {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        value: root.diskUsagePercent
        colorBase: ThemeBackend.surface0
        colorFill: Qt.darker(ThemeBackend.mauve, 1.15)
        icon: String.fromCodePoint(0xF02CA)
        title: root.diskTotalText
        subText: root.diskUsedText
        valueText: Math.round(root.diskUsagePercent * 100) + "%"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
