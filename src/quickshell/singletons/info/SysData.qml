pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"

Item {
    id: root

    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0
    property real netTx: 0
    property int diskPercent: 0
    property real diskGb: 0.0
    property real diskTotalGb: 0.0

    readonly property int historySize: 64
    property var historyUsers: ({})

    property int subscribers: 0
    readonly property bool onBattery: UPower.displayDevice.ready && UPower.displayDevice.state === UPowerDeviceState.Discharging

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            root.netPrimed = false;
            streamProc.running = true;
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            streamProc.running = false;
        }
    }

    property bool netPrimed: false

    function pushHistory(list, value) {
        let next = list.length >= root.historySize ? list.slice(1) : list.slice();
        next.push(isNaN(value) ? 0 : Number(value));
        return next;
    }

    function historyFor(interval) {
        for (let i = 0; i < historyTracks.count; i++) {
            let track = historyTracks.objectAt(i);
            if (track && track.interval === interval) return track;
        }
        return null;
    }

    function acquireHistory(interval) {
        let users = root.historyUsers[interval] || 0;
        if (users === 0) {
            let exists = false;
            for (let i = 0; i < historyModel.count; i++) {
                if (historyModel.get(i).interval === interval) exists = true;
            }
            if (!exists) historyModel.append({ interval: interval });
        }
        root.historyUsers[interval] = users + 1;
    }

    function releaseHistory(interval) {
        root.historyUsers[interval] = Math.max(0, (root.historyUsers[interval] || 0) - 1);
        if (root.historyUsers[interval] === 0) historyPruneTimer.restart();
    }

    ListModel {
        id: historyModel
    }

    Timer {
        id: historyPruneTimer
        interval: 3000
        onTriggered: {
            for (let i = historyModel.count - 1; i >= 0; i--) {
                let interval = historyModel.get(i).interval;
                if (!root.historyUsers[interval]) {
                    delete root.historyUsers[interval];
                    historyModel.remove(i);
                }
            }
        }
    }

    Instantiator {
        id: historyTracks
        model: historyModel

        delegate: QtObject {
            id: track
            required property int interval
            property var cpu: []
            property var ramPercent: []
            property var ramGb: []
            property var temp: []
            property bool legacy: false
            property bool answered: false

            function push(text) {
                let u;
                try {
                    u = JSON.parse(text);
                } catch (e) {
                    return;
                }
                track.answered = true;
                if (Array.isArray(u.cpu)) {
                    track.cpu = u.cpu;
                    track.ramPercent = u.ramPercent;
                    track.ramGb = u.ramGb;
                    track.temp = u.temp;
                    return;
                }
                track.cpu = root.pushHistory(track.cpu, u.cpu);
                track.ramPercent = root.pushHistory(track.ramPercent, u.ramPercent);
                track.ramGb = root.pushHistory(track.ramGb, u.ramGb);
                track.temp = root.pushHistory(track.temp, u.temp);
            }

            property Process proc: Process {
                running: true
                command: track.legacy
                    ? ["serpantinum-core", "watch", "sysinfo", "--interval", String(track.interval)]
                    : ["serpantinum-core", "watch", "history", "--interval", String(track.interval), "--count", String(root.historySize)]
                stdout: SplitParser {
                    onRead: data => track.push(data)
                }
                onExited: {
                    if (track.legacy || track.answered) return;
                    track.legacy = true;
                    running = true;
                }
            }
        }
    }

    function applyUsage(text, withNet) {
        text = text ? text.trim() : "";
        if (!text) return;

        let u;
        try {
            u = JSON.parse(text);
        } catch (e) {
            return;
        }
        root.cpu = u.cpu;
        root.ramPercent = u.ramPercent;
        root.ramGb = u.ramGb;
        root.temp = u.temp;
        if (withNet) {
            if (root.netPrimed) {
                root.netRx = u.netRx || 0;
                root.netTx = u.netTx || 0;
            }
            root.netPrimed = true;
        }
        root.diskPercent = u.diskPercent;
        root.diskGb = u.diskUsedGb;
        root.diskTotalGb = u.diskTotalGb;
    }

    function prewarm() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    // One long-running fetcher while anything is subscribed, printing a line per tick.
    property int streamInterval: root.onBattery ? 4 : 2
    onStreamIntervalChanged: {
        if (streamProc.running) {
            streamProc.running = false;
            streamProc.running = true;
        }
    }

    Process {
        id: streamProc
        running: false
        command: ["serpantinum-core", "watch", "sysinfo", "--interval", String(root.streamInterval)]
        stdout: SplitParser {
            onRead: data => root.applyUsage(data, true)
        }
    }

    Process {
        id: fetchProc
        running: false
        command: ["serpantinum-core", "sysinfo"]
        stdout: StdioCollector {
            onStreamFinished: root.applyUsage(this.text)
        }
    }
}
