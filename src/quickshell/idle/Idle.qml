import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../"

Item {
    id: idleRoot

    property var defaultIdleSettings: ({
        "enabled": false,
        "manualInhibit": false,
        "lockOnSleep": true,
        "actions": {
            "dim": {
                "id": "dim",
                "name": "Dim Screen",
                "timeout": 120,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "lock": {
                "id": "lock",
                "name": "Lock Session",
                "timeout": 300,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 10,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "dpms": {
                "id": "dpms",
                "name": "Display Off (DPMS)",
                "timeout": 360,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "suspend": {
                "id": "suspend",
                "name": "System Suspend",
                "timeout": 600,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 30,
                "warningCommand": "",
                "isCustom": false
            }
        },
        "customActions": []
    })

    property var idleSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["idle"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("idle", idleRoot.defaultIdleSettings);
        }
        return idleRoot.defaultIdleSettings;
    }

    property bool caffeineActive: false
    property double caffeineStartTime: 0
    property double caffeineEndTime: 0
    property int caffeineSecondsLeft: 0
    property int caffeineMinutesLeft: caffeineSecondsLeft > 0 ? Math.max(1, Math.ceil(caffeineSecondsLeft / 60)) : 0

    function _persistCaffeine(enabled) {
        if (typeof Config === "undefined") return;
        let idleObj = Object.assign({}, Config.getSetting("idle", {}));
        idleObj.manualInhibit = enabled;
        idleObj.caffeineStartTime = enabled ? idleRoot.caffeineStartTime : 0;
        idleObj.caffeineEndTime = enabled ? idleRoot.caffeineEndTime : 0;
        Config.setSetting("idle", idleObj);
    }

    function _updateCaffeineRemaining() {
        if (!idleRoot.caffeineActive || idleRoot.caffeineEndTime <= 0) {
            idleRoot.caffeineSecondsLeft = 0;
            return;
        }
        let diff = Math.round((idleRoot.caffeineEndTime - Date.now()) / 1000);
        if (diff <= 0) {
            idleRoot.caffeineSecondsLeft = 0;
            idleRoot.disableCaffeine();
        } else {
            idleRoot.caffeineSecondsLeft = diff;
        }
    }

    function enableCaffeine(minutes) {
        let now = Date.now();
        let mins = (minutes !== undefined && minutes !== null) ? Number(minutes) : 0;
        let durationMs = mins > 0 ? Math.round(mins * 60 * 1000) : 0;
        idleRoot.caffeineStartTime = now;
        idleRoot.caffeineEndTime = durationMs > 0 ? now + durationMs : 0;
        idleRoot.caffeineActive = true;
        idleRoot._updateCaffeineRemaining();
        idleRoot._persistCaffeine(true);
    }

    function increaseCaffeine(minutes) {
        let addMins = (minutes !== undefined && minutes !== null && Number(minutes) > 0) ? Number(minutes) : 60;
        let addMs = Math.round(addMins * 60 * 1000);
        let now = Date.now();
        if (!idleRoot.caffeineActive || idleRoot.caffeineEndTime <= now) {
            idleRoot.enableCaffeine(addMins);
        } else {
            idleRoot.caffeineEndTime += addMs;
            idleRoot._updateCaffeineRemaining();
            idleRoot._persistCaffeine(true);
        }
    }

    function disableCaffeine() {
        idleRoot.caffeineActive = false;
        idleRoot.caffeineStartTime = 0;
        idleRoot.caffeineEndTime = 0;
        idleRoot.caffeineSecondsLeft = 0;
        idleRoot._persistCaffeine(false);
    }

    function toggleCaffeine() {
        if (idleRoot.caffeineActive) {
            idleRoot.disableCaffeine();
        } else {
            idleRoot.enableCaffeine(0);
        }
    }

    function syncCaffeineFromConfig() {
        if (typeof Config === "undefined") return;
        let idleObj = Config.getSetting("idle", {}) || {};
        let endTime = Number(idleObj.caffeineEndTime) || 0;
        if (!idleObj.manualInhibit) {
            idleRoot.caffeineActive = false;
            idleRoot.caffeineStartTime = 0;
            idleRoot.caffeineEndTime = 0;
            idleRoot.caffeineSecondsLeft = 0;
        } else if (endTime > 0 && endTime <= Date.now()) {
            idleRoot.disableCaffeine();
        } else {
            idleRoot.caffeineStartTime = Number(idleObj.caffeineStartTime) || 0;
            idleRoot.caffeineEndTime = endTime;
            idleRoot.caffeineActive = true;
            idleRoot._updateCaffeineRemaining();
        }
    }

    Timer {
        id: caffeineTimer
        interval: 1000
        repeat: true
        running: idleRoot.caffeineActive && idleRoot.caffeineEndTime > 0
        triggeredOnStart: true
        onTriggered: idleRoot._updateCaffeineRemaining()
    }

    Component.onCompleted: {
        idleRoot.syncCaffeineFromConfig();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            idleRoot.idleSettings = Qt.binding(function() {
                let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["idle"] : undefined;
                if (s !== undefined && s !== null) return s;
                if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
                    return Config.getSetting("idle", idleRoot.defaultIdleSettings);
                }
                return idleRoot.defaultIdleSettings;
            });
            idleRoot.syncCaffeineFromConfig();
        }
        function onRawSettingsChanged() {
            idleRoot.syncCaffeineFromConfig();
        }
    }

    property bool idleEnabled: idleSettings && idleSettings.enabled !== undefined ? idleSettings.enabled : false
    property bool manualInhibit: idleRoot.caffeineActive
    property bool isIdleSystemActive: idleEnabled && !manualInhibit
    property bool lockOnSleep: idleSettings && idleSettings.lockOnSleep !== undefined ? idleSettings.lockOnSleep : true
    property bool isDimmed: false
    property bool isLocked: false

    property bool isMediaPlaying: {
        try {
            return Mpris.players && Mpris.players.values ? Mpris.players.values.some(p => p.playbackState === MprisPlaybackState.Playing) : false;
        } catch (e) {
            return false;
        }
    }

    property bool isAppInhibited: false

    Process {
        id: idleHelperProc
        running: Caching.qsDir !== ""
        stdinEnabled: true
        command: ["serpantinum-core", "watch", "idle", Caching.getRunDir("lock") + "/locked"]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line === "inhibit 1") idleRoot.isAppInhibited = true;
                else if (line === "inhibit 0") idleRoot.isAppInhibited = false;
                else if (line === "sleep" && idleRoot.lockOnSleep) idleRoot.lockSession(true);
                else if (line === "wake") idleRoot.reauthLockSession();
            }
        }
        onStarted: idleRoot.syncSleepLock()
        onExited: (exitCode, exitStatus) => {
            idleRoot.isAppInhibited = false;
            if (exitCode !== 0) idleHelperRestartTimer.restart();
        }
    }

    Timer {
        id: idleHelperRestartTimer
        interval: 10000
        onTriggered: idleHelperProc.running = true
    }

    function syncSleepLock() {
        if (idleHelperProc.running) idleHelperProc.write("sleep-lock " + (idleRoot.lockOnSleep ? "on" : "off") + "\n");
    }

    onLockOnSleepChanged: syncSleepLock()

    property var allActions: {
        let list = [];
        let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
        let keys = ["dim", "lock", "dpms", "suspend"];

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let act = (acts && acts[key]) ? Object.assign({}, defaultIdleSettings.actions[key], acts[key]) : defaultIdleSettings.actions[key];
            list.push(act);
        }

        let customs = (idleSettings && idleSettings.customActions) ? idleSettings.customActions : [];
        for (let j = 0; j < customs.length; j++) {
            list.push(customs[j]);
        }
        return list;
    }

    function getActionTimeout(act) {
        if (!act || act.timeout === undefined || act.timeout === null || isNaN(act.timeout) || act.timeout <= 0) {
            if (act && act.id === "dim") return 120;
            if (act && act.id === "lock") return 300;
            if (act && act.id === "dpms") return 360;
            if (act && act.id === "suspend") return 600;
            return 300;
        }
        return Math.max(1, Math.round(Number(act.timeout)));
    }

    function isActionPipelineValid(actionObj) {
        if (!actionObj) return false;
        let id = (actionObj.id || "").toLowerCase();
        let builtInOrder = ["dim", "lock", "dpms", "suspend"];
        let idx = builtInOrder.indexOf(id);
        if (idx === -1) return true;

        let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
        let myTimeout = idleRoot.getActionTimeout(actionObj);

        for (let j = idx + 1; j < builtInOrder.length; j++) {
            let nextKey = builtInOrder[j];
            let nextAct = (acts && acts[nextKey]) ? Object.assign({}, defaultIdleSettings.actions[nextKey], acts[nextKey]) : defaultIdleSettings.actions[nextKey];
            let nextEnabled = nextAct && nextAct.enabled !== undefined ? nextAct.enabled : true;
            if (nextEnabled) {
                let nextTimeout = idleRoot.getActionTimeout(nextAct);
                if (myTimeout >= nextTimeout) return false;
            }
        }
        return true;
    }

    Timer {
        id: frameSettleTimer
        interval: 100
        repeat: false
        property var pendingCallback: null
        onTriggered: {
            if (pendingCallback) {
                pendingCallback();
                pendingCallback = null;
            }
        }
    }

    Timer {
        id: suspendTimer
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    function runCmd(cmd) {
        if (cmd && cmd.trim().length > 0) {
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    function lockSession(isStatic) {
        let cmd = ["bash", Caching.serpantinumDir + "/scripts/lock.sh"];
        if (isStatic === true) cmd.push("--static");
        Quickshell.execDetached(cmd);
    }

    function reauthLockSession() {
        Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/lock.sh", "--reauth"]);
    }

    function performLock() {
        idleRoot.isLocked = true;
        idleRoot.lockSession();
    }

    function dpmsOff() {
        Compositor.setDpms(false);
    }

    function dpmsOn() {
        Compositor.setDpms(true);
    }

    function teardownVisualStates() {
        if (idleRoot.isDimmed) {
            idleRoot.isDimmed = false;
        }
    }

    readonly property var builtInActionHandlers: ({
        "dim": {
            trigger: function(actionObj) {
                if (idleRoot.isLocked) return;
                idleRoot.runCmd(actionObj.beforeCommand);
                idleRoot.isDimmed = true;
                idleRoot.runCmd(actionObj.command);
            },
            resume: function(actionObj) {
                idleRoot.isDimmed = false;
                idleRoot.runCmd(actionObj.resumeCommand);
            }
        },
        "lock": {
            trigger: function(actionObj) {
                idleRoot.teardownVisualStates();
                idleRoot.runCmd(actionObj.beforeCommand);
                frameSettleTimer.pendingCallback = function() {
                    idleRoot.performLock();
                    idleRoot.runCmd(actionObj.command);
                };
                frameSettleTimer.restart();
            },
            resume: function(actionObj) {
                frameSettleTimer.stop();
                idleRoot.isLocked = false;
                idleRoot.runCmd(actionObj.resumeCommand);
            }
        },
        "dpms": {
            trigger: function(actionObj) {
                idleRoot.teardownVisualStates();
                idleRoot.runCmd(actionObj.beforeCommand);
                idleRoot.dpmsOff();
                idleRoot.runCmd(actionObj.command);
            },
            resume: function(actionObj) {
                if (actionObj.resumeCommand && actionObj.resumeCommand.trim().length > 0) {
                    idleRoot.runCmd(actionObj.resumeCommand);
                } else {
                    idleRoot.dpmsOn();
                }
            }
        },
        "suspend": {
            trigger: function(actionObj) {
                idleRoot.teardownVisualStates();
                if (!idleRoot.isLocked) {
                    idleRoot.performLock();
                }
                idleRoot.runCmd(actionObj.command);
                suspendTimer.restart();
            },
            resume: function(actionObj) {
                suspendTimer.stop();
            }
        }
    })

    function triggerWarning(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;
        idleRoot.runCmd(actionObj.warningCommand);
    }

    function triggerAction(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;

        let id = (actionObj.id || "").toLowerCase();
        let handler = idleRoot.builtInActionHandlers[id];
        if (handler && typeof handler.trigger === "function") {
            handler.trigger(actionObj);
            return;
        }

        idleRoot.teardownVisualStates();
        idleRoot.runCmd(actionObj.beforeCommand);
        idleRoot.runCmd(actionObj.command);
    }

    function resumeAction(actionObj) {
        if (!actionObj) return;

        let id = (actionObj.id || "").toLowerCase();
        let handler = idleRoot.builtInActionHandlers[id];
        if (handler && typeof handler.resume === "function") {
            handler.resume(actionObj);
            return;
        }

        idleRoot.runCmd(actionObj.resumeCommand);
    }

    function executeAction(name) {
        if (!name) return;
        let target = name.toString().trim().toLowerCase();
        let actionObj = idleRoot.allActions.find(a => (a.id && a.id.toLowerCase() === target) || (a.name && a.name.toLowerCase() === target));
        if (actionObj) {
            idleRoot.triggerAction(actionObj);
        }
    }

    IpcHandler {
        target: "idle"
        function trigger(name: string): void { idleRoot.executeAction(name); }
        function execute(name: string): void { idleRoot.executeAction(name); }
        function run(name: string): void { idleRoot.executeAction(name); }
        function status(): string { return idleRoot.statusJson(); }
    }

    function statusJson() {
        return JSON.stringify({
            "active": idleRoot.isIdleSystemActive,
            "enabled": idleRoot.idleEnabled,
            "caffeine": {
                "on": idleRoot.caffeineActive,
                "remaining": idleRoot.caffeineActive && idleRoot.caffeineEndTime > 0 ? Math.max(0, Math.round((idleRoot.caffeineEndTime - Date.now()) / 1000)) : 0
            },
            "appInhibited": idleRoot.isAppInhibited,
            "mediaPlaying": idleRoot.isMediaPlaying,
            "locked": idleRoot.isLocked,
            "dimmed": idleRoot.isDimmed,
            "actions": idleRoot.allActions.map(a => ({
                "id": a.id,
                "enabled": a.enabled !== undefined ? a.enabled : true,
                "timeout": idleRoot.getActionTimeout(a),
                "valid": idleRoot.isActionPipelineValid(a),
                "respectInhibitors": a.respectInhibitors !== undefined ? a.respectInhibitors : true,
                "mprisInhibit": !!a.mprisInhibit
            }))
        }, null, 2);
    }

    Dim {
        active: idleRoot.isIdleSystemActive && idleRoot.isDimmed
    }

    Repeater {
        model: idleRoot.allActions
        delegate: Item {
            id: monitorDelegate
            required property var modelData

            property int actionTimeout: idleRoot.getActionTimeout(monitorDelegate.modelData)
            property int warnLead: Math.round(Number(monitorDelegate.modelData && monitorDelegate.modelData.warningTimeout ? monitorDelegate.modelData.warningTimeout : 0))
            property int warnTimeout: Math.max(1, actionTimeout - warnLead)
            property bool hasWarning: monitorDelegate.modelData && monitorDelegate.modelData.warningCommand && monitorDelegate.modelData.warningCommand.trim().length > 0 && warnLead > 0 && warnLead < actionTimeout
            property bool isActionEnabled: monitorDelegate.modelData && monitorDelegate.modelData.enabled !== undefined ? monitorDelegate.modelData.enabled : true
            property bool isValidInPipeline: idleRoot.isActionPipelineValid(monitorDelegate.modelData)
            property bool respectsInhibitors: monitorDelegate.modelData && monitorDelegate.modelData.respectInhibitors !== undefined ? monitorDelegate.modelData.respectInhibitors : true

            IdleMonitor {
                timeout: monitorDelegate.warnTimeout
                enabled: idleRoot.isIdleSystemActive &&
                         monitorDelegate.isValidInPipeline &&
                         monitorDelegate.isActionEnabled &&
                         monitorDelegate.hasWarning &&
                         (!monitorDelegate.modelData || !monitorDelegate.modelData.mprisInhibit || !idleRoot.isMediaPlaying) &&
                         (!monitorDelegate.respectsInhibitors || !idleRoot.isAppInhibited)
                respectInhibitors: monitorDelegate.respectsInhibitors

                onIsIdleChanged: {
                    if (isIdle) {
                        idleRoot.triggerWarning(monitorDelegate.modelData);
                    }
                }
            }

            IdleMonitor {
                timeout: monitorDelegate.actionTimeout
                enabled: idleRoot.isIdleSystemActive &&
                         monitorDelegate.isValidInPipeline &&
                         monitorDelegate.isActionEnabled &&
                         (!monitorDelegate.modelData || !monitorDelegate.modelData.mprisInhibit || !idleRoot.isMediaPlaying) &&
                         (!monitorDelegate.respectsInhibitors || !idleRoot.isAppInhibited)
                respectInhibitors: monitorDelegate.respectsInhibitors

                onIsIdleChanged: {
                    if (isIdle) {
                        idleRoot.triggerAction(monitorDelegate.modelData);
                    } else {
                        idleRoot.resumeAction(monitorDelegate.modelData);
                    }
                }
            }
        }
    }

    Loader {
        active: idleRoot.manualInhibit
        sourceComponent: PanelWindow {
            id: inhibitWindow
            color: "transparent"
            screen: (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
            anchors.top: true
            anchors.left: true
            implicitWidth: 1
            implicitHeight: 1
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            IdleInhibitor {
                window: inhibitWindow
                enabled: true
            }
        }
    }
}
