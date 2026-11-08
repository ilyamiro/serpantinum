import QtQuick
import QtQuick.Window
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 200
    property real minHeight: 120
    property real maxWidth: 800
    property real maxHeight: 700
    property real minAspect: 0.8
    property real maxAspect: 2.2
    property bool isRound: false

    property bool armed: false
    property bool gotFocus: false
    readonly property bool menuOpen: DesktopMenuController.isVisible
    readonly property bool wantsKeyboardFocus: (armed && !menuOpen) || (panelLoader.item !== null && panelLoader.item.isEditingTime === true)

    onMenuOpenChanged: {
        if (menuOpen) {
            armed = false;
            gotFocus = false;
        }
    }

    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onActiveChanged() {
            if (root.Window.active) {
                root.gotFocus = true;
            } else if (root.gotFocus) {
                root.gotFocus = false;
                root.armed = false;
            }
        }
    }

    Shortcut {
        enabled: root.Window.active && !(panelLoader.item !== null && panelLoader.item.isEditingTime === true)
        sequence: "Escape"
        onActivated: root.armed = false
    }

    property int fixedMode: 0

    readonly property real baseW: Scaler.s(360)
    readonly property real baseH: Scaler.s(280)

    Item {
        id: stage
        width: root.baseW
        height: root.baseH
        transformOrigin: Item.TopLeft
        scale: Math.min(parent.width / root.baseW, parent.height / root.baseH)
        x: (parent.width - width * scale) / 2
        y: (parent.height - height * scale) / 2

        Loader {
            id: panelLoader
            anchors.fill: parent
            sourceComponent: root.fixedMode === 1 ? stopwatchPanel : (root.fixedMode === 2 ? pomodoroPanel : timerPanel)
        }
    }

    Component {
        id: timerPanel
        FocusTimerPanel {
            scaleFn: Scaler.s
            isActiveTab: root.Window.active
            contentGap: Scaler.s(16)
        }
    }

    Component {
        id: stopwatchPanel
        FocusStopwatchPanel {
            scaleFn: Scaler.s
            isActiveTab: root.Window.active
            contentGap: Scaler.s(16)
        }
    }

    Component {
        id: pomodoroPanel
        FocusPomodoroPanel {
            scaleFn: Scaler.s
            isActiveTab: root.Window.active
            contentGap: Scaler.s(16)
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            if (!root.menuOpen) root.armed = true;
            mouse.accepted = false;
        }
    }
}
