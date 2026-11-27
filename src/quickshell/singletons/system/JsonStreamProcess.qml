import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var command: []
    property bool active: false
    property int restartInterval: 1000
    property int maxRetries: 0
    property string splitMarker: "\n"
    property bool running: false

    property int _retries: 0
    property bool _restarting: false
    property bool _exhausted: false
    property bool _destroying: false

    signal message(var data)
    signal exited(int exitCode, int exitStatus)

    Component.onDestruction: {
        _destroying = true;
        restartTimer.stop();
        running = false;
    }

    onActiveChanged: {
        if (!active) {
            restartTimer.stop();
            _restarting = false;
            _exhausted = false;
            _retries = 0;
        } else {
            _exhausted = false;
            _retries = 0;
        }
    }

    Process {
        id: proc
        running: root.active && !root._restarting && !root._exhausted && Array.isArray(root.command) && root.command.length > 0
        command: root.command
        onRunningChanged: {
            if (!root._destroying) root.running = Boolean(running);
        }
        stdout: SplitParser {
            splitMarker: root.splitMarker
            onRead: data => {
                if (!root.active) return;
                let parsed;
                try {
                    parsed = JSON.parse(data);
                } catch (e) {
                    return;
                }
                if (parsed !== undefined && parsed !== null) {
                    root._retries = 0;
                    root.message(parsed);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.exited(exitCode, exitStatus);
            if (!root.active) return;
            if (root.maxRetries > 0 && root._retries >= root.maxRetries) {
                root._exhausted = true;
                return;
            }
            root._retries++;
            root._restarting = true;
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: Math.max(1, root.restartInterval)
        repeat: false
        onTriggered: {
            root._restarting = false;
        }
    }
}
