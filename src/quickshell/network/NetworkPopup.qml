import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function animWin(t, a, b) {
        if (t <= a) return 0.0;
        if (t >= b) return 1.0;
        return (t - a) / (b - a);
    }

    function easeOut(t) {
        let c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 - Math.pow(1.0 - c, 3);
    }

    function easeBack(t) {
        let c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 + 2.7 * Math.pow(c - 1.0, 3) + 1.7 * Math.pow(c - 1.0, 2);
    }

    Timer {
        id: btRebuildDebounce
        interval: 150
        repeat: false
        onTriggered: window.rebuildBtData(false)
    }

    function requestBtRebuild() {
        if (window.visible) btRebuildDebounce.restart();
    }

    function getBtDevicesList() {
        let adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.devices) return [];
        let devs = adapter.devices.values || adapter.devices;
        let list = [];
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (d) list.push(d);
        }
        return list;
    }

    function isEthDevice(dev) {
        return !!dev && dev.type === DeviceType.Wired;
    }

    function isWifiDevice(dev) {
        return !!dev && dev.type === DeviceType.Wifi;
    }

    function findDevices() {
        if (!Networking || !Networking.devices) return;
        let devs = Networking.devices.values || Networking.devices;
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (!d) continue;
            if (!window.ethDevice && window.isEthDevice(d)) {
                window.ethDevice = d;
            } else if (!window.wifiDevice && window.isWifiDevice(d)) {
                window.wifiDevice = d;
                window.startWifiScan();
            }
        }
    }

    function gotoTab(tabName) {
        if (!tabName) return;
        let t = String(tabName).toLowerCase();
        if (t === "wifi" || t === "wlan") t = "wifi";
        else if (t === "bt" || t === "bluetooth") t = "bt";
        else if (t === "eth" || t === "ethernet" || t === "wired") t = "eth";
        if (t === "wifi" && window.wifiPresent) window.activeMode = "wifi";
        else if (t === "bt" && window.btPresent) window.activeMode = "bt";
        else if (t === "eth" && window.ethPresent) window.activeMode = "eth";
    }

    property real introState: 0.0
    Behavior on introState {
        enabled: window.visible
        NumberAnimation { duration: 900; easing.type: Easing.Linear }
    }

    property int cardIntroDelay: 0
    property real exitOpacity: 1.0

    property var exitCallback: null

    function startExit(onFinished) {
        introPlayTimer.stop();
        window.exitCallback = onFinished;
        exitAnim.restart();
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        NumberAnimation {
            target: window
            property: "exitOpacity"
            to: 0.0
            duration: 85
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: {
                window.introState = 0.0;
                window.exitOpacity = 1.0;
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        window.exitOpacity = 1.0;
        window.powerAnimAllowed = false;
        powerAnimBlocker.restart();
        window.cardIntroDelay = 0;
        window.introState = 0.0;
        introPlayTimer.restart();
    }

    Timer {
        id: introPlayTimer
        interval: 10
        repeat: false
        onTriggered: window.introState = 1.0
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            modeFile.reload();
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
            window.startBtScan();
            window.startWifiScan();
            window.findDevices();
            window.rebuildEthData();
            window.rebuildWifiData();
            window.rebuildBtData(false);
            window.fetchIpData();
            window.fetchFreqData();
            window.fetchConnectivityData();
            if (window.activeMode === "bt" && !btProfilePoller.running) btProfilePoller.running = true;
        } else {
            exitAnim.stop();
            window.exitOpacity = 1.0;
            window.stopBtScan();
            window.stopWifiScan();
            btProfilePoller.running = false;
            ipFetcher.running = false;
            freqFetcher.running = false;
            btConnectSimTimer.stop();
            busyTimeout.stop();
            failClearTimer.stop();
            btRebuildDebounce.stop();
            powerMinSpinTimer.stop();
            introPlayTimer.stop();
            focusTimer.stop();
            mainPollerTimer.stop();
            window.pendingWifiId = "";
            window.pendingWifiSsid = "";
            window.pendingPairThenConnect = "";
            window.btOpsInFlight = ({});
            window.hoveredCardCount = 0;
            window.disconnectHoverCount = 0;
            window.introState = 0.0;
        }
    }

    Component.onDestruction: {
        window.stopBtScan();
        window.stopWifiScan();
    }

    property int disconnectHoverCount: 0
    readonly property bool isDisconnectHovered: disconnectHoverCount > 0

    Timer {
        id: btConnectSimTimer
        property string targetId: ""
        property int attemptId: 0
        interval: 5000
        onTriggered: {
            if (window.activeConnectId !== attemptId) return;
            let bt = window.busyTasks;
            if (bt[targetId]) {
                delete bt[targetId];
                window.busyTasks = Object.assign({}, bt);
                window.failedId = targetId;
                failClearTimer.restart();
                Sounds.playSfx("network/error.wav");
            }
            window.connectingId = "";
        }
    }

    Item {
        visible: false
        Connections {
            target: Bluetooth
            ignoreUnknownSignals: true
            function onDefaultAdapterChanged() {
                window.rebuildBtData(false);
            }
        }
        Connections {
            target: Bluetooth.defaultAdapter || null
            ignoreUnknownSignals: true
            function onEnabledChanged() {
                window.rebuildBtData(false);
            }
            function onDiscoveringChanged() {
                window.requestBtRebuild();
            }
        }
        Connections {
            target: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.devices) ? Bluetooth.defaultAdapter.devices : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) {
                window.requestBtRebuild();
            }
            function onObjectRemovedPost(object, index) {
                window.requestBtRebuild();
            }
        }
        Repeater {
            id: btDeviceRepeater
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
            Item {
                property var device: modelData
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onConnectedChanged() { window.requestBtRebuild(); }
                    function onBatteryChanged() { window.requestBtRebuild(); }
                    function onBatteryAvailableChanged() { window.requestBtRebuild(); }
                    function onStateChanged() { window.requestBtRebuild(); }
                    function onPairedChanged() { window.requestBtRebuild(); }
                    function onPairingChanged() { window.requestBtRebuild(); }
                    function onTrustedChanged() { window.requestBtRebuild(); }
                    function onNameChanged() { window.requestBtRebuild(); }
                    function onDeviceNameChanged() { window.requestBtRebuild(); }
                }
            }
        }
    }

    property var ethDevice: null
    property var wifiDevice: null

    Item {
        visible: false
        Connections {
            target: Networking
            enabled: window.visible
            ignoreUnknownSignals: true
            function onWifiEnabledChanged() { window.rebuildWifiData(); }
            function onDevicesChanged() {
                window.findDevices();
                window.rebuildEthData();
                window.rebuildWifiData();
            }
        }
        Repeater {
            id: netDeviceRepeater
            model: window.visible ? Networking.devices : null
            Item {
                property var device: modelData

                function syncDevice() {
                    if (!device) return;
                    if (window.isEthDevice(device)) {
                        window.ethDevice = device;
                    } else if (window.isWifiDevice(device)) {
                        window.wifiDevice = device;
                        window.startWifiScan();
                    }
                    window.rebuildEthData();
                    window.rebuildWifiData();
                }

                onDeviceChanged: syncDevice()
                Component.onCompleted: syncDevice()

                Connections {
                    target: device || null
                    enabled: window.visible
                    ignoreUnknownSignals: true
                    function onStateChanged() { window.isEthDevice(device) ? window.rebuildEthData() : window.rebuildWifiData(); }
                    function onConnectedChanged() { window.isEthDevice(device) ? window.rebuildEthData() : window.rebuildWifiData(); }
                }
                Connections {
                    target: (device && window.isEthDevice(device)) ? device : null
                    enabled: window.visible
                    ignoreUnknownSignals: true
                    function onHasLinkChanged() { window.rebuildEthData(); }
                    function onLinkSpeedChanged() { window.rebuildEthData(); }
                }
            }
        }
        Repeater {
            id: wifiNetworkRepeater
            model: (window.visible && window.wifiDevice) ? window.wifiDevice.networks : null
            Item {
                property var network: modelData
                Connections {
                    target: network || null
                    enabled: window.visible
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { window.rebuildWifiData(); }
                    function onStateChanged() { window.rebuildWifiData(); }
                    function onConnectedChanged() { window.rebuildWifiData(); }
                    function onKnownChanged() { window.rebuildWifiData(); }
                    function onConnectionFailed(reason) {
                        window.failedId = network.name || "";
                        failClearTimer.restart();
                        Sounds.playSfx("network/error.wav");
                        let bt = window.busyTasks;
                        if (network.name) delete bt[network.name];
                        window.busyTasks = Object.assign({}, bt);
                        window.connectingId = "";
                    }
                }
            }
        }
    }

    property string fetchedEthIp: ""
    property string fetchedWifiIp: ""
    property string fetchedWifiFreq: ""
    property string lastFetchedEthMac: ""
    property string lastFetchedWifiSsid: ""
    property string wifiDeviceName: ""
    property string connectivityState: "unknown"
    readonly property string wifiConnectedSsid: window.isWifiConn ? (window.wifiConnected.ssid || "") : ""
    readonly property string portalProbeUrl: "http://nmcheck.gnome.org/check_network_status.txt"

    onWifiConnectedSsidChanged: {
        window.connectivityState = "unknown";
        window.fetchConnectivityData();
    }

    Process {
        id: connectivityFetcher
        command: ["sh", "-c", "command -v nmcli >/dev/null 2>&1 && nmcli -t -g CONNECTIVITY general"]
        stdout: StdioCollector {
            onStreamFinished: {
                let state = this.text.trim() || "unknown";
                if (state === window.connectivityState) return;
                window.connectivityState = state;
                if (window.activeMode === "wifi" && window.isWifiConn) window.updateInfoNodes();
            }
        }
    }

    Process {
        id: ipFetcher
        command: ["ip", "-4", "-j", "addr", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    let eIp = ""; let wIp = "";
                    for (let i = 0; i < data.length; i++) {
                        let iface = data[i];
                        if (iface.ifname === window.ethDeviceName && iface.addr_info && iface.addr_info.length > 0) {
                            eIp = iface.addr_info[0].local || "";
                        }
                        if (iface.ifname === window.wifiDeviceName && iface.addr_info && iface.addr_info.length > 0) {
                            wIp = iface.addr_info[0].local || "";
                        }
                    }
                    window.fetchedEthIp = eIp;
                    window.fetchedWifiIp = wIp;
                    if (window.ethDeviceName !== "") window.rebuildEthData();
                    if (window.wifiDeviceName !== "") window.rebuildWifiData();
                } catch(e) {}
            }
        }
    }

    Process {
        id: freqFetcher
        command: window.wifiDeviceName !== "" ? ["iw", "dev", window.wifiDeviceName, "link"] : ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split('\n');
                let f = "";
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.indexOf("freq:") === 0) {
                        f = line.substring(5).trim();
                        break;
                    }
                }
                window.fetchedWifiFreq = f;
                if (window.wifiDeviceName !== "") window.rebuildWifiData();
            }
        }
    }

    function fetchIpData() { if (window.visible) ipFetcher.running = true; }
    function fetchConnectivityData() { if (window.visible && window.isWifiConn) connectivityFetcher.running = true; }
    function fetchFreqData() { if (window.visible && window.wifiDeviceName !== "") freqFetcher.running = true; }

    Timer {
        interval: 5000
        running: window.visible && (window.isEthConn || window.isWifiConn)
        repeat: true
        onTriggered: {
            if (window.isEthConn || window.isWifiConn) window.fetchIpData();
            if (window.isWifiConn) window.fetchFreqData();
            if (window.isWifiConn && window.connectivityState !== "full") window.fetchConnectivityData();
        }
    }

    function startBtScan() {
        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = true;
    }

    function stopBtScan() {
        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false;
    }

    function startWifiScan() {
        if (window.wifiDevice && window.visible && window.activeMode === "wifi" && window.wifiPower === "on") {
            window.wifiDevice.scannerEnabled = true;
        }
    }

    function stopWifiScan() {
        if (window.wifiDevice) {
            window.wifiDevice.scannerEnabled = false;
        }
    }

    function s(val) { return Scaler.s(val); }

    function deepEqual(a, b) {
        if (a === b) return true;
        if (!a || !b || typeof a !== "object" || typeof b !== "object") return false;
        if (Array.isArray(a) !== Array.isArray(b)) return false;
        let ak = Object.keys(a), bk = Object.keys(b);
        if (ak.length !== bk.length) return false;
        for (let k of ak) {
            if (!deepEqual(a[k], b[k])) return false;
        }
        return true;
    }

    function shEsc(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'";
    }

    readonly property string cacheDir: Caching.getCacheDir("network")
    readonly property string modeFilePath: cacheDir + "/mode"

    Shortcut {
        sequence: "Tab"
        enabled: window.visible
        onActivated: {
            if (window.pendingWifiId !== "") {
                window.pendingWifiId = ""; window.pendingWifiSsid = "";
                return;
            }
            Sounds.playSfx("network/switch.wav");
            let modes = [];
            if (window.ethPresent) modes.push("eth");
            if (window.wifiPresent) modes.push("wifi");
            if (window.btPresent) modes.push("bt");
            if (modes.length > 1) {
                let idx = modes.indexOf(window.activeMode);
                let nextMode = modes[(idx + 1) % modes.length];
                if (nextMode && window.activeMode !== nextMode) {
                    window.powerAnimAllowed = false;
                    powerAnimBlocker.restart();
                    window.activeMode = nextMode;
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (window.pendingWifiId !== "") {
            window.pendingWifiId = "";
            window.pendingWifiSsid = "";
            event.accepted = true;
        }
    }

    QtObject {
        id: cache
        property string lastWifiSsid: ""
        property string lastBtJson: ""
    }

    property var btDeviceMap: ({})
    property var btAudioProfiles: ({})

    property bool ethPresent: false
    property bool wifiPresent: false
    property bool btPresent: false

    property int btMissCount: 0
    property bool btFirstLoad: true

    property bool powerAnimAllowed: false
    Timer { id: powerAnimBlocker; interval: 250; running: true; onTriggered: window.powerAnimAllowed = true }

    Timer {
        id: firstLoadFailsafe
        interval: 1500
        running: true
        onTriggered: {
            if (window.btFirstLoad) {
                window.btFirstLoad = false;
                window.validateActiveMode();
            }
        }
    }

    property bool isValidatingMode: false
    function validateActiveMode() {
        if (window.btFirstLoad) return;
        if (isValidatingMode) return;
        isValidatingMode = true;

        let validModes = [];
        if (window.ethPresent) validModes.push("eth");
        if (window.wifiPresent) validModes.push("wifi");
        if (window.btPresent) validModes.push("bt");

        if (validModes.length > 0 && validModes.indexOf(window.activeMode) === -1) {
            window.powerAnimAllowed = false;
            powerAnimBlocker.restart();
            window.activeMode = validModes[0];
        }

        isValidatingMode = false;
    }

    property bool ignoreNextModeFileUpdate: false

    FileView {
        id: modeFile
        path: window.modeFilePath
        watchChanges: window.visible
        onFileChanged: reload()
        onLoaded: {
            let mode = text().trim();
            if ((mode === "wifi" || mode === "bt" || mode === "eth") && window.activeMode !== mode) {
                if ((mode === "eth" && window.ethPresent) ||
                    (mode === "wifi" && window.wifiPresent) ||
                    (mode === "bt" && window.btPresent)) {
                    window.powerAnimAllowed = false;
                    powerAnimBlocker.restart();
                    window.ignoreNextModeFileUpdate = true;
                    window.activeMode = mode;
                }
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + window.cacheDir + "'; if [ ! -f '" + window.modeFilePath + "' ]; then echo '" + activeMode + "' > '" + window.modeFilePath + "'; fi"]);

        window.findDevices();
        window.rebuildEthData();
        window.rebuildWifiData();

        let hasCache = false;
        if (cache.lastBtJson !== "") { window.rebuildBtData(true); hasCache = true; }

        if (hasCache) {
            let validModes = [];
            if (window.ethPresent) validModes.push("eth");
            if (window.wifiPresent) validModes.push("wifi");
            if (window.btPresent) validModes.push("bt");

            if (validModes.length > 0 && validModes.indexOf(window.activeMode) === -1) {
                window.activeMode = validModes[0];
            }
        }

        window.validateActiveMode();
        window.refreshOrbitDisplay();

        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
            window.startBtScan();
            window.startWifiScan();
        }
    }

    readonly property string scriptsDir: Caching.qsDir + "/network"

    readonly property color sharedAccent: Qt.lighter(ThemeBackend.sapphire, 1.15)
    readonly property color btAccent: ThemeBackend.mauve

    property string activeMode: "wifi"
    readonly property color activeColor: activeMode === "bt" ? window.btAccent : window.sharedAccent
    readonly property color activeGradientSecondary: Qt.darker(window.activeColor, 1.25)

    property var busyTasks: ({})
    property var disconnectingDevices: ({})
    property string connectingId: ""
    property string failedId: ""

    property var btOpsInFlight: ({})
    property string pendingPairThenConnect: ""

    function isBtOpBusy(mac) {
        return !!window.btOpsInFlight[mac] || (btConnector.running && btConnector.targetMac === mac);
    }

    function withBtOpLock(mac, fn) {
        if (!mac || window.isBtOpBusy(mac)) return false;

        let ops = window.btOpsInFlight;
        ops[mac] = true;
        window.btOpsInFlight = Object.assign({}, ops);

        Qt.callLater(function() {
            try {
                fn();
            } catch (e) {
                console.warn("BT op failed for", mac, e);
            } finally {
                let o = window.btOpsInFlight;
                delete o[mac];
                window.btOpsInFlight = Object.assign({}, o);
            }
        });
        return true;
    }

    Timer { id: busyTimeout; interval: 15000; onTriggered: { if (btConnector.running) { restart(); return; } window.busyTasks = ({}); window.disconnectingDevices = ({}); window.connectingId = ""; } }
    Timer { id: failClearTimer; interval: 4000; onTriggered: window.failedId = "" }

    Timer { id: ethPendingReset; interval: 8000; onTriggered: { window.ethPowerPending = false; window.expectedEthPower = ""; } }
    Timer { id: wifiPendingReset; interval: 8000; onTriggered: { window.wifiPowerPending = false; window.expectedWifiPower = ""; } }
    Timer { id: btPendingReset; interval: 8000; onTriggered: { window.btPowerPending = false; window.expectedBtPower = ""; } }
    Timer { id: powerMinSpinTimer; interval: 800; onTriggered: { if (window.activeMode === "eth") window.rebuildEthData(); else if (window.activeMode === "wifi") window.rebuildWifiData(); else window.rebuildBtData(false); } }

    property bool showInfoView: false
    onShowInfoViewChanged: {
        window.hoveredCardCount = 0;
        if (window.showInfoView) {
            window.updateInfoNodes();
        }
        window.refreshOrbitDisplay();
    }

    property string pendingWifiSsid: ""
    property string pendingWifiId: ""

    property int activeConnectId: 0

    function connectDevice(mode, id, macOrSsid, password) {
        if (mode === "bt" && btConnector.running) return;
        window.activeConnectId++;
        window.connectingId = id || "";
        window.failedId = "";
        let bt = window.busyTasks;
        if (id) bt[id] = true;
        window.busyTasks = Object.assign({}, bt);
        busyTimeout.restart();

        if (mode === "eth") {
            if (window.ethDevice && window.ethDevice.network) {
                window.ethDevice.network.connect();
            }
        } else if (mode === "wifi") {
            if (window.wifiDevice && window.wifiDevice.networks) {
                let targetNet = null;
                let nets = window.wifiDevice.networks.values;
                for (let i = 0; i < nets.length; i++) {
                    let net = nets[i];
                    if (net && net.name === macOrSsid) { targetNet = net; break; }
                }
                if (targetNet) {
                    if (password && password !== "") targetNet.connectWithPsk(password);
                    else targetNet.connect();
                }
            }
        } else {
            window.stopBtScan();
            let mac = macOrSsid;
            if (window.isBtOpBusy(mac)) return;

            let devList = window.getBtDevicesList();
            let d = devList.find(function(dev) { return dev && dev.address === mac; });
            if (!d || d.pairing || d.state === BluetoothDeviceState.Connecting) {
                let tasks = Object.assign({}, window.busyTasks);
                delete tasks[id];
                window.busyTasks = tasks;
                window.connectingId = "";
                return;
            }
            btConnector.targetMac = mac;
            btConnector.targetId = id || mac;
            btConnector.result = ({});
            btConnector.command = ["python3", window.scriptsDir + "/bluetooth_connect.py", mac];
            btConnector.running = true;
        }
    }

    property var currentCores: [null, null, null, null, null]
    property var coreVisualIndices: [0, 0, 0, 0, 0]
    property int activeCoreCount: 0
    property real smoothedActiveCoreCount: activeCoreCount
    Behavior on smoothedActiveCoreCount { enabled: window.visible; NumberAnimation { duration: 1000; easing.type: Easing.InOutExpo } }

    function syncCores() {
        let list = [];
        if (activeMode === "eth") {
            list = window.ethConnected ? [window.ethConnected] : [];
        } else if (activeMode === "wifi") {
            let wValid = !!window.wifiConnected && window.wifiConnected.ssid !== undefined;
            list = wValid ? [window.wifiConnected] : [];
        } else {
            list = window.btConnected || [];
        }

        if (!currentPower) list = [];
        else if (!Array.isArray(list)) list = [list];

        let newCores = [window.currentCores[0], window.currentCores[1], window.currentCores[2], window.currentCores[3], window.currentCores[4]];
        let found = [false, false, false, false, false];

        for (let i = 0; i < list.length && i < 5; i++) {
            let dev = list[i];
            if (!dev) continue;
            let id = activeMode === "wifi" ? dev.ssid : (activeMode === "eth" ? dev.id : dev.mac);
            if (!id) continue;
            for (let c = 0; c < 5; c++) {
                if (newCores[c]) {
                    let cId = activeMode === "wifi" ? newCores[c].ssid : (activeMode === "eth" ? newCores[c].id : newCores[c].mac);
                    if (cId === id) { found[c] = true; newCores[c] = dev; break; }
                }
            }
        }

        for (let c = 0; c < 5; c++) { if (!found[c]) newCores[c] = null; }

        for (let i = 0; i < list.length && i < 5; i++) {
            let dev = list[i];
            if (!dev) continue;
            let id = activeMode === "wifi" ? dev.ssid : (activeMode === "eth" ? dev.id : dev.mac);
            if (!id) continue;
            let isFound = false;
            for (let c = 0; c < 5; c++) {
                if (newCores[c]) {
                    let cId = activeMode === "wifi" ? newCores[c].ssid : (activeMode === "eth" ? newCores[c].id : newCores[c].mac);
                    if (cId === id) { isFound = true; break; }
                }
            }
            if (!isFound) {
                for (let c = 0; c < 5; c++) {
                    if (!newCores[c]) { newCores[c] = dev; break; }
                }
            }
        }

        window.currentCores = [...newCores];

        let activeCount = 0;
        let newVis = [0, 0, 0, 0, 0];
        for (let c = 0; c < 5; c++) {
            if (newCores[c]) {
                newVis[c] = activeCount;
                activeCount++;
            }
        }
        window.coreVisualIndices = newVis;
        window.activeCoreCount = activeCount;
    }

    onCurrentConnChanged: {
        showInfoView = currentConn;
        if (currentConn) updateInfoNodes();
    }

    onActiveModeChanged: {
        window.cardIntroDelay = 0;
        if (!window.ignoreNextModeFileUpdate) {
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + window.cacheDir + "' && echo '" + window.activeMode + "' > '" + window.modeFilePath + "'"]);
        }
        window.ignoreNextModeFileUpdate = false;

        window.hoveredCardCount = 0;
        window.disconnectHoverCount = 0;
        window.nextWifiList = null;
        window.nextBtList = null;
        window.nextInfoList = null;

        window.pendingWifiId = ""; window.pendingWifiSsid = "";
        if (window.activeMode === "bt" && window.visible && !btProfilePoller.running) btProfilePoller.running = true;

        infoListModel.clear();
        window.busyTasks = ({});
        window.disconnectingDevices = ({});
        window.currentCores = [null, null, null, null, null];
        window.coreVisualIndices = [0, 0, 0, 0, 0];
        window.activeCoreCount = 0;
        syncCores();
        window.showInfoView = window.currentConn;

        if (window.activeMode === "wifi") {
            window.startWifiScan();
            window.rebuildWifiData();
        } else if (window.activeMode === "bt") {
            window.stopWifiScan();
            window.rebuildBtData(false);
        } else if (window.activeMode === "eth") {
            window.stopWifiScan();
            window.rebuildEthData();
        }

        if (window.showInfoView) window.updateInfoNodes();
        window.refreshOrbitDisplay();
    }

    ListModel { id: wifiListModel }
    ListModel { id: btListModel }
    ListModel { id: infoListModel }
    ListModel { id: orbitDisplayModel }

    function refreshOrbitDisplay() {
        let src = (window.currentConn && window.showInfoView) ? infoListModel : (window.activeMode === "wifi" ? wifiListModel : (window.activeMode === "bt" ? btListModel : null));
        let arr = [];
        if (src) {
            for (let i = 0; i < src.count; i++) arr.push(src.get(i));
        }
        window.syncModel(orbitDisplayModel, arr);
    }

    function syncModel(listModel, dataArray) {
        if (!listModel || !dataArray) return;
        for (let i = listModel.count - 1; i >= 0; i--) {
            let item = listModel.get(i);
            let id = item ? item.id : null;
            let found = false;
            if (id !== null && id !== undefined) {
                for (let j = 0; j < dataArray.length; j++) {
                    if (id === dataArray[j].id) { found = true; break; }
                }
            }
            if (!found) { listModel.remove(i); }
        }

        for (let i = 0; i < dataArray.length && i < 30; i++) {
            let d = dataArray[i];
            if (!d) continue;
            let foundIdx = -1;
            for (let j = 0; j < listModel.count; j++) {
                let mItem = listModel.get(j);
                if (mItem && mItem.id === d.id) { foundIdx = j; break; }
            }

            let obj = {
                id: d.id || "", ssid: d.ssid || "", mac: d.mac || "",
                name: d.name || d.ssid || "", icon: d.icon || "", security: d.security || "", action: d.action || "",
                isInfoNode: d.isInfoNode || false, isActionable: d.isActionable !== undefined ? d.isActionable : true,
                cmdStr: d.cmdStr || "", parentIndex: d.parentIndex !== undefined ? d.parentIndex : -1
            };

            if (foundIdx === -1) {
                listModel.insert(i, obj);
            } else {
                if (foundIdx !== i) { listModel.move(foundIdx, i, 1); }
                let currentModelItem = listModel.get(i);
                if (currentModelItem) {
                    for (let key in obj) {
                        if (currentModelItem[key] !== obj[key]) {
                            listModel.setProperty(i, key, obj[key]);
                        }
                    }
                }
            }
        }
    }

    property int hoveredCardCount: 0
    readonly property bool isListLocked: hoveredCardCount > 0
    property var nextWifiList: null
    property var nextBtList: null
    property var nextInfoList: null

    onIsListLockedChanged: {
        if (!isListLocked) {
            if (nextWifiList !== null) { window.syncModel(wifiListModel, nextWifiList); window.wifiList = nextWifiList; nextWifiList = null; }
            if (nextBtList !== null) { window.syncModel(btListModel, nextBtList); window.btList = nextBtList; nextBtList = null; }
            if (nextInfoList !== null) { window.syncModel(infoListModel, nextInfoList); nextInfoList = null; }
            window.refreshOrbitDisplay();
        }
    }

    property string ethDeviceName: ""
    property bool ethPowerPending: false
    property string expectedEthPower: ""
    property string ethPower: "off"
    property var ethConnected: null
    readonly property bool isEthConn: !!window.ethConnected

    onEthConnectedChanged: { syncCores(); if (window.currentConn && window.activeMode === "eth") updateInfoNodes(); }

    property bool wifiPowerPending: false
    property string expectedWifiPower: ""
    property string wifiPower: "off"
    property var wifiConnected: null
    property var wifiList: []
    property string strongestWifiSsid: ""
    readonly property bool isWifiConn: !!window.wifiConnected && window.wifiConnected.ssid !== undefined

    readonly property string targetWifiSsid: {
        let found = false;
        if (cache.lastWifiSsid !== "") {
            for (let i = 0; i < wifiList.length; i++) {
                if (wifiList[i] && wifiList[i].id === cache.lastWifiSsid) { found = true; break; }
            }
        }
        return found ? cache.lastWifiSsid : strongestWifiSsid;
    }

    onWifiConnectedChanged: {
        if (window.wifiConnected && window.wifiConnected.ssid) { cache.lastWifiSsid = window.wifiConnected.ssid; }
        syncCores();
        if (window.currentConn && window.activeMode === "wifi") updateInfoNodes();
    }

    property bool btPowerPending: false
    property string expectedBtPower: ""
    property string btPower: "off"
    property var btConnected: []
    property var btList: []
    readonly property bool isBtConn: window.btConnected.length > 0

    onBtConnectedChanged: {
        syncCores();
        if (window.currentConn && window.activeMode === "bt") updateInfoNodes();
    }

    readonly property bool currentPower: activeMode === "eth" ? window.ethPower === "on" : (activeMode === "wifi" ? window.wifiPower === "on" : window.btPower === "on")
    onCurrentPowerChanged: { syncCores(); }

    readonly property bool currentPowerPending: activeMode === "eth" ? window.ethPowerPending : (activeMode === "wifi" ? window.wifiPowerPending : window.btPowerPending)
    readonly property bool currentConn: activeMode === "eth" ? window.isEthConn : (activeMode === "wifi" ? window.isWifiConn : window.isBtConn)

    readonly property var currentObjList: activeMode === "eth" ? (window.isEthConn ? [window.ethConnected] : []) : (activeMode === "wifi" ? (window.isWifiConn ? [window.wifiConnected] : []) : window.btConnected)

    readonly property string orbitSourceKey: (window.currentConn && window.showInfoView)
        ? ("info_" + window.activeMode)
        : (window.activeMode === "wifi" ? "wifi" : (window.activeMode === "bt" ? "bt" : (window.activeMode === "eth" ? "eth" : "none")))
    onOrbitSourceKeyChanged: {
        window.hoveredCardCount = 0;
        window.refreshOrbitDisplay();
    }

    readonly property bool isLogicMultiState: window.activeMode === "bt" && window.activeCoreCount > 1

    property real multiTransitionState: (isLogicMultiState && window.currentPower) ? 1.0 : 0.0
    Behavior on multiTransitionState { enabled: window.visible; NumberAnimation { duration: 1200; easing.type: Easing.InOutExpo } }

    function updateInfoNodes() {
        let nodes = [];
        let cList = [];

        if (window.activeMode === "eth") {
            cList = window.ethConnected ? [window.ethConnected] : [];
        } else if (window.activeMode === "wifi") {
            let wConn = window.wifiConnected;
            if (Array.isArray(wConn)) wConn = wConn[0];
            cList = (!!wConn && wConn.ssid !== undefined) ? [wConn] : [];
        } else {
            cList = window.btConnected || [];
        }

        if (window.currentConn && cList.length > 0) {
            for (let i = 0; i < cList.length; i++) {
                let obj = cList[i];
                if (!obj) continue;
                let cIndex = 0;

                if (window.activeMode === "bt" && obj.mac) {
                    for (let c = 0; c < 5; c++) {
                        if (window.currentCores[c] && window.currentCores[c].mac === obj.mac) { cIndex = c; break; }
                    }
                }

                if (window.activeMode === "eth") {
                    nodes.push({ id: "ip", name: obj.ip || I18n.t("network.status.no_ip") || "No IP", icon: "󰩟", action: "", isInfoNode: true, isActionable: true, cmdStr: "printf '%s' " + window.shEsc(obj.ip || "") + " | wl-copy", parentIndex: cIndex });
                    nodes.push({ id: "spd", name: obj.speed || I18n.t("network.status.unknown") || "Unknown", icon: "󰓅", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    nodes.push({ id: "mac", name: obj.mac || I18n.t("network.status.unknown") || "Unknown", icon: "󰒋", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                } else if (window.activeMode === "wifi") {
                    let sigValue = obj.signal !== undefined ? obj.signal + "%" : (I18n.t("network.status.calculating") || "Calculating...");
                    nodes.push({ id: "sig_" + i, name: sigValue, icon: obj.icon || "󰤨", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    nodes.push({ id: "sec_" + i, name: obj.security || I18n.t("network.status.open") || "Open", icon: "󰦝", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    if (obj.ip) nodes.push({ id: "ip_" + i, name: obj.ip, icon: "󰩟", action: "", isInfoNode: true, isActionable: true, cmdStr: "printf '%s' " + window.shEsc(obj.ip) + " | wl-copy", parentIndex: cIndex });
                    if (obj.freq) nodes.push({ id: "freq_" + i, name: obj.freq, icon: "󰖧", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    if (window.connectivityState === "portal") nodes.push({ id: "action_portal", name: I18n.t("network.actions.sign_in") || "Sign in", icon: "󰖟", action: "", isInfoNode: true, isActionable: true, cmdStr: "command -v xdg-open >/dev/null 2>&1 && xdg-open " + window.shEsc(window.portalProbeUrl), parentIndex: cIndex });
                } else if (obj.mac) {
                    nodes.push({ id: "bat_" + obj.mac, name: (obj.battery || "0") + "%", icon: "󰥉", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    if (obj.profile) {
                        nodes.push({ id: "prof_" + obj.mac, name: obj.profile, icon: (obj.profile === "Hi-Fi (A2DP)" ? "󰓃" : "󰋎"), action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    }
                    nodes.push({ id: "mac_" + obj.mac, name: obj.mac || I18n.t("network.status.unknown") || "Unknown", icon: "󰒋", action: "", isInfoNode: true, isActionable: false, parentIndex: cIndex });
                    nodes.push({ id: "forget_" + obj.mac, name: I18n.t("network.actions.unpair") || "Unpair", icon: "󰆴", action: "", isInfoNode: true, isActionable: true, cmdStr: "BT_FORGET_" + obj.mac, parentIndex: cIndex });
                }
            }
            if (window.activeMode !== "eth") {
                nodes.push({ id: "action_scan", name: I18n.t("network.actions.scan") || "Scan", icon: "󰍉", action: "", isInfoNode: true, isActionable: true, cmdStr: "TOGGLE_VIEW", parentIndex: -1 });
            }
        }

        if (window.isListLocked && window.activeMode !== "eth") window.nextInfoList = nodes;
        else { window.syncModel(infoListModel, nodes); window.nextInfoList = null; window.refreshOrbitDisplay(); }
    }

    function rebuildEthData() {
        if (!window.ethDevice) window.findDevices();
        let hasEth = !!window.ethDevice && (window.ethDevice.hasLink || window.ethDevice.connected);
        window.ethPresent = hasEth;
        if (!window.ethPresent) {
            window.ethConnected = null;
            window.validateActiveMode();
            return;
        }

        window.ethDeviceName = (window.ethDevice && (window.ethDevice.name || window.ethDevice.interfaceName || window.ethDevice.interface)) ? (window.ethDevice.name || window.ethDevice.interfaceName || window.ethDevice.interface) : "";
        let fetchedPower = (window.ethDevice.hasLink || window.ethDevice.connected) ? "on" : "off";

        if (window.ethPowerPending) {
            window.ethPower = window.expectedEthPower;
            if (fetchedPower === window.expectedEthPower && !powerMinSpinTimer.running) {
                window.ethPowerPending = false;
                ethPendingReset.stop();
            }
        } else {
            window.ethPower = fetchedPower;
            window.expectedEthPower = "";
        }

        let newConnected = null;
        if (window.ethDevice.connected) {
            if (window.lastFetchedEthMac !== window.ethDevice.address) {
                window.lastFetchedEthMac = window.ethDevice.address || "";
                window.fetchIpData();
            }
            newConnected = {
                id: window.ethDeviceName,
                mac: window.ethDevice.address || "",
                speed: window.ethDevice.linkSpeed ? window.ethDevice.linkSpeed.toString() + " Mbps" : "",
                ip: window.fetchedEthIp
            };
        } else {
            window.lastFetchedEthMac = "";
        }

        if (!window.deepEqual(window.ethConnected, newConnected)) {
            if (!window.isEthConn && newConnected && window.activeMode === "eth") Sounds.playSfx("network/connect.wav");
            window.ethConnected = newConnected;
        }

        if (window.activeMode === "eth") {
            let dd = window.disconnectingDevices;
            let ddChanged = false;
            for (let devId in dd) {
                if (!newConnected || newConnected.id !== devId) {
                    delete dd[devId];
                    ddChanged = true;
                }
            }
            if (ddChanged) {
                window.disconnectingDevices = Object.assign({}, dd);
                if (Object.keys(window.disconnectingDevices).length === 0 && Object.keys(window.busyTasks).length === 0) busyTimeout.stop();
            }
        }
        window.validateActiveMode();
    }

    function rebuildWifiData() {
        if (!window.wifiDevice) window.findDevices();
        window.wifiPresent = !!window.wifiDevice;
        if (!window.wifiPresent) { window.wifiConnected = null; window.validateActiveMode(); return; }

        window.wifiDeviceName = (window.wifiDevice && (window.wifiDevice.name || window.wifiDevice.interfaceName || window.wifiDevice.interface)) ? (window.wifiDevice.name || window.wifiDevice.interfaceName || window.wifiDevice.interface) : "";
        let fetchedPower = Networking.wifiEnabled ? "on" : "off";

        if (window.wifiPowerPending) {
            window.wifiPower = window.expectedWifiPower;
            if (fetchedPower === window.expectedWifiPower && !powerMinSpinTimer.running) {
                window.wifiPowerPending = false;
                wifiPendingReset.stop();
            }
        } else {
            window.wifiPower = fetchedPower;
            window.expectedWifiPower = "";
        }

        let newConnected = null;
        let newNetworks = [];
        let maxSig = -1;
        let bestSsid = "";

        if (window.wifiDevice && window.wifiDevice.networks) {
            let nets = window.wifiDevice.networks.values;
            for (let i = 0; i < nets.length; i++) {
                let net = nets[i];
                if (!net || !net.name) continue;

                let secStr = "Open";
                if (net.security === 1) secStr = "WEP";
                else if (net.security === 2) secStr = "WPA";
                else if (net.security === 3) secStr = "WPA2";
                else if (net.security === 4) secStr = "WPA3";
                else if (net.security === 5) secStr = "WPA2/WPA3";
                else if (net.security === 6) secStr = "Enterprise";
                else if (net.security === 7) secStr = "OWE";
                else if (net.security > 0) secStr = "Secure";

                let sig = net.signalStrength !== undefined ? Math.round(net.signalStrength * 100) : 0;
                if (sig > maxSig) { maxSig = sig; bestSsid = net.name; }

                let nObj = {
                    id: net.name,
                    ssid: net.name,
                    mac: "",
                    name: net.name,
                    icon: "󰤨",
                    security: secStr,
                    signal: sig.toString(),
                    action: net.known ? "" : "Connect",
                    isActionable: true
                };

                if (net.connected) {
                    if (window.lastFetchedWifiSsid !== net.name) {
                        window.lastFetchedWifiSsid = net.name;
                        window.fetchIpData();
                        window.fetchFreqData();
                    }
                    nObj.ip = window.fetchedWifiIp;
                    nObj.freq = window.fetchedWifiFreq;
                    newConnected = nObj;
                } else {
                    newNetworks.push(nObj);
                }
            }
        }

        if (!newConnected) window.lastFetchedWifiSsid = "";
        window.strongestWifiSsid = bestSsid;

        let isNowWifiConn = !!newConnected;
        let wasWifiConn = !!window.wifiConnected;

        if (!window.deepEqual(window.wifiConnected, newConnected)) {
            window.wifiConnected = newConnected;
        }

        newNetworks.sort((a, b) => (a && b && a.id && b.id) ? a.id.localeCompare(b.id) : 0);

        if (isNowWifiConn && window.activeMode === "wifi") {
            newNetworks.push({ id: "action_settings", ssid: I18n.t("network.status.current_device") || "Current Device", mac: "", name: I18n.t("network.status.current_device") || "Current Device", icon: "󰒓", action: "", isInfoNode: false, isActionable: true, cmdStr: "TOGGLE_VIEW", parentIndex: -1 });
        }

        if (!window.deepEqual(window.wifiList, newNetworks)) {
            if (window.isListLocked) window.nextWifiList = newNetworks;
            else { window.syncModel(wifiListModel, newNetworks); window.wifiList = newNetworks; window.nextWifiList = null; window.refreshOrbitDisplay(); }
        }

        if (window.activeMode === "wifi") {
            if (!wasWifiConn && isNowWifiConn) window.showInfoView = true;

            let dd = window.disconnectingDevices;
            let ddChanged = false;
            for (let ssid in dd) {
                if (!isNowWifiConn || (newConnected && newConnected.ssid !== ssid)) {
                    delete dd[ssid];
                    ddChanged = true;
                }
            }
            if (ddChanged) {
                window.disconnectingDevices = Object.assign({}, dd);
                if (Object.keys(window.disconnectingDevices).length === 0 && Object.keys(window.busyTasks).length === 0) busyTimeout.stop();
            }

            let newlyConnected = false;
            let bt = window.busyTasks;
            if (isNowWifiConn && newConnected && bt[newConnected.ssid]) {
                newlyConnected = true;
                delete bt[newConnected.ssid];
                window.connectingId = "";
            }
            if (newlyConnected) {
                Sounds.playSfx("network/connect.wav");
                window.busyTasks = Object.assign({}, bt);
                if (Object.keys(window.busyTasks).length === 0 && Object.keys(window.disconnectingDevices).length === 0) busyTimeout.stop();
            }

            if (isNowWifiConn || window.isBtConn || window.isEthConn) window.updateInfoNodes();
        }
        window.validateActiveMode();
    }

    function rebuildBtData(isCache) {
        if (!isCache && window.btFirstLoad) {
            window.powerAnimAllowed = false;
            powerAnimBlocker.restart();
            window.btFirstLoad = false;
        }
        let adapter = Bluetooth.defaultAdapter;
        if (!adapter) {
            window.btMissCount++;
            if (window.btMissCount >= 2) window.btPresent = false;
            if (!isCache) validateActiveMode();
            return;
        }

        window.btMissCount = 0;
        window.btPresent = true;

        let fetchedPower = adapter.enabled ? "on" : "off";

        if (window.btPowerPending) {
            window.btPower = window.expectedBtPower;
            if (fetchedPower === window.expectedBtPower && !powerMinSpinTimer.running) {
                window.btPowerPending = false;
                btPendingReset.stop();
            }
        } else {
            window.btPower = fetchedPower;
            window.expectedBtPower = "";
        }

        let oldBtLen = window.btConnected ? window.btConnected.length : 0;
        let newBtConnected = [];
        let newDevices = [];
        let map = {};

        let devList = window.getBtDevicesList();
        for (let i = 0; i < devList.length; i++) {
            let d = devList[i];
            if (!d) continue;
            let mac = d.address || "";
            if (mac === "") continue;

            map[mac] = d;

            let deviceName = d.deviceName || "";
            let alias = d.name || "";
            let hasName = deviceName !== "";
            let paired = d.paired || d.bonded;

            let name = hasName ? deviceName : (alias !== "" ? alias : mac);

            // Pairing temporarily opens a link before authentication succeeds.
            // Keep that link in the pending list until the operation completes.
            let connected = d.connected && !d.pairing
                && !(btConnector.running && btConnector.targetMac === mac);
            let battery = d.batteryAvailable ? Math.round(d.battery * 100) : 0;
            let iconType = d.icon || "";

            let icon = "";
            let typeLower = iconType.toLowerCase();
            let nameLower = name.toLowerCase();
            if (typeLower.indexOf("headset") !== -1 || typeLower.indexOf("headphone") !== -1 || nameLower.indexOf("headphone") !== -1 || nameLower.indexOf("buds") !== -1 || nameLower.indexOf("pods") !== -1) icon = "🎧";
            else if (typeLower.indexOf("audio") !== -1 || typeLower.indexOf("speaker") !== -1 || typeLower.indexOf("card") !== -1 || nameLower.indexOf("speaker") !== -1) icon = "📻";
            else if (typeLower.indexOf("phone") !== -1 || nameLower.indexOf("phone") !== -1 || nameLower.indexOf("iphone") !== -1 || nameLower.indexOf("android") !== -1) icon = "📱";
            else if (typeLower.indexOf("mouse") !== -1 || nameLower.indexOf("mouse") !== -1) icon = "󰍽";
            else if (typeLower.indexOf("keyboard") !== -1 || nameLower.indexOf("keyboard") !== -1) icon = "⌨️";
            else if (typeLower.indexOf("controller") !== -1 || nameLower.indexOf("controller") !== -1) icon = "🎮";

            if (connected) {
                newBtConnected.push({
                    id: mac,
                    name: name,
                    mac: mac,
                    icon: icon,
                    battery: battery.toString(),
                    profile: window.btAudioProfiles[mac.toLowerCase()] || "Connected"
                });
            } else {
                if (!hasName && !paired) continue;

                newDevices.push({
                    id: mac,
                    name: name,
                    mac: mac,
                    icon: icon,
                    action: paired ? "Connect" : "Pair",
                    isActionable: true
                });
            }
        }

        window.btDeviceMap = map;
        let isNowBtConn = newBtConnected.length > 0;

        if (!window.deepEqual(window.btConnected, newBtConnected)) {
            window.btConnected = newBtConnected;
        }

        newDevices.sort((a, b) => (a && b && a.id && b.id) ? a.id.localeCompare(b.id) : 0);

        if (isNowBtConn && window.activeMode === "bt") {
            newDevices.push({ id: "action_settings", ssid: "", mac: "action_settings", name: I18n.t("network.status.current_device") || "Current Device", icon: "󰒓", action: "", isInfoNode: false, isActionable: true, cmdStr: "TOGGLE_VIEW", parentIndex: -1 });
        }

        if (!window.deepEqual(window.btList, newDevices)) {
            if (window.isListLocked) window.nextBtList = newDevices;
            else { window.syncModel(btListModel, newDevices); window.btList = newDevices; window.nextBtList = null; window.refreshOrbitDisplay(); }
        }

        if (window.activeMode === "bt") {
            if (newBtConnected.length > oldBtLen) {
                window.showInfoView = true;
            }

            let dd = window.disconnectingDevices;
            let ddChanged = false;
            for (let mac in dd) {
                let stillConnected = false;
                for (let i = 0; i < newBtConnected.length; i++) {
                    if (newBtConnected[i] && newBtConnected[i].mac === mac) { stillConnected = true; break; }
                }
                if (!stillConnected) {
                    delete dd[mac];
                    ddChanged = true;
                }
            }
            if (ddChanged) {
                window.disconnectingDevices = Object.assign({}, dd);
                if (Object.keys(window.disconnectingDevices).length === 0 && Object.keys(window.busyTasks).length === 0) busyTimeout.stop();
            }

            let newlyConnected = false;
            let bt = window.busyTasks;
            for (let i = 0; i < newBtConnected.length; i++) {
                if (newBtConnected[i] && newBtConnected[i].mac) {
                    let mac = newBtConnected[i].mac;
                    if (bt[mac]) {
                        newlyConnected = true;
                        delete bt[mac];
                        window.connectingId = "";
                    }
                }
            }
            if (newlyConnected) {
                btConnectSimTimer.stop();
                Sounds.playSfx("network/connect.wav");
                window.busyTasks = Object.assign({}, bt);
                if (Object.keys(window.busyTasks).length === 0 && Object.keys(window.disconnectingDevices).length === 0) busyTimeout.stop();
            }

            if (isNowBtConn || window.isWifiConn || window.isEthConn) window.updateInfoNodes();
        }
        if (!isCache) validateActiveMode();
    }

    Process {
        id: btConnector
        property string targetMac: ""
        property string targetId: ""
        property var result: ({})
        stdout: StdioCollector {
            onStreamFinished: {
                try { btConnector.result = JSON.parse(this.text.trim()); }
                catch (e) { btConnector.result = ({ok: false, error: "Invalid Bluetooth helper response"}); }
                if (!btConnector.result.ok)
                    console.warn("Bluetooth connection failed:", btConnector.result.error);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim()) console.warn("Bluetooth helper:", this.text.trim()); }
        }
        onExited: (exitCode) => {
            let tasks = Object.assign({}, window.busyTasks);
            delete tasks[targetId];
            window.busyTasks = tasks;
            window.connectingId = "";
            if (exitCode !== 0) {
                window.failedId = targetId;
                failClearTimer.restart();
                Sounds.playSfx("network/error.wav");
            } else {
                Sounds.playSfx("network/connect.wav");
            }
            window.requestBtRebuild();
            if (Object.keys(tasks).length === 0 && Object.keys(window.disconnectingDevices).length === 0)
                busyTimeout.stop();
        }
    }

    Process {
        id: btProfilePoller
        command: ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text.trim();
                    if (text !== "") {
                        window.btAudioProfiles = JSON.parse(text);
                        window.requestBtRebuild();
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: mainPollerTimer
        interval: (Object.keys(window.busyTasks).length > 0 || Object.keys(window.disconnectingDevices).length > 0) ? 1000 : 3000
        running: window.visible
        repeat: true
        property int tick: 0
        onTriggered: {
            tick = (tick + 1) % 4;
            if (window.activeMode === "bt") {
                if (!btProfilePoller.running) btProfilePoller.running = true;
            }
            if (tick === 0) {
                if (window.activeMode !== "bt" && !btProfilePoller.running) btProfilePoller.running = true;
            }
        }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 400000; loops: Animation.Infinite; running: window.visible
    }

    property real lightningStrikeProg: window.animWin(window.introState, 0.40, 0.85)

    property alias busyTimeoutTimer: busyTimeout
    property alias ethPendingResetTimer: ethPendingReset
    property alias wifiPendingResetTimer: wifiPendingReset
    property alias btPendingResetTimer: btPendingReset
    property alias powerMinSpinTimerRef: powerMinSpinTimer
    property alias powerAnimBlockerTimer: powerAnimBlocker
    property alias orbitModel: orbitDisplayModel

    Item {
        anchors.fill: parent
        visible: window.visible
        enabled: window.visible
        opacity: window.exitOpacity * window.easeOut(window.animWin(window.introState, 0.0, 0.12))
        scale: (0.96 + 0.04 * window.easeOut(window.animWin(window.introState, 0.0, 0.12))) * (0.97 + 0.03 * window.exitOpacity)
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            border.width: 0
            border.color: "transparent"
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
            }
            layer.enabled: window.visible && window.introState > 0.001 && window.introState < 0.999
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 12
                blur: (1.0 - window.easeOut(window.animWin(window.introState, 0.0, 0.40))) * 0.35
            }

            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(120)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(80)
                opacity: (window.currentPower ? (window.isDisconnectHovered ? 0.05 : 0.03) : 0.01) * window.easeOut(window.animWin(window.introState, 0.02, 0.22))
                color: window.isDisconnectHovered && window.currentConn
                    ? ThemeBackend.red
                    : (window.currentConn ? window.activeColor : ThemeBackend.surface2)
                Behavior on color { enabled: window.visible; ColorAnimation { duration: 300; easing.type: Easing.OutQuad } }
                Behavior on opacity { enabled: window.visible && window.introState >= 1.0; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                visible: opacity > 0.005
            }

            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-120)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-80)
                opacity: (window.currentPower ? (window.isDisconnectHovered ? 0.04 : 0.02) : 0.005) * window.easeOut(window.animWin(window.introState, 0.04, 0.26))
                color: window.isDisconnectHovered && window.currentConn
                    ? Qt.darker(ThemeBackend.red, 1.25)
                    : (window.currentConn ? window.activeGradientSecondary : ThemeBackend.surface1)
                Behavior on color { enabled: window.visible; ColorAnimation { duration: 300; easing.type: Easing.OutQuad } }
                Behavior on opacity { enabled: window.visible && window.introState >= 1.0; NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                visible: opacity > 0.002
            }

            Rectangle {
                id: introPing
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -window.s(65) / 2
                width: window.s(520); height: width; radius: width / 2
                color: "transparent"
                border.color: window.activeColor
                border.width: window.s(2)
                property real pingProg: window.animWin(window.introState, 0.03, 0.32)
                opacity: (1 - pingProg) * (window.currentPower ? 0.45 : 0.18)
                scale: 0.2 + 0.9 * pingProg
                visible: window.visible && pingProg > 0.001 && pingProg < 0.999 && opacity > 0.01
                Behavior on border.color { enabled: window.visible; ColorAnimation { duration: 300 } }
            }

            Item {
                id: radarItem
                anchors.fill: parent
                anchors.bottomMargin: window.s(65)
                opacity: window.currentPower ? 1.0 : 0.0
                scale: window.currentPower ? 1.0 : 1.05
                visible: window.visible && opacity > 0.01
                Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                Behavior on scale { enabled: window.visible; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: window.s(220) + (index * window.s(130))
                        height: width
                        radius: width / 2
                        color: "transparent"

                        border.color: Object.keys(window.disconnectingDevices).length > 0 ? ThemeBackend.red : window.activeColor
                        border.width: Object.keys(window.disconnectingDevices).length > 0 ? window.s(2) : 1

                        Behavior on border.color { enabled: window.visible; ColorAnimation { duration: 150 } }
                        Behavior on border.width { enabled: window.visible; NumberAnimation { duration: 150 } }

                        property real ringIntro: window.easeOut(window.animWin(window.introState, 0.06 + index * 0.05, 0.22 + index * 0.05))
                        scale: 0.75 + 0.25 * ringIntro
                        opacity: (Object.keys(window.disconnectingDevices).length > 0 ? 0.2 : (window.currentConn ? 0.08 - (index * 0.02) : 0.03)) * ringIntro
                        Behavior on opacity { enabled: window.visible && window.introState >= 1.0; NumberAnimation { duration: 150 } }
                    }
                }
            }

            ShaderEffect {
                id: nodeLinesCanvas
                anchors.fill: parent
                anchors.bottomMargin: window.s(65)
                z: 0
                opacity: (window.currentConn && window.showInfoView && window.currentPower && window.lightningStrikeProg > 0.01) ? 1.0 : 0.0
                visible: window.visible && opacity > 0.01
                Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 400 } }

                property real animTime: 0.0
                NumberAnimation on animTime {
                    running: window.visible && nodeLinesCanvas.opacity > 0.01 && window.currentPower
                    loops: Animation.Infinite
                    from: 0; to: 1000
                    duration: 1000000
                }

                property vector2d itemSize: Qt.vector2d(width, height)
                property real time: animTime
                property real strikeProg: window.lightningStrikeProg
                property real scale: window.s(1.0)
                property color activeColor: window.activeColor

                function calcActiveBeams() {
                    var beams = [];
                    if (!window.currentConn || !window.showInfoView || !window.currentPower || window.lightningStrikeProg <= 0.001) {
                        return beams;
                    }
                    for (var i = 0; i < cardLayer.repeater.count; i++) {
                        var item = cardLayer.repeater.itemAt(i);
                        if (!item || !item.isLoaded) continue;

                        var targetX = item.x + item.width / 2;
                        var targetY = item.y + item.height / 2;

                        if (typeof item.myParentIdx === "number" && item.myParentIdx === -1) {
                            for (var c = 0; c < coreLayer.repeater.count; c++) {
                                var cItem = coreLayer.repeater.itemAt(c);
                                if (cItem && cItem.activeTransition > 0.01) {
                                    beams.push(Qt.vector4d(cItem.x + cItem.width / 2, cItem.y + cItem.height / 2, targetX, targetY));
                                }
                            }
                        } else if (typeof item.myParentIdx === "number" && item.myParentIdx >= 0 && item.myParentIdx < coreLayer.repeater.count) {
                            var pItem = coreLayer.repeater.itemAt(item.myParentIdx);
                            if (pItem && pItem.activeTransition > 0.01) {
                                beams.push(Qt.vector4d(pItem.x + pItem.width / 2, pItem.y + pItem.height / 2, targetX, targetY));
                            }
                        }
                    }
                    return beams;
                }

                property var activeBeams: {
                    var _tick = window.globalOrbitAngle;
                    var _vis = window.visible;
                    var _conn = window.currentConn;
                    return calcActiveBeams();
                }

                property real beamCount: Math.min(8.0, activeBeams.length)
                property real coreRadius: {
                    var _tick = window.globalOrbitAngle;
                    var r = 0;
                    for (var i = 0; i < coreLayer.repeater.count; i++) {
                        var cItem = coreLayer.repeater.itemAt(i);
                        if (cItem && cItem.activeTransition > 0.01) r = Math.max(r, cItem.width * cItem.scale / 2);
                    }
                    return r;
                }
                property vector4d beam0: activeBeams.length > 0 ? activeBeams[0] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam1: activeBeams.length > 1 ? activeBeams[1] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam2: activeBeams.length > 2 ? activeBeams[2] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam3: activeBeams.length > 3 ? activeBeams[3] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam4: activeBeams.length > 4 ? activeBeams[4] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam5: activeBeams.length > 5 ? activeBeams[5] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam6: activeBeams.length > 6 ? activeBeams[6] : Qt.vector4d(-1, -1, -1, -1)
                property vector4d beam7: activeBeams.length > 7 ? activeBeams[7] : Qt.vector4d(-1, -1, -1, -1)

                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/vfx/node_beams_clipped.frag.qsb"
            }

            NetworkCoreLayer {
                id: coreLayer
                window: window
            }

            NetworkCardLayer {
                id: cardLayer
                window: window
                orbitContainer: coreLayer
                coreRepeater: coreLayer.repeater
            }

            NetworkControls {
                window: window
            }
        }
    }
}
