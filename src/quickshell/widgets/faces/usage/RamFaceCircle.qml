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

    property real rawRam: isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: root.ramUsage
        accentColor: Qt.lighter(ThemeBackend.accent, 1.15)
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
