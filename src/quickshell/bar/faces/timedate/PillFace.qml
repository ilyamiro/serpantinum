import QtQuick
import "../../../reusables"
import "../../../"

Item {
    id: pillFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property bool isCompact: widget ? widget.isCompact : false
    readonly property bool showDate: widget ? widget.showDate : true

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.timeShort) ? DateTime.timeShort : "14:28"
    readonly property string hourStr: widget ? widget.hourStr : "14"
    readonly property string minuteStr: widget ? widget.minuteStr : "28"
    readonly property string shortDateStr: (typeof DateTime !== "undefined" && DateTime.shortDate) ? DateTime.shortDate : "18 Sep"
    readonly property string dayStr: (typeof DateTime !== "undefined" && DateTime.dayShort) ? DateTime.dayShort : "18"

    readonly property color pillColor: isCompact ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
    readonly property color inkColor: ThemeBackend.base

    function s(val) {
        return widget ? widget.s(val) : val;
    }

    implicitWidth: pill.width
    implicitHeight: pill.height

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: pillFaceRoot.pillColor
        radius: Math.min(width, height) / 2
        width: pillFaceRoot.isVertical
            ? pillFaceRoot.s(pillFaceRoot.isCompact ? 26 : 30)
            : contentLoader.implicitWidth + pillFaceRoot.s(pillFaceRoot.isCompact ? 18 : 22)
        height: pillFaceRoot.isVertical
            ? contentLoader.implicitHeight + pillFaceRoot.s(pillFaceRoot.isCompact ? 14 : 18)
            : pillFaceRoot.s(pillFaceRoot.isCompact ? 22 : 26)

        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

        Loader {
            id: contentLoader
            anchors.centerIn: parent
            sourceComponent: pillFaceRoot.isVertical ? sideContent : topContent
        }
    }

    Component {
        id: topContent

        Row {
            spacing: pillFaceRoot.s(6)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pillFaceRoot.timeStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 13 : 14)
                font.weight: Font.Black
                color: pillFaceRoot.inkColor
            }

            Rectangle {
                visible: pillFaceRoot.showDate
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, pillFaceRoot.s(1.5))
                height: pillFaceRoot.s(pillFaceRoot.isCompact ? 10 : 12)
                radius: width / 2
                color: Qt.alpha(pillFaceRoot.inkColor, 0.35)
            }

            Text {
                visible: pillFaceRoot.showDate
                anchors.verticalCenter: parent.verticalCenter
                text: pillFaceRoot.shortDateStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 10 : 11)
                font.weight: Font.Bold
                color: Qt.alpha(pillFaceRoot.inkColor, 0.75)
            }
        }
    }

    Component {
        id: sideContent

        Column {
            spacing: pillFaceRoot.s(1)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pillFaceRoot.hourStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 12 : 13)
                font.weight: Font.Black
                color: pillFaceRoot.inkColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pillFaceRoot.minuteStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 12 : 13)
                font.weight: Font.Black
                color: pillFaceRoot.inkColor
            }

            Item {
                visible: pillFaceRoot.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                width: pillFaceRoot.s(12)
                height: pillFaceRoot.s(6)

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: Math.max(1, pillFaceRoot.s(1.5))
                    radius: height / 2
                    color: Qt.alpha(pillFaceRoot.inkColor, 0.35)
                }
            }

            Text {
                visible: pillFaceRoot.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: pillFaceRoot.dayStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 10 : 11)
                font.weight: Font.Bold
                color: Qt.alpha(pillFaceRoot.inkColor, 0.75)
            }
        }
    }
}
