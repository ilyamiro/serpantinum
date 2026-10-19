import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"

ColumnLayout {
    required property var screenRoot
    id: clockModule
    anchors.centerIn: parent
    anchors.verticalCenterOffset: screenRoot.inputActive ? screenRoot.s(-280) : screenRoot.s(-130)
    spacing: screenRoot.s(8)

    opacity: (screenRoot.inputActive || screenRoot.centerReveal > 0.02) ? 0.0 : 1.0
    scale: (screenRoot.inputActive || screenRoot.centerReveal > 0.02) ? 0.92 : 1.0
    visible: opacity > 0.01

    property var currentTime: (typeof DateTime !== "undefined" && DateTime.now) ? DateTime.now : new Date()
    property string timeFormat: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) {
            return Config.rawSettings.bar.time.format;
        }
        return "HH:mm:ss";
    }
    readonly property bool is12h: timeFormat.includes("h") || timeFormat.toLowerCase().includes("ap")
    readonly property string hourFmt: is12h ? (timeFormat.includes("hh") ? "hh" : "h") : (timeFormat.includes("H") && !timeFormat.includes("HH") ? "H" : "HH")

    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: screenRoot.s(4)

        Text {
            id: clockHours
            text: Qt.formatDateTime(clockModule.currentTime, clockModule.hourFmt)
            font.family: ThemeBackend.fontFamily
            font.pixelSize: screenRoot.s(120)
            font.weight: Font.Normal
            color: "#ffffff"

            Text {
                anchors.fill: parent
                anchors.topMargin: screenRoot.s(1.5)
                anchors.bottomMargin: -screenRoot.s(1.5)
                font.family: parent.font.family
                font.pixelSize: parent.font.pixelSize
                font.weight: parent.font.weight
                color: Qt.rgba(0, 0, 0, 0.16)
                text: parent.text
                z: -1
            }
        }

        Text {
            id: clockColon
            text: ":"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: screenRoot.s(80)
            font.weight: Font.Light
            Layout.alignment: Qt.AlignVCenter
            opacity: 0.75
            color: "#ffffff"

            Text {
                anchors.fill: parent
                anchors.topMargin: screenRoot.s(1.5)
                anchors.bottomMargin: -screenRoot.s(1.5)
                font.family: parent.font.family
                font.pixelSize: parent.font.pixelSize
                font.weight: parent.font.weight
                color: Qt.rgba(0, 0, 0, 0.16)
                text: parent.text
                z: -1
            }
        }

        Text {
            id: clockMinutes
            text: Qt.formatDateTime(clockModule.currentTime, "mm")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: screenRoot.s(120)
            font.weight: Font.Normal
            color: "#ffffff"

            Text {
                anchors.fill: parent
                anchors.topMargin: screenRoot.s(1.5)
                anchors.bottomMargin: -screenRoot.s(1.5)
                font.family: parent.font.family
                font.pixelSize: parent.font.pixelSize
                font.weight: parent.font.weight
                color: Qt.rgba(0, 0, 0, 0.16)
                text: parent.text
                z: -1
            }
        }

        Text {
            id: clockAmPm
            text: clockModule.is12h ? Qt.formatDateTime(clockModule.currentTime, "AP") : ""
            visible: text !== ""
            font.family: ThemeBackend.fontFamily
            font.pixelSize: screenRoot.s(28)
            font.weight: Font.Bold
            color: "#ffffff"
            opacity: 0.8
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: screenRoot.s(24)

            Text {
                anchors.fill: parent
                anchors.topMargin: screenRoot.s(1.5)
                anchors.bottomMargin: -screenRoot.s(1.5)
                font.family: parent.font.family
                font.pixelSize: parent.font.pixelSize
                font.weight: parent.font.weight
                color: Qt.rgba(0, 0, 0, 0.16)
                text: parent.text
                z: -1
            }
        }
    }

    Text {
        id: dateText
        text: Qt.formatDateTime(clockModule.currentTime, "dddd, d MMMM").toUpperCase()
        Layout.alignment: Qt.AlignHCenter
        font.family: ThemeBackend.fontFamily
        font.pixelSize: screenRoot.s(14)
        font.weight: Font.Bold
        font.letterSpacing: 1.4
        color: "#ffffff"
        opacity: 0.85

        Text {
            anchors.fill: parent
            anchors.topMargin: screenRoot.s(1.5)
            anchors.bottomMargin: -screenRoot.s(1.5)
            font.family: parent.font.family
            font.pixelSize: parent.font.pixelSize
            font.weight: parent.font.weight
            font.letterSpacing: parent.font.letterSpacing
            color: Qt.rgba(0, 0, 0, 0.16)
            text: parent.text
            z: -1
        }
    }

    Connections {
        target: typeof DateTime !== "undefined" ? DateTime : null
        function onNowChanged() {
            clockModule.currentTime = DateTime.now;
        }
    }
}
