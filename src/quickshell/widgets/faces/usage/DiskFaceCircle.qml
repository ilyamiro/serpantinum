import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceCircleBase {
    id: root

    property real rawDisk: isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property string diskTotalText: SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : ""

    SystemUsageCircle {
        anchors.fill: parent
        value: root.diskUsagePercent
        accentColor: Qt.darker(ThemeBackend.mauve, 1.15)
        icon: String.fromCodePoint(0xF02CA)
        title: root.diskTotalText
        valueText: Math.round(root.diskUsagePercent * 100) + "%"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
