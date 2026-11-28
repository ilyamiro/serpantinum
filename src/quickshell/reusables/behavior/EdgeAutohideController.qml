import QtQuick

Item {
    id: root
    visible: false

    property bool autohide: false
    property int timeout: 1000
    property bool hovered: false
    property bool keepOpen: false
    property bool forceHidden: false
    property bool positionChanging: false
    property int positionChangeDuration: 200

    readonly property bool hideTimerRunning: hideTimer.running
    readonly property bool isRevealed: {
        if (forceHidden) return false;
        if (keepOpen) return true;
        if (!autohide) return true;
        if (hovered) return true;
        if (hideTimer.running) return true;
        return false;
    }

    function checkHide() {
        if (!hovered && !keepOpen && autohide && !forceHidden) {
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }

    function triggerPositionChange() {
        positionChanging = true;
        positionChangeTimer.restart();
    }

    onHoveredChanged: checkHide()
    onKeepOpenChanged: checkHide()
    onAutohideChanged: checkHide()
    onForceHiddenChanged: checkHide()

    Timer {
        id: hideTimer
        interval: root.timeout
        repeat: false
    }

    Timer {
        id: positionChangeTimer
        interval: root.positionChangeDuration
        repeat: false
        onTriggered: root.positionChanging = false
    }
}
