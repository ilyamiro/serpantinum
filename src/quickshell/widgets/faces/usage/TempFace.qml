import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 100
    property real minHeight: 70
    property real maxWidth: 600
    property real maxHeight: 400
    property real minAspect: 0.6
    property real maxAspect: 3.0
    property bool isRound: false

    property bool isSubscribed: false
    property bool compactMode: root.height < Scaler.s(100) || root.width < Scaler.s(140)

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

    SystemUsageCard {
        anchors.fill: parent
        value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
        colorBase: ThemeBackend.surface0
        colorFill: ThemeBackend.mauve
        icon: String.fromCodePoint(0xF050F)
        title: I18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
