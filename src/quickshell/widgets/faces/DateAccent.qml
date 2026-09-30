import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 190
    property real minHeight: 70
    property real maxWidth: 900
    property real maxHeight: 300
    property real minAspect: 2.0
    property real maxAspect: 8.0

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(4, parent.width * 0.018)
        radius: width / 2
        color: ThemeBackend.primary ?? ThemeBackend.mauve
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(18, parent.width * 0.08)
        anchors.rightMargin: 16
        spacing: 10

        Text {
            text: DateTime.dayNameShort.toUpperCase()
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(12, root.height * 0.22)
            font.weight: Font.DemiBold
            color: ThemeBackend.subtext0
        }
        Text {
            text: DateTime.day
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(24, root.height * 0.65)
            font.weight: Font.Black
            color: ThemeBackend.primary ?? ThemeBackend.mauve
        }
        Text {
            Layout.fillWidth: true
            text: DateTime.month + "  " + DateTime.year
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(11, root.height * 0.2)
            color: ThemeBackend.text
            elide: Text.ElideRight
        }
    }
}
