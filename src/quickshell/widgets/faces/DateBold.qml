import QtQuick
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 150
    property real minHeight: 130
    property real maxWidth: 700
    property real maxHeight: 500
    property real minAspect: 0.9
    property real maxAspect: 3.0

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    Column {
        anchors.fill: parent
        anchors.margins: Math.max(14, Math.min(width, height) * 0.1)
        spacing: 0

        Text {
            width: parent.width
            height: parent.height * 0.16
            text: DateTime.dayName.toUpperCase()
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(11, root.height * 0.075)
            font.weight: Font.DemiBold
            font.letterSpacing: 2
            color: ThemeBackend.mauve
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            width: parent.width
            height: parent.height * 0.66
            spacing: -Math.min(18, width * 0.06)

            Text {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: DateTime.day.charAt(0)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.height * 0.40
                fontSizeMode: Text.Fit
                minimumPixelSize: 24
                font.weight: Font.Black
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: DateTime.day.charAt(1)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.height * 0.40
                fontSizeMode: Text.Fit
                minimumPixelSize: 24
                font.weight: Font.Black
                color: ThemeBackend.primary ?? ThemeBackend.mauve
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            width: parent.width
            height: parent.height * 0.16
            text: DateTime.month + "  ·  " + DateTime.year
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(10, root.height * 0.07)
            color: ThemeBackend.subtext0
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
