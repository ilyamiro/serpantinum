import QtQuick
import QtQuick.Layouts
import "../../"
import "../../../"

FocusPanel {
    id: root

    readonly property bool isRunning: FocusTimer.isStopwatchRunning
    readonly property var interceptedShortcuts: ["Return", "Enter"]

    property real liveMs: 0
    readonly property real displayMs: fastTicker.running ? liveMs : FocusTimer.swDisplayMs

    function toggle() {
        FocusTimer.toggleMode(1);
    }

    Timer {
        id: fastTicker
        interval: 32
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.widgetVisible && FocusTimer.isStopwatchRunning
        onTriggered: root.liveMs = FocusTimer.swAccumulatedMs + (Date.now() - FocusTimer.swStartEpoch)
    }

    Shortcut { enabled: root.visible && root.isActiveTab; sequence: "Return"; onActivated: root.toggle() }
    Shortcut { enabled: root.visible && root.isActiveTab; sequence: "Enter"; onActivated: root.toggle() }

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
                id: card
                padX: root.s(26)
                padY: root.s(10)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: root.contentGap < 0 ? parent.verticalCenter : undefined
                anchors.bottom: root.contentGap >= 0 ? parent.bottom : undefined
                anchors.bottomMargin: Math.max(0, root.contentGap)

                ColumnLayout {
                    spacing: root.s(10)

                    Text {
                        id: timeText
                        Layout.alignment: Qt.AlignHCenter
                        text: FocusTimer.formatTime(root.displayMs, true)
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: root.s(52)
                        color: ThemeBackend.text
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.s(270)
                        Layout.preferredHeight: FocusTimer.swLapData.length > 0
                            ? Math.min(root.s(130), contentArea.height - Math.max(0, root.contentGap) - card.padY * 2 - timeText.height - root.s(10))
                            : 0
                        visible: FocusTimer.swLapData.length > 0
                        clip: true

                        ListView {
                            id: lapList
                            anchors.fill: parent
                            model: FocusTimer.swLapData.length
                            spacing: root.s(6)

                            delegate: Rectangle {
                                width: lapList.width
                                height: root.s(32)
                                radius: ThemeBackend.borderRadius
                                color: lapGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, ThemeBackend.elementOpacity)

                                GlassFill {
                                    id: lapGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: ThemeBackend.surface1
                                    tintAmount: 0.3
                                }

                                property int trueIdx: FocusTimer.swLapData.length - 1 - index
                                property var lapItem: FocusTimer.swLapData[trueIdx]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: root.s(15); anchors.rightMargin: root.s(15)
                                    Text { text: I18n.t("quickactions.timer.stopwatch.lap", { number: trueIdx + 1 }); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.fillWidth: true }
                                    Text { text: lapItem ? "+" + FocusTimer.formatTime(lapItem.diff, true) : ""; color: ThemeBackend.mauve; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12) }
                                    Text { text: lapItem ? FocusTimer.formatTime(lapItem.total, true) : ""; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.alignment: Qt.AlignRight }
                                }
                            }
                        }
                    }
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
            leftIcon: root.isRunning ? "" : ""
            playIcon: root.isRunning ? "" : ""
            onLeftClicked: FocusTimer.stopwatchLapOrReset()
            onPlayClicked: root.toggle()
        }
    }
}
