import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import "../"

Scope {
    id: root

    property string freezeTimestamp: ""
    property bool staticLock: false
    property bool isUnlocking: false
    property int resumeRevision: 0

    property bool isNiri: false
    property bool isSway: false
    readonly property bool isMango: MangoState.isMango
    property string kbLayout: "US"
    property int connectedScreenCount: 1
    property bool fingerprintAvailable: false
    property bool fpUnsupported: false
    property bool fpHolding: false
    property bool fpGotInfo: false
    property bool fpAborting: false
    property bool pwAborting: false
    readonly property int fingerprintMaxAttempts: 5

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop
    readonly property int batCap: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property string batPercent: batCap + "%"
    readonly property string batStatus: UPower.displayDevice.ready ? (UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? "Full" : (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging" : "Unknown")) : "Unknown"
    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property string batIcon: isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃")

    readonly property color batDynamicColor: {
        if (batCap <= 15 && !isCharging) return ThemeBackend.red;
        if (batCap <= 25 && !isCharging) return ThemeBackend.peach;
        if (isCharging) return ThemeBackend.green;
        return ThemeBackend.text;
    }

    function updateDeInfo() {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isNiri = de.indexOf("niri") !== -1;
        root.isSway = de.indexOf("sway") !== -1;
    }

    function updateScreenCount() {
        root.connectedScreenCount = Quickshell.screens ? Quickshell.screens.length : 1;
    }

    Component.onCompleted: {
        SystemInfo.fetch();
        root.updateDeInfo();
        root.updateScreenCount();
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
        pamServiceProbe.running = true;
    }

    Component.onDestruction: {
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.updateScreenCount();
        }
    }

    function switchKbLayout() {
        root.updateDeInfo();
        if (root.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (root.isSway) {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else if (root.isMango) {
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        } else {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    Timer {
        id: kbPollerRestartTimer
        interval: 400
        repeat: false
        onTriggered: {
            kbWaiter.running = false;
            kbPoller.running = false;
            if (rootLock.locked) kbPoller.running = true;
        }
    }

    Process {
        id: kbPoller
        running: rootLock.locked
        command: [
            "bash",
            "-c",
            root.isMango
                ? "layout=$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : root.isNiri
                ? "layout=$(niri msg -j keyboard-layouts 2>/dev/null | jq -r '.names[.current_idx] // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : (root.isSway
                    ? "layout=$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == \"keyboard\" and .xkb_active_layout_name != null)] | .[0].xkb_active_layout_name // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                    : "layout=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'")
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && root.kbLayout !== txt) root.kbLayout = txt;
                kbWaiter.running = false;
                if (rootLock.locked) kbWaiter.running = true;
            }
        }
    }

    Process {
        id: kbWaiter
        command: [
            "bash",
            Caching.qsDir + "/watchers/kb_wait.sh",
            root.isMango ? "mango" : (root.isNiri ? "niri" : (root.isSway ? "sway" : "hyprland"))
        ]
        onExited: {
            kbPoller.running = false;
            if (rootLock.locked) kbPoller.running = true;
        }
    }

    Process {
        id: grimLockSnapProcess
        property string timeStamp: ""
        property var screenNames: []

        command: {
            let ts = timeStamp;
            let dir = Caching.getRunDir("screenshot");
            let cmd = "dir=\"" + dir + "\"; mkdir -p \"$dir\"; ";
            let mons = screenNames;
            if (mons && mons.length > 0) {
                for (let i = 0; i < mons.length; i++) {
                    let m = mons[i];
                    cmd += "grim -o \"" + m + "\" -l 0 \"$dir/lock_freeze_" + m + "_" + ts + ".png\" & ";
                }
                cmd += "wait; ";
                let firstMon = mons[0];
                cmd += "ln -sf \"$dir/lock_freeze_" + firstMon + "_" + ts + ".png\" \"$dir/lock_freeze_default_" + ts + ".png\" 2>/dev/null || cp -f \"$dir/lock_freeze_" + firstMon + "_" + ts + ".png\" \"$dir/lock_freeze_default_" + ts + ".png\" 2>/dev/null || true;";
            } else {
                cmd += "grim -l 0 \"$dir/lock_freeze_default_" + ts + ".png\" || exit 1;";
            }
            return ["bash", "-c", cmd];
        }

        onExited: (exitCode) => {
            grimTimeoutTimer.stop();
            if (exitCode === 0) {
                root.freezeTimestamp = timeStamp;
            } else {
                root.freezeTimestamp = "";
            }
            root.doLock();
        }
    }

    Timer {
        id: grimTimeoutTimer
        interval: 500
        repeat: false
        onTriggered: {
            grimLockSnapProcess.running = false;
            root.doLock();
        }
    }

    Process {
        id: pamServiceProbe
        command: [
            "bash",
            "-c",
            "test -e \"${1:-/etc/pam.d}/serpantinum\"",
            "pam-probe",
            pam.configDirectory
        ]
        onExited: (exitCode) => {
            if (exitCode !== 0) return;
            pam.config = "serpantinum";
            fpPam.config = "serpantinum";
        }
    }

    Timer {
        id: fingerprintRestartTimer
        interval: 1000
        repeat: false
        onTriggered: root.startFingerprint()
    }

    Timer {
        id: fingerprintSettleTimer
        interval: 1700
        repeat: false
        onTriggered: {
            if (lockUI.fpState === "failed") lockUI.fpState = "ready";
        }
    }

    Timer {
        id: fingerprintUnlockTimer
        interval: 480
        repeat: false
        onTriggered: root.finishUnlock()
    }

    Timer {
        id: passwordStartTimer
        interval: 3000
        repeat: false
        onTriggered: root.startPassword(true)
    }

    Timer {
        id: passwordRetryTimer
        interval: 350
        repeat: false
        onTriggered: root.startPassword(false)
    }

    function markFingerprintUnsupported() {
        root.fpUnsupported = true;
        root.fpHolding = false;
        root.fingerprintAvailable = false;
        fingerprintRestartTimer.stop();
        root.startPassword(true);
    }

    function startFingerprint() {
        if (root.fpUnsupported || !rootLock.locked || root.isUnlocking || fpPam.active) return;
        if (lockUI.fpState === "success") return;
        root.fpGotInfo = false;
        root.fpAborting = false;
        fpPam.start();
    }

    function startPassword(force) {
        if (!rootLock.locked || root.isUnlocking || pam.active) return;
        if (!force && !root.fpUnsupported && !root.fpHolding) {
            passwordRetryTimer.restart();
            return;
        }
        root.pwAborting = false;
        pam.start();
    }

    function beginAuth() {
        if (!rootLock.locked || root.isUnlocking) return;
        root.startFingerprint();
        passwordStartTimer.restart();
    }

    function stopAuth() {
        fingerprintRestartTimer.stop();
        fingerprintSettleTimer.stop();
        passwordStartTimer.stop();
        passwordRetryTimer.stop();
        root.fpAborting = true;
        root.fpHolding = false;
        if (fpPam.active) fpPam.abort();
        if (pam.active) {
            root.pwAborting = true;
            pam.abort();
        }
    }

    function restartAuth() {
        root.stopAuth();
        root.fpUnsupported = false;
        root.fingerprintAvailable = false;
        if (lockUI.fpState !== "success") lockUI.fpState = "ready";
        pamActionTimer.restart();
    }

    function handleFingerprintMessage() {
        if (!rootLock.locked || root.isUnlocking || lockUI.fpState === "success") return;
        if (fpPam.responseRequired) {
            root.fpHolding = false;
            root.fpAborting = true;
            fpPam.abort();
            if (root.fpGotInfo) fingerprintRestartTimer.restart();
            else root.markFingerprintUnsupported();
            return;
        }
        if (fpPam.messageIsError) {
            lockUI.fpFailures = Math.min(lockUI.fpFailures + 1, root.fingerprintMaxAttempts);
            lockUI.fpState = "failed";
            fingerprintSettleTimer.restart();
            return;
        }
        root.fpGotInfo = true;
        root.fpHolding = true;
        root.fingerprintAvailable = true;
        root.startPassword(false);
    }

    function handleFingerprintCompleted(result) {
        root.fpHolding = false;
        if (root.fpAborting || !rootLock.locked || root.isUnlocking) return;
        if (result === PamResult.Success) {
            fingerprintSettleTimer.stop();
            lockUI.fpState = "success";
            fingerprintUnlockTimer.restart();
        } else if (root.fpGotInfo) {
            fingerprintRestartTimer.restart();
        } else {
            root.markFingerprintUnsupported();
        }
    }

    function lockStatic() {
        if (rootLock.locked) return;
        grimLockSnapProcess.running = false;
        grimTimeoutTimer.stop();
        root.staticLock = true;
        root.freezeTimestamp = "";
        root.doLock();
    }

    function lock() {
        if (rootLock.locked) return;
        root.staticLock = false;
        let ts = Date.now().toString();
        let mons = [];
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i] && Quickshell.screens[i].name) {
                    mons.push(Quickshell.screens[i].name);
                }
            }
        }
        grimLockSnapProcess.screenNames = mons;
        grimLockSnapProcess.timeStamp = ts;
        grimLockSnapProcess.running = false;
        grimLockSnapProcess.running = true;
        grimTimeoutTimer.restart();
    }

    function doLock() {
        grimTimeoutTimer.stop();
        SystemInfo.fetch();
        root.updateDeInfo();
        root.updateScreenCount();
        root.isUnlocking = false;
        lockUI.failed = false;
        lockUI.authenticating = false;
        lockUI.statusText = I18n.t("lock.status.locked");
        lockUI.fpState = "ready";
        lockUI.fpFailures = 0;
        root.stopAuth();
        root.fpUnsupported = false;
        root.fingerprintAvailable = false;
        fingerprintUnlockTimer.stop();
        rootLock.locked = true;
        pamActionTimer.start();
        kbPollerRestartTimer.restart();
    }

    function finishUnlock() {
        if (root.isUnlocking) return;
        root.isUnlocking = true;
        fingerprintUnlockTimer.stop();
        root.stopAuth();
    }

    function completeUnlock() {
        if (!rootLock.locked) return;
        rootLock.locked = false;
        root.isUnlocking = false;
        root.stopAuth();
        kbWaiter.running = false;
        kbPoller.running = false;
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
        if (root.freezeTimestamp !== "") {
            Quickshell.execDetached(["bash", "-c", "rm -f " + Caching.getRunDir("screenshot") + "/lock_freeze_*_" + root.freezeTimestamp + ".png"]);
            root.freezeTimestamp = "";
        }
    }

    IpcHandler {
        target: "lock"
        function activate(): void {
            root.lock();
        }
        function activateStatic(): void {
            root.lockStatic();
        }
        function restartAuth(): void {
            if (rootLock.locked) root.restartAuth();
        }
    }


    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: I18n.t("lock.status.locked")
        property string fpState: "ready"
        property int fpFailures: 0
        readonly property string fpLabel: {
            switch (fpState) {
            case "failed": return I18n.t("lock.fingerprint.not_recognized");
            case "success": return I18n.t("lock.fingerprint.recognized");
            default: return I18n.t("lock.fingerprint.ready");
            }
        }
    }

    Timer {
        id: pamActionTimer
        interval: 350
        onTriggered: {
            root.beginAuth();
        }
    }

    PamContext {
        id: fpPam

        onPamMessage: root.handleFingerprintMessage()
        onCompleted: (result) => root.handleFingerprintCompleted(result)
        onError: root.markFingerprintUnsupported()
    }

    PamContext {
        id: pam

        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (root.pwAborting) return;
            if (result === PamResult.Success) {
                root.finishUnlock();
            } else {
                lockUI.failed = true;
                lockUI.statusText = I18n.t("lock.status.access_denied");
                passwordRetryTimer.start();
            }
        }
    }

    Process {
        id: suspendProcess
        command: ["bash", Caching.serpantinumDir + "/scripts/system/suspend.sh"]
        onExited: {
            SystemInfo.fetch();
            root.updateDeInfo();
            kbPollerRestartTimer.restart();
            root.resumeRevision++;
            if (rootLock.locked) root.restartAuth();
        }
    }

    Process {
        id: poweroffProcess
        command: ["bash", Caching.serpantinumDir + "/scripts/system/poweroff.sh"]
    }

    Process {
        id: reloadProcess
        command: ["bash", Caching.serpantinumDir + "/scripts/system/reboot.sh"]
    }

    WlSessionLock {
        id: rootLock
        locked: false
        onLockedChanged: {
            let lockFile = Caching.getRunDir("lock") + "/locked";
            if (locked) {
                Quickshell.execDetached(["touch", lockFile]);
            } else {
                Quickshell.execDetached(["rm", "-f", lockFile]);
            }
        }

        surface: Component {
            LockSurface {
                sRoot: root
                sRootLock: rootLock
                sPam: pam
                sLockUI: lockUI
                sSuspendProcess: suspendProcess
                sReloadProcess: reloadProcess
                sPoweroffProcess: poweroffProcess
            }
        }
    }
}
