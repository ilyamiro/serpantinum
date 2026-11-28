import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: materialFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    readonly property string hours: (widget && widget.hourStr !== undefined && widget.hourStr !== "") ? String(widget.hourStr) : (typeof DateTime !== "undefined" && DateTime.hours ? String(DateTime.hours) : "14")
    readonly property string minutes: (widget && widget.minuteStr !== undefined) ? String(widget.minuteStr) : (typeof DateTime !== "undefined" && DateTime.minutes ? String(DateTime.minutes) : "")
    readonly property string seconds: (widget && widget.secondStr !== undefined) ? String(widget.secondStr) : (typeof DateTime !== "undefined" && DateTime.seconds ? String(DateTime.seconds) : "")
    readonly property string ampm: (widget && widget.ampmStr !== undefined) ? String(widget.ampmStr) : (typeof DateTime !== "undefined" && DateTime.ampm ? String(DateTime.ampm) : "")
    readonly property bool hasMinutes: minutes !== ""
    readonly property bool hasSeconds: seconds !== ""

    readonly property string dayVal: (widget && widget.dayStr !== undefined && widget.dayStr !== "") ? String(widget.dayStr) : (typeof DateTime !== "undefined" && DateTime.day ? String(DateTime.day) : "18")
    readonly property string monthVal: ((widget && widget.monthStr !== undefined && widget.monthStr !== "") ? String(widget.monthStr) : (typeof DateTime !== "undefined" && DateTime.monthShort ? String(DateTime.monthShort) : "Sep")).toUpperCase()
    readonly property string weekdayVal: ((widget && widget.weekdayStr !== undefined && widget.weekdayStr !== "") ? String(widget.weekdayStr) : (typeof DateTime !== "undefined" && DateTime.weekdayShort ? String(DateTime.weekdayShort) : "")).toUpperCase()

    FontLoader {
        id: clockFontLoader
        source: (typeof Caching !== "undefined" && Caching.serpantinumDir && Caching.serpantinumDir !== "")
            ? ("file://" + Caching.serpantinumDir + "/assets/fonts/GoogleSansFlex.ttf")
            : Qt.resolvedUrl("../../../../assets/fonts/GoogleSansFlex.ttf")
    }

    readonly property string clockFont: clockFontLoader.status === FontLoader.Ready && clockFontLoader.name !== ""
        ? clockFontLoader.name
        : (ThemeBackend.fontFamily !== "" ? ThemeBackend.fontFamily : "sans-serif")

    implicitWidth: bodyLoader.item ? bodyLoader.item.implicitWidth : 0
    implicitHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0

    Loader {
        id: bodyLoader
        anchors.centerIn: parent
        sourceComponent: materialFaceRoot.isVertical ? sideBodyComponent : topBodyComponent
    }

    Component {
        id: topBodyComponent

        Row {
            id: contentRow
            spacing: widget ? widget.s(widget.isCompact ? 6 : 8) : 8

            Item {
                id: diagonalClock
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: {
                    if (materialFaceRoot.hasSeconds) {
                        return hourText.width + (widget ? widget.s(4) : 4) + stackedCol.width;
                    }
                    if (materialFaceRoot.hasMinutes) {
                        return minuteText.x + minuteText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(2) : 2) : 0);
                    }
                    return hourText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(2) : 2) : 0);
                }
                implicitHeight: {
                    if (materialFaceRoot.hasSeconds) {
                        return Math.max(hourText.height, stackedCol.height);
                    }
                    if (materialFaceRoot.hasMinutes) {
                        return minuteText.y + minuteText.height;
                    }
                    return hourText.height;
                }
                width: implicitWidth
                height: implicitHeight

                Text {
                    id: hourText
                    x: 0
                    anchors.verticalCenter: materialFaceRoot.hasSeconds ? parent.verticalCenter : undefined
                    y: materialFaceRoot.hasSeconds ? 0 : 0
                    text: materialFaceRoot.hours
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? (materialFaceRoot.hasSeconds ? 18 : 17) : (materialFaceRoot.hasSeconds ? 22 : 20)) : (materialFaceRoot.hasSeconds ? 22 : 20)
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    font.letterSpacing: -0.8
                    color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
                }

                Text {
                    id: minuteText
                    visible: !materialFaceRoot.hasSeconds && materialFaceRoot.hasMinutes
                    x: hourText.width + (widget ? widget.s(1) : 1)
                    y: widget ? widget.s(widget.isCompact ? 5 : 7) : 7
                    text: materialFaceRoot.minutes
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 14 : 16) : 16
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    font.letterSpacing: -0.5
                    color: ThemeBackend.text
                }

                Text {
                    id: ampmText
                    visible: !materialFaceRoot.hasSeconds && materialFaceRoot.ampm !== ""
                    x: materialFaceRoot.hasMinutes
                        ? (minuteText.x + minuteText.width + (widget ? widget.s(2) : 2))
                        : (hourText.width + (widget ? widget.s(2) : 2))
                    y: materialFaceRoot.hasMinutes
                        ? (minuteText.y + minuteText.height - height - (widget ? widget.s(1) : 1))
                        : (hourText.y + hourText.height - height - (widget ? widget.s(1) : 1))
                    text: materialFaceRoot.ampm
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    color: ThemeBackend.subtext0
                }

                Column {
                    id: stackedCol
                    visible: materialFaceRoot.hasSeconds
                    x: hourText.width + (widget ? widget.s(4) : 4)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Row {
                        spacing: widget ? widget.s(2) : 2
                        Text {
                            text: materialFaceRoot.minutes
                            font.family: materialFaceRoot.clockFont
                            font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                            font.weight: Font.Bold
                            font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                            font.letterSpacing: -0.4
                            color: ThemeBackend.text
                        }

                        Text {
                            visible: materialFaceRoot.ampm !== ""
                            text: materialFaceRoot.ampm
                            font.family: materialFaceRoot.clockFont
                            font.pixelSize: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
                            font.weight: Font.Bold
                            font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                            color: ThemeBackend.subtext0
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: widget ? widget.s(1) : 1
                        }
                    }

                    Text {
                        x: widget ? widget.s(2) : 2
                        text: materialFaceRoot.seconds
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        font.letterSpacing: -0.3
                        color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
                    }
                }
            }

            Rectangle {
                id: dateDivider
                visible: widget ? widget.showDate : true
                width: widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2
                height: widget ? widget.s(widget.isCompact ? 14 : 16) : 16
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(ThemeBackend.surface2, 0.7)
            }

            Row {
                id: dateRow
                visible: widget ? widget.showDate : true
                anchors.verticalCenter: parent.verticalCenter
                spacing: widget ? widget.s(widget.isCompact ? 2 : 3) : 3

                Text {
                    id: dayText
                    anchors.verticalCenter: parent.verticalCenter
                    text: materialFaceRoot.dayVal
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 15) : 15
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    font.letterSpacing: -0.5
                    color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
                }

                Column {
                    id: monthCol
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        visible: materialFaceRoot.weekdayVal !== ""
                        text: materialFaceRoot.weekdayVal
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        font.letterSpacing: 0.2
                        color: ThemeBackend.subtext0
                    }

                    Text {
                        visible: materialFaceRoot.monthVal !== ""
                        text: materialFaceRoot.monthVal
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        font.letterSpacing: -0.2
                        color: ThemeBackend.text
                    }
                }
            }
        }
    }

    Component {
        id: sideBodyComponent

        Column {
            id: mainCol
            spacing: widget ? widget.s(widget.isCompact ? 4 : 6) : 6

            Item {
                id: sideDiagonalClock
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: {
                    if (materialFaceRoot.hasSeconds) {
                        return sideHourText.width + (widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2) + sideStackedCol.width;
                    }
                    if (materialFaceRoot.hasMinutes) {
                        return sideMinuteText.x + sideMinuteText.width + (sideAmpmText.visible ? sideAmpmText.width + (widget ? widget.s(1.5) : 1.5) : 0);
                    }
                    return sideHourText.width + (sideAmpmText.visible ? sideAmpmText.width + (widget ? widget.s(1.5) : 1.5) : 0);
                }
                implicitHeight: {
                    if (materialFaceRoot.hasSeconds) {
                        return Math.max(sideHourText.height, sideStackedCol.height);
                    }
                    if (materialFaceRoot.hasMinutes) {
                        return sideAmpmText.visible
                            ? Math.max(sideMinuteText.y + sideMinuteText.height, sideAmpmText.y + sideAmpmText.height)
                            : (sideMinuteText.y + sideMinuteText.height);
                    }
                    return sideHourText.height;
                }
                width: implicitWidth
                height: implicitHeight

                Text {
                    id: sideHourText
                    x: 0
                    anchors.verticalCenter: materialFaceRoot.hasSeconds ? parent.verticalCenter : undefined
                    y: materialFaceRoot.hasSeconds ? 0 : 0
                    text: materialFaceRoot.hours
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: {
                        if (materialFaceRoot.hasSeconds) {
                            return widget ? widget.s(widget.isCompact ? 14 : 16) : 16;
                        }
                        return widget ? widget.s(widget.isCompact ? 16 : 18) : 18;
                    }
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    font.letterSpacing: -0.8
                    color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
                }

                Text {
                    id: sideMinuteText
                    visible: !materialFaceRoot.hasSeconds && materialFaceRoot.hasMinutes
                    x: widget ? widget.s(widget.isCompact ? 4 : 5) : 5
                    y: sideHourText.height - (widget ? widget.s(widget.isCompact ? 2 : 3) : 3)
                    text: materialFaceRoot.minutes
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 15) : 15
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    font.letterSpacing: -0.6
                    color: ThemeBackend.text
                }

                Text {
                    id: sideAmpmText
                    visible: !materialFaceRoot.hasSeconds && materialFaceRoot.ampm !== ""
                    x: materialFaceRoot.hasMinutes
                        ? (sideMinuteText.x + sideMinuteText.width + (widget ? widget.s(1.5) : 1.5))
                        : (sideHourText.width + (widget ? widget.s(1.5) : 1.5))
                    y: materialFaceRoot.hasMinutes
                        ? (sideMinuteText.y + sideMinuteText.height - height - (widget ? widget.s(1) : 1))
                        : (sideHourText.y + sideHourText.height - height - (widget ? widget.s(1) : 1))
                    text: materialFaceRoot.ampm
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 6.5 : 7.5) : 7.5
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    color: ThemeBackend.subtext0
                }

                Column {
                    id: sideStackedCol
                    visible: materialFaceRoot.hasSeconds
                    x: sideHourText.width + (widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: widget ? widget.s(widget.isCompact ? 0 : 0.5) : 0.5

                    Text {
                        text: materialFaceRoot.minutes
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        font.letterSpacing: -0.4
                        color: ThemeBackend.text
                    }

                    Text {
                        x: widget ? widget.s(widget.isCompact ? 1 : 1.5) : 1.5
                        text: materialFaceRoot.seconds
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 7.5 : 8.5) : 8.5
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        font.letterSpacing: -0.3
                        color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
                    }

                    Text {
                        visible: materialFaceRoot.ampm !== ""
                        x: widget ? widget.s(widget.isCompact ? 1 : 1.5) : 1.5
                        text: materialFaceRoot.ampm
                        font.family: materialFaceRoot.clockFont
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
                        font.weight: Font.Bold
                        font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                        color: ThemeBackend.subtext0
                    }
                }
            }

            Rectangle {
                id: sideDateDivider
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                width: widget ? widget.s(widget.isCompact ? 13 : 16) : 16
                height: widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2
                radius: height / 2
                color: Qt.alpha(ThemeBackend.surface2, 0.7)
            }

            Column {
                id: dateCol
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: materialFaceRoot.dayVal
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 10 : 11) : 11
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    color: ThemeBackend.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
                    font.family: materialFaceRoot.clockFont
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 8.5 : 9.5) : 9.5
                    font.weight: Font.Bold
                    font.variableAxes: ({ "wght": 700, "ROND": 100, "wdth": 100 })
                    color: ThemeBackend.subtext0
                }
            }
        }
    }
}
