import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceCircleBase {
    id: root

    property real rawRam: isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: root.ramUsage
        accentColor: Qt.lighter(ThemeBackend.mauve, 1.15)
        icon: String.fromCodePoint(0xF035C)
        title: I18n.t("quickactions.systemusage.ram")
        valueText: root.ramUsedGb.toFixed(1) + "G"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
