pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"

Item {
    id: root

    readonly property bool hasBattery: Boolean(UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent)
    readonly property bool isDesktop: UPower.displayDevice.ready ? !root.hasBattery : (typeof SystemInfo !== "undefined" ? SystemInfo.isDesktop : true)
    readonly property int batteryPercentage: (UPower.displayDevice.ready && root.hasBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: root.hasBattery && UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property string stateFilePath: {
        let base = (typeof Caching !== "undefined" && Caching.runDir) ? Caching.runDir : "/tmp/serpantinum";
        return base + "/battery_notif_state.json";
    }

    property bool stateLoaded: false
    property bool initialized: false
    property int lastPercentage: -1
    property bool notifiedFull: false
    property bool notifiedLow: false
    property bool notifiedCritical: false
    property real lastNotifTime: 0
    property string lastNotifType: ""

    onHasBatteryChanged: {
        if (!root.hasBattery) {
            root.notifiedFull = false;
            root.notifiedLow = false;
            root.notifiedCritical = false;
        }
        root.checkBattery();
    }
    onIsDesktopChanged: root.checkBattery()

    FileView {
        id: stateFileView
        path: root.stateFilePath
        watchChanges: false
        onLoaded: {
            root.loadState();
        }
    }

    function loadState() {
        try {
            let txt = typeof stateFileView.text === "function" ? stateFileView.text() : stateFileView.text;
            if (txt && txt.trim().length > 0) {
                let data = JSON.parse(txt);
                if (data && typeof data === "object") {
                    if (data.notifiedFull !== undefined) root.notifiedFull = Boolean(data.notifiedFull);
                    if (data.notifiedLow !== undefined) root.notifiedLow = Boolean(data.notifiedLow);
                    if (data.notifiedCritical !== undefined) root.notifiedCritical = Boolean(data.notifiedCritical);
                    if (data.lastPercentage !== undefined) root.lastPercentage = Number(data.lastPercentage);
                    if (data.lastNotifTime !== undefined) root.lastNotifTime = Number(data.lastNotifTime);
                    if (data.lastNotifType !== undefined) root.lastNotifType = String(data.lastNotifType);
                    root.stateLoaded = true;
                }
            }
        } catch (e) {}
    }

    function saveState() {
        let payload = JSON.stringify({
            "notifiedFull": root.notifiedFull,
            "notifiedLow": root.notifiedLow,
            "notifiedCritical": root.notifiedCritical,
            "lastPercentage": root.lastPercentage,
            "lastNotifTime": root.lastNotifTime,
            "lastNotifType": root.lastNotifType
        });
        let dir = (typeof Caching !== "undefined" && Caching.runDir) ? Caching.runDir : "/tmp/serpantinum";
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$3"', "_", dir, payload, root.stateFilePath]);
    }

    function sendNotification(type, summary, body, icon, urgency) {
        let now = Date.now();
        if (root.lastNotifType === type && (now - root.lastNotifTime < 60000)) {
            return;
        }
        if (now - root.lastNotifTime < 3000) {
            return;
        }
        root.lastNotifType = type;
        root.lastNotifTime = now;
        root.saveState();

        let u = urgency ? urgency : "normal";
        let ic = icon ? icon : "battery";
        let appName = I18n.t("sysnotif.battery.app_name");
        if (appName === "sysnotif.battery.app_name") appName = "System";
        Quickshell.execDetached([
            "notify-send",
            "-a", appName,
            "-u", u,
            "-i", ic,
            summary,
            body
        ]);
    }

    function checkBattery() {
        if (!root.hasBattery || root.isDesktop || !UPower.displayDevice.ready || (typeof I18n !== "undefined" && !I18n.isReady)) return;

        if (!root.stateLoaded) {
            root.loadState();
        }

        let pct = root.batteryPercentage;
        let state = UPower.displayDevice.state;
        let charging = state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged;

        if (!root.initialized) {
            root.initialized = true;
            if (!root.stateLoaded) {
                root.lastPercentage = pct;
                if (pct >= 100) {
                    root.notifiedFull = true;
                }
                root.saveState();
            } else {
                if (pct >= 100 && (root.lastPercentage >= 100 || root.lastPercentage === -1)) {
                    root.notifiedFull = true;
                }
            }
        }

        if (pct < 100) {
            root.notifiedFull = false;
        }

        if (charging) {
            if (pct > 20) {
                root.notifiedLow = false;
                root.notifiedCritical = false;
            }

            if ((pct >= 100 || state === UPowerDeviceState.FullyCharged) && !root.notifiedFull && root.lastPercentage < 100) {
                let title = I18n.t("sysnotif.battery.full_title");
                let body = I18n.t("sysnotif.battery.full_body");
                if (title === "sysnotif.battery.full_title" || body === "sysnotif.battery.full_body") return;
                root.notifiedFull = true;
                root.sendNotification(
                    "full",
                    title,
                    body,
                    "battery-full-charged",
                    "normal"
                );
            }
        } else {
            if (pct <= 5) {
                if (!root.notifiedCritical) {
                    let title = I18n.t("sysnotif.battery.critical_title");
                    let body = I18n.t("sysnotif.battery.critical_body", { "pct": pct.toString() });
                    if (title === "sysnotif.battery.critical_title") return;
                    root.notifiedCritical = true;
                    root.notifiedLow = true;
                    root.sendNotification(
                        "critical",
                        title,
                        body,
                        "battery-level-0-symbolic",
                        "critical"
                    );
                }
            } else if (pct <= 20) {
                if (!root.notifiedLow) {
                    let title = I18n.t("sysnotif.battery.low_title");
                    let body = I18n.t("sysnotif.battery.low_body", { "pct": pct.toString() });
                    if (title === "sysnotif.battery.low_title") return;
                    root.notifiedLow = true;
                    root.sendNotification(
                        "low",
                        title,
                        body,
                        "battery-level-20-symbolic",
                        "critical"
                    );
                }
            } else if (pct > 25) {
                root.notifiedLow = false;
                root.notifiedCritical = false;
            }
        }

        if (pct !== root.lastPercentage) {
            root.lastPercentage = pct;
            root.saveState();
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() { root.checkBattery(); }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() { root.checkBattery(); }
        function onStateChanged() { root.checkBattery(); }
        function onReadyChanged() { root.checkBattery(); }
        function onIsPresentChanged() { root.checkBattery(); }
        function onIsLaptopBatteryChanged() { root.checkBattery(); }
    }

    Component.onCompleted: {
        root.loadState();
    }
}
