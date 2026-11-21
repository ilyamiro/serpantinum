import QtQuick
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property bool previewMode: false

    property real minWidth: 100
    property real minHeight: 70
    property real maxWidth: 600
    property real maxHeight: 400
    property real minAspect: 0.6
    property real maxAspect: 3.0
    property bool isRound: false

    property bool compactMode: root.height < Scaler.s(100) || root.width < Scaler.s(140)

    property real updatesPerMinute: 30
    readonly property int sampleInterval: Math.max(1, Math.min(10, Math.round(60 / Math.max(1, root.updatesPerMinute))))
    property int heldInterval: 0
    readonly property var track: root.heldInterval > 0 ? SysData.historyFor(root.heldInterval) : null

    function lastOf(list) {
        return list && list.length > 0 ? list[list.length - 1] : 0;
    }

    function updateTrack() {
        let wanted = root.visible ? root.sampleInterval : 0;
        if (wanted === root.heldInterval) return;
        if (root.heldInterval > 0) SysData.releaseHistory(root.heldInterval);
        if (wanted > 0) SysData.acquireHistory(wanted);
        root.heldInterval = wanted;
    }

    onVisibleChanged: updateTrack()
    onSampleIntervalChanged: updateTrack()
    Component.onCompleted: updateTrack()
    Component.onDestruction: {
        if (root.heldInterval > 0) SysData.releaseHistory(root.heldInterval);
    }
}
