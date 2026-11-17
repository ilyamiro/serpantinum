import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Quickshell.Services.UPower
import "../"
import "../lock"

Scope {
    id: greeter

    readonly property string loginUser: Quickshell.env("SERPANTINUM_GREETER_USER") || Quickshell.env("USER") || ""
    readonly property var sessionCommand: [Quickshell.env("SERPANTINUM_GREETER_SESSION") || "start-hyprland"]
    readonly property string sessionDesktop: Quickshell.env("SERPANTINUM_GREETER_SESSION_DESKTOP") || "Hyprland"
    readonly property var sessionEnv: [
        "XDG_SESSION_TYPE=wayland",
        "XDG_SESSION_DESKTOP=" + sessionDesktop,
        "XDG_CURRENT_DESKTOP=" + sessionDesktop
    ]
    readonly property bool hybridAuth: Quickshell.env("SERPANTINUM_GREETER_HYBRID_AUTH") !== "0"
    readonly property bool testMode: !Greetd.available

    property string freezeTimestamp: ""
    property bool staticLock: false
    property bool isUnlocking: false
    property int resumeRevision: 0
    property bool fingerprintAvailable: false
    property bool fpBlocked: false

    readonly property var lockscreenSettings: Config.getSetting("lockscreen", { "fingerprintEnabled": true, "attemptLimitEnabled": false, "passwordMaxAttempts": 5, "fingerprintMaxAttempts": 5 })
    readonly property bool fingerprintEnabled: lockscreenSettings.fingerprintEnabled !== false
    readonly property bool attemptLimitEnabled: lockscreenSettings.attemptLimitEnabled === true
    readonly property int passwordMaxAttempts: Math.max(1, Math.round(Number(lockscreenSettings.passwordMaxAttempts) || 5))
    readonly property int fingerprintMaxAttempts: Math.max(1, Math.round(Number(lockscreenSettings.fingerprintMaxAttempts) || 5))
    readonly property int passwordLockoutMs: 30000

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop

    property string pendingPassword: ""
    property bool promptOpen: false
    property bool promptAnswered: false
    property bool firstMessageSeen: false
    property bool passwordFirst: false
    property bool fpWaiting: false
    property bool restarting: false
    property bool launchRequested: false

    function startSession() {
        greeter.promptOpen = false;
        greeter.promptAnswered = false;
        greeter.firstMessageSeen = false;
        greeter.fpWaiting = false;
        if (greeter.testMode) {
            greeterUI.statusText = I18n.t("lock.status.greeter_test_mode", "Test mode (no greetd), Ctrl+Esc quits");
            return;
        }
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        Greetd.createSession(greeter.loginUser);
    }

    function restartSession(delay) {
        restartTimer.interval = delay;
        restartTimer.restart();
    }

    function answer(text) {
        greeter.promptOpen = false;
        greeter.promptAnswered = true;
        Greetd.respond(text);
    }

    function submitPassword(text) {
        if (text.length === 0 || greeterUI.authenticating || greeterUI.lockedOut || greeter.isUnlocking) return;
        greeterUI.authenticating = true;
        greeterUI.failed = false;
        greeterUI.statusText = I18n.t("lock.status.authenticating");

        if (greeter.testMode) {
            testUnlockTimer.restart();
            return;
        }
        if (greeter.promptOpen) {
            greeter.answer(text);
            return;
        }
        greeter.pendingPassword = text;
        if (greeter.fpWaiting && greeter.promptAnswered && greeter.passwordFirst) {
            greeter.restarting = true;
            if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
            greeter.restartSession(150);
        }
    }

    function passwordRejected() {
        greeterUI.authenticating = false;
        greeterUI.failed = true;
        greeterUI.statusText = I18n.t("lock.status.access_denied");
        greeterUI.pwFailures++;
        if (greeter.attemptLimitEnabled && greeterUI.pwFailures >= greeter.passwordMaxAttempts) {
            greeterUI.lockedOut = true;
            greeterUI.statusText = I18n.t("lock.status.too_many_attempts", "Too many attempts");
            passwordLockoutTimer.restart();
        }
    }

    function fingerprintFailed() {
        greeterUI.fpFailures = Math.min(greeterUI.fpFailures + 1, greeter.fingerprintMaxAttempts);
        if (greeter.attemptLimitEnabled && greeterUI.fpFailures >= greeter.fingerprintMaxAttempts) {
            greeter.fpBlocked = true;
            greeterUI.fpState = "blocked";
            return;
        }
        greeterUI.fpState = "failed";
        fingerprintSettleTimer.restart();
    }

    function finishUnlock() {
        if (greeter.isUnlocking) return;
        greeter.isUnlocking = true;
    }

    function completeUnlock() {
        if (greeter.launchRequested) return;
        greeter.launchRequested = true;
        if (greeter.testMode) {
            Qt.quit();
            return;
        }
        Greetd.launch(greeter.sessionCommand, greeter.sessionEnv, true);
    }

    function restartAuth() {
        if (greeter.isUnlocking) return;
        greeter.restarting = true;
        if (!greeter.testMode && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        greeter.restartSession(500);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            greeter.restarting = false;
            const first = !greeter.firstMessageSeen;
            greeter.firstMessageSeen = true;

            if (responseRequired) {
                if (first) greeter.passwordFirst = true;
                greeter.fpWaiting = false;

                if (greeter.pendingPassword !== "") {
                    const t = greeter.pendingPassword;
                    greeter.pendingPassword = "";
                    greeter.answer(t);
                    return;
                }
                if (first && greeter.hybridAuth && greeter.fingerprintEnabled && !greeter.fpBlocked
                        && !echoResponse && !greeter.promptAnswered) {
                    greeter.answer("");
                    return;
                }
                greeter.promptOpen = true;
                return;
            }

            if (first) greeter.passwordFirst = false;

            if (error) {
                greeter.fingerprintFailed();
                return;
            }

            if (/finger|fprint|swipe|sensor|reader/i.test(message)) {
                if (greeterUI.authenticating) greeter.passwordRejected();
                greeter.fingerprintAvailable = true;
                greeter.fpWaiting = true;
                if (greeterUI.fpState !== "success" && !greeter.fpBlocked && greeterUI.fpState !== "failed")
                    greeterUI.fpState = "ready";
                return;
            }

            if (message !== "") greeterUI.statusText = message;
        }

        function onAuthFailure(message) {
            greeter.promptOpen = false;
            greeter.fpWaiting = false;
            if (greeter.restarting) return;
            if (greeterUI.authenticating) {
                greeter.passwordRejected();
                greeter.restartSession(greeterUI.lockedOut ? greeter.passwordLockoutMs : 350);
            } else {
                greeter.restartSession(1000);
            }
        }

        function onReadyToLaunch() {
            greeter.promptOpen = false;
            if (greeterUI.authenticating) {
                greeterUI.authenticating = false;
                greeter.finishUnlock();
            } else {
                fingerprintSettleTimer.stop();
                greeterUI.fpState = "success";
                fingerprintUnlockTimer.restart();
            }
        }

        function onError(error) {
            console.warn("greetd error:", error);
            greeterUI.authenticating = false;
            if (greeter.restarting) return;
            greeterUI.statusText = error;
            greeter.restartSession(1000);
        }
    }

    Timer { id: restartTimer; interval: 350; onTriggered: greeter.startSession() }
    Timer { id: fingerprintUnlockTimer; interval: 500; onTriggered: greeter.finishUnlock() }
    Timer { id: testUnlockTimer; interval: 400; onTriggered: greeter.finishUnlock() }

    Timer {
        id: fingerprintSettleTimer
        interval: 1700
        onTriggered: if (greeterUI.fpState === "failed") greeterUI.fpState = "ready"
    }

    Timer {
        id: passwordLockoutTimer
        interval: greeter.passwordLockoutMs
        onTriggered: {
            greeterUI.lockedOut = false;
            greeterUI.pwFailures = 0;
            greeterUI.failed = false;
            greeterUI.statusText = I18n.t("lock.status.locked");
        }
    }

    QtObject {
        id: greeterLockState
        property bool locked: true
        property bool secure: true
    }

    QtObject {
        id: greeterUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: I18n.t("lock.status.locked")
        property string fpState: "ready"
        property int fpFailures: 0
        property int pwFailures: 0
        property bool lockedOut: false
        property bool inputActive: false
        property string passwordText: ""
        function submitPassword(text) {
            greeter.submitPassword(text);
        }
        readonly property string fpLabel: {
            switch (fpState) {
            case "failed": return I18n.t("lock.fingerprint.not_recognized");
            case "success": return I18n.t("lock.fingerprint.recognized");
            case "blocked": return I18n.t("lock.fingerprint.blocked", "Fingerprint disabled");
            default: return I18n.t("lock.fingerprint.ready");
            }
        }
    }

    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
        onExited: {
            greeter.resumeRevision++;
            greeter.restartAuth();
        }
    }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: greeterWindow
            required property var modelData

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"

            WlrLayershell.namespace: "serpantinum-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0]
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

            LockScreen {
                surface: greeterWindow
                root: greeter
                rootLock: greeterLockState
                pam: null
                lockUI: greeterUI
                suspendProcess: suspendProc
                reloadProcess: rebootProc
                poweroffProcess: poweroffProc
            }

            Shortcut {
                enabled: greeter.testMode
                sequence: "Ctrl+Escape"
                onActivated: Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        SystemInfo.fetch();
        greeter.startSession();
    }
}
