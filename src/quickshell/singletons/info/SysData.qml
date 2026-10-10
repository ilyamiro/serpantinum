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
    property bool isScanningNet: false
    readonly property bool onBattery: UPower.displayDevice.ready && UPower.displayDevice.state === UPowerDeviceState.Discharging

    function subscribe() {
        subscribers++;
        if (subscribers === 1) streamProc.running = true;
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) streamProc.running = false;
    }

    // Parses one cpu|ram%|ramGB|temp|rx|tx|disk%|diskUsedGB|diskTotalGB line.
    function applyUsage(text, withNet) {
        text = text ? text.trim() : "";
        if (!text) return;

        let p = text.split("|");
        if (p.length >= 4) {
            root.cpu = parseInt(p[0]);
            root.ramPercent = parseInt(p[1]);
            root.ramGb = parseFloat(p[2]);
            root.temp = parseInt(p[3]);
        }
        if (withNet && p.length >= 6) {
            root.netRx = parseFloat(p[4]);
            root.netTx = parseFloat(p[5]);
        }
        if (p.length >= 9) {
            root.diskPercent = parseInt(p[6]);
            root.diskGb = parseFloat(p[7]);
            root.diskTotalGb = parseFloat(p[8]);
        }
    }

    function prewarm() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    function scanNetwork() {
        if (isScanningNet) return;
        isScanningNet = true;
        netScanProc.running = false;
        netScanProc.running = true;
    }

    // Samples are rewritten every tick, so they live on tmpfs rather than in ~/.cache.
    readonly property string stateDir: Caching.getRunDir("sysdata")

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
        command: ["bash", Caching.qsDir + "/watchers/sys_fetcher.sh", "--stream", String(root.streamInterval)]
        environment: ({ QS_RUN_SYSDATA: root.stateDir })
        stdout: SplitParser {
            onRead: data => root.applyUsage(data, false)
        }
    }

    Process {
        id: fetchProc
        running: false
        command: ["bash", Caching.qsDir + "/watchers/sys_fetcher.sh"]
        environment: ({ QS_RUN_SYSDATA: root.stateDir })
        stdout: StdioCollector {
            onStreamFinished: root.applyUsage(this.text, false)
        }
    }

    Process {
        id: netScanProc
        running: false
        command: ["bash", Caching.qsDir + "/watchers/sys_fetcher.sh"]
        environment: ({ QS_RUN_SYSDATA: root.stateDir })
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyUsage(this.text, true);
                root.isScanningNet = false;
            }
        }
    }
}
