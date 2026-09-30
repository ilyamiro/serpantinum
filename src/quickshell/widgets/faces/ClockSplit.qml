import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 250
    property real minHeight: 120
    property real maxWidth: 1100
    property real maxHeight: 480
    property real minAspect: 1.8
    property real maxAspect: 5.0

    readonly property real pad: Math.max(10, Math.min(root.width, root.height) * 0.1)
    readonly property real railThickness: Math.max(3, Math.min(7, root.height * 0.035))
    readonly property bool secondsVisible: DateTime.second !== ""
    readonly property bool meridiemVisible: DateTime.amPm !== ""
    readonly property real secondProgress: Math.min(1, (DateTime.now.getMilliseconds() / 1000 + DateTime.now.getSeconds()) / 60)

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    Item {
        id: inset
        anchors.fill: parent
        anchors.margins: root.pad

        Item {
            id: digitArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: bottomRow.visible ? bottomRow.top : parent.bottom
            anchors.bottomMargin: bottomRow.visible ? root.pad * 0.7 : 0

            RowLayout {
                id: digitRow
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
                    Layout.preferredWidth: Math.max(2, root.width * 0.005)
                    Layout.preferredHeight: digitArea.height * 0.55
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

                Text {
                    visible: root.meridiemVisible
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: digitArea.height * 0.14
                    Layout.leftMargin: digitArea.width * 0.02
                    text: DateTime.amPm
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(10, digitArea.height * 0.16)
                    font.weight: Font.Bold
                    color: ThemeBackend.subtext1
                }
            }
        }

        RowLayout {
            id: bottomRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: root.pad * 0.5
            visible: root.secondsVisible

            Rectangle {
                id: rail
                Layout.fillWidth: true
                Layout.preferredHeight: root.railThickness
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: ThemeBackend.surface1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.secondProgress
                    radius: height / 2
                    color: ThemeBackend.blue
                    Behavior on width {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: DateTime.second
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(10, root.railThickness * 2.1)
                font.weight: Font.Bold
                color: ThemeBackend.subtext1
            }
        }
    }
}
