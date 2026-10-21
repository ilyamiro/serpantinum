import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: sideMaterialFaceRoot
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

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    Column {
        id: mainCol
        anchors.centerIn: parent
        spacing: widget ? widget.s(widget.isCompact ? 4 : 6) : 6

        Item {
            id: diagonalClock
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: {
                if (parsedTime.hasSeconds) {
                    return hourText.width + (widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2) + stackedCol.width;
                }
                if (parsedTime.hasMinutes) {
                    return minuteText.x + minuteText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(1.5) : 1.5) : 0);
                }
                return hourText.width + (ampmText.visible ? ampmText.width + (widget ? widget.s(1.5) : 1.5) : 0);
            }
            implicitHeight: {
                if (parsedTime.hasSeconds) {
                    return Math.max(hourText.height, stackedCol.height);
                }
                if (parsedTime.hasMinutes) {
                    return ampmText.visible
                        ? Math.max(minuteText.y + minuteText.height, ampmText.y + ampmText.height)
                        : (minuteText.y + minuteText.height);
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
                font.pixelSize: {
                    if (parsedTime.hasSeconds) {
                        return widget ? widget.s(widget.isCompact ? 14 : 16) : 16;
                    }
                    return widget ? widget.s(widget.isCompact ? 16 : 18) : 18;
                }
                font.weight: Font.Black
                font.bold: true
                font.letterSpacing: -0.8
                color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
            }

            Text {
                id: minuteText
                visible: !parsedTime.hasSeconds && parsedTime.hasMinutes
                x: widget ? widget.s(widget.isCompact ? 4 : 5) : 5
                y: hourText.height - (widget ? widget.s(widget.isCompact ? 2 : 3) : 3)
                text: parsedTime.minutes
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 15) : 15
                font.weight: Font.Black
                font.bold: true
                font.letterSpacing: -0.6
                color: ThemeBackend.text
            }

            Text {
                id: ampmText
                visible: !parsedTime.hasSeconds && parsedTime.ampm !== ""
                x: parsedTime.hasMinutes
                    ? (minuteText.x + minuteText.width + (widget ? widget.s(1.5) : 1.5))
                    : (hourText.width + (widget ? widget.s(1.5) : 1.5))
                y: parsedTime.hasMinutes
                    ? (minuteText.y + minuteText.height - height - (widget ? widget.s(1) : 1))
                    : (hourText.y + hourText.height - height - (widget ? widget.s(1) : 1))
                text: parsedTime.ampm
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 6.5 : 7.5) : 7.5
                font.weight: Font.Black
                font.bold: true
                color: ThemeBackend.subtext0
            }

            Column {
                id: stackedCol
                visible: parsedTime.hasSeconds
                x: hourText.width + (widget ? widget.s(widget.isCompact ? 1.5 : 2) : 2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: widget ? widget.s(widget.isCompact ? 0 : 0.5) : 0.5

                Text {
                    text: parsedTime.minutes
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
                    font.weight: Font.Black
                    font.bold: true
                    font.letterSpacing: -0.4
                    color: ThemeBackend.text
                }

                Text {
                    x: widget ? widget.s(widget.isCompact ? 1 : 1.5) : 1.5
                    text: parsedTime.seconds
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 7.5 : 8.5) : 8.5
                    font.weight: Font.Black
                    font.bold: true
                    font.letterSpacing: -0.3
                    color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
                }

                Text {
                    visible: parsedTime.ampm !== ""
                    x: widget ? widget.s(widget.isCompact ? 1 : 1.5) : 1.5
                    text: parsedTime.ampm
                    font.family: "Monocraft"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
                    font.weight: Font.Black
                    font.bold: true
                    color: ThemeBackend.subtext0
                }
            }
        }

        Rectangle {
            id: dateDivider
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
                text: widget ? widget.dayStr : (typeof DateTime !== "undefined" ? DateTime.day : "18")
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 10 : 11) : 11
                font.weight: Font.Black
                font.bold: true
                color: ThemeBackend.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
                font.family: "Monocraft"
                font.pixelSize: widget ? widget.s(widget.isCompact ? 8.5 : 9.5) : 9.5
                font.weight: Font.Black
                font.bold: true
                color: ThemeBackend.subtext0
            }
        }
    }
}
