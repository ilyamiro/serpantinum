import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"

GuideTab {
    id: tabRoot

    property alias appListModel: appListModel
    property alias monthListModel: monthListModel
    property alias weekAppListModel: weekAppListModel
    property alias weekListModel: weekListModel

    readonly property color textMain: ThemeBackend.liquidGlass ? "#ffffff" : ThemeBackend.text
    readonly property color textSub: ThemeBackend.liquidGlass ? "#ffffff" : ThemeBackend.subtext0
    readonly property color textDim: ThemeBackend.liquidGlass ? "#ffffff" : ThemeBackend.overlay0
    readonly property color textAccent: ThemeBackend.liquidGlass ? "#ffffff" : ThemeBackend.mauve

    readonly property var monthNames: [
        I18n.t("guide.wellbeing.months.january"),
        I18n.t("guide.wellbeing.months.february"),
        I18n.t("guide.wellbeing.months.march"),
        I18n.t("guide.wellbeing.months.april"),
        I18n.t("guide.wellbeing.months.may"),
        I18n.t("guide.wellbeing.months.june"),
        I18n.t("guide.wellbeing.months.july"),
        I18n.t("guide.wellbeing.months.august"),
        I18n.t("guide.wellbeing.months.september"),
        I18n.t("guide.wellbeing.months.october"),
        I18n.t("guide.wellbeing.months.november"),
        I18n.t("guide.wellbeing.months.december")
    ]

    property var globalDate: new Date()
    property var appDate: new Date()
    readonly property var activeDate: tabRoot.selectedAppClass === "" ? tabRoot.globalDate : tabRoot.appDate

    property string selectedDateStr: ""
    property string selectedAppClass: ""
    property string selectedAppName: ""
    property string selectedAppIcon: ""
    property int totalSeconds: 0
    property int averageSeconds: 0
    property int yesterdaySeconds: 0
    property string weekRangeStr: ""
    property string liveActiveApp: I18n.t("guide.wellbeing.desktop")

    property bool isWeekView: false
    property bool isSettingsView: false

    property var topApps: []
    property var weekData: []
    property real maxWeekTotal: 1
    property var monthData: []
    property real maxMonthTotal: 1

    property var weekAppsData: []
    property var weekHeatmapData: [[],[],[],[],[],[],[]]
    property real maxWeekHour: 1
    property string peakUsageHours: I18n.t("guide.wellbeing.not_available")

    property var hourlyData: new Array(48).fill(0)
    property real maxHourlyTotal: 1

    property var allKnownApps: []

    property real animatedTotalSeconds: 0
    Behavior on animatedTotalSeconds {
        NumberAnimation { duration: 850; easing.type: Easing.OutQuint }
    }
    onTotalSecondsChanged: {
        animatedTotalSeconds = totalSeconds;
    }

    property real weekViewFocus: tabRoot.isWeekView && !tabRoot.isSettingsView ? 1.0 : 0.0
    Behavior on weekViewFocus { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }

    property real appViewFocus: tabRoot.selectedAppClass !== "" && !tabRoot.isSettingsView ? 1.0 : 0.0
    Behavior on appViewFocus { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }

    property real settingsViewFocus: tabRoot.isSettingsView ? 1.0 : 0.0
    Behavior on settingsViewFocus { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }

    property bool isFirstLoad: true
    readonly property bool isTodaySelected: getIsoDate(tabRoot.activeDate) === getIsoDate(new Date())

    readonly property string scriptsDir: rootObj.appPaths.qsDir + "/guide/wellbeing"
    readonly property string stateFilePath: rootObj.appPaths.getRunDir("focustime") + "/focustime_state.json"

    property real introHeader: 0.0
    property real introStats: 0.0
    property real introMidLeft: 0.0
    property real introMidRight: 0.0
    property real introBottom: 0.0
    property real introAppBars: 0.0

    ParallelAnimation {
        id: introAnim

        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: tabRoot; property: "introHeader"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: tabRoot; property: "introStats"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: tabRoot; property: "introMidLeft"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuart }
        }
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation { target: tabRoot; property: "introAppBars"; from: 0; to: 1.0; duration: 1300; easing.type: Easing.OutQuart }
        }
        SequentialAnimation {
            PauseAnimation { duration: 450 }
            NumberAnimation { target: tabRoot; property: "introMidRight"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuart }
        }
        SequentialAnimation {
            PauseAnimation { duration: 550 }
            NumberAnimation { target: tabRoot; property: "introBottom"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutExpo }
        }
    }

    function resolveApp(appClass, fallbackName) {
        if (!appClass) return { class: appClass, name: fallbackName || appClass, icon: "" };
        let entry = DesktopEntries.heuristicLookup(appClass);
        if (entry) {
            return { class: appClass, name: entry.name || fallbackName || appClass, icon: entry.icon || "" };
        }
        return { class: appClass, name: fallbackName || appClass, icon: "" };
    }

    function enrichApps(list) {
        return list.map(function(a) {
            let r = tabRoot.resolveApp(a.class, a.name);
            return Object.assign({}, a, { name: r.name, icon: r.icon });
        });
    }

    Timer {
        id: dataUpdateDebounceTimer
        interval: 200
        repeat: false
        onTriggered: requestDataUpdate()
    }

    function activateTab() {
        dataUpdateDebounceTimer.restart();
        introHeader = 0.0; introStats = 0.0; introMidLeft = 0.0;
        introMidRight = 0.0; introBottom = 0.0; introAppBars = 0.0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) activateTab();
    }

    Component.onCompleted: {
        if (visible) activateTab();
    }

    function updateFromData(data) {
        tabRoot.selectedDateStr = data.selected_date;
        tabRoot.totalSeconds = data.total || 0;
        tabRoot.averageSeconds = data.average || 0;
        tabRoot.yesterdaySeconds = data.yesterday || 0;
        tabRoot.weekRangeStr = data.week_range || "";
        tabRoot.liveActiveApp = data.current || I18n.t("guide.about.unknown");

        if (tabRoot.isFirstLoad) firstLoadTimer.start();

        tabRoot.topApps = tabRoot.enrichApps(data.apps || []);
        syncAppsModel();

        tabRoot.weekAppsData = tabRoot.enrichApps(data.week_apps || []);
        syncWeekAppsModel();

        tabRoot.allKnownApps = tabRoot.enrichApps(data.all_known_apps || []);

        tabRoot.weekHeatmapData = data.week_heatmap || [[],[],[],[],[],[],[]];
        let mwh = 1;
        let hourSums = new Array(24).fill(0);

        for (let i = 0; i < 7; i++) {
            if (!tabRoot.weekHeatmapData[i]) continue;
            for (let j = 0; j < 24; j++) {
                if (tabRoot.weekHeatmapData[i][j] > mwh) mwh = tabRoot.weekHeatmapData[i][j];
                hourSums[j] += tabRoot.weekHeatmapData[i][j];
            }
        }
        tabRoot.maxWeekHour = mwh;

        let max2HourVal = -1;
        let peakStart = 0;
        for (let h = 0; h < 23; h++) {
            let current2H = hourSums[h] + hourSums[h+1];
            if (current2H > max2HourVal) {
                max2HourVal = current2H;
                peakStart = h;
            }
        }

        function formatAMPM(hour) {
            let ampm = hour >= 12 ? I18n.t("guide.wellbeing.pm") : I18n.t("guide.wellbeing.am");
            let h12 = hour % 12;
            h12 = h12 ? h12 : 12;
            return h12 + ' ' + ampm;
        }

        if (max2HourVal > 0) {
            tabRoot.peakUsageHours = formatAMPM(peakStart) + " - " + formatAMPM(peakStart + 2);
        } else {
            tabRoot.peakUsageHours = I18n.t("guide.wellbeing.not_available");
        }

        let parsedWeek = data.week || [];
        if (JSON.stringify(tabRoot.weekData) !== JSON.stringify(parsedWeek)) {
            tabRoot.weekData = parsedWeek;
            syncWeekModel();
        }

        let parsedMonth = data.month || [];
        if (JSON.stringify(tabRoot.monthData) !== JSON.stringify(parsedMonth)) {
            tabRoot.monthData = parsedMonth;
            syncMonthModel();
        }

        tabRoot.hourlyData = data.hourly || new Array(48).fill(0);
        let currentMaxHour = 1;
        for(let i=0; i<48; i++) {
            if (tabRoot.hourlyData[i] > currentMaxHour) currentMaxHour = tabRoot.hourlyData[i];
        }
        tabRoot.maxHourlyTotal = currentMaxHour;
    }

    function requestDataUpdate() {
        if (tabRoot.selectedAppClass === "" && getIsoDate(tabRoot.activeDate) === getIsoDate(new Date())) {
            liveFileReader.running = true;
        } else {
            let cmd = ["python3", tabRoot.scriptsDir + "/get_stats.py", getIsoDate(tabRoot.activeDate)];
            if (tabRoot.selectedAppClass !== "") {
                cmd.push("--app");
                cmd.push(tabRoot.selectedAppClass);
            }
            cmd.push("--db-dir");
            cmd.push(rootObj.appPaths.getStateDir("focustime"));
            statsPoller.command = cmd;
            statsPoller.running = true;
        }
    }

    Process {
        id: liveFileReader
        command: ["cat", tabRoot.stateFilePath]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    let data = JSON.parse(raw);
                    tabRoot.updateFromData(data);
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: tabRoot.isTodaySelected && tabRoot.visible
        repeat: true
        onTriggered: tabRoot.requestDataUpdate()
    }

    Process {
        id: statsPoller
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    let data = JSON.parse(raw);
                    tabRoot.updateFromData(data);
                } catch(e) {}
            }
        }
    }

    function getIsoDate(d) {
        let z = d.getTimezoneOffset() * 60000;
        return (new Date(d - z)).toISOString().slice(0, 10);
    }

    function getFancyDate(d) {
        let monthName = tabRoot.monthNames[d.getMonth()];
        let dateNum = d.getDate();
        let isToday = getIsoDate(d) === getIsoDate(new Date());
        return isToday ? I18n.t("guide.wellbeing.today") : `${monthName} ${dateNum}`;
    }

    function changeDay(offsetDays) {
        let d = new Date(tabRoot.activeDate);
        d.setDate(d.getDate() + offsetDays);
        if (tabRoot.selectedAppClass === "") {
            tabRoot.globalDate = d;
        } else {
            tabRoot.appDate = d;
        }
        tabRoot.isFirstLoad = true;
        tabRoot.requestDataUpdate();
    }

    function changeToDate(clickedDateStr) {
        if (!clickedDateStr) return;
        let currentIso = getIsoDate(tabRoot.activeDate);
        if (clickedDateStr === currentIso) return;
        let dCurrent = new Date(currentIso + "T12:00:00");
        let dClicked = new Date(clickedDateStr + "T12:00:00");
        let diffDays = Math.round((dClicked - dCurrent) / (1000 * 60 * 60 * 24));
        if (diffDays !== 0) changeDay(diffDays);
    }

    Timer {
        id: firstLoadTimer
        interval: 1000
        onTriggered: tabRoot.isFirstLoad = false
    }

    ListModel { id: appListModel }
    ListModel { id: weekAppListModel }
    ListModel { id: weekListModel }
    ListModel { id: monthListModel }

    function syncAppsModel() {
        for (let i = 0; i < tabRoot.topApps.length; i++) {
            let app = tabRoot.topApps[i];
            if (i < appListModel.count) {
                appListModel.setProperty(i, "name", app.name);
                appListModel.setProperty(i, "appClass", app.class);
                appListModel.setProperty(i, "icon", app.icon || "");
                appListModel.setProperty(i, "seconds", app.seconds);
                appListModel.setProperty(i, "percent", app.percent);
            } else {
                appListModel.append({
                    name: app.name, appClass: app.class, icon: app.icon || "",
                    seconds: app.seconds, percent: app.percent, idx: i
                });
            }
        }
        while (appListModel.count > tabRoot.topApps.length) appListModel.remove(appListModel.count - 1);
    }

    function syncWeekAppsModel() {
        for (let i = 0; i < tabRoot.weekAppsData.length; i++) {
            let app = tabRoot.weekAppsData[i];
            if (i < weekAppListModel.count) {
                weekAppListModel.setProperty(i, "name", app.name);
                weekAppListModel.setProperty(i, "appClass", app.class);
                weekAppListModel.setProperty(i, "icon", app.icon || "");
                weekAppListModel.setProperty(i, "seconds", app.seconds);
                weekAppListModel.setProperty(i, "percent", app.percent);
            } else {
                weekAppListModel.append({
                    name: app.name, appClass: app.class, icon: app.icon || "",
                    seconds: app.seconds, percent: app.percent, idx: i
                });
            }
        }
        while (weekAppListModel.count > tabRoot.weekAppsData.length) weekAppListModel.remove(weekAppListModel.count - 1);
    }

    function syncWeekModel() {
        let currentMax = 1;
        for (let i = 0; i < tabRoot.weekData.length; i++) {
            if (tabRoot.weekData[i].total > currentMax) currentMax = tabRoot.weekData[i].total;
        }
        tabRoot.maxWeekTotal = currentMax;

        for (let i = 0; i < tabRoot.weekData.length; i++) {
            let w = tabRoot.weekData[i];
            if (i < weekListModel.count) {
                weekListModel.setProperty(i, "dateStr", w.date);
                weekListModel.setProperty(i, "dayName", w.day);
                weekListModel.setProperty(i, "total", w.total);
                weekListModel.setProperty(i, "isTarget", w.is_target);
            } else {
                weekListModel.append({ dateStr: w.date, dayName: w.day, total: w.total, isTarget: w.is_target });
            }
        }
        while (weekListModel.count > tabRoot.weekData.length) weekListModel.remove(weekListModel.count - 1);
    }

    function syncMonthModel() {
        let currentMax = 1;
        for (let i = 0; i < tabRoot.monthData.length; i++) {
            if (tabRoot.monthData[i].total > currentMax) currentMax = tabRoot.monthData[i].total;
        }
        tabRoot.maxMonthTotal = currentMax;

        for (let i = 0; i < tabRoot.monthData.length; i++) {
            let m = tabRoot.monthData[i];
            if (i < monthListModel.count) {
                monthListModel.setProperty(i, "dateStr", m.date);
                monthListModel.setProperty(i, "total", m.total);
                monthListModel.setProperty(i, "isTarget", m.is_target);
            } else {
                monthListModel.append({ dateStr: m.date, total: m.total, isTarget: m.is_target });
            }
        }
        while (monthListModel.count > tabRoot.monthData.length) monthListModel.remove(monthListModel.count - 1);
    }

    function formatTimeLarge(secs) {
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        if (h > 0) return I18n.t("guide.wellbeing.time_hm", { "h": h, "m": m });
        return I18n.t("guide.wellbeing.time_m", { "m": m });
    }

    function formatTimeList(secs) {
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        if (h > 0) return I18n.t("guide.wellbeing.time_hm", { "h": h, "m": m.toString().padStart(2, '0') });
        return I18n.t("guide.wellbeing.time_m", { "m": m });
    }

    Shortcut { sequence: "Left"; enabled: tabRoot.visible && !tabRoot.isSettingsView; onActivated: changeDay(tabRoot.isWeekView ? -7 : -1) }
    Shortcut { sequence: "Right"; enabled: tabRoot.visible && !tabRoot.isSettingsView; onActivated: changeDay(tabRoot.isWeekView ? 7 : 1) }
    Shortcut { sequence: "Home"; enabled: tabRoot.visible && !tabRoot.isSettingsView; onActivated: changeDay(-7) }
    Shortcut { sequence: "End"; enabled: tabRoot.visible && !tabRoot.isSettingsView; onActivated: changeDay(7) }
}
