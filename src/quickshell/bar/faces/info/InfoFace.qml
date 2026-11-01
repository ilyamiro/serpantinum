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

    readonly property bool isRecording: RecordingState.isRecording
    readonly property string recTimeFormatted: RecordingState.recTimeFormatted
    readonly property bool wantsRecording: !module || module.moduleActive
    property bool recSubscribed: false

    readonly property var timerEntries: TimerState.entries
    readonly property bool isTimerActive: timerEntries.length > 0
    readonly property color greenColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.green !== undefined) ? ThemeBackend.green : Qt.rgba(166/255, 227/255, 161/255, 1.0)

    readonly property bool hasActiveContent: isRecording || isTimerActive

    property alias recRow: recLayout
    property alias recCol: recLayout
    property alias timerRow: timerLayout
    property alias timerCol: timerLayout

    function syncRecordingSubscription() {
        if (wantsRecording === recSubscribed) return;
        recSubscribed = wantsRecording;
        if (wantsRecording) RecordingState.subscribe();
        else RecordingState.unsubscribe();
    }

    onWantsRecordingChanged: syncRecordingSubscription()

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
                    NumberAnimation { duration: 250 }
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
                            font.family: ThemeBackend.iconFont
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

    Component.onCompleted: syncRecordingSubscription()

    Component.onDestruction: {
        if (recSubscribed) RecordingState.unsubscribe();
    }
}
