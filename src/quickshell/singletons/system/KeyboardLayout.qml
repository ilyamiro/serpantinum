pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

Singleton {
    id: root

    property string layout: "US"
    property bool ready: false
    property int subscribers: 0
    readonly property bool active: subscribers > 0

    readonly property bool isNiri: NiriState.isNiri
    readonly property bool isMango: MangoState.isMango
    readonly property bool isSway: !isNiri && SwayState.isSway
    readonly property bool isHyprland: !isNiri && !isMango && !isSway
    property string mainKeyboard: ""

    function subscribe() {
        subscribers++;
        if (subscribers === 1) start();
    }

    function unsubscribe() {
        if (subscribers <= 0) return;
        subscribers--;
        if (subscribers === 0) stop();
    }

    function start() {
        if (isNiri) {
            NiriState.subscribe();
            applyNiriLayout();
            return;
        }
        if (isSway) {
            SwayState.subscribeKeyboard();
            applySwayLayout();
            return;
        }
        if (isMango) {
            mangoLayoutStream.running = true;
            return;
        }
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function stop() {
        if (isNiri) {
            NiriState.unsubscribe();
            return;
        }
        if (isSway) {
            SwayState.unsubscribeKeyboard();
            return;
        }
        mangoRestartTimer.stop();
        mangoLayoutStream.running = false;
        devicesPoller.running = false;
    }

    function refresh() {
        if (!active || isNiri) return;
        if (isSway) {
            SwayState.refreshKeyboard();
            return;
        }
        if (isMango) {
            mangoLayoutStream.running = false;
            mangoLayoutStream.running = true;
            return;
        }
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function switchNext() {
        if (isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (isSway) {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else if (isMango) {
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        } else {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    function applyNiriLayout() {
        if (!NiriState.keyboardReady) return;
        let txt = NiriState.shortKeyboardLayout;
        if (txt !== "") root.layout = txt;
        root.ready = true;
    }

    Connections {
        target: NiriState
        enabled: root.isNiri && root.active
        function onShortKeyboardLayoutChanged() { root.applyNiriLayout(); }
        function onKeyboardReadyChanged() { root.applyNiriLayout(); }
    }

    function applySwayLayout() {
        if (!SwayState.keyboardReady) return;
        root.layout = SwayState.shortKeyboardLayout;
        root.ready = true;
    }

    Connections {
        target: SwayState
        enabled: root.isSway && root.active
        function onShortKeyboardLayoutChanged() { root.applySwayLayout(); }
        function onKeyboardReadyChanged() { root.applySwayLayout(); }
    }

    function applyLayoutName(name) {
        let txt = (name && name !== "null") ? String(name) : "US";
        root.layout = txt.substring(0, 2).toUpperCase();
        root.ready = true;
    }

    Connections {
        target: root.isHyprland ? Hyprland : null
        enabled: root.isHyprland && root.active
        function onRawEvent(event) {
            if (!event || event.name !== "activelayout") return;
            let args = event.parse(2);
            if (args.length === 2 && root.mainKeyboard !== "" && args[0] === root.mainKeyboard) {
                root.applyLayoutName(args[1]);
            } else if (!devicesPoller.running) {
                devicesPoller.running = true;
            }
        }
    }

    Process {
        id: devicesPoller
        command: ["hyprctl", "devices", "-j"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                let keyboards = [];
                try {
                    keyboards = JSON.parse(this.text).keyboards || [];
                } catch (e) {}
                let kb = keyboards.find(k => k.main === true) || keyboards[0] || null;
                root.mainKeyboard = kb ? String(kb.name || "") : "";
                root.applyLayoutName(kb ? kb.active_keymap : "");
            }
        }
    }

    Process {
        id: mangoLayoutStream
        command: ["mmsg", "watch", "keyboardlayout"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let payload = null;
                try {
                    payload = JSON.parse(data);
                } catch (e) {
                    return;
                }
                root.applyLayoutName(payload ? payload.layout : "");
            }
        }
        onExited: {
            if (root.active && root.isMango) mangoRestartTimer.restart();
        }
    }

    Timer {
        id: mangoRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.active && root.isMango && !mangoLayoutStream.running) mangoLayoutStream.running = true;
        }
    }
}
