import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 150
    property real minHeight: 150
    property real maxWidth: 700
    property real maxHeight: 700
    property real minAspect: 0.8
    property real maxAspect: 1.2
    property bool isRound: true

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ThemeBackend.surface0
        border.width: Math.max(2, width * 0.025)
        border.color: ThemeBackend.primary ?? ThemeBackend.mauve
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.72
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: DateTime.day
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.width * 0.34
            font.weight: Font.Black
            color: ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: DateTime.dayNameShort.toUpperCase()
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(10, root.width * 0.075)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: ThemeBackend.mauve
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: DateTime.monthShort + "  " + DateTime.year
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(10, root.width * 0.07)
            color: ThemeBackend.subtext0
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
