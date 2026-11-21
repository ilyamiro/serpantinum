import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceGraphBase {
    id: root

    readonly property var samples: root.track ? root.track.ramPercent : []
    readonly property var gbSamples: root.track ? root.track.ramGb : []
    property real rawRamGb: root.lastOf(root.gbSamples)
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageGraph {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        history: root.samples.map(v => v / 100)
        statsSource: root.gbSamples
        formatValue: v => v.toFixed(1) + "G"
        lineColor: Qt.lighter(ThemeBackend.mauve, 1.15)
        title: I18n.t("quickactions.systemusage.ram")
        valueText: root.ramUsedGb.toFixed(1) + "G"
        sampleInterval: root.sampleInterval * 1000
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
