import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: materialFaceRoot
    property var widget: null

    readonly property string fullTimeStr: {
        if (widget && widget.timeStr !== undefined && widget.timeStr !== null && String(widget.timeStr) !== "") {
            return String(widget.timeStr);
        }
        if (typeof DateTime !== "undefined" && DateTime.time !== undefined && DateTime.time !== null && String(DateTime.time) !== "") {
            return String(DateTime.time);
        }
        var h = widget && widget.hourStr !== undefined ? String(widget.hourStr) : (typeof DateTime !== "undefined" && DateTime.hour !== undefined ? String(DateTime.hour) : "14");
        var m = widget && widget.minuteStr !== undefined && String(widget.minuteStr) !== "" ? String(widget.minuteStr) : "";
        var s = widget && widget.secondStr !== undefined && String(widget.secondStr) !== "" ? String(widget.secondStr) : "";
        if (s !== "") return h + ":" + m + ":" + s;
        if (m !== "") return h + ":" + m;
        return h;
    }

    readonly property var parsedTime: {
        var str = fullTimeStr.trim();
        var ap = "";

        var ampmMatch = str.match(/\s*([a-zA-Z.]+)\s*$/);
        if (ampmMatch && /^(am|pm|a\.m\.|p\.m\.)$/i.test(ampmMatch[1])) {
            ap = ampmMatch[1].toUpperCase().replace(/\./g, "");
            str = str.substring(0, ampmMatch.index).trim();
        }

        var parts = str.split(":");
        var h = parts.length > 0 && parts[0] !== "" ? parts[0] : (widget && widget.hourStr ? String(widget.hourStr) : "14");
        var m = parts.length > 1 ? parts[1] : "";
        var s = parts.length > 2 ? parts[2] : "";

        return {
            hours: h,
            minutes: m,
            seconds: s,
            ampm: ap,
            hasMinutes: m !== "",
            hasSeconds: s !== ""
        };
    }

    readonly property var parsedDate: {
        var day = widget && widget.dayStr !== undefined ? String(widget.dayStr) : (typeof DateTime !== "undefined" && DateTime.day !== undefined ? String(DateTime.day) : "");
        var month = widget && widget.monthStr !== undefined ? String(widget.monthStr) : (typeof DateTime !== "undefined" && DateTime.monthShort !== undefined ? String(DateTime.monthShort) : "");
        var weekday = typeof DateTime !== "undefined" && DateTime.dayOfWeekShort !== undefined ? String(DateTime.dayOfWeekShort) : "";
        var raw = widget && widget.dateStr !== undefined ? String(widget.dateStr) : (typeof DateTime !== "undefined" && DateTime.fullDate !== undefined ? String(DateTime.fullDate) : "Mon, Jan 1");

        if (day === "" || month === "") {
            var match = raw.match(/([a-zA-Z]+)[,\s]+([a-zA-Z]+)\s+(\d+)/);
            if (match) {
                weekday = match[1];
                month = match[2];
                day = match[3];
            } else {
                var numMatch = raw.match(/(\d+)/);
                if (numMatch) {
                    day = numMatch[1];
                    var rem = raw.replace(numMatch[1], "").replace(/[,]/g, " ").trim().split(/\s+/);
                    if (rem.length > 1) {
                        weekday = rem[0];
                        month = rem[1];
                    } else if (rem.length === 1 && rem[0] !== "") {
                        month = rem[0];
                    }
                } else {
                    day = raw;
                }
            }
        }

        return {
            day: day,
            month: month.toUpperCase(),
            weekday: weekday.toUpperCase()
        };
    }

    implicitWidth: contentRow.implicitWidth
    implicitHeight: contentRow.implicitHeight

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: widget ? widget.s(widget.isCompact ? 6 : 8) : 8

        Item {
            id: diagonalClock
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: {
                if (parsedTime.hasSeconds) {
                    return hourText.width + (widget ? widget.s(4) : 4) + stackedCol.width;
                }
                if (parsedTime.hasMinutes) {
                    return minuteText.x + minuteText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(2) : 2) : 0);
                }
                return hourText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(2) : 2) : 0);
            }
            implicitHeight: {
                if (parsedTime.hasSeconds) {
                    return Math.max(hourText.height, stackedCol.height);
                }
                if (parsedTime.hasMinutes) {
                    return minuteText.y + minuteText.height;
                }
                return hourText.height;
            }
            width: implicitWidth
            height: implicitHeight

            Text {
                id: hourText
                x: 0
                anchors.verticalCenter: parsedTime.hasSeconds ? parent.verticalCenter : undefined
                y: parsedTime.hasSeconds ? 0 : 0
                text: parsedTime.hours
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? (parsedTime.hasSeconds ? 18 : 17) : (parsedTime.hasSeconds ? 22 : 20)) : (parsedTime.hasSeconds ? 22 : 20)
                font.weight: Font.Black
                font.bold: true
                font.letterSpacing: -0.8
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
            }

            Text {
                id: minuteText
                visible: !parsedTime.hasSeconds && parsedTime.hasMinutes
                x: hourText.width + (widget ? widget.s(1) : 1)
                y: widget ? widget.s(widget.isCompact ? 5 : 7) : 7
                text: parsedTime.minutes
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 14 : 16) : 16
                font.weight: Font.Black
                font.bold: true
                font.letterSpacing: -0.5
                color: ThemeBackend.text
            }

            Text {
                id: ampmText
                visible: !parsedTime.hasSeconds && parsedTime.ampm !== ""
                x: parsedTime.hasMinutes
                    ? (minuteText.x + minuteText.width + (widget ? widget.s(2) : 2))
                    : (hourText.width + (widget ? widget.s(2) : 2))
                y: parsedTime.hasMinutes
                    ? (minuteText.y + minuteText.height - height - (widget ? widget.s(1) : 1))
                    : (hourText.y + hourText.height - height - (widget ? widget.s(1) : 1))
                text: parsedTime.ampm
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                font.weight: Font.Black
                font.bold: true
                color: ThemeBackend.subtext0
            }

            Column {
                id: stackedCol
                visible: parsedTime.hasSeconds
                x: hourText.width + (widget ? widget.s(4) : 4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Row {
                    spacing: widget ? widget.s(2) : 2
                    Text {
                        text: parsedTime.minutes
                        font.family: "Monocraft"
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
                        font.weight: Font.Black
                        font.bold: true
                        font.letterSpacing: -0.4
                        color: ThemeBackend.text
                    }

                    Text {
                        visible: parsedTime.ampm !== ""
                        text: parsedTime.ampm
                        font.family: "Monocraft"
                        font.pixelSize: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
                        font.weight: Font.Black
                        font.bold: true
                        color: ThemeBackend.subtext0
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: widget ? widget.s(1) : 1
                    }
                }

                Text {
                    x: widget ? widget.s(2) : 2
                    text: parsedTime.seconds
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                    font.weight: Font.Black
                    font.bold: true
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
                text: parsedDate.day
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 15) : 15
                font.weight: Font.Black
                font.bold: true
                font.letterSpacing: -0.5
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
            }

            Column {
                id: monthCol
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    visible: parsedDate.weekday !== ""
                    text: parsedDate.weekday
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
                    font.weight: Font.Black
                    font.bold: true
                    font.letterSpacing: 0.2
                    color: ThemeBackend.subtext0
                }

                Text {
                    visible: parsedDate.month !== ""
                    text: parsedDate.month
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 8 : 9) : 9
                    font.weight: Font.Black
                    font.bold: true
                    font.letterSpacing: -0.2
                    color: ThemeBackend.text
                }
            }
        }
    }
}
