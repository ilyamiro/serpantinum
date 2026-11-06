pragma Singleton
import QtQuick
import Quickshell
import "../../"

CompositorStateBase {
    id: root

    property var windows: []
    signal windowsUpdated()

    property string keyboardLayout: ""
    property bool keyboardReady: false
    readonly property string shortKeyboardLayout: keyboardLayout ? keyboardLayout.substring(0, 2).toUpperCase() : "US"

    property int workspaceSubscribers: 0
    property int windowSubscribers: 0
    property int keyboardSubscribers: 0

    watching: Compositor.name === "sway" && (workspaceSubscribers + windowSubscribers + keyboardSubscribers) > 0

    function subscribe() {
        workspaceSubscribers++;
    }

    function unsubscribe() {
        workspaceSubscribers = Math.max(0, workspaceSubscribers - 1);
    }

    function subscribeWindows() {
        windowSubscribers++;
    }

    function unsubscribeWindows() {
        windowSubscribers = Math.max(0, windowSubscribers - 1);
    }

    function subscribeKeyboard() {
        keyboardSubscribers++;
    }

    function unsubscribeKeyboard() {
        keyboardSubscribers = Math.max(0, keyboardSubscribers - 1);
    }

    function focusWorkspace(index) {
        Quickshell.execDetached(["swaymsg", "workspace", "number", String(index + 1)]);
    }

    onCoreState: state => {
        root.applyWorkspaces(state.workspaces);
        if (root.assign("windows", Array.isArray(state.windows) ? state.windows : [])) root.windowsUpdated();
        if (state.keyboard) {
            if (root.keyboardLayout !== state.keyboard.layout) root.keyboardLayout = state.keyboard.layout;
            root.keyboardReady = true;
        }
    }
}
