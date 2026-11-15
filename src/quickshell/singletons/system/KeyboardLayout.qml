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
        if (Compositor.name !== "hyprland") return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function stop() {
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
        } else {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    // Apply the selected XKB layout/variant list to Hyprland at runtime.
    // Keyboard layout configuration is persisted separately in General settings.
    function applyHyprlandLayouts(layouts) {
        if (Compositor.name !== "hyprland" || !Array.isArray(layouts) || layouts.length === 0) return false;

        let layoutCodes = [];
        let variants = [];
        for (let i = 0; i < layouts.length; i++) {
            let item = layouts[i];
            let layout = typeof item === "string" ? item : String(item.layout || "");
            let variant = typeof item === "string" ? "" : String(item.variant || "");
            let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-/";
            if (layout.length === 0 || layout.split("").some(ch => allowed.indexOf(ch) < 0)) continue;
            if (variant.split("").some(ch => allowed.indexOf(ch) < 0)) continue;
            layoutCodes.push(layout);
            variants.push(variant);
        }
        if (layoutCodes.length === 0) return false;

        // This Serpantinum Hyprland setup uses the Lua configuration API.
        // `hyprctl keyword` is not supported by that provider; use `hyprctl eval`.
        // Layout and variant values are validated above before embedding them in Lua.
        let lua = "hl.config({ input = { kb_layout = \"" + layoutCodes.join(",")
            + "\", kb_variant = \"" + variants.join(",") + "\" } })";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
        return true;
    }


    Component.onCompleted: {
        if (Compositor.name !== "hyprland" || !Config.dataReady) return;
        let settings = Config.getSetting("general", {});
        if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
            root.applyHyprlandLayouts(settings.keyboardLayouts);
    }


    Connections {
        target: Config
        function onSettingsLoaded() {
            if (Compositor.name !== "hyprland") return;
            let settings = Config.getSetting("general", {});
            if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
                root.applyHyprlandLayouts(settings.keyboardLayouts);
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
        enabled: Compositor.name === "niri" && root.active
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
        enabled: Compositor.name === "sway" && root.active
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

    function applyLayoutName(name) {
        let txt = (name && name !== "null") ? String(name) : "US";
        root.layout = txt.substring(0, 2).toUpperCase();
        root.ready = true;
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        enabled: Compositor.name === "hyprland" && root.active
        function onRawEvent(event) {
            if (!event) return;
            if (event.name === "configreloaded") {
                let settings = Config.getSetting("general", {});
                if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
                    root.applyHyprlandLayouts(settings.keyboardLayouts);
                return;
            }
            if (event.name !== "activelayout") return;
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
