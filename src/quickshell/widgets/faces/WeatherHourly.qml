import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 320
    property real minHeight: 110
    property real maxWidth: 1200
    property real maxHeight: 400
    property real minAspect: 2.2
    property real maxAspect: 8.0
    readonly property var hourly: Weather.forecast && Weather.forecast[0] ? (Weather.forecast[0].hourly || []) : []

    function hourLabel(value) {
        let h = parseInt(String(value || "").split(":")[0]);
        if (isNaN(h)) return "--";
        if (DateTime.is12Hour) {
            let suffix = h >= 12 ? "PM" : "AM";
            h = h % 12;
            if (h === 0) h = 12;
            return h + suffix;
        }
        return (h < 10 ? "0" : "") + h + ":00";
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    Column {
        anchors.fill: parent
        anchors.margins: Math.max(12, root.height * 0.12)
        spacing: 6

        Text {
            width: parent.width
            height: root.height * 0.18
            text: "HOURLY  ·  " + (Weather.currentTempFormatted || "--")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(11, root.height * 0.09)
            font.weight: Font.Bold
            font.letterSpacing: 1.6
            color: ThemeBackend.text
        }

        Row {
            width: parent.width
            height: parent.height - root.height * 0.18 - 6
            spacing: Math.max(4, width * 0.012)

            Repeater {
                model: Math.min(6, root.hourly.length)
                delegate: Column {
                    required property int index
                    width: (parent.width - (Math.min(6, root.hourly.length) - 1) * parent.spacing) / Math.max(1, Math.min(6, root.hourly.length))
                    height: parent.height
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.hourLabel(root.hourly[index].time)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9, root.height * 0.08)
                        color: ThemeBackend.subtext0
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: root.hourly[index].icon || ""
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(18, root.height * 0.25)
                        color: root.hourly[index].hex || ThemeBackend.mauve
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: (root.hourly[index].temp || "--") + "°"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(11, root.height * 0.11)
                        font.weight: Font.Black
                        color: ThemeBackend.text
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
