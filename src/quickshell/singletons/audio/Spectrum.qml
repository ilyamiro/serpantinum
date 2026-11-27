pragma Singleton
import QtQuick
import Quickshell
import "../../"

RefCountedService {
    id: root

    property int barCount: 64
    readonly property var emptyLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return Object.freeze(arr);
    }
    property var barLevels: emptyLevels
    readonly property int activeConsumers: root.subscribers
    property bool isPlaying: MprisController.isPlaying || Audio.hasActiveStream
    property bool isDecaying: false
    property bool processEnabled: root.active && (isPlaying || isDecaying)

    function registerConsumer() {
        subscribe();
    }

    function unregisterConsumer() {
        unsubscribe();
    }

    function resetBars() {
        root.barLevels = root.emptyLevels;
    }

    onDeactivated: {
        root.isDecaying = false;
        decayTimer.stop();
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            root.isDecaying = false;
            decayTimer.stop();
        } else if (root.active) {
            root.isDecaying = true;
            decayTimer.restart();
        } else {
            root.isDecaying = false;
            decayTimer.stop();
            resetBars();
        }
    }

    onProcessEnabledChanged: {
        if (!processEnabled) {
            resetBars();
        }
    }

    Timer {
        id: decayTimer
        interval: 1200
        repeat: false
        onTriggered: root.isDecaying = false
    }

    JsonStreamProcess {
        id: visualizerProcess
        active: root.processEnabled
        maxRetries: 5
        restartInterval: 500
        command: ["serpantinum-audio", "visualizer", "--bars", String(root.barCount), "--framerate", "60", "--sensitivity", "150"]
        onMessage: levels => {
            if (!root.processEnabled) return;
            if (!Array.isArray(levels) || levels.length !== root.barCount) return;
            root.barLevels = levels;
        }
    }
}
