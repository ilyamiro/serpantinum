import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: sideBadgeFaceRoot
    property var widget: null

    readonly property string timeStr: widget ? widget.timeStr : (typeof DateTime !== "undefined" ? DateTime.time : "14:28")
    readonly property string dayStr: widget ? String(widget.dayStr) : (typeof DateTime !== "undefined" ? String(DateTime.day) : "18")
    readonly property real dotSize: widget ? widget.s(widget.isCompact ? 1.6 : 1.9) : 1.9
    readonly property real dotSpacing: widget ? widget.s(widget.isCompact ? 0.8 : 1.0) : 1.0

    implicitWidth: badgeCol.implicitWidth
    implicitHeight: badgeCol.implicitHeight

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
            " ": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0],
            "A": [0,1,0, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "P": [1,1,0, 1,0,1, 1,1,0, 1,0,0, 1,0,0],
            "M": [1,0,1, 1,1,1, 1,0,1, 1,0,1, 1,0,1]
        })
        function getPattern(charStr) {
            return chars[charStr] || chars[charStr.toUpperCase()] || [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0]
        }
    }

    Column {
        id: badgeCol
        anchors.centerIn: parent
        spacing: widget ? widget.s(widget.isCompact ? 3.5 : 4.5) : 4.5

        Column {
            id: timeCol
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2

            Repeater {
                model: {
                    var str = String(sideBadgeFaceRoot.timeStr || "").trim();
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
                    return res.length > 0 ? res : [sideBadgeFaceRoot.timeStr];
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
                            id: charGrid
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
                            spacing: sideBadgeFaceRoot.dotSpacing

                            Repeater {
                                model: 15

                                Rectangle {
                                    property int dotIndex: index
                                    property bool isLit: charGrid.pattern && charGrid.pattern[dotIndex] === 1

                                    width: sideBadgeFaceRoot.dotSize
                                    height: sideBadgeFaceRoot.dotSize
                                    radius: sideBadgeFaceRoot.dotSize / 2
                                    color: isLit ? charGrid.activeColor : Qt.alpha(charGrid.activeColor, 0.1)
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
            spacing: sideBadgeFaceRoot.dotSpacing

            Repeater {
                model: 3

                Rectangle {
                    width: sideBadgeFaceRoot.dotSize
                    height: sideBadgeFaceRoot.dotSize
                    radius: sideBadgeFaceRoot.dotSize / 2
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
                    model: sideBadgeFaceRoot.dayStr.length

                    Grid {
                        id: dayGrid
                        property int charIndex: index
                        property string character: sideBadgeFaceRoot.dayStr.charAt(charIndex)
                        property var pattern: matrixFont.getPattern(character)
                        property color activeColor: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach

                        columns: 3
                        rows: 5
                        spacing: sideBadgeFaceRoot.dotSpacing

                        Repeater {
                            model: 15

                            Rectangle {
                                property int dotIndex: index
                                property bool isLit: dayGrid.pattern && dayGrid.pattern[dotIndex] === 1

                                width: sideBadgeFaceRoot.dotSize
                                height: sideBadgeFaceRoot.dotSize
                                radius: sideBadgeFaceRoot.dotSize / 2
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
                font.family: "Monocraft"
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
