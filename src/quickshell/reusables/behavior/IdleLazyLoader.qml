import QtQuick
import Quickshell

Scope {
    id: root

    property bool wanted: false
    property int unloadDelay: 45000
    property bool keepAlive: false
    default property alias component: innerLoader.component
    readonly property alias item: innerLoader.item
    readonly property alias active: innerLoader.active

    onWantedChanged: {
        if (wanted) {
            unloadTimer.stop();
            keepAlive = true;
        } else if (keepAlive) {
            unloadTimer.restart();
        }
    }

    Component.onCompleted: {
        if (wanted) keepAlive = true;
    }

    Timer {
        id: unloadTimer
        interval: root.unloadDelay
        repeat: false
        onTriggered: {
            if (root.wanted) return;
            if (innerLoader.item && innerLoader.item.visible) {
                restart();
                return;
            }
            root.keepAlive = false;
            Qt.callLater(gc);
        }
    }

    LazyLoader {
        id: innerLoader
        active: root.wanted || root.keepAlive
    }
}
