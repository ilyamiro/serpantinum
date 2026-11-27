pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

RefCountedService {
    id: root

    property string layout: "US"
    property string fullLayout: ""
    property bool ready: false
    property string mainKeyboard: ""

    onActivated: start()
    onDeactivated: stop()

    function start() {
        if (Compositor.name === "hyprland") {
            devicesPoller.running = false;
            devicesPoller.running = true;
            return;
        }
        Compositor.subscribe();
        applyCompositorLayout();
    }

    function stop() {
        root.ready = false;
        if (Compositor.name === "hyprland") {
            devicesPoller.running = false;
            return;
        }
        Compositor.unsubscribe();
    }

    function refresh() {
        if (!active || Compositor.name !== "hyprland") return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function switchNext() {
        Compositor.switchKeyboardLayout();
    }

    function applyCompositorLayout() {
        if (Compositor.name === "niri") applyNiriLayout();
        else if (Compositor.name === "sway") applySwayLayout();
        else if (Compositor.name === "mango") applyMangoLayout();
        else if (Compositor.name === "umbriel") applyUmbrielLayout();
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
