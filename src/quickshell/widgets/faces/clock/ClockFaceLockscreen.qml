import QtQuick
import QtQuick.Layouts
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 160
    property real minHeight: 80
    property real maxWidth: 1600
    property real maxHeight: 800
    property real minAspect: 0.8
    property real maxAspect: 2.8
    property bool isRound: false

    readonly property bool isStacked: (width / height) < 1.25
    readonly property color hourColor: ThemeBackend.accent
    readonly property color minuteColor: ThemeBackend.text
    readonly property color dateColor: ThemeBackend.subtext0
    readonly property string stackedDateText: root.meridiemText !== "" ? root.meridiemText + "  ·  " + root.dateText : root.dateText

    property var currentTime: (typeof DateTime !== "undefined" && DateTime.now) ? DateTime.now : new Date()
    property string timeFormat: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) {
            return Config.rawSettings.bar.time.format;
        }
        return "HH:mm:ss";
    }
    readonly property bool is12h: root.timeFormat.includes("h") || root.timeFormat.toLowerCase().includes("ap")
    readonly property string hourFmt: root.is12h ? (root.timeFormat.includes("hh") ? "hh" : "h") : (root.timeFormat.includes("H") && !root.timeFormat.includes("HH") ? "H" : "HH")
    readonly property string hoursText: Qt.formatDateTime(root.currentTime, root.hourFmt)
    readonly property string minutesText: Qt.formatDateTime(root.currentTime, "mm")
    readonly property string meridiemText: root.is12h ? Qt.formatDateTime(root.currentTime, "AP") : ""
    readonly property string dateText: Qt.formatDateTime(root.currentTime, "dddd, d MMMM").toUpperCase()

    Connections {
        target: typeof DateTime !== "undefined" ? DateTime : null
        function onNowChanged() {
            root.currentTime = DateTime.now;
        }
    }

    component ShadowText: Text {
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold

        Text {
            anchors.fill: parent
            anchors.topMargin: Scaler.s(3)
            anchors.bottomMargin: -Scaler.s(3)
            font.family: parent.font.family
            font.pixelSize: parent.font.pixelSize
            font.weight: parent.font.weight
            font.letterSpacing: parent.font.letterSpacing
            color: Qt.rgba(0, 0, 0, 0.32)
            text: parent.text
            z: -1
        }
    }

    ColumnLayout {
        visible: root.isStacked
        anchors.centerIn: parent
        spacing: Scaler.s(8)
        scale: Math.min(root.width / Math.max(1, implicitWidth), root.height / Math.max(1, implicitHeight))

        ShadowText {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: -Scaler.s(28)
            text: root.hoursText
            color: root.hourColor
            font.pixelSize: Scaler.s(150)
        }

        ShadowText {
            Layout.alignment: Qt.AlignHCenter
            text: root.minutesText
            color: root.minuteColor
            font.pixelSize: Scaler.s(150)
        }

        ShadowText {
            Layout.alignment: Qt.AlignHCenter
            text: root.stackedDateText
            color: root.dateColor
            font.pixelSize: Scaler.s(16)
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }
    }

    ColumnLayout {
        visible: !root.isStacked
        anchors.centerIn: parent
        spacing: Scaler.s(8)
        scale: Math.min(root.width / Math.max(1, implicitWidth), root.height / Math.max(1, implicitHeight))

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Scaler.s(4)

            ShadowText {
                text: root.hoursText
                color: root.hourColor
                font.pixelSize: Scaler.s(120)
            }

            ShadowText {
                Layout.alignment: Qt.AlignVCenter
                text: ":"
                color: root.dateColor
                font.pixelSize: Scaler.s(80)
            }

            ShadowText {
                text: root.minutesText
                color: root.minuteColor
                font.pixelSize: Scaler.s(120)
            }

            ShadowText {
                visible: text !== ""
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: Scaler.s(24)
                text: root.meridiemText
                color: root.dateColor
                font.pixelSize: Scaler.s(28)
            }
        }

        ShadowText {
            Layout.alignment: Qt.AlignHCenter
            text: root.dateText
            color: root.dateColor
            font.pixelSize: Scaler.s(16)
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }
    }
}
