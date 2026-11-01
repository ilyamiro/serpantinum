pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    property bool isRecording: false
    property int recSeconds: 0
    property real recStartEpoch: 0
    readonly property string recTimeFormatted: String(Math.floor(recSeconds / 60)).padStart(2, "0") + ":" + String(recSeconds % 60).padStart(2, "0")
    readonly property string recCacheDir: Caching.cacheDir ? Caching.getCacheDir("recording") : ""

    property int subscribers: 0
    readonly property bool active: subscribers > 0 && recCacheDir !== ""

    function subscribe() {
        subscribers++;
        checkRecording();
    }

    function unsubscribe() {
        if (subscribers > 0) subscribers--;
    }

    function checkRecording() {
        if (!active) return;
        recCheckProc.running = false;
        recCheckProc.running = true;
    }

    onIsRecordingChanged: {
        if (!isRecording) {
            recSeconds = 0;
            recStartEpoch = 0;
        }
    }

    onActiveChanged: {
        if (active) {
            checkRecording();
        } else {
            recWatcherRestartTimer.stop();
            recCheckProc.running = false;
        }
    }

    Process {
        id: recCheckProc
        command: root.recCacheDir ? [
            "bash", "-c",
            "d='" + root.recCacheDir + "'; if [ -f \"$d/rec_pid\" ] && [ -f \"$d/rec_start_epoch\" ]; then p=$(cat \"$d/rec_pid\" 2>/dev/null); if [ -n \"$p\" ] && kill -0 \"$p\" 2>/dev/null; then cat \"$d/rec_start_epoch\" 2>/dev/null; else echo 'NONE'; fi; else echo 'NONE'; fi"
        ] : []
        stdout: StdioCollector {
            id: recCheckOut
            onStreamFinished: {
                let txt = recCheckOut.text.trim();
                let epoch = parseInt(txt);
                if (!isNaN(epoch) && epoch > 0) {
                    root.recStartEpoch = epoch;
                    root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
                    root.isRecording = true;
                } else {
                    root.isRecording = false;
                }
            }
        }
    }

    Process {
        id: recWatcher
        running: root.active
        command: root.recCacheDir ? [
            "bash", "-c",
            "mkdir -p '" + root.recCacheDir + "' && exec inotifywait -m -e create,delete,modify,moved_to,moved_from '" + root.recCacheDir + "' 2>/dev/null"
        ] : []
        stdout: SplitParser {
            onRead: data => {
                root.checkRecording();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 127) return;
            if (root.active) recWatcherRestartTimer.restart();
        }
    }

    Timer {
        id: recWatcherRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.active && !recWatcher.running) recWatcher.running = true;
        }
    }

    Timer {
        interval: 1000
        running: root.active && root.isRecording
        repeat: true
        onTriggered: {
            root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - root.recStartEpoch));
            if (root.recSeconds % 5 === 0) root.checkRecording();
        }
    }
}
