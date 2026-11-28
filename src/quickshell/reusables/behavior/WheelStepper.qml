import QtQuick

Item {
    id: root
    visible: false

    property real threshold: 120
    property int resetInterval: 200
    property real accumulator: 0

    signal stepped(int delta)

    function feed(angleDelta) {
        if (angleDelta === 0 || threshold <= 0) return;
        resetTimer.restart();
        accumulator += angleDelta;
        while (accumulator >= threshold) {
            accumulator -= threshold;
            stepped(1);
        }
        while (accumulator <= -threshold) {
            accumulator += threshold;
            stepped(-1);
        }
    }

    function reset() {
        accumulator = 0;
        resetTimer.stop();
    }

    Timer {
        id: resetTimer
        interval: root.resetInterval
        repeat: false
        onTriggered: root.accumulator = 0
    }
}
