pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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
    readonly property string compositor: isMango ? "mango" : "hyprland"

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
        kbPoller.running = false;
        kbPoller.running = true;
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
        kbPoller.running = false;
        kbWaiter.running = false;
    }

    function refresh() {
        if (!active || isNiri) return;
        if (isSway) {
            SwayState.refreshKeyboard();
            return;
        }
        kbWaiter.running = false;
        kbPoller.running = false;
        kbPoller.running = true;
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

    Process {
        id: kbPoller
        command: [
            "bash",
            "-c",
            root.isMango
                ? "layout=$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : "layout=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") root.layout = txt;
                root.ready = true;
                if (root.active && !root.isNiri && !kbWaiter.running) kbWaiter.running = true;
            }
        }
    }

    Process {
        id: kbWaiter
        command: ["bash", Caching.qsDir + "/watchers/kb_wait.sh", root.compositor]
        onExited: {
            kbPoller.running = false;
            if (root.active && !root.isNiri) kbPoller.running = true;
        }
    }
}
