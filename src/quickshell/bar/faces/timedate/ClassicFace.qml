import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: classicFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    readonly property string hours: (widget && widget.hourStr !== undefined && widget.hourStr !== "") ? String(widget.hourStr) : (typeof DateTime !== "undefined" && DateTime.hours ? String(DateTime.hours) : "14")
    readonly property string minutes: (widget && widget.minuteStr !== undefined) ? String(widget.minuteStr) : (typeof DateTime !== "undefined" && DateTime.minutes ? String(DateTime.minutes) : "")
    readonly property string seconds: (widget && widget.secondStr !== undefined) ? String(widget.secondStr) : (typeof DateTime !== "undefined" && DateTime.seconds ? String(DateTime.seconds) : "")
    readonly property string ampm: (widget && widget.ampmStr !== undefined) ? String(widget.ampmStr) : (typeof DateTime !== "undefined" && DateTime.ampm ? String(DateTime.ampm) : "")
    readonly property bool hasMinutes: minutes !== ""
    readonly property bool hasSeconds: seconds !== ""

    implicitWidth: bodyLoader.item ? bodyLoader.item.implicitWidth : 0
    implicitHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0

    Loader {
        id: bodyLoader
        anchors.centerIn: parent
        sourceComponent: classicFaceRoot.isVertical ? sideBodyComponent : topBodyComponent
    }

    Component {
        id: topBodyComponent

        Column {
            id: timeCol
            spacing: -2

            Text {
                id: timeText
                anchors.left: parent.left
                text: widget ? widget.timeStr : (typeof DateTime !== "undefined" ? DateTime.time : "12:00")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 14 : 15) : 15
                font.weight: Font.Black
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
            }

            Text {
                id: dateText
                visible: widget ? widget.showDate : true
                anchors.left: parent.left
                text: widget ? widget.dateStr : (typeof DateTime !== "undefined" ? DateTime.fullDate : "Mon, Jan 1")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                font.weight: Font.Bold
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.subtext0, 1.08) : ThemeBackend.subtext0
            }
        }
    }

    Component {
        id: sideBodyComponent

        Column {
            id: sideTimeCol
            spacing: widget ? widget.s(1) : 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: classicFaceRoot.hours
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
                font.weight: Font.Black
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
            }

            Text {
                visible: classicFaceRoot.hasMinutes
                anchors.horizontalCenter: parent.horizontalCenter
                text: classicFaceRoot.minutes
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
                font.weight: Font.Black
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.sapphire, 1.1) : ThemeBackend.sapphire
            }

            Text {
                visible: classicFaceRoot.hasSeconds
                anchors.horizontalCenter: parent.horizontalCenter
                text: classicFaceRoot.seconds
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                font.weight: Font.Bold
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
            }

            Text {
                visible: classicFaceRoot.ampm !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: classicFaceRoot.ampm
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                font.weight: Font.Bold
                color: ThemeBackend.subtext0
            }

            Item {
                visible: widget ? widget.showDate : true
                width: widget ? widget.s(widget.isCompact ? 14 : 16) : 16
                height: widget ? widget.s(10) : 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 2
                    radius: 1
                    color: ThemeBackend.surface1
                }
            }

            Text {
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget ? widget.dayStr : (typeof DateTime !== "undefined" ? DateTime.day : "18")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                font.weight: Font.Bold
                color: ThemeBackend.text
            }

            Text {
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                font.weight: Font.Bold
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.subtext0, 1.08) : ThemeBackend.subtext0
            }
        }
    }
}
