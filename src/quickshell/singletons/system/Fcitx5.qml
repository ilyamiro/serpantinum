pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property bool enabled: Config.getSetting("bar", {}).kbUseFcitx5 === true
    property int subscribers: 0
    readonly property bool active: enabled && subscribers > 0
    readonly property bool available: active && connected && bridge.running
    property bool connected: false
    property bool supported: true
    property string layout: ""

    function subscribe() { subscribers++; }
    function unsubscribe() { if (subscribers > 0) subscribers--; }
    function switchNext() { if (available) bridge.write("next\n"); }

    onActiveChanged: {
        connected = false;
        supported = true;
        bridge.running = active;
    }

    Process {
        id: bridge
        command: ["python3", Qt.resolvedUrl("fcitx5-bar.py").toString().replace(/^file:\/\//, "")]
        stdinEnabled: true
        onExited: (exitCode, exitStatus) => {
            root.connected = false;
            if (exitCode === 3) root.supported = false;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    let status = JSON.parse(data);
                    root.connected = status.available === true && typeof status.label === "string";
                    if (root.connected) root.layout = status.label;
                } catch (error) {
                    root.connected = false;
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("Fcitx5:", data)
        }
    }

    Timer {
        interval: 2000
        running: root.active && root.supported && !bridge.running
        repeat: true
        onTriggered: bridge.running = true
    }
}
