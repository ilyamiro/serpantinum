pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string endpoint: "https://dots-telemetry.ilyamiro-work.workers.dev/ping"
    readonly property bool enabled: Config.dataReady && Config.getSetting("general.dailyPing", true) !== false
    property string lastPingDay: ""
    property bool stateLoaded: false
    property var pending: null

    function start() {
        startupTimer.start();
    }

    function tryPing() {
        if (!root.enabled || !root.stateLoaded) return;
        let day = new Date().toISOString().slice(0, 10);
        if (day === root.lastPingDay) return;
        if (root.pending) root.pending.abort();

        let xhr = new XMLHttpRequest();
        root.pending = xhr;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (root.pending !== xhr) return;
            root.pending = null;
            if (xhr.status >= 200 && xhr.status < 300) {
                root.lastPingDay = day;
                stateFile.setText(day);
            }
        };
        xhr.open("POST", root.endpoint);
        xhr.send();
    }

    Timer {
        id: startupTimer
        interval: 60 * 1000
        repeat: false
        onTriggered: {
            root.tryPing();
            hourlyTimer.start();
        }
    }

    Timer {
        id: hourlyTimer
        interval: 60 * 60 * 1000
        repeat: true
        onTriggered: root.tryPing()
    }

    FileView {
        id: stateFile
        path: Caching.getStateDir() + "/daily_ping"
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let raw = typeof stateFile.text === "function" ? stateFile.text() : stateFile.text;
            root.lastPingDay = raw ? raw.trim() : "";
            root.stateLoaded = true;
        }
        onLoadFailed: root.stateLoaded = true
    }
}
