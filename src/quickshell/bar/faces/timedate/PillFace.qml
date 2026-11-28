import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: pillFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property bool isCompact: widget ? widget.isCompact : false
    readonly property bool showDate: widget ? widget.showDate : true

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.timeShort) ? DateTime.timeShort : "14:28"
    readonly property string hourStr: widget ? widget.hourStr : (typeof DateTime !== "undefined" && DateTime.hours ? DateTime.hours : "14")
    readonly property string minuteStr: widget ? widget.minuteStr : (typeof DateTime !== "undefined" && DateTime.minutes ? DateTime.minutes : "28")
    readonly property string shortDateStr: (typeof DateTime !== "undefined" && DateTime.shortDate) ? DateTime.shortDate : "18 Sep"
    readonly property string dayStr: (typeof DateTime !== "undefined" && DateTime.dayShort) ? DateTime.dayShort : "18"

    readonly property color pillColor: isCompact ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
    readonly property color inkColor: pill.displayTextColor

    function s(val) {
        return widget ? widget.s(val) : val;
    }

    implicitWidth: pill.width
    implicitHeight: pill.height

    ClickButton {
        id: pill
        anchors.centerIn: parent
        accentColor: pillFaceRoot.pillColor
        textColor: ThemeBackend.base
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - pillFaceRoot.s(2))
        horizontalPadding: 0
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

        onClicked: {
            if (widget && typeof widget.activate === "function") {
                widget.activate();
            }
        }
    }

    Component {
        id: topContent

        Row {
            id: topRow
            spacing: pillFaceRoot.s(6)

            readonly property int dateBaseSize: Math.round(pillFaceRoot.s(pillFaceRoot.isCompact ? 10 : 11))
            readonly property int timeInkParity: Math.round(timeInk.tightBoundingRect.height) % 2
            readonly property int dateSize: {
                if (Math.round(dateBaseInk.tightBoundingRect.height) % 2 === timeInkParity) return dateBaseSize;
                if (Math.round(dateSmallerInk.tightBoundingRect.height) % 2 === timeInkParity) return dateBaseSize - 1;
                if (Math.round(dateLargerInk.tightBoundingRect.height) % 2 === timeInkParity) return dateBaseSize + 1;
                return dateBaseSize;
            }

            TextMetrics {
                id: dateBaseInk
                font: Qt.font({ family: ThemeBackend.fontFamily, pixelSize: topRow.dateBaseSize, weight: Font.Bold })
                text: "0123456789"
            }

            TextMetrics {
                id: dateSmallerInk
                font: Qt.font({ family: ThemeBackend.fontFamily, pixelSize: topRow.dateBaseSize - 1, weight: Font.Bold })
                text: "0123456789"
            }

            TextMetrics {
                id: dateLargerInk
                font: Qt.font({ family: ThemeBackend.fontFamily, pixelSize: topRow.dateBaseSize + 1, weight: Font.Bold })
                text: "0123456789"
            }

            Text {
                id: timeLabel
                y: Math.round(topRow.height / 2 - timeInk.tightBoundingRect.y - timeInk.tightBoundingRect.height / 2) - baselineOffset
                text: pillFaceRoot.timeStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: pillFaceRoot.s(pillFaceRoot.isCompact ? 13 : 14)
                font.weight: Font.Black
                color: pillFaceRoot.inkColor

                TextMetrics {
                    id: timeInk
                    font: timeLabel.font
                    text: "0123456789"
                }
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
                id: dateLabel
                visible: pillFaceRoot.showDate
                y: Math.round(topRow.height / 2 - dateInk.tightBoundingRect.y - dateInk.tightBoundingRect.height / 2) - baselineOffset
                text: pillFaceRoot.shortDateStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: topRow.dateSize
                font.weight: Font.Bold
                color: Qt.alpha(pillFaceRoot.inkColor, 0.75)

                TextMetrics {
                    id: dateInk
                    font: dateLabel.font
                    text: "0123456789"
                }
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
