import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: sideClassicFaceRoot
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

    implicitWidth: timeCol.implicitWidth
    implicitHeight: timeCol.implicitHeight

    Column {
        id: timeCol
        anchors.centerIn: parent
        spacing: widget ? widget.s(1) : 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parsedTime.hours
            font.family: "Monocraft"
            font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
            font.weight: Font.Black
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
        }

        Text {
            visible: parsedTime.hasMinutes
            anchors.horizontalCenter: parent.horizontalCenter
            text: parsedTime.minutes
            font.family: "Monocraft"
            font.pixelSize: widget ? widget.s(widget.isCompact ? 13 : 14) : 14
            font.weight: Font.Black
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.sapphire, 1.1) : ThemeBackend.sapphire
        }

        Text {
            visible: parsedTime.hasSeconds
            anchors.horizontalCenter: parent.horizontalCenter
            text: parsedTime.seconds
            font.family: "Monocraft"
            font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
            font.weight: Font.Bold
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal
        }

        Text {
            visible: parsedTime.ampm !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: parsedTime.ampm
            font.family: "Monocraft"
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
            font.family: "Monocraft"
            font.pixelSize: widget ? widget.s(widget.isCompact ? 11 : 12) : 12
            font.weight: Font.Bold
            color: ThemeBackend.text
        }

        Text {
            visible: widget ? widget.showDate : true
            anchors.horizontalCenter: parent.horizontalCenter
            text: widget ? widget.monthStr : (typeof DateTime !== "undefined" ? DateTime.monthShort : "Sep")
            font.family: "Monocraft"
            font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
            font.weight: Font.Bold
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.subtext0, 1.08) : ThemeBackend.subtext0
        }
    }
}
