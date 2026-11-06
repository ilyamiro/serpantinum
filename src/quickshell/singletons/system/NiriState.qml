pragma Singleton
import QtQuick
import Quickshell
import "../../"

CompositorStateBase {
    id: root


    property var existingMap: ({})
    property int maxWorkspaceIndex: 0
    property var windowsMap: ({})
    property var workspacesMap: ({})
    signal windowsUpdated()

    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0
    property bool keyboardReady: false
    readonly property string keyboardLayout: (keyboardLayouts && keyboardLayouts.length > keyboardLayoutIndex && keyboardLayouts[keyboardLayoutIndex]) ? keyboardLayouts[keyboardLayoutIndex] : ""
    readonly property string shortKeyboardLayout: keyboardLayout ? keyboardLayout.substring(0, 2).toUpperCase() : "US"

    property int subscribers: 0

    watching: Compositor.name === "niri" && subscribers > 0

    function subscribe() {
        subscribers++;
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
    }

    onCoreState: state => {
        let ws = state.workspaces || {};
        root.applyWorkspaces(ws);
        root.assign("existingMap", ws.existingMap || {});
        if (ws.maxWorkspaceIndex !== undefined && root.maxWorkspaceIndex !== ws.maxWorkspaceIndex) root.maxWorkspaceIndex = ws.maxWorkspaceIndex;
        let workspacesChanged = root.assign("workspacesMap", ws.map || {});
        let windowsChanged = root.assign("windowsMap", state.windows || {});
        if (workspacesChanged || windowsChanged) root.windowsUpdated();
        if (state.keyboard) {
            root.assign("keyboardLayouts", state.keyboard.layouts || []);
            if (root.keyboardLayoutIndex !== state.keyboard.index) root.keyboardLayoutIndex = state.keyboard.index || 0;
            root.keyboardReady = true;
        }
    }
}
