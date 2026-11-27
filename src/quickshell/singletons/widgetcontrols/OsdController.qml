pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../"
import "../../reusables"

Item {
    id: controller

    property bool isVisible: false
    property string kind: "volume"
    property int briVal: Brightness.value
    property string stateVal: "off"
    property string layoutName: ""
    property var screen: null
    property bool isHovered: false
    property bool isFullscreen: false

    readonly property PwNode activeSink: Audio.effectiveSink
    readonly property real sysVolume: Audio.sinkVolumePercent
    readonly property bool sysMuted: Audio.sinkMuted

    readonly property PwNode activeSource: Audio.effectiveSource
    readonly property real sysMicVolume: Audio.sourceVolumePercent
    readonly property bool sysMicMuted: Audio.sourceMuted

    readonly property bool wifiRadioEnabled: Connectivity.wifiEnabled
    readonly property bool btRadioEnabled: Connectivity.bluetoothEnabled
    readonly property bool sysAirplane: Connectivity.airplaneMode

    readonly property int sysBrightness: Brightness.value
    readonly property bool brightnessInitialized: Brightness.initialized
    readonly property string brightnessBackend: Brightness.backend

    property real lastVolume: -1
    property bool lastMuted: false
    property real lastMicVolume: -1
    property bool lastMicMuted: false
    property bool lastAirplane: false
    property int lastCapsLock: -1
    property int lastNumLock: -1
    property int lastBrightness: -1
    property bool kbInitialized: false
    property bool wantsKeyboardLayout: false
    property bool kbLayoutInitialized: false
    property bool kbLayoutSettling: false
    property string lastKeyboardLayout: ""
    property bool isInitialized: false

    SubscriptionGate {
        target: KeyboardLayout
        wanted: controller.wantsKeyboardLayout
    }

    function readWantsKeyboardLayout() {
        if (typeof Config === "undefined") return false;
        let osd = (Config.rawSettings && Config.rawSettings.osd) ? Config.rawSettings.osd : null;
        if (!osd && typeof Config.getSetting === "function") {
            osd = Config.getSetting("osd", null);
        }
        if (!osd || osd.showKeyboardLayout !== true) return false;
        return osd.orientation !== "vertical";
    }

    function syncKeyboardLayoutSetting() {
        let enabled = readWantsKeyboardLayout();
        if (enabled === controller.wantsKeyboardLayout) return;
        let wasInactive = !KeyboardLayout.active;
        if (enabled) {
            controller.kbLayoutInitialized = false;
            controller.lastKeyboardLayout = "";
            controller.wantsKeyboardLayout = true;
            if (wasInactive) {
                controller.kbLayoutSettling = true;
                kbLayoutSettleTimer.restart();
            }
            if (KeyboardLayout.ready) {
                controller.lastKeyboardLayout = KeyboardLayout.fullLayout || KeyboardLayout.layout;
                controller.kbLayoutInitialized = true;
            }
        } else {
            kbLayoutSettleTimer.stop();
            controller.kbLayoutSettling = false;
            controller.kbLayoutInitialized = false;
            controller.lastKeyboardLayout = "";
            controller.wantsKeyboardLayout = false;
        }
    }

    function handleKeyboardLayoutUpdate() {
        if (!controller.wantsKeyboardLayout || !KeyboardLayout.ready) return;
        let current = KeyboardLayout.fullLayout || KeyboardLayout.layout;
        if (!current) return;
        if (!controller.kbLayoutInitialized || !controller.isInitialized || controller.kbLayoutSettling) {
            controller.lastKeyboardLayout = current;
            controller.kbLayoutInitialized = true;
            return;
        }
        if (current !== controller.lastKeyboardLayout) {
            controller.lastKeyboardLayout = current;
            controller.show("layout", KeyboardLayout.layout);
        }
    }

    Timer {
        id: kbLayoutSettleTimer
        interval: 250
        repeat: false
        onTriggered: {
            controller.kbLayoutSettling = false;
            if (controller.wantsKeyboardLayout && KeyboardLayout.ready) {
                controller.lastKeyboardLayout = KeyboardLayout.fullLayout || KeyboardLayout.layout;
                controller.kbLayoutInitialized = true;
            }
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { controller.syncKeyboardLayoutSetting(); }
        function onRawSettingsChanged() { controller.syncKeyboardLayoutSetting(); }
    }

    Connections {
        target: KeyboardLayout
        enabled: controller.wantsKeyboardLayout
        function onFullLayoutChanged() { controller.handleKeyboardLayoutUpdate(); }
        function onReadyChanged() { controller.handleKeyboardLayoutUpdate(); }
    }

    Component.onCompleted: {
        controller.syncKeyboardLayoutSetting();
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (!controller.isHovered) {
                controller.isVisible = false;
            }
        }
    }

    Timer {
        id: initTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            controller.lastVolume = controller.sysVolume;
            controller.lastMuted = controller.sysMuted;
            controller.lastMicVolume = controller.sysMicVolume;
            controller.lastMicMuted = controller.sysMicMuted;
            controller.lastAirplane = controller.sysAirplane;
            controller.lastBrightness = controller.sysBrightness;
            if (controller.wantsKeyboardLayout && KeyboardLayout.ready) {
                controller.lastKeyboardLayout = KeyboardLayout.fullLayout || KeyboardLayout.layout;
                controller.kbLayoutInitialized = true;
            }
            controller.isInitialized = true;
        }
    }

    onSysVolumeChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastVolume !== controller.sysVolume) {
            controller.lastVolume = controller.sysVolume;
            controller.show("volume");
        }
    }

    onSysMutedChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMuted !== controller.sysMuted) {
            controller.lastMuted = controller.sysMuted;
            controller.show("volume");
        }
    }

    onSysMicVolumeChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMicVolume !== controller.sysMicVolume) {
            controller.lastMicVolume = controller.sysMicVolume;
            controller.show("mic");
        }
    }

    onSysMicMutedChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMicMuted !== controller.sysMicMuted) {
            controller.lastMicMuted = controller.sysMicMuted;
            controller.show("mic");
        }
    }

    onSysAirplaneChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastAirplane !== controller.sysAirplane) {
            controller.lastAirplane = controller.sysAirplane;
            controller.show("airplane", controller.sysAirplane ? "on" : "off");
        }
    }

    onBrightnessInitializedChanged: {
        if (controller.brightnessInitialized) {
            controller.lastBrightness = controller.sysBrightness;
            controller.briVal = controller.sysBrightness;
        }
    }

    onSysBrightnessChanged: {
        controller.briVal = controller.sysBrightness;
        if (!controller.isInitialized || !controller.brightnessInitialized) {
            controller.lastBrightness = controller.sysBrightness;
            return;
        }
        if (controller.lastBrightness !== controller.sysBrightness) {
            controller.lastBrightness = controller.sysBrightness;
            controller.show("brightness");
        }
    }

    JsonStreamProcess {
        id: kbWatcher
        active: true
        command: ["serpantinum-core", "watch", "locks"]
        onMessage: locks => {
            let caps = locks.capsLock ? 1 : 0;
            let num = locks.numLock ? 1 : 0;
            if (!controller.kbInitialized) {
                controller.lastCapsLock = caps;
                controller.lastNumLock = num;
                controller.kbInitialized = true;
                return;
            }
            if (caps !== controller.lastCapsLock) {
                controller.lastCapsLock = caps;
                controller.show("capslock", caps === 1 ? "on" : "off");
            }
            if (num !== controller.lastNumLock) {
                controller.lastNumLock = num;
                controller.show("numlock", num === 1 ? "on" : "off");
            }
        }
    }

    function show(k, v, scr) {
        controller.kind = k || "volume";
        if (controller.kind === "brightness" && v !== undefined) {
            controller.briVal = parseInt(v) || 0;
        } else if (controller.kind === "layout") {
            controller.stateVal = (v !== undefined && v !== "") ? v.toString() : KeyboardLayout.layout;
            controller.layoutName = KeyboardLayout.fullLayout;
        } else if (v !== undefined) {
            controller.stateVal = v.toString();
        }
        if (scr !== undefined && scr !== null) {
            controller.screen = scr;
        }
        controller.isVisible = true;
        hideTimer.restart();
    }

    function display(k, v, scr) {
        show(k, v, scr);
    }

    IpcHandler {
        target: "osd"

        function show(kind: string): void {
            controller.show(kind);
        }

        function display(kind: string): void {
            controller.show(kind);
        }
    }

    function hide() {
        hideTimer.stop();
        controller.isVisible = false;
    }

    function requestHide() {
        if (!controller.isHovered) {
            hideTimer.restart();
        }
    }

    function cancelHide() {
        hideTimer.stop();
    }

    function restartTimer() {
        if (controller.isVisible) {
            hideTimer.restart();
        }
    }

    function toggle(k, v, scr) {
        if (controller.isVisible && controller.kind === k) {
            hide();
        } else {
            show(k, v, scr);
        }
    }
}
