import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 360
    property real minHeight: 130
    property real maxWidth: 1400
    property real maxHeight: 500
    property real minAspect: 2.4
    property real maxAspect: 8.0

    readonly property string zoneLabel: {
        let city = "";
        try {
            let zone = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
            city = zone.split("/").pop().replace(/_/g, " ");
        } catch (e) {}

        let offsetMinutes = -DateTime.now.getTimezoneOffset();
        let sign = offsetMinutes >= 0 ? "+" : "-";
        let absolute = Math.abs(offsetMinutes);
        let hours = Math.floor(absolute / 60);
        let minutes = absolute % 60;
        let offset = "GMT" + sign + hours;
        if (minutes > 0) offset += ":" + (minutes < 10 ? "0" : "") + minutes;

        return (city !== "" ? city.toUpperCase() : "LOCAL") + "  ·  " + offset;
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(18, width * 0.035)
        anchors.rightMargin: Math.max(18, width * 0.035)
        spacing: Math.max(16, width * 0.035)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(16, root.height * 0.16)
                text: root.zoneLabel + (DateTime.amPm !== "" ? "  ·  " + DateTime.amPm : "")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(10, root.height * 0.075)
                font.weight: Font.DemiBold
                font.letterSpacing: 3
                color: ThemeBackend.text
                opacity: 0.88
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: DateTime.hour + ":" + DateTime.minute
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.height * 0.72
                fontSizeMode: Text.Fit
                minimumPixelSize: 36
                font.weight: Font.Black
                color: ThemeBackend.blue
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        ColumnLayout {
            Layout.preferredWidth: Math.max(76, root.width * 0.17)
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: DateTime.second
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.height * 0.34
                fontSizeMode: Text.Fit
                minimumPixelSize: 22
                font.weight: Font.Black
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignBottom
            }

            Text {
                Layout.fillWidth: true
                text: DateTime.dayName
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(11, root.height * 0.085)
                font.weight: Font.DemiBold
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                Layout.fillWidth: true
                text: DateTime.month
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(11, root.height * 0.085)
                font.weight: Font.DemiBold
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
