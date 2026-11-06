import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: base

    property int activeIndex: 0
    property var activeIndicesByOutput: ({})
    property var occupiedMap: ({})

    property bool watching: false
    signal coreState(var state)

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }

    function assign(name, value) {
        if (JSON.stringify(base[name]) === JSON.stringify(value)) return false;
        base[name] = value;
        return true;
    }

    function applyWorkspaces(ws) {
        if (!ws) return;
        if (ws.activeIndex !== undefined && base.activeIndex !== ws.activeIndex) base.activeIndex = ws.activeIndex;
        assign("activeIndicesByOutput", ws.activeIndicesByOutput || {});
        assign("occupiedMap", ws.occupiedMap || {});
    }

    Process {
        id: coreWatch
        running: base.watching
        command: ["serpantinum-core", "watch", "compositor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let state;
                try {
                    state = JSON.parse(data);
                } catch (e) {
                    return;
                }
                if (state) base.coreState(state);
            }
        }
        onExited: {
            if (base.watching) coreRestart.restart();
        }
    }

    Timer {
        id: coreRestart
        interval: 1000
        repeat: false
        onTriggered: {
            if (base.watching && !coreWatch.running) coreWatch.running = true;
        }
    }
}
