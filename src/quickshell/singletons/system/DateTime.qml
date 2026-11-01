pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: root

    property var now: new Date()
    property int _lastDay: -1
    property int _lastMinuteKey: -1
    property string _lastLang: ""

    readonly property string timeFormat: {
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) {
                return Config.rawSettings.bar.time.format;
            }
            if (Config.rawSettings.general && Config.rawSettings.general.time_format !== undefined) {
                return Config.rawSettings.general.time_format;
            }
        }
        return "HH:mm:ss";
    }

    readonly property string hourFormat: {
        if (timeFormat.indexOf("HH") !== -1) return "HH";
        if (timeFormat.indexOf("hh") !== -1) return "hh";
        if (timeFormat.indexOf("H") !== -1) return "H";
        if (timeFormat.indexOf("h") !== -1) return "h";
        return "HH";
    }

    readonly property string minuteFormat: {
        if (timeFormat.indexOf("mm") !== -1) return "mm";
        if (timeFormat.indexOf("m") !== -1) return "m";
        return "mm";
    }

    readonly property string secondFormat: {
        if (timeFormat.indexOf("ss") !== -1) return "ss";
        if (timeFormat.indexOf("s") !== -1) return "s";
        return "";
    }

    readonly property string amPmFormat: {
        if (timeFormat.indexOf("AP") !== -1) return "AP";
        if (timeFormat.indexOf("ap") !== -1) return "ap";
        if (timeFormat.indexOf("A") !== -1 || timeFormat.indexOf("a") !== -1) return "AP";
        return "";
    }

    readonly property bool is12Hour: amPmFormat !== "" || hourFormat === "hh" || hourFormat === "h"
    readonly property bool hasSeconds: secondFormat !== "" || timeFormat.indexOf("ss") !== -1 || timeFormat.indexOf("s") !== -1

    property string time: ""
    property string timeShort: ""
    property string timeLong: ""
    property string timeOnly: ""

    property string hour: ""
    property string minute: ""
    property string second: ""
    property string amPm: ""

    readonly property string fullDatePattern: {
        if (typeof I18n === "undefined" || !I18n.isReady) return "dddd, MMMM dd";
        let pattern = I18n.t("datetime.full_date");
        return (pattern && pattern !== "datetime.full_date") ? pattern : "dddd, MMMM dd";
    }

    property string fullDate: ""
    property string shortDate: ""
    property string dateBadge: ""
    property string day: ""
    property string dayShort: ""
    property string dayName: ""
    property string dayNameShort: ""
    readonly property alias dayOfWeekShort: root.dayNameShort
    property string month: ""
    property string monthShort: ""
    property string year: ""

    function format(pattern, dateObj) {
        return Qt.formatDateTime(dateObj || now, pattern);
    }

    function syncTimer(d) {
        if (!d) d = new Date();
        if (root.hasSeconds) {
            clockTimer.interval = 1000;
        } else {
            let msToNextMinute = (60 - d.getSeconds()) * 1000 - d.getMilliseconds();
            clockTimer.interval = Math.max(500, msToNextMinute);
        }
    }

    function updateTime(forceAll) {
        let d = new Date();
        root.now = d;

        let curSec = root.hasSeconds ? Qt.formatDateTime(d, secondFormat !== "" ? secondFormat : "ss") : "";
        if (root.second !== curSec) root.second = curSec;

        let curTime = Qt.formatDateTime(d, timeFormat);
        if (root.time !== curTime) root.time = curTime;
        if (root.timeOnly !== curTime) root.timeOnly = curTime;

        let curTimeLong = timeFormat === "HH:mm:ss" ? curTime : Qt.formatDateTime(d, "HH:mm:ss");
        if (root.timeLong !== curTimeLong) root.timeLong = curTimeLong;

        let minuteKey = d.getHours() * 60 + d.getMinutes();
        if (forceAll || root._lastMinuteKey !== minuteKey) {
            root._lastMinuteKey = minuteKey;

            let curMin = Qt.formatDateTime(d, minuteFormat);
            if (root.minute !== curMin) root.minute = curMin;

            let curHour = Qt.formatDateTime(d, hourFormat);
            if (root.hour !== curHour) root.hour = curHour;

            let curAmPm = amPmFormat !== "" ? Qt.formatDateTime(d, amPmFormat) : "";
            if (root.amPm !== curAmPm) root.amPm = curAmPm;

            let curTimeShort = Qt.formatDateTime(d, hourFormat + ":" + minuteFormat + (amPmFormat !== "" ? " " + amPmFormat : ""));
            if (root.timeShort !== curTimeShort) root.timeShort = curTimeShort;
        }

        let curDay = d.getDate();
        let curLang = (typeof I18n !== "undefined" && I18n.currentLang) ? I18n.currentLang : "en";
        if (forceAll || root._lastDay !== curDay || root._lastLang !== curLang) {
            root._lastDay = curDay;
            root._lastLang = curLang;
            let loc = Qt.locale(typeof I18n !== "undefined" ? I18n.qtLocaleName : curLang);
            root.fullDate = d.toLocaleDateString(loc, fullDatePattern);
            root.shortDate = d.toLocaleDateString(loc, "d MMM");
            root.dateBadge = d.toLocaleDateString(loc, "d MMM").toUpperCase();
            root.day = Qt.formatDateTime(d, "dd");
            root.dayShort = Qt.formatDateTime(d, "d");
            root.dayName = d.toLocaleDateString(loc, "dddd");
            root.dayNameShort = d.toLocaleDateString(loc, "ddd");
            root.month = d.toLocaleDateString(loc, "MMMM");
            root.monthShort = d.toLocaleDateString(loc, "MMM");
            root.year = Qt.formatDateTime(d, "yyyy");
        }

        syncTimer(d);
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTime(false)
    }

    onTimeFormatChanged: {
        root.updateTime(true);
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            root.updateTime(true);
        }
        function onRawSettingsChanged() {
            root.updateTime(true);
        }
    }

    Connections {
        target: typeof I18n !== "undefined" ? I18n : null
        function onLanguageChanged() {
            root.updateTime(true);
        }
        function onIsReadyChanged() {
            root.updateTime(true);
        }
    }

    Component.onCompleted: {
        root.updateTime(true);
    }
}
