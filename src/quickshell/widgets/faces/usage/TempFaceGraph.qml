import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceGraphBase {
    id: root

    readonly property var samples: root.track ? root.track.temp : []
    property real rawTemp: root.lastOf(root.samples)
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageGraph {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        history: root.samples.map(v => v / 100)
        statsSource: root.samples
        formatValue: v => Math.round(v) + "°"
        lineColor: ThemeBackend.mauve
        title: I18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        sampleInterval: root.sampleInterval * 1000
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
