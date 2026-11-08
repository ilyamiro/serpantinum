import QtQuick
import "../../"
import "../../../"

FocusPanel {
    id: root

    property bool persistView: false
    property string iconFont: ThemeBackend.iconFont
    property int presetMs: 0
    property bool presetTouched: false

    readonly property bool isTimerIdle: FocusTimer.isTimerIdle
    readonly property bool isTimerRunning: FocusTimer.isTimerRunning
    readonly property bool isEditingTime: stateSelector.visible && stateSelector.isEditing

    readonly property var interceptedShortcuts: isEditingTime || isTimerIdle
        ? ["Return", "Enter", "Left", "Right", "Up", "Down"]
        : ["Return", "Enter"]

    function syncFromBackend() {
        if (!presetTouched) presetMs = FocusTimer.timerPresetMs;
    }

    function toggle() {
        if (isEditingTime) return;
        FocusTimer.toggleMode(0, presetMs);
    }

    function resetOrClear() {
        if (isTimerIdle) {
            presetTouched = true;
            presetMs = 0;
            if (persistView) FocusTimer.setTimerPreset(0);
        } else {
            FocusTimer.resetTimer();
        }
    }

    Component.onCompleted: syncFromBackend()

    Connections {
        target: FocusTimer
        function onStateLoadedChanged() { root.syncFromBackend(); }
    }

    Shortcut { enabled: root.visible && root.isActiveTab && !root.isEditingTime; sequence: "Return"; onActivated: root.toggle() }
    Shortcut { enabled: root.visible && root.isActiveTab && !root.isEditingTime; sequence: "Enter"; onActivated: root.toggle() }

    Item {
        anchors.fill: parent
        anchors.margins: root.padding

        Item {
            id: contentArea
            anchors.top: parent.top
            anchors.bottom: controls.top
            anchors.left: parent.left
            anchors.right: parent.right

            FocusTimeCard {
                padX: root.s(26)
                padY: root.s(10)
                visible: !root.isTimerIdle
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: root.contentGap < 0 ? parent.verticalCenter : undefined
                anchors.bottom: root.contentGap >= 0 ? parent.bottom : undefined
                anchors.bottomMargin: Math.max(0, root.contentGap)

                Text {
                    text: FocusTimer.formatTime(FocusTimer.timerRemainingMs, false)
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(68)
                    color: FocusTimer.timerRemainingMs === 0 && !root.isTimerRunning ? ThemeBackend.mauve : ThemeBackend.text
                }
            }

            TimeSelector {
                id: stateSelector
                visible: root.isTimerIdle
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: root.contentGap < 0 ? parent.verticalCenter : undefined
                anchors.bottom: root.contentGap >= 0 ? parent.bottom : undefined
                anchors.bottomMargin: Math.max(0, root.contentGap)
                valueMs: root.presetMs
                isActive: root.visible && root.isActiveTab && root.isTimerIdle
                isWidgetVisible: root.widgetVisible
                iconFont: root.iconFont
                baseColor: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: root.alpha(ThemeBackend.surface1, 0.5)
                activeTextColor: ThemeBackend.mantle
                scaleMultiplier: 1.4
                onValueChanged: function(newMs) {
                    root.presetTouched = true;
                    root.presetMs = newMs;
                    if (root.persistView) FocusTimer.setTimerPreset(newMs);
                }
            }
        }

        FocusTimerControls {
            id: controls
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.s(10)
            anchors.left: parent.left
            anchors.right: parent.right
            scaleFn: root.scaleFn
            leftIcon: ""
            playIcon: root.isTimerRunning ? "" : ""
            onLeftClicked: root.resetOrClear()
            onPlayClicked: root.toggle()
        }
    }
}
