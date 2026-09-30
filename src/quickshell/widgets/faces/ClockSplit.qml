import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 110
    property real maxWidth: 1100
    property real maxHeight: 480
    property real minAspect: 1.8
    property real maxAspect: 5.0

    readonly property real secondIndex: DateTime.now.getSeconds()
    readonly property real secondProgress: Math.min(1, (DateTime.now.getMilliseconds() / 1000 + secondIndex) / 60)
    readonly property bool secondsVisible: DateTime.second !== ""

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, Math.min(root.width, root.height) * 0.1)
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: DateTime.hour
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: height
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 20
                    font.weight: Font.Black
                    color: ThemeBackend.text
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    Layout.preferredWidth: Math.max(1, root.width * 0.004)
                    Layout.preferredHeight: parent.height * 0.54
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: ThemeBackend.surface2
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: DateTime.minute
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: height
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 20
                    font.weight: Font.Black
                    color: ThemeBackend.mauve
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.height * 0.08
            Layout.topMargin: root.height * 0.05
            visible: root.secondsVisible || DateTime.amPm !== ""

            Rectangle {
                id: secondTrack
                anchors.fill: parent
                radius: height / 2
                color: ThemeBackend.surface1
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: secondTrack.width * (root.secondsVisible ? root.secondProgress : 0)
                radius: height / 2
                color: ThemeBackend.blue
                Behavior on width {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: DateTime.amPm !== "" ? DateTime.amPm : DateTime.second
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(9, root.height * 0.055)
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                color: ThemeBackend.subtext0
            }
        }
    }
}
