import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: tabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

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

    function activateTab() {
        requestDataUpdate();
        introHeader = 0.0; introStats = 0.0; introMidLeft = 0.0;
        introMidRight = 0.0; introBottom = 0.0; introAppBars = 0.0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) activateTab();
    }

    Component.onCompleted: {
        activateTab();
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

    Shortcut {
        sequence: "Escape"
        enabled: tabRoot.visible && (tabRoot.selectedAppClass !== "" || tabRoot.isWeekView)
        onActivated: {
            if (tabRoot.selectedAppClass !== "") {
                tabRoot.selectedAppClass = "";
                tabRoot.selectedAppName = "";
                tabRoot.selectedAppIcon = "";
                tabRoot.requestDataUpdate();
            } else if (tabRoot.isWeekView) {
                tabRoot.isWeekView = false;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(6)

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: rootObj.s(36)

            opacity: introHeader
            transform: Translate { y: rootObj.s(-20) * (1 - introHeader) }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: rootObj.s(4)

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    size: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰒓"
                    iconFontSize: rootObj.s(16)
                    iconOffsetX: -1
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0
                    onClicked: tabRoot.isSettingsView = !tabRoot.isSettingsView
                }

                Item {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)

                    IconButton {
                        anchors.fill: parent
                        size: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰁍"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0
                        opacity: (tabRoot.selectedAppClass !== "" || tabRoot.isWeekView || tabRoot.isSettingsView) ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        onClicked: {
                            if (tabRoot.isSettingsView) {
                                tabRoot.isSettingsView = false;
                            } else if (tabRoot.selectedAppClass !== "") {
                                tabRoot.selectedAppClass = "";
                                tabRoot.selectedAppName = "";
                                tabRoot.selectedAppIcon = "";
                                tabRoot.requestDataUpdate();
                            } else if (tabRoot.isWeekView) {
                                tabRoot.isWeekView = false;
                            }
                        }
                    }

                    IconButton {
                        anchors.fill: parent
                        size: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰃭"
                        iconFontSize: rootObj.s(16)
                        iconOffsetX: -1
                        accentColor: ThemeBackend.surface0
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0
                        opacity: (tabRoot.selectedAppClass === "" && !tabRoot.isWeekView && !tabRoot.isSettingsView) ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        onClicked: tabRoot.isWeekView = true
                    }
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    size: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰅁"
                    iconFontSize: rootObj.s(16)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0
                    onClicked: changeDay(tabRoot.isWeekView ? -7 : -1)
                    opacity: tabRoot.isSettingsView ? 0.0 : 1.0
                    visible: opacity > 0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: rootObj.s(8)

                Item { Layout.fillWidth: true }

                Image {
                    property bool active: tabRoot.selectedAppClass !== "" && tabRoot.selectedAppIcon !== "" && !tabRoot.isWeekView && !tabRoot.isSettingsView
                    property real animWidth: active ? rootObj.s(20) : 0
                    Behavior on animWidth { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                    source: tabRoot.selectedAppIcon.startsWith("/") ? "file://" + tabRoot.selectedAppIcon : "image://icon/" + tabRoot.selectedAppIcon
                    sourceSize: Qt.size(rootObj.s(20), rootObj.s(20))
                    Layout.preferredWidth: animWidth
                    Layout.preferredHeight: rootObj.s(20)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: active ? rootObj.s(6) : 0
                    opacity: animWidth / rootObj.s(20.0)
                    visible: animWidth > 0
                    fillMode: Image.PreserveAspectFit
                    clip: true
                }

                Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: rootObj.s(17)
                    color: ThemeBackend.text
                    text: tabRoot.isSettingsView ? I18n.t("guide.wellbeing.settings.title") : (tabRoot.isWeekView ? (tabRoot.weekRangeStr !== "" ? tabRoot.weekRangeStr : I18n.t("guide.wellbeing.week_overview")) : (tabRoot.selectedAppClass !== "" ? `${tabRoot.selectedAppName} - ${tabRoot.getFancyDate(tabRoot.activeDate)}` : tabRoot.getFancyDate(tabRoot.activeDate)))
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: rootObj.s(4)

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    size: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰅂"
                    iconFontSize: rootObj.s(16)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0
                    onClicked: changeDay(tabRoot.isWeekView ? 7 : 1)
                    opacity: tabRoot.isSettingsView ? 0.0 : 1.0
                    visible: opacity > 0
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: dailyViewWrapper
                anchors.fill: parent
                spacing: rootObj.s(6)

                opacity: 1.0 - Math.max(tabRoot.weekViewFocus, tabRoot.settingsViewFocus)
                visible: opacity > 0
                transform: Translate { x: rootObj.s(-40) * Math.max(tabRoot.weekViewFocus, tabRoot.settingsViewFocus) }
                scale: 0.95 + (0.05 * (1.0 - Math.max(tabRoot.weekViewFocus, tabRoot.settingsViewFocus)))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(64)
                    Layout.maximumHeight: rootObj.s(64)
                    Layout.minimumHeight: rootObj.s(64)
                    spacing: rootObj.s(6)

                    opacity: introStats
                    transform: Translate { y: rootObj.s(30) * (1 - introStats) }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rootObj.s(190)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.4)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: rootObj.s(14)
                            anchors.rightMargin: rootObj.s(14)
                            spacing: rootObj.s(10)

                            IconButton {
                                enabled: false
                                size: rootObj.s(36)
                                Layout.preferredWidth: rootObj.s(36)
                                Layout.preferredHeight: rootObj.s(36)
                                Layout.alignment: Qt.AlignVCenter
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰔛"
                                iconFontSize: rootObj.s(19)
                                accentColor: ThemeBackend.surface0
                                textColor: "#ffffff"
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: rootObj.s(20)
                                color: ThemeBackend.text
                                text: tabRoot.formatTimeList(tabRoot.averageSeconds)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                Text {
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.subtext0
                                    text: I18n.t("guide.wellbeing.daily_average")
                                    elide: Text.ElideRight
                                }

                                Text {
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Medium
                                    font.pixelSize: rootObj.s(11)
                                    color: ThemeBackend.overlay0
                                    text: tabRoot.weekRangeStr
                                    visible: tabRoot.weekRangeStr !== ""
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rootObj.s(260)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.5)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: rootObj.s(16)
                            anchors.rightMargin: rootObj.s(16)
                            spacing: rootObj.s(12)

                            IconButton {
                                enabled: false
                                size: rootObj.s(36)
                                Layout.preferredWidth: rootObj.s(36)
                                Layout.preferredHeight: rootObj.s(36)
                                Layout.alignment: Qt.AlignVCenter
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰥔"
                                iconFontSize: rootObj.s(19)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.mauve
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: rootObj.s(30)
                                color: ThemeBackend.text
                                text: tabRoot.formatTimeLarge(tabRoot.animatedTotalSeconds)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rootObj.s(190)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.4)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: rootObj.s(14)
                            anchors.rightMargin: rootObj.s(14)
                            spacing: rootObj.s(12)

                            IconButton {
                                enabled: false
                                size: rootObj.s(36)
                                Layout.preferredWidth: rootObj.s(36)
                                Layout.preferredHeight: rootObj.s(36)
                                Layout.alignment: Qt.AlignVCenter
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: {
                                    let diff = tabRoot.totalSeconds - tabRoot.yesterdaySeconds;
                                    return diff > 0 ? "󰁝" : "󰁅";
                                }
                                iconFontSize: rootObj.s(19)
                                accentColor: ThemeBackend.surface0
                                textColor: {
                                    let diff = tabRoot.totalSeconds - tabRoot.yesterdaySeconds;
                                    return diff > 0 ? ThemeBackend.peach : ThemeBackend.green;
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                RowLayout {
                                    spacing: rootObj.s(4)
                                    visible: !(tabRoot.totalSeconds === 0 && tabRoot.yesterdaySeconds === 0) && tabRoot.totalSeconds !== tabRoot.yesterdaySeconds

                                    Text {
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: rootObj.s(20)
                                        color: {
                                            let diff = tabRoot.totalSeconds - tabRoot.yesterdaySeconds;
                                            return diff > 0 ? ThemeBackend.peach : ThemeBackend.green;
                                        }
                                        text: tabRoot.formatTimeList(Math.abs(tabRoot.totalSeconds - tabRoot.yesterdaySeconds))
                                    }
                                }

                                Text {
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: rootObj.s(13)
                                    color: ThemeBackend.overlay0
                                    text: (tabRoot.totalSeconds === 0 && tabRoot.yesterdaySeconds === 0) ? I18n.t("guide.wellbeing.no_data") : I18n.t("guide.wellbeing.same_time")
                                    visible: (tabRoot.totalSeconds === 0 && tabRoot.yesterdaySeconds === 0) || tabRoot.totalSeconds === tabRoot.yesterdaySeconds
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    id: middleSection
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(145)
                    Layout.fillHeight: false
                    spacing: rootObj.s(6)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rootObj.s(440)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.4)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        border.width: 1

                        opacity: introMidLeft
                        transform: Translate { x: rootObj.s(-30) * (1 - introMidLeft) }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(10)
                            spacing: rootObj.s(8)

                            Repeater {
                                model: weekListModel
                                delegate: Item {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true

                                    MouseArea {
                                        id: barMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: tabRoot.changeToDate(model.dateStr);
                                    }

                                    Item {
                                        anchors.bottom: dayLbl.top
                                        anchors.bottomMargin: rootObj.s(6)
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: rootObj.s(4)
                                        height: Math.max(rootObj.s(4), (parent.height - rootObj.s(24)) * (model.total / Math.max(tabRoot.maxWeekTotal, 1)) * tabRoot.introAppBars)
                                        Behavior on height {
                                            enabled: tabRoot.introAppBars === 1.0
                                            NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: rootObj.s(3)
                                            color: ThemeBackend.surface2
                                            visible: !model.isTarget
                                            opacity: barMa.containsMouse ? 0.7 : 1.0
                                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: rootObj.s(3)
                                            visible: model.isTarget
                                            opacity: barMa.containsMouse ? 0.7 : 1.0
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: ThemeBackend.mauve }
                                                GradientStop { position: 1.0; color: ThemeBackend.blue }
                                            }
                                        }
                                    }

                                    Text {
                                        id: dayLbl
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: rootObj.s(11)
                                        color: model.isTarget ? ThemeBackend.text : ThemeBackend.overlay0
                                        text: model.dayName
                                        Behavior on color { ColorAnimation { duration: 400 } }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rootObj.s(260)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.4)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        border.width: 1

                        opacity: introMidRight
                        transform: Translate { x: rootObj.s(30) * (1 - introMidRight) }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(10)
                            spacing: rootObj.s(6)

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: rootObj.s(6)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(20)
                                    Layout.preferredWidth: rootObj.s(20)
                                    Layout.preferredHeight: rootObj.s(20)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰃭"
                                    iconFontSize: rootObj.s(12)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.mauve
                                }

                                Text {
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: rootObj.s(13)
                                    color: ThemeBackend.text
                                    text: tabRoot.monthNames[tabRoot.activeDate.getMonth()]
                                }
                            }

                            Grid {
                                Layout.alignment: Qt.AlignCenter
                                columns: 7
                                flow: Grid.LeftToRight
                                spacing: rootObj.s(5)

                                Repeater {
                                    model: monthListModel
                                    delegate: Rectangle {
                                        width: rootObj.s(16)
                                        height: rootObj.s(16)
                                        radius: rootObj.s(3)
                                        color: model.total === -1 ? "transparent" : (model.total === 0 ? ThemeBackend.surface2 : Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, Math.min(1.0, 0.3 + 0.7 * (model.total / tabRoot.maxMonthTotal))))
                                        Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuint } }

                                        border.color: model.isTarget ? ThemeBackend.text : "transparent"
                                        border.width: model.isTarget ? 1 : 0
                                        Behavior on border.color { ColorAnimation { duration: 300 } }

                                        visible: model.total !== -1
                                        scale: 0.7 + (0.3 * introMidRight)

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: model.total !== -1
                                            onClicked: {
                                                if (model.total !== -1) {
                                                    tabRoot.changeToDate(model.dateStr);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    opacity: introBottom
                    transform: Translate { y: rootObj.s(30) * (1 - introBottom) }

                    ListView {
                        id: appList
                        anchors.fill: parent
                        spacing: rootObj.s(6)

                        opacity: 1.0 - tabRoot.appViewFocus
                        visible: opacity > 0
                        transform: Translate { x: rootObj.s(-30) * tabRoot.appViewFocus }
                        scale: 0.95 + (0.05 * (1.0 - tabRoot.appViewFocus))

                        model: appListModel
                        interactive: true
                        clip: true

                        move: Transition { NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutQuint } }

                        ScrollBar.vertical: ScrollBar {
                            active: appList.moving || appList.movingVertically
                            width: rootObj.s(4)
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
                        }

                        delegate: Rectangle {
                            id: appDelegateCard
                            width: ListView.view.width - (appList.contentHeight > appList.height ? rootObj.s(8) : 0)
                            height: rootObj.s(52)
                            radius: ThemeBackend.borderRadius
                            color: rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.45) : Qt.alpha(ThemeBackend.surface0, 0.4)
                            border.color: rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface2, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.3)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            transform: Translate { y: (index * rootObj.s(12)) * (1 - introBottom) }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tabRoot.selectedAppClass = model.appClass;
                                    tabRoot.selectedAppName = model.name;
                                    tabRoot.selectedAppIcon = model.icon;
                                    tabRoot.appDate = new Date();
                                    tabRoot.requestDataUpdate();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: rootObj.s(12)
                                anchors.rightMargin: rootObj.s(12)
                                spacing: rootObj.s(10)

                                Rectangle {
                                    id: iconWrapper
                                    implicitWidth: rootObj.s(32)
                                    implicitHeight: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Math.round(rootObj.s(32) * 0.28)
                                    color: ThemeBackend.surface0
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: rootObj.s(4)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        visible: model.icon !== "" && status === Image.Ready
                                        source: {
                                            let ic = model.icon || "";
                                            if (!ic) return "";
                                            if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                            return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !model.icon || model.icon === ""
                                        text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        font.bold: true
                                        color: ThemeBackend.text
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(3)

                                    Text {
                                        Layout.fillWidth: true
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                        text: model.name
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: rootObj.s(8)

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            height: rootObj.s(6)
                                            Rectangle { anchors.fill: parent; radius: rootObj.s(3); color: ThemeBackend.surface1 }
                                            Rectangle {
                                                height: parent.height
                                                width: Math.max(rootObj.s(6), parent.width * (model.percent / 100.0) * tabRoot.introAppBars)
                                                radius: rootObj.s(3)
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: ThemeBackend.mauve }
                                                    GradientStop { position: 1.0; color: ThemeBackend.blue }
                                                }
                                                Behavior on width {
                                                    enabled: tabRoot.introAppBars === 1.0
                                                    NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                                }
                                            }
                                        }

                                        ClickButton {
                                            enabled: false
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredHeight: rootObj.s(22)
                                            horizontalPadding: rootObj.s(8)
                                            cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                                            textFontSize: rootObj.s(11)
                                            accentColor: Qt.alpha(ThemeBackend.surface1, 0.7)
                                            textColor: ThemeBackend.subtext0
                                            buttonText: tabRoot.formatTimeList(model.seconds)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: appChartCard
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.surface0, 0.4)
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        border.width: 1

                        opacity: tabRoot.appViewFocus
                        visible: opacity > 0
                        transform: Translate { x: rootObj.s(30) * (1 - tabRoot.appViewFocus) }
                        scale: 0.95 + (0.05 * tabRoot.appViewFocus)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(12)
                            spacing: rootObj.s(10)

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: rootObj.s(6)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(22)
                                    Layout.preferredWidth: rootObj.s(22)
                                    Layout.preferredHeight: rootObj.s(22)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰘖"
                                    iconFontSize: rootObj.s(13)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.mauve
                                }

                                Text {
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: rootObj.s(13)
                                    color: ThemeBackend.text
                                    text: I18n.t("guide.wellbeing.daily_usage")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: rootObj.s(3)

                                Repeater {
                                    model: 48
                                    delegate: Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Math.max(rootObj.s(4), parent.height * (tabRoot.hourlyData[index] / Math.max(tabRoot.maxHourlyTotal, 1)) * tabRoot.introAppBars)
                                            radius: rootObj.s(2)
                                            color: tabRoot.hourlyData[index] > 0 ? ThemeBackend.blue : ThemeBackend.surface1

                                            Behavior on height {
                                                enabled: tabRoot.introAppBars === 1.0
                                                NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                            }
                                            Behavior on color { ColorAnimation { duration: 400 } }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: { parent.opacity = 0.7 }
                                                onExited: { parent.opacity = 1.0 }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: ThemeBackend.overlay0; text: "00:00" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: ThemeBackend.overlay0; text: "06:00" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: ThemeBackend.overlay0; text: "12:00" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: ThemeBackend.overlay0; text: "18:00" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: ThemeBackend.overlay0; text: "23:00" }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: weekViewWrapper
                anchors.fill: parent
                spacing: rootObj.s(6)

                opacity: tabRoot.weekViewFocus
                visible: opacity > 0
                transform: Translate { x: rootObj.s(40) * (1 - tabRoot.weekViewFocus) }
                scale: 0.95 + (0.05 * tabRoot.weekViewFocus)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(230)
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
                    border.width: 1

                    opacity: introMidLeft
                    transform: Translate { y: rootObj.s(20) * (1 - introMidLeft) }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: rootObj.s(12)
                        spacing: rootObj.s(12)

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 4
                            Layout.fillHeight: true
                            spacing: rootObj.s(4)

                            Repeater {
                                model: 7
                                delegate: RowLayout {
                                    property int dayIndex: index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: rootObj.s(6)

                                    opacity: introMidLeft
                                    transform: Translate { x: rootObj.s(-20) * (1 - introMidLeft) + (dayIndex * rootObj.s(5) * (1 - introMidLeft)) }

                                    Text {
                                        text: [
                                            I18n.t("guide.wellbeing.days.monday"),
                                            I18n.t("guide.wellbeing.days.tuesday"),
                                            I18n.t("guide.wellbeing.days.wednesday"),
                                            I18n.t("guide.wellbeing.days.thursday"),
                                            I18n.t("guide.wellbeing.days.friday"),
                                            I18n.t("guide.wellbeing.days.saturday"),
                                            I18n.t("guide.wellbeing.days.sunday")
                                        ][dayIndex]
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Normal
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                        Layout.preferredWidth: rootObj.s(65)
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: ThemeBackend.borderRadius
                                        color: "transparent"
                                        clip: true

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 0

                                            Repeater {
                                                model: 24
                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    radius: 0

                                                    property real val: (tabRoot.weekHeatmapData[dayIndex] && tabRoot.weekHeatmapData[dayIndex][index]) ? tabRoot.weekHeatmapData[dayIndex][index] : 0
                                                    property real intensity: Math.min(1.0, 0.2 + 0.8 * (val / Math.max(tabRoot.maxWeekHour, 1)))
                                                    color: val === 0 ? ThemeBackend.surface1 : Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, intensity)

                                                    scale: tabRoot.isWeekView ? 1.0 : 0.5
                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: 400 + (dayIndex * 30) + (index * 10)
                                                            easing.type: Easing.OutBack
                                                        }
                                                    }
                                                    Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutQuint } }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: parent.opacity = 0.7
                                                        onExited: parent.opacity = 1.0
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.maximumWidth: rootObj.s(170)
                            Layout.fillHeight: true
                            spacing: rootObj.s(8)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.35)
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: rootObj.s(8)

                                    IconButton {
                                        enabled: false
                                        size: rootObj.s(32)
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "󰔛"
                                        iconFontSize: rootObj.s(16)
                                        accentColor: ThemeBackend.surface0
                                        textColor: "#ffffff"
                                    }

                                    ColumnLayout {
                                        spacing: rootObj.s(2)
                                        Text {
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Medium
                                            font.pixelSize: rootObj.s(11)
                                            color: ThemeBackend.subtext0
                                            text: I18n.t("guide.wellbeing.daily_average")
                                        }
                                        Text {
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Bold
                                            font.pixelSize: rootObj.s(16)
                                            color: ThemeBackend.text
                                            text: tabRoot.formatTimeList(tabRoot.averageSeconds)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.35)
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: rootObj.s(8)

                                    IconButton {
                                        enabled: false
                                        size: rootObj.s(32)
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "󰥔"
                                        iconFontSize: rootObj.s(16)
                                        accentColor: ThemeBackend.surface0
                                        textColor: ThemeBackend.mauve
                                    }

                                    ColumnLayout {
                                        spacing: rootObj.s(2)
                                        Text {
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Medium
                                            font.pixelSize: rootObj.s(11)
                                            color: ThemeBackend.subtext0
                                            text: I18n.t("guide.wellbeing.peak_hours")
                                        }
                                        Text {
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Bold
                                            font.pixelSize: rootObj.s(13)
                                            color: ThemeBackend.text
                                            text: tabRoot.peakUsageHours
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    opacity: introBottom
                    transform: Translate { y: rootObj.s(30) * (1 - introBottom) }

                    ListView {
                        id: weekAppList
                        anchors.fill: parent
                        spacing: rootObj.s(6)
                        model: weekAppListModel
                        interactive: true
                        clip: true

                        move: Transition { NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutQuint } }

                        ScrollBar.vertical: ScrollBar {
                            active: weekAppList.moving || weekAppList.movingVertically
                            width: rootObj.s(4)
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
                        }

                        delegate: Rectangle {
                            id: weekAppDelegateCard
                            width: ListView.view.width - (weekAppList.contentHeight > weekAppList.height ? rootObj.s(8) : 0)
                            height: rootObj.s(52)
                            radius: ThemeBackend.borderRadius
                            color: weekRowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.45) : Qt.alpha(ThemeBackend.surface0, 0.4)
                            border.color: weekRowMa.containsMouse ? Qt.alpha(ThemeBackend.surface2, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.3)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            transform: Translate { y: (index * rootObj.s(12)) * (1 - introBottom) }

                            MouseArea {
                                id: weekRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tabRoot.selectedAppClass = model.appClass;
                                    tabRoot.selectedAppName = model.name;
                                    tabRoot.selectedAppIcon = model.icon;
                                    tabRoot.appDate = new Date();
                                    tabRoot.isWeekView = false;
                                    tabRoot.requestDataUpdate();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: rootObj.s(12)
                                anchors.rightMargin: rootObj.s(12)
                                spacing: rootObj.s(10)

                                Rectangle {
                                    implicitWidth: rootObj.s(32)
                                    implicitHeight: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Math.round(rootObj.s(32) * 0.28)
                                    color: ThemeBackend.surface0
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: rootObj.s(4)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        visible: model.icon !== "" && status === Image.Ready
                                        source: {
                                            let ic = model.icon || "";
                                            if (!ic) return "";
                                            if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                            return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !model.icon || model.icon === ""
                                        text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        font.bold: true
                                        color: ThemeBackend.text
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(3)

                                    Text {
                                        Layout.fillWidth: true
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                        text: model.name
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: rootObj.s(8)

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            height: rootObj.s(6)
                                            Rectangle { anchors.fill: parent; radius: rootObj.s(3); color: ThemeBackend.surface1 }
                                            Rectangle {
                                                height: parent.height
                                                width: Math.max(rootObj.s(6), parent.width * (model.percent / 100.0) * tabRoot.introAppBars)
                                                radius: rootObj.s(3)
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: ThemeBackend.mauve }
                                                    GradientStop { position: 1.0; color: ThemeBackend.blue }
                                                }
                                                Behavior on width {
                                                    enabled: tabRoot.introAppBars === 1.0
                                                    NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                                }
                                            }
                                        }

                                        ClickButton {
                                            enabled: false
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredHeight: rootObj.s(22)
                                            horizontalPadding: rootObj.s(8)
                                            cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                                            textFontSize: rootObj.s(11)
                                            accentColor: Qt.alpha(ThemeBackend.surface1, 0.7)
                                            textColor: ThemeBackend.subtext0
                                            buttonText: tabRoot.formatTimeList(model.seconds)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: settingsWrapper
                anchors.fill: parent
                opacity: tabRoot.settingsViewFocus
                visible: opacity > 0
                transform: Translate { y: rootObj.s(40) * (1 - tabRoot.settingsViewFocus) }

                Reserved {
                    anchors.centerIn: parent
                    imageSize: rootObj.s(220)
                    textSize: rootObj.s(15)
                }
            }
        }
    }
}
