import QtQuick
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
}
