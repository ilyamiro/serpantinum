import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.5
    property real maxAspect: 2.0
    property bool isRound: false

    property bool sineWave: true
    property real lineThickness: 8

    property bool isSubscribed: false
    property bool compactMode: Math.min(root.height, root.width) < Scaler.s(110)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            SysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

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
