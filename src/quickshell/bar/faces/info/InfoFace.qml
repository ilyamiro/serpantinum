import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool isCleaningUp: false
    property bool isRecording: false
    property int recSeconds: 0
    property real recStartEpoch: 0
    property string recTimeFormatted: String(Math.floor(recSeconds / 60)).padStart(2, "0") + ":" + String(recSeconds % 60).padStart(2, "0")
    readonly property string recCacheDir: Caching.cacheDir ? Caching.getCacheDir("recording") : ""

    readonly property var timerEntries: TimerState.entries
    readonly property bool isTimerActive: timerEntries.length > 0
    readonly property color greenColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.green !== undefined) ? ThemeBackend.green : Qt.rgba(166/255, 227/255, 161/255, 1.0)

    readonly property bool hasActiveContent: isRecording || isTimerActive

    property alias recRow: recLayout
    property alias recCol: recLayout
    property alias timerRow: timerLayout
    property alias timerCol: timerLayout

    function checkRecording() {
        if (root.isCleaningUp || (module && !module.moduleActive) || root.recCacheDir === "") return;
        recCheckProc.running = false;
        recCheckProc.running = true;
    }

    onIsRecordingChanged: {
        if (!isRecording) {
            recSeconds = 0;
            recStartEpoch = 0;
        }
    }

    onRecCacheDirChanged: {
        if (recCacheDir !== "") {
            root.checkRecording();
        }
    }

    Process {
        id: recCheckProc
        command: root.recCacheDir ? [
            "bash", "-c",
            "d='" + root.recCacheDir + "'; if [ -f \"$d/rec_pid\" ] && [ -f \"$d/rec_start_epoch\" ]; then p=$(cat \"$d/rec_pid\" 2>/dev/null); if [ -n \"$p\" ] && kill -0 \"$p\" 2>/dev/null; then cat \"$d/rec_start_epoch\" 2>/dev/null; else echo 'NONE'; fi; else echo 'NONE'; fi"
        ] : []
        stdout: StdioCollector {
            id: recCheckOut
            onStreamFinished: {
                let txt = recCheckOut.text.trim();
                let epoch = parseInt(txt);
                if (!isNaN(epoch) && epoch > 0) {
                    root.recStartEpoch = epoch;
                    root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
                    root.isRecording = true;
                } else {
                    root.isRecording = false;
                }
            }
        }
    }

    Process {
        id: recWatcher
        running: !root.isCleaningUp && (!module || module.moduleActive) && root.recCacheDir !== ""
        command: root.recCacheDir ? [
            "bash", "-c",
            "mkdir -p '" + root.recCacheDir + "' && exec inotifywait -m -e create,delete,modify,moved_to,moved_from '" + root.recCacheDir + "' 2>/dev/null"
        ] : []
        stdout: SplitParser {
            onRead: data => {
                root.checkRecording();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 127 || root.isCleaningUp) return;
            if ((!module || module.moduleActive) && root.recCacheDir !== "") {
                recWatcherRestartTimer.restart();
            }
        }
    }

    Timer {
        id: recWatcherRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isCleaningUp && (!module || module.moduleActive) && root.recCacheDir !== "" && !recWatcher.running) {
                recWatcher.running = true;
            }
        }
    }

    Timer {
        id: recElapsedTimer
        interval: 1000
        running: !root.isCleaningUp && (!module || module.moduleActive) && root.isRecording
        repeat: true
        onTriggered: {
            root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - root.recStartEpoch));
            if (root.recSeconds % 5 === 0) {
                root.checkRecording();
            }
        }
    }

    property real lengthPadding: barWindow ? barWindow.cs(isCompact ? 10 : 12) : (isCompact ? 10 : 12)
    property real innerSpacing: isVertical ? (barWindow ? barWindow.cs(isCompact ? 8 : 10) : (isCompact ? 8 : 10)) : (barWindow ? barWindow.cs(isCompact ? 10 : 12) : (isCompact ? 10 : 12))

    property real recLength: isRecording ? (isVertical ? recLayout.implicitHeight : recLayout.implicitWidth) : 0
    property real timerLength: isTimerActive ? (isVertical ? timerLayout.implicitHeight : timerLayout.implicitWidth) : 0
    property real activeSpacing: (isRecording && isTimerActive) ? innerSpacing : 0
    property real targetLength: hasActiveContent ? (recLength + timerLength + activeSpacing + (lengthPadding * 2)) : 0
    property bool showLayout: false
    property bool isFaceVisible: showLayout && hasActiveContent && targetLength > 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: root.showLayout = true
    }

    Item {
        id: topArea
        anchors.fill: parent

        AxisFlow {
            id: centerActiveLayout
            vertical: root.isVertical
            horizontalItemAlignment: Grid.AlignHCenter
            anchors.centerIn: parent
            spacing: root.innerSpacing

            AxisFlow {
                id: recLayout
                vertical: root.isVertical
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                spacing: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)) : (barWindow ? barWindow.cs(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6))
                visible: root.isRecording
                opacity: root.isRecording ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: barWindow ? !barWindow.positionChanging : true
                    NumberAnimation { duration: 300 }
                }

                Rectangle {
                    id: recDot
                    width: barWindow ? barWindow.cs(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                    height: barWindow ? barWindow.cs(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                    radius: width * 0.5
                    color: root.isCompact ? Qt.lighter(ThemeBackend.red, 1.08) : ThemeBackend.red

                    SequentialAnimation on opacity {
                        running: root.isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    id: recText
                    text: root.recTimeFormatted
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)) : (barWindow ? barWindow.cs(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14))
                    font.weight: Font.Bold
                    color: root.isCompact ? Qt.lighter(ThemeBackend.red, 1.08) : ThemeBackend.red
                }
            }

            AxisFlow {
                id: timerLayout
                vertical: root.isVertical
                horizontalItemAlignment: Grid.AlignHCenter
                spacing: root.innerSpacing
                visible: root.isTimerActive

                Repeater {
                    model: root.timerEntries

                    AxisFlow {
                        id: timerItem
                        vertical: root.isVertical
                        horizontalItemAlignment: Grid.AlignHCenter
                        verticalItemAlignment: Grid.AlignVCenter
                        required property var modelData
                        readonly property color entryColor: modelData.colorType === "green" ? root.greenColor : ThemeBackend.mauve
                        spacing: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)) : (barWindow ? barWindow.cs(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6))

                        Text {
                            text: timerItem.modelData.icon
                            font.family: "Font Awesome 6 Free Solid"
                            font.pixelSize: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 10 : 11) : (root.isCompact ? 10 : 11)) : (barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12))
                            color: root.isCompact ? Qt.lighter(timerItem.entryColor, 1.08) : timerItem.entryColor
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

                        Text {
                            text: timerItem.modelData.time
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)) : (barWindow ? barWindow.cs(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14))
                            font.weight: Font.Bold
                            color: root.isCompact ? Qt.lighter(timerItem.entryColor, 1.08) : timerItem.entryColor
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.checkRecording();
    }

    Component.onDestruction: {
        root.isCleaningUp = true;
        recWatcherRestartTimer.stop();
        recWatcher.running = false;
        recCheckProc.running = false;
    }
}
