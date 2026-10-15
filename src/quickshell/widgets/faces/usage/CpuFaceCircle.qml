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

    property real rawCpu: isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: root.cpuUsage
        accentColor: Qt.lighter(ThemeBackend.mauve, 1.35)
        icon: String.fromCodePoint(0xF035B)
        title: I18n.t("quickactions.systemusage.cpu")
        valueText: Math.round(root.cpuUsage * 100) + "%"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
