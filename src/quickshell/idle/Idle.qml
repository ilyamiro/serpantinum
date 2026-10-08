import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../"

Item {
    id: idleRoot

    property bool isNiri: {
        let de = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        if (de.indexOf("niri") !== -1) return true;
        let xdg = (typeof Quickshell !== "undefined" && Quickshell.env) ? (Quickshell.env("XDG_CURRENT_DESKTOP") || "") : "";
        return xdg.toLowerCase().indexOf("niri") !== -1;
    }

    property var defaultIdleSettings: ({
        "enabled": false,
        "manualInhibit": false,
        "actions": {
            "dim": {
                "id": "dim",
                "name": "Dim Screen",
                "timeout": 120,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": false,
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
                "mprisInhibit": false,
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
                "mprisInhibit": false,
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
                "mprisInhibit": false,
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
        }
    }

    property bool idleEnabled: idleSettings && idleSettings.enabled !== undefined ? idleSettings.enabled : false
    property bool manualInhibit: idleSettings && idleSettings.manualInhibit !== undefined ? idleSettings.manualInhibit : false
    property bool isIdleSystemActive: idleEnabled && !manualInhibit
    property bool isDimmed: false
    property bool isLocked: false

    property bool isMediaPlaying: {
        try {
            return Mpris.players && Mpris.players.values ? Mpris.players.values.some(p => p.playbackState === MprisPlaybackState.Playing) : false;
        } catch (e) {
            return false;
        }
    }

    // Set while an app asks org.freedesktop.ScreenSaver not to lock (games, Steam, Wine)
    property bool isAppInhibited: false

    Process {
        id: screensaverProc
        running: Caching.qsDir !== ""
        command: ["python3", Caching.qsDir + "/idle/screensaver_inhibit.py"]
        stdout: SplitParser {
            onRead: data => idleRoot.isAppInhibited = data.trim() === "1"
        }
        onExited: (exitCode, exitStatus) => {
            idleRoot.isAppInhibited = false;
            // 0 means python-jeepney is missing, no point in retrying
            if (exitCode !== 0) screensaverRestartTimer.restart();
        }
    }

    Timer {
        id: screensaverRestartTimer
        interval: 10000
        onTriggered: screensaverProc.running = true
    }

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

    function lockSession() {
        Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/lock.sh"]);
    }

    function performLock() {
        idleRoot.isLocked = true;
        idleRoot.lockSession();
    }

    function dpmsOff() {
        if (idleRoot.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })' 2>/dev/null || hyprctl dispatch dpms off"]);
        }
    }

    function dpmsOn() {
        if (idleRoot.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })' 2>/dev/null || hyprctl dispatch dpms on"]);
        }
    }

    function teardownVisualStates() {
        if (idleRoot.isDimmed) {
            idleRoot.isDimmed = false;
        }
    }

    function triggerWarning(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;
        if (actionObj.warningCommand && actionObj.warningCommand.trim().length > 0) {
            idleRoot.runCmd(actionObj.warningCommand);
        }
    }

    function triggerAction(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;

        let id = (actionObj.id || "").toLowerCase();

        if (id === "dim") {
            if (!idleRoot.isLocked) {
                if (actionObj.beforeCommand && actionObj.beforeCommand.trim().length > 0) {
                    idleRoot.runCmd(actionObj.beforeCommand);
                }
                idleRoot.isDimmed = true;
                if (actionObj.command && actionObj.command.trim().length > 0) {
                    idleRoot.runCmd(actionObj.command);
                }
            }
            return;
        }

        idleRoot.teardownVisualStates();

        if (id === "lock") {
            if (actionObj.beforeCommand && actionObj.beforeCommand.trim().length > 0) {
                idleRoot.runCmd(actionObj.beforeCommand);
            }
            frameSettleTimer.pendingCallback = function() {
                idleRoot.performLock();
                if (actionObj.command && actionObj.command.trim().length > 0) {
                    idleRoot.runCmd(actionObj.command);
                }
            };
            frameSettleTimer.restart();
            return;
        }

        if (id === "dpms") {
            if (actionObj.beforeCommand && actionObj.beforeCommand.trim().length > 0) {
                idleRoot.runCmd(actionObj.beforeCommand);
            }
            idleRoot.dpmsOff();
            if (actionObj.command && actionObj.command.trim().length > 0) {
                idleRoot.runCmd(actionObj.command);
            }
            return;
        }

        if (id === "suspend") {
            if (!idleRoot.isLocked) {
                idleRoot.performLock();
            }
            if (actionObj.command && actionObj.command.trim().length > 0) {
                idleRoot.runCmd(actionObj.command);
            }
            suspendTimer.restart();
            return;
        }

        if (actionObj.beforeCommand && actionObj.beforeCommand.trim().length > 0) {
            idleRoot.runCmd(actionObj.beforeCommand);
        }
        if (actionObj.command && actionObj.command.trim().length > 0) {
            idleRoot.runCmd(actionObj.command);
        }
    }

    function resumeAction(actionObj) {
        if (!actionObj) return;

        let id = (actionObj.id || "").toLowerCase();
        if (id === "dim") {
            idleRoot.isDimmed = false;
        } else if (id === "lock") {
            frameSettleTimer.stop();
            idleRoot.isLocked = false;
        } else if (id === "dpms") {
            if (actionObj.resumeCommand && actionObj.resumeCommand.trim().length > 0) {
                idleRoot.runCmd(actionObj.resumeCommand);
            } else {
                idleRoot.dpmsOn();
            }
            return;
        } else if (id === "suspend") {
            suspendTimer.stop();
            return;
        }

        if (actionObj.resumeCommand && actionObj.resumeCommand.trim().length > 0) {
            idleRoot.runCmd(actionObj.resumeCommand);
        }
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
