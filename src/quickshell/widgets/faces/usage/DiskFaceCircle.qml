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
