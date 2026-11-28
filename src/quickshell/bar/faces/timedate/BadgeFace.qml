import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: badgeFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    readonly property string timeStr: widget ? widget.timeStr : (typeof DateTime !== "undefined" ? DateTime.time : (isVertical ? "14:28" : "12:30"))
    readonly property string dayStr: widget ? String(widget.dayStr) : (typeof DateTime !== "undefined" ? String(DateTime.day) : "18")
    readonly property string dateStr: {
        if (widget && widget.dateStr !== undefined && widget.dateStr !== null && String(widget.dateStr) !== "") {
            return String(widget.dateStr).toUpperCase();
        }
        if (widget && widget.dayStr && widget.monthStr) {
            return (String(widget.dayStr) + " " + String(widget.monthStr)).toUpperCase();
        }
        if (typeof DateTime !== "undefined") {
            if (DateTime.day !== undefined && DateTime.monthShort !== undefined) {
                return (String(DateTime.day) + " " + String(DateTime.monthShort)).toUpperCase();
            }
            if (DateTime.fullDate) {
                return String(DateTime.fullDate).toUpperCase();
            }
        }
        return "18 SEP";
    }

    readonly property var sideTimeSegments: {
        let h = (widget && widget.hourStr !== undefined && widget.hourStr !== "") ? String(widget.hourStr) : (typeof DateTime !== "undefined" && DateTime.hours ? String(DateTime.hours) : "14");
        let m = (widget && widget.minuteStr !== undefined) ? String(widget.minuteStr) : (typeof DateTime !== "undefined" && DateTime.minutes ? String(DateTime.minutes) : "");
        let sec = (widget && widget.secondStr !== undefined) ? String(widget.secondStr) : (typeof DateTime !== "undefined" && DateTime.seconds ? String(DateTime.seconds) : "");
        let ap = (widget && widget.ampmStr !== undefined) ? String(widget.ampmStr) : (typeof DateTime !== "undefined" && DateTime.ampm ? String(DateTime.ampm) : "");
        let res = [];
        if (h !== "") res.push(h);
        if (m !== "") res.push(m);
        if (sec !== "") res.push(sec);
        if (ap !== "") res.push(ap);
        return res.length > 0 ? res : [badgeFaceRoot.timeStr];
    }

    readonly property real dotSize: isVertical ? (widget ? widget.s(widget.isCompact ? 1.6 : 1.9) : 1.9) : (widget ? widget.s(widget.isCompact ? 1.8 : 2.2) : 2.2)
    readonly property real dotSpacing: isVertical ? (widget ? widget.s(widget.isCompact ? 0.8 : 1.0) : 1.0) : (widget ? widget.s(widget.isCompact ? 0.9 : 1.1) : 1.1)

    implicitWidth: bodyLoader.item ? bodyLoader.item.implicitWidth : 0
    implicitHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0

    QtObject {
        id: matrixFont
        readonly property var chars: ({
            "0": [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1],
            "1": [0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1],
            "2": [1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1],
            "3": [1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1],
            "4": [1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1],
            "5": [1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1],
            "6": [1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1],
            "7": [1,1,1, 0,0,1, 0,0,1, 0,0,1, 0,0,1],
            "8": [1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1],
            "9": [1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1],
            ":": [0,0,0, 0,1,0, 0,0,0, 0,1,0, 0,0,0],
            ".": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,1,0],
            "-": [0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0],
            "/": [0,0,1, 0,0,1, 0,1,0, 1,0,0, 1,0,0],
            ",": [0,0,0, 0,0,0, 0,0,0, 0,1,0, 1,0,0],
            " ": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0],
            "A": [0,1,0, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "B": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,1,0],
            "C": [0,1,1, 1,0,0, 1,0,0, 1,0,0, 0,1,1],
            "D": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,1,0],
            "E": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,1,1],
            "F": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,0,0],
            "G": [0,1,1, 1,0,0, 1,0,1, 1,0,1, 0,1,1],
            "H": [1,0,1, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "I": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 1,1,1],
            "J": [0,0,1, 0,0,1, 0,0,1, 1,0,1, 0,1,0],
            "K": [1,0,1, 1,1,0, 1,0,0, 1,1,0, 1,0,1],
            "L": [1,0,0, 1,0,0, 1,0,0, 1,0,0, 1,1,1],
            "M": [1,0,1, 1,1,1, 1,0,1, 1,0,1, 1,0,1],
            "N": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,0,1],
            "O": [0,1,0, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "P": [1,1,0, 1,0,1, 1,1,0, 1,0,0, 1,0,0],
            "Q": [0,1,0, 1,0,1, 1,0,1, 0,1,1, 0,0,1],
            "R": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,0,1],
            "S": [0,1,1, 1,0,0, 0,1,0, 0,0,1, 1,1,0],
            "T": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 0,1,0],
            "U": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "V": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "W": [1,0,1, 1,0,1, 1,0,1, 1,1,1, 1,0,1],
            "X": [1,0,1, 1,0,1, 0,1,0, 1,0,1, 1,0,1],
            "Y": [1,0,1, 1,0,1, 0,1,0, 0,1,0, 0,1,0],
            "Z": [1,1,1, 0,0,1, 0,1,0, 1,0,0, 1,1,1]
        })

        function getPattern(charStr) {
            return chars[charStr] || chars[charStr.toUpperCase()] || [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0];
        }
    }

    component DotMatrixChar: Grid {
        id: dmChar
        property string character: ""
        property color activeColor: ThemeBackend.text
        readonly property var pattern: matrixFont.getPattern(character)

        columns: 3
        rows: 5
        spacing: badgeFaceRoot.dotSpacing

        Repeater {
            model: 15

            Rectangle {
                required property int index
                readonly property bool isLit: dmChar.pattern && dmChar.pattern[index] === 1

                width: badgeFaceRoot.dotSize
                height: badgeFaceRoot.dotSize
                radius: badgeFaceRoot.dotSize / 2
                color: isLit ? dmChar.activeColor : Qt.alpha(dmChar.activeColor, 0.1)
            }
        }
    }

    Loader {
        id: bodyLoader
        anchors.centerIn: parent
        sourceComponent: badgeFaceRoot.isVertical ? sideBodyComponent : topBodyComponent
    }

    Component {
        id: topBodyComponent

        Row {
            id: badgeRow
            spacing: widget ? widget.s(widget.isCompact ? 6 : 8.5) : 8.5

            Row {
                id: timeRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

                Repeater {
                    model: badgeFaceRoot.timeStr.length

                    DotMatrixChar {
                        required property int index
                        readonly property int colonIndex: badgeFaceRoot.timeStr.indexOf(":")
                        character: badgeFaceRoot.timeStr.charAt(index)
                        activeColor: character === ":"
                            ? ThemeBackend.subtext0
                            : (colonIndex === -1 || index < colonIndex ? ThemeBackend.blue : ThemeBackend.text)
                    }
                }
            }

            Grid {
                id: matrixDivider
                visible: widget ? widget.showDate : true
                columns: 1
                rows: 5
                spacing: badgeFaceRoot.dotSpacing
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 5

                    Rectangle {
                        width: badgeFaceRoot.dotSize
                        height: badgeFaceRoot.dotSize
                        radius: badgeFaceRoot.dotSize / 2
                        color: (index === 1 || index === 3)
                            ? Qt.alpha(ThemeBackend.surface2, 0.8)
                            : Qt.alpha(ThemeBackend.surface2, 0.15)
                    }
                }
            }

            Row {
                id: dateRow
                visible: widget ? widget.showDate : true
                anchors.verticalCenter: parent.verticalCenter
                spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

                Repeater {
                    model: badgeFaceRoot.dateStr.length

                    DotMatrixChar {
                        required property int index
                        character: badgeFaceRoot.dateStr.charAt(index)
                        activeColor: {
                            if (/[0-9]/.test(character)) {
                                return (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach;
                            }
                            if (/[\.\-\/\,]/.test(character)) {
                                return ThemeBackend.surface2;
                            }
                            return ThemeBackend.subtext0;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: sideBodyComponent

        Column {
            id: badgeCol
            spacing: widget ? widget.s(widget.isCompact ? 3.5 : 4.5) : 4.5

            Column {
                id: timeCol
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2

                Repeater {
                    model: badgeFaceRoot.sideTimeSegments

                    Row {
                        id: segmentRow
                        required property int index
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

                        Repeater {
                            model: segmentRow.modelData.length

                            DotMatrixChar {
                                required property int index
                                character: segmentRow.modelData.charAt(index)
                                activeColor: {
                                    if (segmentRow.index === 0) return ThemeBackend.blue;
                                    if (segmentRow.modelData === "AM" || segmentRow.modelData === "PM") return ThemeBackend.subtext0;
                                    return ThemeBackend.text;
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: sideDividerDots
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: badgeFaceRoot.dotSpacing

                Repeater {
                    model: 3

                    Rectangle {
                        width: badgeFaceRoot.dotSize
                        height: badgeFaceRoot.dotSize
                        radius: badgeFaceRoot.dotSize / 2
                        color: index === 1
                            ? Qt.alpha(ThemeBackend.surface2, 0.8)
                            : Qt.alpha(ThemeBackend.surface2, 0.15)
                    }
                }
            }

            Column {
                id: dateSubCol
                visible: widget ? widget.showDate : true
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2

                Row {
                    id: dayRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

                    Repeater {
                        model: badgeFaceRoot.dayStr.length

                        DotMatrixChar {
                            required property int index
                            character: badgeFaceRoot.dayStr.charAt(index)
                            activeColor: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach
                        }
                    }
                }

                Text {
                    id: monthLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 7.5 : 8.5) : 8.5
                    font.weight: Font.Black
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                    color: ThemeBackend.subtext0
                }
            }
        }
    }
}
