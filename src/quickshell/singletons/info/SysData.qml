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
            fetchTimer.restart();
            fetchProc.running = true;
            root.resetNet();
            netTimer.restart();
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            fetchTimer.stop();
            fetchProc.running = false;
            netTimer.stop();
        }
    }

    function prewarm() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    // Live network throughput: sampled straight from /proc/net/dev every 1.5s
    // with millisecond timing, independent of the slower sys_fetcher cycle.
    property real lastNetRxBytes: -1
    property real lastNetTxBytes: -1
    property real lastNetSampleMs: 0

    function resetNet() {
        lastNetRxBytes = -1;
        lastNetTxBytes = -1;
        lastNetSampleMs = 0;
    }

    function sampleNet() {
        netDev.reload();
        let text = netDev.text();
        if (!text) return;

        let rx = 0, tx = 0;
        let lines = text.split("\n");
        for (let i = 2; i < lines.length; i++) {
            let line = lines[i];
            let colon = line.indexOf(":");
            if (colon < 0) continue;
            let iface = line.substring(0, colon).trim();
            if (!/^(e|w)/.test(iface)) continue;
            let f = line.substring(colon + 1).trim().split(/\s+/);
            rx += parseFloat(f[0]) || 0;
            tx += parseFloat(f[8]) || 0;
        }

        let now = Date.now();
        if (root.lastNetRxBytes >= 0 && now > root.lastNetSampleMs) {
            let dt = (now - root.lastNetSampleMs) / 1000;
            root.netRx = rx >= root.lastNetRxBytes ? (rx - root.lastNetRxBytes) / dt : 0;
            root.netTx = tx >= root.lastNetTxBytes ? (tx - root.lastNetTxBytes) / dt : 0;
        }
        root.lastNetRxBytes = rx;
        root.lastNetTxBytes = tx;
        root.lastNetSampleMs = now;
    }

    FileView {
        id: netDev
        path: "/proc/net/dev"
        blockLoading: true
    }

    Timer {
        id: netTimer
        interval: root.onBattery ? 3000 : 1500
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: root.sampleNet()
    }

    Timer {
        id: fetchTimer
        interval: root.onBattery ? 4000 : 2000
        repeat: true
        running: false
        onTriggered: {
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        running: false
        command: ["bash", "-c", "export QS_CACHE_SYSDATA='" + Caching.getCacheDir("sysdata") + "'; export QS_SCAN_NET=0; bash '" + Caching.qsDir + "/watchers/sys_fetcher.sh'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : "";
                if (!text) return;

                let p = text.split("|");
                if (p.length >= 4) {
                    root.cpu = parseInt(p[0]);
                    root.ramPercent = parseInt(p[1]);
                    root.ramGb = parseFloat(p[2]);
                    root.temp = parseInt(p[3]);
                }
                if (p.length >= 6 && !netTimer.running) {
                    root.netRx = parseFloat(p[4]);
                    root.netTx = parseFloat(p[5]);
                }
                if (p.length >= 9) {
                    root.diskPercent = parseInt(p[6]);
                    root.diskGb = parseFloat(p[7]);
                    root.diskTotalGb = parseFloat(p[8]);
                }
            }
        }
    }
}
