import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 300
    property real minHeight: 120
    property real maxWidth: 1200
    property real maxHeight: 500
    property real minAspect: 2.0
    property real maxAspect: 7.0
    readonly property var days: Weather.forecast || []

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    Column {
        anchors.fill: parent
        anchors.margins: Math.max(12, root.height * 0.12)
        spacing: 8

        Row {
            width: parent.width
            height: root.height * 0.2
            spacing: 8

            Text {
                text: "FORECAST"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(11, root.height * 0.09)
                font.weight: Font.Bold
                font.letterSpacing: 2
                color: ThemeBackend.text
            }
            Text {
                text: Weather.isLoading ? "UPDATING" : (days.length > 0 ? Weather.unitSym : "NO DATA")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(9, root.height * 0.07)
                color: ThemeBackend.mauve
            }
        }

        Row {
            width: parent.width
            height: parent.height - root.height * 0.2 - 8
            spacing: Math.max(4, width * 0.012)

            Repeater {
                model: root.days
                delegate: Column {
                    required property var modelData
                    required property int index
                    width: (parent.width - (root.days.length - 1) * parent.spacing) / Math.max(1, root.days.length)
                    height: parent.height
                    spacing: 3

                    Text {
                        width: parent.width
                        text: modelData.day || (index === 0 ? "Today" : "")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9, root.height * 0.07)
                        font.weight: Font.DemiBold
                        color: ThemeBackend.subtext0
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.icon || ""
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(18, root.height * 0.19)
                        color: modelData.hex || ThemeBackend.mauve
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: (modelData.max || "--") + "°"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(12, root.height * 0.11)
                        font.weight: Font.Black
                        color: ThemeBackend.text
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: (modelData.min || "--") + "°"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(10, root.height * 0.08)
                        color: ThemeBackend.subtext0
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
