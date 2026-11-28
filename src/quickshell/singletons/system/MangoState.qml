pragma Singleton
import QtQuick
import Quickshell
import "../../"

CompositorStateBase {
    id: root

    property int tagCount: 0
    property var occupiedByOutput: ({})
    property var clients: []
    signal clientsUpdated()

    property string keyboardLayout: ""
    property bool keyboardReady: false

    watching: Compositor.name === "mango" && active

    function isOccupied(outputName, index) {
        let perOutput = (outputName && occupiedByOutput) ? occupiedByOutput[outputName] : null;
        if (perOutput) return Boolean(perOutput[index]);
        return Boolean(occupiedMap[index]);
    }

    onCoreState: state => {
        let ws = state.workspaces || {};
        root.applyWorkspaces(ws);
        root.assign("occupiedByOutput", ws.occupiedByOutput || {});
        if (ws.tagCount !== undefined && root.tagCount !== ws.tagCount) root.tagCount = ws.tagCount;
        if (root.assign("clients", Array.isArray(state.windows) ? state.windows : [])) root.clientsUpdated();
        if (state.keyboard) {
            if (root.keyboardLayout !== state.keyboard.layout) root.keyboardLayout = state.keyboard.layout;
            root.keyboardReady = true;
        }
    }
}
