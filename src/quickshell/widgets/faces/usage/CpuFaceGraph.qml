import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceGraphBase {
    id: root

    readonly property var samples: root.track ? root.track.cpu : []
    property real rawCpu: root.lastOf(root.samples)
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageGraph {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        history: root.samples.map(v => v / 100)
        statsSource: root.samples
        lineColor: Qt.lighter(ThemeBackend.mauve, 1.35)
        title: I18n.t("quickactions.systemusage.cpu")
        valueText: Math.round(root.cpuUsage) + "%"
        sampleInterval: root.sampleInterval * 1000
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
