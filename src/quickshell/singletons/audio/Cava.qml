pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property int barCount: 64
    readonly property var emptyLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return arr;
    }
    property var barLevels: emptyLevels
    property int activeConsumers: 0
    property bool isPlaying: MprisController.isPlaying || (typeof Audio !== "undefined" && Audio.hasActiveStream)
    property bool isDecaying: false
    property bool hasActiveAudio: false
    property bool isRestarting: false
    property bool processEnabled: activeConsumers > 0 && (isPlaying || isDecaying) && !isRestarting

    function registerConsumer() {
        activeConsumers++;
    }

    function unregisterConsumer() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }

    function resetBars() {
        root.barLevels = root.emptyLevels;
    }

    function restartCava() {
        if (!processEnabled) return;
        isRestarting = true;
        restartTimer.restart();
    }

    onActiveConsumersChanged: {
        if (activeConsumers === 0) {
            root.isDecaying = false;
            decayTimer.stop();
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            root.isDecaying = false;
            decayTimer.stop();
        } else if (activeConsumers > 0) {
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
            root.hasActiveAudio = false;
            dataWatchdog.stop();
            resetBars();
        }
    }

    Timer {
        id: decayTimer
        interval: 1200
        repeat: false
        onTriggered: root.isDecaying = false
    }

    Timer {
        id: restartTimer
        interval: 500
        repeat: false
        onTriggered: root.isRestarting = false
    }

    Timer {
        id: dataWatchdog
        interval: 2000
        running: cavaProcess.running && root.isPlaying
        repeat: false
        onTriggered: root.restartCava()
    }

    Process {
        id: cavaProcess
        running: root.processEnabled
        onExited: root.restartCava()
        command: [
            "bash", "-c",
            "cava -p <(printf '[general]\\nbars = %d\\nframerate = 60\\nsensitivity = 150\\nsleep_timer = 2\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 1000\\nbar_delimiter = 59\\n' " + root.barCount + ")"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!root.processEnabled) return;
                let str = data.trim();
                if (str.length === 0) return;
                dataWatchdog.restart();

                let hasAudio = /[1-9]/.test(str);
                if (!hasAudio) {
                    if (root.hasActiveAudio) {
                        root.hasActiveAudio = false;
                        root.resetBars();
                    }
                    return;
                }

                root.hasActiveAudio = true;

                let parts = str.split(";");
                let count = Math.min(parts.length, root.barCount);
                let newLevels = new Array(root.barCount);
                for (let i = 0; i < root.barCount; i++) {
                    let val = i < count ? (parseInt(parts[i]) || 0) : 0;
                    newLevels[i] = Math.max(0.0, Math.min(1.0, val / 1000.0));
                }
                root.barLevels = newLevels;
            }
        }
    }
}
