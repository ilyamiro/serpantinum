import QtQuick

Item {
    id: guideTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: -1

    readonly property bool isCurrent: rootObj.currentTab === tabIndex && (subTabIndex < 0 || rootObj.currentSubTab === subTabIndex)

    property bool revealed: visible

    anchors.fill: parent
    visible: isCurrent
    opacity: revealed ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: 150 } }

    property int deferredStages: 0
    property int deferredStage: 0
    property int deferredInterval: 16
    readonly property bool deferredBuilding: deferredStage < deferredStages
    readonly property bool buildUrgent: rootObj.pendingHighlightItem !== null || rootObj.highlightedSettingId !== ""
    property bool deferredCounted: false

    onBuildUrgentChanged: {
        if (buildUrgent) deferredStage = deferredStages;
    }

    onDeferredBuildingChanged: {
        if (!deferredBuilding && deferredCounted) {
            deferredCounted = false;
            rootObj.deferredBuilds--;
        }
    }

    Component.onCompleted: {
        if (buildUrgent) deferredStage = deferredStages;
        if (deferredBuilding) {
            deferredCounted = true;
            rootObj.deferredBuilds++;
        }
    }

    Component.onDestruction: {
        if (deferredCounted) rootObj.deferredBuilds--;
    }

    Timer {
        interval: guideTabRoot.deferredInterval
        repeat: true
        running: guideTabRoot.deferredBuilding
        onTriggered: guideTabRoot.deferredStage++
    }
}
