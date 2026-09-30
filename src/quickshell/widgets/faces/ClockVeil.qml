import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 90
    property real maxWidth: 1000
    property real maxHeight: 400
    property real minAspect: 2.0
    property real maxAspect: 8.0

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
        opacity: 0.92
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, Math.min(width, height) * 0.12)
        spacing: 2

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: DateTime.timeShort
            font.family: ThemeBackend.fontFamily
            font.pixelSize: height
            fontSizeMode: Text.Fit
            minimumPixelSize: 24
            font.weight: Font.Black
            color: ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            text: DateTime.dayNameShort.toUpperCase() + "  ·  " + DateTime.dateBadge
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(10, height * 0.18)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
            color: ThemeBackend.mauve
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
