import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

UsageFaceCircleBase {
    id: root

    property real rawTemp: isNaN(SysData.temp) ? 0.0 : SysData.temp
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
        accentColor: ThemeBackend.mauve
        icon: String.fromCodePoint(0xF050F)
        title: I18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
