import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 110
    property real minHeight: 180
    property real maxWidth: 500
    property real maxHeight: 900
    property real minAspect: 0.45
    property real maxAspect: 1.0

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, Math.min(width, height) * 0.1)
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: DateTime.hour
            font.family: ThemeBackend.fontFamily
            font.pixelSize: height
            fontSizeMode: Text.Fit
            minimumPixelSize: 20
            font.weight: Font.Normal
            color: ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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
            color: ThemeBackend.primary ?? ThemeBackend.mauve
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            text: DateTime.dayNameShort.toUpperCase() + "  " + DateTime.dateBadge
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(10, height * 0.16)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: ThemeBackend.subtext0
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
