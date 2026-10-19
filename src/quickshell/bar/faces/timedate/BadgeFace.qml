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
            return String(widget.dateStr).toUpperCase()
        }
        if (widget && widget.dayStr && widget.monthStr) {
            return (String(widget.dayStr) + " " + String(widget.monthStr)).toUpperCase()
        }
        if (typeof DateTime !== "undefined") {
            if (DateTime.day !== undefined && DateTime.monthShort !== undefined) {
                return (String(DateTime.day) + " " + String(DateTime.monthShort)).toUpperCase()
            }
            if (DateTime.fullDate) {
                return String(DateTime.fullDate).toUpperCase()
            }
        }
        return "18 SEP"
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
            return chars[charStr] || chars[charStr.toUpperCase()] || [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0]
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

                    Grid {
                        id: charGrid
                        property int charIndex: index
                        property string character: badgeFaceRoot.timeStr.charAt(charIndex)
                        property var pattern: matrixFont.getPattern(character)
                        property int colonIndex: badgeFaceRoot.timeStr.indexOf(":")
                        property color activeColor: character === ":"
                            ? ThemeBackend.subtext0
                            : (colonIndex === -1 || charIndex < colonIndex ? ThemeBackend.blue : ThemeBackend.text)

                        columns: 3
                        rows: 5
                        spacing: badgeFaceRoot.dotSpacing

                        Repeater {
                            model: 15

                            Rectangle {
                                property int dotIndex: index
                                property bool isLit: charGrid.pattern && charGrid.pattern[dotIndex] === 1

                                width: badgeFaceRoot.dotSize
                                height: badgeFaceRoot.dotSize
                                radius: badgeFaceRoot.dotSize / 2
                                color: isLit ? charGrid.activeColor : Qt.alpha(charGrid.activeColor, 0.1)
                            }
                        }
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

                    Grid {
                        id: dateCharGrid
                        property int charIndex: index
                        property string character: badgeFaceRoot.dateStr.charAt(charIndex)
                        property var pattern: matrixFont.getPattern(character)
                        property color activeColor: {
                            if (/[0-9]/.test(character)) {
                                return (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach
                            }
                            if (/[\.\-\/\,]/.test(character)) {
                                return ThemeBackend.surface2
                            }
                            return ThemeBackend.subtext0
                        }

                        columns: 3
                        rows: 5
                        spacing: badgeFaceRoot.dotSpacing

                        Repeater {
                            model: 15

                            Rectangle {
                                property int dotIndex: index
                                property bool isLit: dateCharGrid.pattern && dateCharGrid.pattern[dotIndex] === 1

                                width: badgeFaceRoot.dotSize
                                height: badgeFaceRoot.dotSize
                                radius: badgeFaceRoot.dotSize / 2
                                color: isLit ? dateCharGrid.activeColor : Qt.alpha(dateCharGrid.activeColor, 0.1)
                            }
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
                    model: {
                        var str = String(badgeFaceRoot.timeStr || "").trim();
                        var ap = "";

                        var ampmMatch = str.match(/\s*([a-zA-Z.]+)\s*$/);
                        if (ampmMatch && /^(am|pm|a\.m\.|p\.m\.)$/i.test(ampmMatch[1])) {
                            ap = ampmMatch[1].toUpperCase().replace(/\./g, "");
                            str = str.substring(0, ampmMatch.index).trim();
                        }

                        var parts = str.split(":");
                        var res = [];
                        for (var i = 0; i < parts.length; i++) {
                            var p = parts[i].trim();
                            if (p !== "") {
                                res.push(p);
                            }
                        }
                        if (ap !== "") {
                            res.push(ap);
                        }
                        return res.length > 0 ? res : [badgeFaceRoot.timeStr];
                    }

                    Row {
                        id: segmentRow
                        property int segmentIndex: index
                        property string segmentStr: modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

                        Repeater {
                            model: segmentRow.segmentStr.length

                            Grid {
                                id: sideCharGrid
                                property int charIndex: index
                                property string character: segmentRow.segmentStr.charAt(charIndex)
                                property var pattern: matrixFont.getPattern(character)
                                property color activeColor: {
                                    if (segmentRow.segmentIndex === 0) return ThemeBackend.blue;
                                    if (segmentRow.segmentStr === "AM" || segmentRow.segmentStr === "PM") return ThemeBackend.subtext0;
                                    return ThemeBackend.text;
                                }

                                columns: 3
                                rows: 5
                                spacing: badgeFaceRoot.dotSpacing

                                Repeater {
                                    model: 15

                                    Rectangle {
                                        property int dotIndex: index
                                        property bool isLit: sideCharGrid.pattern && sideCharGrid.pattern[dotIndex] === 1

                                        width: badgeFaceRoot.dotSize
                                        height: badgeFaceRoot.dotSize
                                        radius: badgeFaceRoot.dotSize / 2
                                        color: isLit ? sideCharGrid.activeColor : Qt.alpha(sideCharGrid.activeColor, 0.1)
                                    }
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

                        Grid {
                            id: dayGrid
                            property int charIndex: index
                            property string character: badgeFaceRoot.dayStr.charAt(charIndex)
                            property var pattern: matrixFont.getPattern(character)
                            property color activeColor: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach

                            columns: 3
                            rows: 5
                            spacing: badgeFaceRoot.dotSpacing

                            Repeater {
                                model: 15

                                Rectangle {
                                    property int dotIndex: index
                                    property bool isLit: dayGrid.pattern && dayGrid.pattern[dotIndex] === 1

                                    width: badgeFaceRoot.dotSize
                                    height: badgeFaceRoot.dotSize
                                    radius: badgeFaceRoot.dotSize / 2
                                    color: isLit ? dayGrid.activeColor : Qt.alpha(dayGrid.activeColor, 0.1)
                                }
                            }
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
