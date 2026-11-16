import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"
import ".."

PanelWindow {
    id: win
    color: "transparent"

    required property var host

    property alias redactorMode: redactorMode
    property alias activeWidgetsModel: redactorMode.activeWidgetsModel

    property string monitorName: {
        if (host.targetMonitorName && host.targetMonitorName !== "") {
            return host.targetMonitorName;
        }
        let envMon = Quickshell.env("QS_WIDGET_MONITOR");
        if (envMon && envMon.trim() !== "") return envMon.trim();
        return (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
    }

    property var targetScreen: {
        let scr = Quickshell.screens.find(s => s.name === win.monitorName);
        return scr || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }
    readonly property string safeMonitorName: (monitorName || (targetScreen ? targetScreen.name : "default")).replace(/[^a-zA-Z0-9_-]/g, "_")
    screen: win.targetScreen

    WlrLayershell.namespace: "qs-widget-redactor-" + win.safeMonitorName
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    margins.left: 0
    margins.top: 0

    function s(val) { return Scaler.s(val); }

    Timer {
        id: exitTimer
        interval: 100
        repeat: false
        onTriggered: host.close()
    }

    function exitRedactor() {
        redactorMode.selectedId = "";
        host.targetSelectedWidgetId = "";
        WidgetSync.setRedactMode(win.safeMonitorName, false);
        exitTimer.start();
    }

    Component.onDestruction: {
        redactorMode.selectedId = "";
        host.targetSelectedWidgetId = "";
        WidgetSync.setRedactMode(win.safeMonitorName, false);
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (redactorMode.toolbar.dismiss()) return;
            redactorMode.selectedId = "";
            win.exitRedactor();
        }
    }

    Shortcut {
        sequence: "Ctrl+Z"
        onActivated: redactorMode.undo()
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
        onActivated: redactorMode.redo()
    }

    Shortcut {
        sequence: "Left"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(-1, 0, false)
    }

    Shortcut {
        sequence: "Right"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(1, 0, false)
    }

    Shortcut {
        sequence: "Up"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(0, -1, false)
    }

    Shortcut {
        sequence: "Down"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(0, 1, false)
    }

    Shortcut {
        sequence: "Shift+Left"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(-1, 0, true)
    }

    Shortcut {
        sequence: "Shift+Right"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(1, 0, true)
    }

    Shortcut {
        sequence: "Shift+Up"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(0, -1, true)
    }

    Shortcut {
        sequence: "Shift+Down"
        enabled: redactorMode.canNudge
        onActivated: redactorMode.nudgeSelected(0, 1, true)
    }

    RedactorWorkspace {
        id: redactorMode
        host: win.host
        redactorWindow: win
    }
}
