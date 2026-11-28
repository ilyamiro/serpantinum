import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"

Row {
    id: root
    layoutDirection: I18n.layoutDirection
    spacing: root.s(6)

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    property bool allowEmpty: false
    property bool manageSelection: true
    property bool autoLoadMonitors: true
    property bool interactive: true

    property var monitors: autoLoadMonitors ? getQuickshellScreenNames() : []
    property var selectedMonitors: null

    property real buttonHeight: root.s(26)
    property real buttonCornerRadius: root.s(6)
    property real buttonHorizontalPadding: root.s(8)
    property int textFontSize: Math.round(root.s(10))

    property color activeColor: ThemeBackend.text
    property color activeTextColor: ThemeBackend.base
    property color inactiveColor: ThemeBackend.surface1
    property color inactiveTextColor: ThemeBackend.text
    property real bgOpacity: ThemeBackend.elementOpacity

    signal selectionChanged(var selectedMonitors)

    function getQuickshellScreenNames() {
        let names = [];
        let screens = Quickshell.screens;
        if (!screens) return names;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name) {
                names.push(screens[i].name);
            }
        }
        return names;
    }

    function updateMonitors(names) {
        let clean = [];
        if (Array.isArray(names)) {
            for (let i = 0; i < names.length; i++) {
                if (names[i] && clean.indexOf(names[i]) === -1) {
                    clean.push(String(names[i]));
                }
            }
        }
        if (Array.isArray(root.monitors) && root.monitors.length === clean.length) {
            let same = true;
            for (let i = 0; i < clean.length; i++) {
                if (root.monitors[i] !== clean[i]) {
                    same = false;
                    break;
                }
            }
            if (same) return;
        }
        root.monitors = clean;
    }

    function reloadMonitors() {
        if (!root.autoLoadMonitors) return;
        if (root.monitors.length === 0) {
            root.updateMonitors(root.getQuickshellScreenNames());
        }
        monitorDetector.running = false;
        monitorDetector.running = true;
    }

    function isMonitorSelected(name) {
        if (!Array.isArray(root.selectedMonitors)) return true;
        return root.selectedMonitors.indexOf(name) !== -1;
    }

    function getSelectedList() {
        let active = [];
        if (!Array.isArray(root.monitors)) return active;
        for (let i = 0; i < root.monitors.length; i++) {
            let m = root.monitors[i];
            if (root.isMonitorSelected(m)) {
                active.push(m);
            }
        }
        return active;
    }

    function getOutputs() {
        if (!Array.isArray(root.monitors) || root.monitors.length <= 1) return "all";
        let active = root.getSelectedList();
        if (active.length === 0) return "none";
        if (active.length === root.monitors.length) return "all";
        return active.join(",");
    }

    function applySelection(next) {
        if (root.manageSelection) {
            root.selectedMonitors = next;
        }
        root.selectionChanged(next);
    }

    function toggleMonitor(name) {
        if (!name || !root.interactive || !root.enabled) return;
        let current = root.getSelectedList();
        let idx = current.indexOf(name);
        if (idx !== -1) {
            if (!root.allowEmpty && current.length <= 1) return;
            current.splice(idx, 1);
        } else {
            current.push(name);
        }
        let next = (root.monitors.length > 0 && current.length === root.monitors.length) ? null : current;
        root.applySelection(next);
    }

    Process {
        id: monitorDetector
        running: false
        command: ["serpantinum-core", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                let names = [];
                try {
                    let parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed)) {
                        for (let i = 0; i < parsed.length; i++) {
                            if (parsed[i] && parsed[i].name) names.push(parsed[i].name);
                        }
                    }
                } catch (e) {}
                if (names.length > 0) {
                    root.updateMonitors(names);
                } else {
                    root.updateMonitors(root.getQuickshellScreenNames());
                }
            }
        }
    }

    Connections {
        target: Quickshell
        enabled: root.autoLoadMonitors
        function onScreensChanged() {
            root.reloadMonitors();
        }
    }

    Component.onCompleted: {
        if (root.autoLoadMonitors) {
            root.reloadMonitors();
        }
    }

    Repeater {
        model: root.monitors
        delegate: ClickButton {
            required property string modelData
            readonly property bool selected: root.isMonitorSelected(modelData)

            height: root.buttonHeight
            cornerRadius: Math.round(root.buttonCornerRadius)
            horizontalPadding: Math.round(root.buttonHorizontalPadding)
            buttonText: modelData
            textFontSize: root.textFontSize
            accentColor: selected ? root.activeColor : root.inactiveColor
            bgOpacity: root.bgOpacity
            textColor: selected ? root.activeTextColor : root.inactiveTextColor
            enabled: root.enabled && root.interactive
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            onClicked: root.toggleMonitor(modelData)
        }
    }
}
