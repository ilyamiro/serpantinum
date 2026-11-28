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

    watching: Compositor.name === "sway" && active

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
