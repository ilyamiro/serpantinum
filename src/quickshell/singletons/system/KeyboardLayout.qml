pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

Singleton {
    id: root

    property string layout: "US"
    property string fullLayout: ""
    property bool ready: false
    property int subscribers: 0
    readonly property bool active: subscribers > 0

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
        if (Compositor.name === "niri") {
            NiriState.subscribe();
            applyNiriLayout();
            return;
        }
        if (Compositor.name === "sway") {
            SwayState.subscribeKeyboard();
            applySwayLayout();
            return;
        }
        if (Compositor.name === "mango") {
            MangoState.subscribeKeyboard();
            applyMangoLayout();
            return;
        }
        if (Compositor.name === "umbriel") {
            UmbrielState.subscribeKeyboard();
            applyUmbrielLayout();
            return;
        }
        if (Compositor.name !== "hyprland") return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function stop() {
        root.ready = false;
        if (Compositor.name === "niri") {
            NiriState.unsubscribe();
            return;
        }
        if (Compositor.name === "sway") {
            SwayState.unsubscribeKeyboard();
            return;
        }
        if (Compositor.name === "mango") {
            MangoState.unsubscribeKeyboard();
            return;
        }
        if (Compositor.name === "umbriel") {
            UmbrielState.unsubscribeKeyboard();
            return;
        }
        devicesPoller.running = false;
    }

    function refresh() {
        if (!active || Compositor.name !== "hyprland") return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function switchNext() {
        if (Compositor.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (Compositor.name === "sway") {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else if (Compositor.name === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        } else if (Compositor.name === "umbriel") {
            Quickshell.execDetached(["umbriel", "msg", "keyboard-layout-next"]);
        } else if (Compositor.name === "hyprland") {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    function applyNiriLayout() {
        if (!NiriState.keyboardReady) return;
        let name = NiriState.keyboardLayout;
        if (name !== "") {
            root.applyLayoutName(name);
            return;
        }
        let txt = NiriState.shortKeyboardLayout;
        if (txt !== "") {
            root.layout = txt;
            root.fullLayout = txt;
        }
        root.ready = true;
    }

    Connections {
        target: NiriState
        enabled: Compositor.name === "niri" && root.active
        function onKeyboardLayoutChanged() { root.applyNiriLayout(); }
        function onShortKeyboardLayoutChanged() { root.applyNiriLayout(); }
        function onKeyboardReadyChanged() { root.applyNiriLayout(); }
    }

    function applySwayLayout() {
        if (!SwayState.keyboardReady) return;
        let name = SwayState.keyboardLayout;
        if (name !== "") {
            root.applyLayoutName(name);
            return;
        }
        root.layout = SwayState.shortKeyboardLayout;
        root.fullLayout = SwayState.shortKeyboardLayout;
        root.ready = true;
    }

    Connections {
        target: SwayState
        enabled: Compositor.name === "sway" && root.active
        function onKeyboardLayoutChanged() { root.applySwayLayout(); }
        function onShortKeyboardLayoutChanged() { root.applySwayLayout(); }
        function onKeyboardReadyChanged() { root.applySwayLayout(); }
    }

    function applyMangoLayout() {
        if (!MangoState.keyboardReady) return;
        root.applyLayoutName(MangoState.keyboardLayout);
    }

    Connections {
        target: MangoState
        enabled: Compositor.name === "mango" && root.active
        function onKeyboardLayoutChanged() { root.applyMangoLayout(); }
        function onKeyboardReadyChanged() { root.applyMangoLayout(); }
    }

    function applyUmbrielLayout() {
        if (!UmbrielState.keyboardReady) return;
        root.applyLayoutName(UmbrielState.keyboardLayout);
    }

    Connections {
        target: UmbrielState
        enabled: Compositor.name === "umbriel" && root.active
        function onKeyboardLayoutChanged() { root.applyUmbrielLayout(); }
        function onKeyboardReadyChanged() { root.applyUmbrielLayout(); }
    }

    function applyLayoutName(name) {
        let raw = (name && name !== "null") ? String(name).trim() : "";
        let txt = raw !== "" ? raw : "US";
        let shortCode = txt.substring(0, 2).toUpperCase();
        root.layout = shortCode;
        root.fullLayout = raw !== "" ? raw : shortCode;
        root.ready = true;
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        enabled: Compositor.name === "hyprland" && root.active
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
}
