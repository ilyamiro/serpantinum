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

    property int connectedScreenCount: 1
    property bool fingerprintAvailable: false
    property bool fpUnsupported: false
    property bool fpHolding: false
    property bool fpGotInfo: false
    property bool fpAborting: false
    property bool pwAborting: false
    property bool fpBlocked: false
    property int fpResumeRetries: 0
    property bool noFpPamReady: false
    property string defaultPamDir: ""
    property string defaultPamConfig: ""
    readonly property string noFpPamDir: Caching.getRunDir("lock") + "/pam"
    readonly property int passwordLockoutMs: 30000
    readonly property var lockscreenSettings: Config.getSetting("lockscreen", { "fingerprintEnabled": true, "attemptLimitEnabled": false, "passwordMaxAttempts": 5, "fingerprintMaxAttempts": 5 })
    readonly property bool fingerprintEnabled: lockscreenSettings.fingerprintEnabled !== false
    readonly property bool attemptLimitEnabled: lockscreenSettings.attemptLimitEnabled === true
    readonly property int passwordMaxAttempts: Math.max(1, Math.round(Number(lockscreenSettings.passwordMaxAttempts) || 5))
    readonly property int fingerprintMaxAttempts: Math.max(1, Math.round(Number(lockscreenSettings.fingerprintMaxAttempts) || 5))

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

    function updateScreenCount() {
        root.connectedScreenCount = Quickshell.screens ? Quickshell.screens.length : 1;
    }

    Component.onCompleted: {
        SystemInfo.fetch();
        root.updateScreenCount();
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
        root.defaultPamDir = pam.configDirectory;
        root.defaultPamConfig = pam.config;
        noFpPamBuilder.running = true;
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
            root.defaultPamConfig = "serpantinum";
        }
    }

    Process {
        id: noFpPamBuilder
        command: ["bash", Caching.serpantinumDir + "/scripts/system/pam_without_fingerprint.sh", root.defaultPamDir, root.noFpPamDir, "serpantinum"]
        onExited: (exitCode) => root.noFpPamReady = exitCode === 0
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
        interval: 500
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
        id: passwordLockoutTimer
        interval: root.passwordLockoutMs
        repeat: false
        onTriggered: {
            lockUI.lockedOut = false;
            lockUI.pwFailures = 0;
            lockUI.failed = false;
            lockUI.statusText = I18n.t("lock.status.locked");
            root.startPassword(false);
        }
    }

    Timer {
        id: passwordRetryTimer
        interval: 350
        repeat: false
        onTriggered: root.startPassword(false)
    }

    function markFingerprintUnsupported() {
        if (root.fpResumeRetries > 0 && !root.fpGotInfo && root.fingerprintEnabled && !root.fpBlocked && rootLock.locked && !root.isUnlocking) {
            root.fpResumeRetries--;
            root.fpHolding = false;
            root.fpUnsupported = false;
            fingerprintRestartTimer.restart();
            return;
        }
        root.fpUnsupported = true;
        root.fpHolding = false;
        root.fingerprintAvailable = false;
        fingerprintRestartTimer.stop();
        root.startPassword(true);
    }

    function startFingerprint() {
        if (!root.fingerprintEnabled) {
            root.fpUnsupported = true;
            root.startPassword(true);
            return;
        }
        if (root.fpUnsupported || root.fpBlocked || !rootLock.locked || root.isUnlocking || fpPam.active) return;
        if (lockUI.fpState === "success") return;
        root.fpGotInfo = false;
        root.fpAborting = false;
        fpPam.start();
    }

    function applyPasswordConfig() {
        if ((!root.fingerprintEnabled || root.fpBlocked || root.fpResumeRetries > 0) && root.noFpPamReady) {
            pam.configDirectory = root.noFpPamDir;
            pam.config = "serpantinum-nofp";
        } else {
            pam.configDirectory = root.defaultPamDir;
            pam.config = root.defaultPamConfig;
        }
    }

    function startPassword(force) {
        if (!rootLock.locked || root.isUnlocking || pam.active || lockUI.lockedOut) return;
        if (!force && !root.fpUnsupported && !root.fpHolding) {
            passwordRetryTimer.restart();
            return;
        }
        root.pwAborting = false;
        root.applyPasswordConfig();
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
        root.fpUnsupported = root.fpBlocked;
        root.fpResumeRetries = 5;
        root.fingerprintAvailable = root.fpBlocked;
        if (lockUI.fpState !== "success" && !root.fpBlocked) lockUI.fpState = "ready";
        pamActionTimer.restart();
    }

    function blockFingerprint() {
        root.fpBlocked = true;
        root.fpUnsupported = true;
        root.fpHolding = false;
        root.fpAborting = true;
        fingerprintRestartTimer.stop();
        fingerprintSettleTimer.stop();
        if (fpPam.active) fpPam.abort();
        lockUI.fpState = "blocked";
        if (pam.active) {
            root.pwAborting = true;
            pam.abort();
            passwordRetryTimer.restart();
        } else {
            root.startPassword(true);
        }
    }

    function startPasswordLockout() {
        lockUI.lockedOut = true;
        lockUI.statusText = I18n.t("lock.status.too_many_attempts", "Too many attempts");
        passwordLockoutTimer.restart();
    }

    function handleFingerprintMessage() {
        if (!rootLock.locked || root.isUnlocking || root.fpBlocked || lockUI.fpState === "success") return;
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
            if (root.attemptLimitEnabled && lockUI.fpFailures >= root.fingerprintMaxAttempts) {
                root.blockFingerprint();
                return;
            }
            lockUI.fpState = "failed";
            fingerprintSettleTimer.restart();
            return;
        }
        root.fpGotInfo = true;
        root.fpResumeRetries = 0;
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
        root.updateScreenCount();
        root.isUnlocking = false;
        lockUI.failed = false;
        lockUI.authenticating = false;
        lockUI.statusText = I18n.t("lock.status.locked");
        lockUI.fpState = "ready";
        lockUI.fpFailures = 0;
        lockUI.pwFailures = 0;
        lockUI.lockedOut = false;
        passwordLockoutTimer.stop();
        root.fpBlocked = false;
        root.fpResumeRetries = 0;
        root.stopAuth();
        root.fpUnsupported = false;
        root.fingerprintAvailable = false;
        fingerprintUnlockTimer.stop();
        rootLock.locked = true;
        pamActionTimer.start();
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
        passwordLockoutTimer.stop();
        root.stopAuth();
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
        property int pwFailures: 0
        property bool lockedOut: false
        readonly property string fpLabel: {
            switch (fpState) {
            case "failed": return I18n.t("lock.fingerprint.not_recognized");
            case "success": return I18n.t("lock.fingerprint.recognized");
            case "blocked": return I18n.t("lock.fingerprint.blocked", "Fingerprint disabled");
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
                lockUI.pwFailures++;
                if (root.attemptLimitEnabled && lockUI.pwFailures >= root.passwordMaxAttempts) {
                    root.startPasswordLockout();
                } else {
                    passwordRetryTimer.start();
                }
            }
        }
    }

    Process {
        id: suspendProcess
        command: ["bash", Caching.serpantinumDir + "/scripts/system/suspend.sh"]
        onExited: {
            SystemInfo.fetch();
            KeyboardLayout.refresh();
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
