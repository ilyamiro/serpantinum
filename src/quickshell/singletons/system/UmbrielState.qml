pragma Singleton
import QtQuick
import Quickshell
import "../../"

CompositorStateBase {
    id: root

    property var countByOutput: ({})
    property int workspaceCount: 0
    property var occupiedByOutput: ({})
    property string focusedOutput: ""
    property var windows: []
    signal windowsUpdated()

    property string keyboardLayout: ""
    property var keyboardLayouts: []
    property bool keyboardReady: false

    property int workspaceSubscribers: 0
    property int windowSubscribers: 0
    property int keyboardSubscribers: 0

    watching: Compositor.name === "umbriel" && (workspaceSubscribers + windowSubscribers + keyboardSubscribers) > 0

    function subscribe() {
        workspaceSubscribers++;
    }

    function unsubscribe() {
        workspaceSubscribers = Math.max(0, workspaceSubscribers - 1);
    }

    function subscribeClients() {
        windowSubscribers++;
    }

    function unsubscribeClients() {
        windowSubscribers = Math.max(0, windowSubscribers - 1);
    }

    function subscribeKeyboard() {
        keyboardSubscribers++;
    }

    function unsubscribeKeyboard() {
        keyboardSubscribers = Math.max(0, keyboardSubscribers - 1);
    }

    function isOccupied(outputName, index) {
        let perOutput = (outputName && occupiedByOutput) ? occupiedByOutput[outputName] : null;
        if (perOutput) return Boolean(perOutput[index]);
        return Boolean(occupiedMap[index]);
    }

    function countFor(outputName) {
        let count = (outputName && countByOutput) ? countByOutput[outputName] : undefined;
        return count !== undefined ? count : workspaceCount;
    }

    function dispatch(action, args) {
        let list = args || [];
        Quickshell.execDetached(["sh", "-c", 'umbriel msg "$@" 2>/dev/null || umbriel msg "$1:$2"', "sh", action].concat(list));
    }

    onCoreState: state => {
        let ws = state.workspaces || {};
        root.applyWorkspaces(ws);
        root.assign("occupiedByOutput", ws.occupiedByOutput || {});
        root.assign("countByOutput", ws.countByOutput || {});
        if (ws.workspaceCount !== undefined && root.workspaceCount !== ws.workspaceCount) root.workspaceCount = ws.workspaceCount;
        let focused = ws.focusedOutput || "";
        if (root.focusedOutput !== focused) root.focusedOutput = focused;
        if (root.assign("windows", Array.isArray(state.windows) ? state.windows : [])) root.windowsUpdated();
        if (state.keyboard) {
            if (root.keyboardLayout !== state.keyboard.layout) root.keyboardLayout = state.keyboard.layout;
            root.assign("keyboardLayouts", state.keyboard.layouts || []);
            root.keyboardReady = true;
        }
    }
}
