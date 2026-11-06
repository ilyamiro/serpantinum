pragma Singleton
import QtQuick
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
