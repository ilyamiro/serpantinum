import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: Scaler.s(520)
    property real maxWidth: Scaler.s(1200)
    property real minHeight: Scaler.s(140)
    property real maxHeight: Scaler.s(380)
    property real fixedAspect: 0
    property real minAspect: minWidth / maxHeight
    property real maxAspect: maxWidth / minHeight
    property bool isRound: false

    property string username: ""
    property var rawContributionsList: []
    property var weeks: []
    property int totalContributions: 0
    property bool loading: false
    property bool hasError: false

    property var selectedDay: null
    property bool isEditingUser: false
    property bool wantsKeyboardFocus: isEditingUser

    property int currentYear: new Date().getFullYear()
    property int selectedYear: new Date().getFullYear()
    property int minYear: 2008
    property int maxYear: new Date().getFullYear()

    readonly property real spacing: Scaler.s(3)
    readonly property real monthGap: Scaler.s(8)
    readonly property real availH: Math.max(10, heatmapContainer.height)
    property real cellSize: Math.max(Scaler.s(10), Math.floor((availH - (6 * spacing)) / 7))
    property bool isResizing: false

    function setKeyboardFocus(enable) {
        root.wantsKeyboardFocus = enable;
        try {
            let win = root.Window ? root.Window.window : null;
            let targets = [];
            if (win) targets.push(win);
            let cur = root;
            while (cur) {
                targets.push(cur);
                if (!cur.parent) break;
                cur = cur.parent;
            }
            for (let i = 0; i < targets.length; i++) {
                let t = targets[i];
                if (!t) continue;
                if (t.wantsKeyboardFocus !== undefined) {
                    t.wantsKeyboardFocus = enable;
                }
                if (t.focusable !== undefined) {
                    t.focusable = enable;
                }
                if (t.WlrLayershell !== undefined) {
                    let focusVal = enable ? 1 : 0;
                    if (typeof WlrKeyboardFocus !== "undefined") {
                        focusVal = enable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None;
                    } else if (typeof WlrLayershell !== "undefined" && WlrLayershell.KeyboardFocus) {
                        focusVal = enable ? WlrLayershell.KeyboardFocus.OnDemand : WlrLayershell.KeyboardFocus.None;
                    }
                    t.WlrLayershell.keyboardFocus = focusVal;
                }
                if (enable && typeof t.requestActivate === "function") {
                    t.requestActivate();
                }
            }
        } catch(e) {}
    }

    Timer {
        id: resizeSettledTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.isResizing = false;
            let nextSize = Math.max(Scaler.s(10), Math.floor((root.availH - (6 * root.spacing)) / 7));
            if (Math.abs(root.cellSize - nextSize) >= 1) {
                root.cellSize = nextSize;
            }
            root.scrollToLatest();
        }
    }

    onWidthChanged: {
        root.isResizing = true;
        resizeSettledTimer.restart();
    }

    onAvailHChanged: {
        root.isResizing = true;
        resizeSettledTimer.restart();
    }

    function scrollToLatest() {
        if (heatmapFlickable.contentWidth > heatmapFlickable.width) {
            heatmapFlickable.contentX = heatmapFlickable.contentWidth - heatmapFlickable.width;
        } else {
            heatmapFlickable.contentX = 0;
        }
    }

    function formatDate(dateStr) {
        if (!dateStr) return "";
        let parts = dateStr.split("-");
        if (parts.length !== 3) return dateStr;
        let monthKeys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        let m = parseInt(parts[1]) - 1;
        let d = parseInt(parts[2]);
        let monthStr = (m >= 0 && m < 12) ? I18n.t("weather.months." + monthKeys[m]) : parts[1];
        return monthStr + " " + d;
    }

    function getColorForLevel(lvl) {
        let accent = (typeof ThemeBackend !== "undefined" && ThemeBackend.green) ? ThemeBackend.green : Qt.color("#a6e3a1");
        let baseSurface = (typeof ThemeBackend !== "undefined" && ThemeBackend.surface1) ? ThemeBackend.surface1 : Qt.color("#313244");
        if (lvl <= 0) return Qt.alpha(baseSurface, ThemeBackend.elementOpacity);
        if (lvl === 1) return Qt.rgba(accent.r, accent.g, accent.b, 0.35);
        if (lvl === 2) return Qt.rgba(accent.r, accent.g, accent.b, 0.58);
        if (lvl === 3) return Qt.rgba(accent.r, accent.g, accent.b, 0.80);
        return accent;
    }

    function selectDefaultDate() {
        if (!root.rawContributionsList || root.rawContributionsList.length === 0) {
            root.selectedDay = null;
            return;
        }

        let now = new Date();
        let yyyy = now.getFullYear();
        let mm = String(now.getMonth() + 1).padStart(2, "0");
        let dd = String(now.getDate()).padStart(2, "0");
        let todayStr = yyyy + "-" + mm + "-" + dd;

        for (let i = root.rawContributionsList.length - 1; i >= 0; i--) {
            if (root.rawContributionsList[i].date === todayStr) {
                root.selectedDay = root.rawContributionsList[i];
                return;
            }
        }
        root.selectedDay = root.rawContributionsList[root.rawContributionsList.length - 1];
    }

    function processContributions(list, totalCount) {
        if (!list || list.length === 0) {
            root.rawContributionsList = [];
            root.weeks = [];
            root.totalContributions = 0;
            root.selectedDay = null;
            root.loading = false;
            return;
        }

        list.sort(function(a, b) {
            return a.date.localeCompare(b.date);
        });

        root.rawContributionsList = list;

        let weeksArr = [];
        let curWeek = [];
        let prevMonth = -1;

        let firstDateParts = list[0].date.split("-");
        let firstDate = new Date(parseInt(firstDateParts[0]), parseInt(firstDateParts[1]) - 1, parseInt(firstDateParts[2]));
        let firstDayOfWeek = (firstDate.getDay() + 6) % 7;

        for (let p = 0; p < firstDayOfWeek; p++) {
            curWeek.push(null);
        }

        let calculatedTotal = 0;
        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            calculatedTotal += (item.count || 0);
            curWeek.push(item);
            if (curWeek.length === 7) {
                let primaryMonth = -1;
                for (let d = 0; d < 7; d++) {
                    if (curWeek[d] && curWeek[d].date) {
                        let m = parseInt(curWeek[d].date.split("-")[1]) - 1;
                        if (primaryMonth === -1 || d >= 3) {
                            primaryMonth = m;
                        }
                    }
                }
                let isMonthStart = (prevMonth !== -1 && primaryMonth !== -1 && primaryMonth !== prevMonth);
                if (primaryMonth !== -1) prevMonth = primaryMonth;

                weeksArr.push({ days: curWeek, isNewMonth: isMonthStart });
                curWeek = [];
            }
        }

        if (curWeek.length > 0) {
            while (curWeek.length < 7) {
                curWeek.push(null);
            }
            let primaryMonth = -1;
            for (let d = 0; d < 7; d++) {
                if (curWeek[d] && curWeek[d].date) {
                    let m = parseInt(curWeek[d].date.split("-")[1]) - 1;
                    if (primaryMonth === -1 || d >= 3) {
                        primaryMonth = m;
                    }
                }
            }
            let isMonthStart = (prevMonth !== -1 && primaryMonth !== -1 && primaryMonth !== prevMonth);
            weeksArr.push({ days: curWeek, isNewMonth: isMonthStart });
        }

        root.weeks = weeksArr;
        root.totalContributions = (totalCount !== undefined && totalCount !== null) ? totalCount : calculatedTotal;
        root.hasError = false;
        root.loading = false;
        root.selectDefaultDate();
        Qt.callLater(root.scrollToLatest);
    }

    function clearData() {
        root.rawContributionsList = [];
        root.weeks = [];
        root.totalContributions = 0;
        root.selectedDay = null;
        root.hasError = false;
        root.loading = false;
    }

    function saveUsername(user) {
        userSaveProcess.pendingUser = user;
        userSaveProcess.running = false;
        userSaveProcess.running = true;
    }

    function loadUser(user, forceFetch) {
        if (!user || user.trim() === "") {
            clearData();
            return;
        }
        let clean = user.trim();
        root.username = clean;
        root.selectedDay = null;
        if (forceFetch) {
            fetchContributions(clean, root.selectedYear);
            return;
        }
        readCacheForYear(clean, root.selectedYear);
    }

    function readCacheForYear(user, year) {
        cacheReadProcess.targetUser = user;
        cacheReadProcess.targetYear = year;
        cacheReadProcess.running = false;
        cacheReadProcess.running = true;
    }

    function saveCachedData(user, year, list, totalVal) {
        try {
            let obj = {
                user: user,
                year: year,
                total: totalVal,
                contributions: list
            };
            cacheSaveProcess.targetUser = user;
            cacheSaveProcess.targetYear = year;
            cacheSaveProcess.jsonData = JSON.stringify(obj);
            cacheSaveProcess.running = false;
            cacheSaveProcess.running = true;
        } catch(e) {}
    }

    function fetchContributions(user, year) {
        if (!user || user.trim() === "") return;
        let cleanUser = user.trim();
        root.loading = true;
        root.hasError = false;

        let queryParam = (year === root.currentYear) ? "y=last" : ("y=" + year);
        let url = "https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(cleanUser) + "?" + queryParam;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    let resp = JSON.parse(xhr.responseText);
                    if (resp && resp.years && resp.years.length > 0) {
                        let numericYears = resp.years.map(function(item) {
                            return typeof item === "object" ? parseInt(item.year) : parseInt(item);
                        }).filter(function(y) { return !isNaN(y); });
                        if (numericYears.length > 0) {
                            root.minYear = Math.min(...numericYears);
                            root.maxYear = Math.max(...numericYears);
                        }
                    }

                    if (resp && resp.contributions && resp.contributions.length > 0) {
                        let tot = null;
                        if (resp.total) {
                            if (year === root.currentYear && resp.total.lastYear !== undefined) {
                                tot = resp.total.lastYear;
                            } else if (resp.total[year.toString()] !== undefined) {
                                tot = resp.total[year.toString()];
                            } else if (resp.total[year] !== undefined) {
                                tot = resp.total[year];
                            }
                        }
                        root.processContributions(resp.contributions, tot);
                        root.saveCachedData(cleanUser, year, resp.contributions, tot);
                        return;
                    }
                } catch(e) {}
            }
            fetchGithubHtml(cleanUser, year);
        };
        xhr.send();
    }

    function fetchGithubHtml(cleanUser, year) {
        let fromDate = year + "-01-01";
        let toDate = year + "-12-31";
        let url = "https://github.com/users/" + encodeURIComponent(cleanUser) + "/contributions?from=" + fromDate + "&to=" + toDate;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    let html = xhr.responseText;
                    let yearRegex = /id="year-link-(\d{4})"/g;
                    let yMatch;
                    let parsedYears = [];
                    while ((yMatch = yearRegex.exec(html)) !== null) {
                        let yr = parseInt(yMatch[1]);
                        if (!isNaN(yr)) parsedYears.push(yr);
                    }
                    if (parsedYears.length > 0) {
                        root.minYear = Math.min(...parsedYears);
                        root.maxYear = Math.max(...parsedYears);
                    }

                    let dayRegex = /data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="(\d+)"/g;
                    let match;
                    let list = [];
                    while ((match = dayRegex.exec(html)) !== null) {
                        let dateStr = match[1];
                        let lvl = parseInt(match[2]);
                        let cnt = lvl === 0 ? 0 : (lvl === 1 ? 1 : (lvl === 2 ? 3 : (lvl === 3 ? 6 : 10)));
                        list.push({ date: dateStr, level: lvl, count: cnt });
                    }

                    if (list.length === 0) {
                        let altRegex = /data-level="(\d+)"[^>]*data-date="(\d{4}-\d{2}-\d{2})"/g;
                        while ((match = altRegex.exec(html)) !== null) {
                            let lvl = parseInt(match[1]);
                            let dateStr = match[2];
                            let cnt = lvl === 0 ? 0 : (lvl === 1 ? 1 : (lvl === 2 ? 3 : (lvl === 3 ? 6 : 10)));
                            list.push({ date: dateStr, level: lvl, count: cnt });
                        }
                    }

                    if (list.length > 0) {
                        let totalVal = null;
                        let totMatch = html.match(/([0-9,]+)\s+contributions?\s+in/i);
                        if (totMatch) {
                            totalVal = parseInt(totMatch[1].replace(/,/g, ""));
                        }
                        root.processContributions(list, totalVal);
                        root.saveCachedData(cleanUser, year, list, totalVal);
                        return;
                    }
                } catch(e) {}
            }
            root.loading = false;
            root.hasError = true;
        };
        xhr.send();
    }

    Process {
        id: userReadProcess
        command: [
            "bash",
            "-c",
            'FILE="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/github/user.txt"; if [ -f "$FILE" ]; then cat "$FILE"; fi'
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let u = this.text.trim();
                if (u !== "") {
                    root.loadUser(u, false);
                } else if (typeof SystemInfo !== "undefined" && SystemInfo.username !== "") {
                    root.loadUser(SystemInfo.username, false);
                }
            }
        }
    }

    Process {
        id: userSaveProcess
        property string pendingUser: ""
        command: [
            "bash",
            "-c",
            'DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/github"; mkdir -p "$DIR"; printf "%s" "$1" > "$DIR/user.txt"',
            "--",
            pendingUser
        ]
        running: false
    }

    Process {
        id: cacheReadProcess
        property string targetUser: ""
        property int targetYear: root.currentYear
        command: [
            "bash",
            "-c",
            'FILE="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/github/${1}_${2}.json"; if [ -f "$FILE" ] && [ -s "$FILE" ]; then cat "$FILE"; else echo "CACHE_MISS"; fi',
            "--",
            targetUser,
            targetYear.toString()
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let content = this.text.trim();
                let u = cacheReadProcess.targetUser;
                let yr = cacheReadProcess.targetYear;
                if (u !== root.username || yr !== root.selectedYear) return;

                if (content !== "" && content !== "CACHE_MISS") {
                    try {
                        let parsed = JSON.parse(content);
                        if (parsed && parsed.contributions && parsed.contributions.length > 0) {
                            root.processContributions(parsed.contributions, parsed.total);
                            return;
                        }
                    } catch(e) {}
                }
                root.fetchContributions(u, yr);
            }
        }
    }

    Process {
        id: cacheSaveProcess
        property string targetUser: ""
        property int targetYear: root.currentYear
        property string jsonData: ""
        command: [
            "bash",
            "-c",
            'DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/github"; mkdir -p "$DIR"; printf "%s" "$3" > "$DIR/${1}_${2}.json"',
            "--",
            targetUser,
            targetYear.toString(),
            jsonData
        ]
        running: false
    }

    Component.onCompleted: {
        userReadProcess.running = true;
    }

    TextMetrics {
        id: usernameTextMetrics
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(11)
        font.weight: Font.Medium
        text: root.username !== "" ? root.username : I18n.t("widgets.github.set_user")
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.clampedBorderRadius !== undefined ? ThemeBackend.clampedBorderRadius : ThemeBackend.borderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Scaler.s(8)
            spacing: Scaler.s(6)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Scaler.s(30)
                spacing: Scaler.s(6)

                IconButton {
                    Layout.preferredWidth: Scaler.s(30)
                    Layout.preferredHeight: Scaler.s(30)
                    size: Scaler.s(30)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                    buttonIcon: root.isEditingUser ? "󰄬" : "󰏫"
                    iconFontSize: Scaler.s(14)
                    accentColor: root.isEditingUser ? ThemeBackend.green : ThemeBackend.surface1
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: root.isEditingUser ? ThemeBackend.surface0 : ThemeBackend.subtext0

                    onClicked: {
                        if (root.isEditingUser) {
                            let clean = usernameInput.text.trim();
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                            if (clean !== root.username && clean !== "") {
                                root.saveUsername(clean);
                                root.loadUser(clean, false);
                            }
                        } else {
                            usernameInput.text = root.username;
                            root.isEditingUser = true;
                            root.setKeyboardFocus(true);
                            Qt.callLater(function() {
                                if (usernameInput.forceInputFocus) {
                                    usernameInput.forceInputFocus();
                                } else if (usernameInput.forceActiveFocus) {
                                    usernameInput.forceActiveFocus();
                                }
                                if (usernameInput.selectAll) {
                                    usernameInput.selectAll();
                                }
                            });
                        }
                    }
                }

                Item {
                    id: usernameSlot
                    Layout.preferredWidth: root.isEditingUser ? Math.max(Scaler.s(100), usernameInput.implicitWidth) : Math.max(Scaler.s(44), usernameTextMetrics.width + Scaler.s(22))
                    Layout.fillWidth: root.isEditingUser
                    Layout.maximumWidth: root.isEditingUser ? Scaler.s(160) : -1
                    Layout.preferredHeight: Scaler.s(30)

                    ClickButton {
                        id: usernameDisplayButton
                        anchors.fill: parent
                        visible: !root.isEditingUser
                        enabled: !root.isEditingUser
                        cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                        horizontalPadding: Scaler.s(8)
                        textFontSize: Scaler.s(11)
                        accentColor: ThemeBackend.surface1
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        buttonText: root.username !== "" ? root.username : I18n.t("widgets.github.set_user")

                        onClicked: {
                            usernameInput.text = root.username;
                            root.isEditingUser = true;
                            root.setKeyboardFocus(true);
                            Qt.callLater(function() {
                                if (usernameInput.forceInputFocus) {
                                    usernameInput.forceInputFocus();
                                } else if (usernameInput.forceActiveFocus) {
                                    usernameInput.forceActiveFocus();
                                }
                                if (usernameInput.selectAll) {
                                    usernameInput.selectAll();
                                }
                            });
                        }
                    }

                    Input {
                        id: usernameInput
                        anchors.fill: parent
                        visible: root.isEditingUser
                        enabled: root.isEditingUser
                        fontPixelSize: Scaler.s(11)
                        horizontalPadding: Scaler.s(8)
                        cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                        baseColor: ThemeBackend.surface1
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        accentColor: ThemeBackend.green
                        leadingIcon: ""
                        showClearButton: false
                        placeholderText: I18n.t("widgets.types.user")
                        isBusy: root.loading && !root.isEditingUser
                        hasError: false

                        Keys.onEscapePressed: {
                            usernameInput.text = root.username;
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                        }

                        onAccepted: function(finalText) {
                            let clean = (finalText !== undefined ? finalText : usernameInput.text).trim();
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                            if (clean !== root.username && clean !== "") {
                                root.saveUsername(clean);
                                root.loadUser(clean, false);
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                        color: "transparent"
                        visible: root.isEditingUser
                        z: 10
                    }
                }

                NumberSelector {
                    id: yearSelector
                    Layout.preferredWidth: Scaler.s(104)
                    Layout.preferredHeight: Scaler.s(30)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                    from: root.minYear
                    to: root.maxYear
                    stepSize: 1.0
                    decimals: 0
                    value: root.selectedYear
                    fontPixelSize: Scaler.s(11)
                    iconFontSize: Scaler.s(12)
                    baseColor: Qt.alpha(ThemeBackend.surface1, ThemeBackend.elementOpacity)
                    buttonColor: Qt.alpha(ThemeBackend.surface2 !== undefined ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.surface1, 1.1), ThemeBackend.elementOpacity)
                    textColor: ThemeBackend.text
                    accentColor: ThemeBackend.green
                    buttonTextColor: ThemeBackend.subtext0

                    onValueChanged: {
                        let y = Math.round(value);
                        if (y !== root.selectedYear) {
                            root.selectedYear = y;
                            if (root.username !== "") {
                                root.readCacheForYear(root.username, y);
                            }
                        }
                    }
                }

                ClickButton {
                    Layout.preferredHeight: Scaler.s(30)
                    Layout.minimumWidth: Scaler.s(60)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                    horizontalPadding: Scaler.s(10)
                    textFontSize: Scaler.s(11)
                    accentColor: ThemeBackend.surface1
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: root.hasError ? ThemeBackend.red : (root.loading ? ThemeBackend.subtext0 : ThemeBackend.text)
                    buttonText: {
                        if (root.loading) return "...";
                        if (root.hasError) return I18n.t("widgets.github.error");
                        if (root.username === "") return "0 " + I18n.t("widgets.github.commits");
                        return root.totalContributions + " " + (root.totalContributions === 1 ? I18n.t("widgets.github.commit") : I18n.t("widgets.github.commits"));
                    }

                    onClicked: {
                        if (root.username !== "") {
                            Quickshell.execDetached(["xdg-open", "https://github.com/" + root.username]);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                ClickButton {
                    Layout.preferredWidth: Scaler.s(142)
                    Layout.minimumWidth: Scaler.s(90)
                    Layout.preferredHeight: Scaler.s(30)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                    horizontalPadding: Scaler.s(8)
                    textFontSize: Scaler.s(10)
                    accentColor: ThemeBackend.surface1
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    buttonText: {
                        if (root.selectedDay) {
                            let cnt = root.selectedDay.count || 0;
                            let commitLabel = cnt === 1 ? I18n.t("widgets.github.commit") : I18n.t("widgets.github.commits");
                            return cnt + " " + commitLabel + " • " + root.formatDate(root.selectedDay.date);
                        }
                        return I18n.t("widgets.github.no_day_selected");
                    }

                    onClicked: {
                        root.selectDefaultDate();
                    }
                }

                IconButton {
                    Layout.preferredWidth: Scaler.s(30)
                    Layout.preferredHeight: Scaler.s(30)
                    size: Scaler.s(30)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(6)) : Scaler.s(6)
                    buttonIcon: "󰑓"
                    iconFontSize: Scaler.s(14)
                    accentColor: ThemeBackend.surface1
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.subtext0

                    onClicked: {
                        if (root.username !== "") {
                            root.fetchContributions(root.username, root.selectedYear);
                        }
                    }
                }
            }

            Item {
                id: heatmapContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: heatmapFlickable
                    anchors.fill: parent
                    contentWidth: weeksRow.width
                    contentHeight: parent.height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    WheelHandler {
                        target: heatmapFlickable
                        onWheel: function(event) {
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            heatmapFlickable.contentX = Math.max(0, Math.min(heatmapFlickable.contentWidth - heatmapFlickable.width, heatmapFlickable.contentX - delta));
                        }
                    }

                    Row {
                        id: weeksRow
                        spacing: 0
                        height: parent.height

                        Repeater {
                            model: root.weeks

                            delegate: Row {
                                id: weekRow
                                spacing: 0
                                height: parent.height
                                readonly property var weekData: modelData
                                z: weekHoverHandler.hovered ? 3 : 1

                                HoverHandler {
                                    id: weekHoverHandler
                                }

                                Item {
                                    width: (weekData.isNewMonth && index > 0) ? root.monthGap : 0
                                    height: 1
                                }

                                Column {
                                    spacing: root.spacing
                                    width: root.cellSize
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: weekData.days

                                        delegate: Rectangle {
                                            id: cellBox
                                            readonly property var dayObj: modelData
                                            readonly property bool isHovered: (tileMa.containsMouse || tileHoverHandler.hovered) && cellBox.dayObj !== null
                                            readonly property color baseColor: cellBox.dayObj ? root.getColorForLevel(cellBox.dayObj.level) : "transparent"

                                            property real popScale: 1.0
                                            property real flashOpacity: 0.0

                                            z: cellBox.isHovered ? 2 : 1
                                            width: root.cellSize
                                            height: root.cellSize
                                            radius: Math.max(2, Math.min(Scaler.s(4), Math.round(root.cellSize * 0.22)))
                                            color: cellBox.dayObj === null ? "transparent" : (tileMa.pressed ? Qt.darker(cellBox.baseColor, 1.12) : (cellBox.isHovered ? Qt.lighter(cellBox.baseColor, 1.12) : cellBox.baseColor))
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            scale: (cellBox.dayObj === null ? 1.0 : (tileMa.pressed ? 1.08 : (cellBox.isHovered ? 1.04 : 1.0))) * cellBox.popScale
                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 250
                                                    easing.type: Easing.OutQuint
                                                }
                                            }

                                            SequentialAnimation {
                                                id: tilePopAnim
                                                NumberAnimation {
                                                    target: cellBox
                                                    property: "popScale"
                                                    to: 1.1
                                                    duration: 110
                                                    easing.type: Easing.OutQuad
                                                }
                                                NumberAnimation {
                                                    target: cellBox
                                                    property: "popScale"
                                                    to: 1.0
                                                    duration: 400
                                                    easing.type: Easing.OutQuint
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: cellBox.radius
                                                color: "#ffffff"
                                                opacity: cellBox.flashOpacity
                                                clip: true

                                                PropertyAnimation on opacity {
                                                    id: tileFlashAnim
                                                    to: 0
                                                    duration: 400
                                                    easing.type: Easing.OutExpo
                                                }
                                            }

                                            HoverHandler {
                                                id: tileHoverHandler
                                                enabled: !root.isResizing && cellBox.dayObj !== null
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            MouseArea {
                                                id: tileMa
                                                anchors.fill: parent
                                                enabled: !root.isResizing && cellBox.dayObj !== null
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    if (cellBox.dayObj) {
                                                        tilePopAnim.start();
                                                        cellBox.flashOpacity = 0.4;
                                                        tileFlashAnim.start();
                                                        if (typeof Sounds !== "undefined") {
                                                            Sounds.playSfx("reusables/iconbutton/click.wav");
                                                        }
                                                        root.selectedDay = cellBox.dayObj;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: root.spacing
                                    height: 1
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Scaler.s(4)
                    visible: root.weeks.length === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: Scaler.s(22)
                        color: root.hasError ? ThemeBackend.red : ThemeBackend.subtext0
                        text: root.hasError ? "󰅚" : (root.loading ? "󰑓" : "󰊤")
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Scaler.s(10)
                        font.weight: Font.Medium
                        color: root.hasError ? ThemeBackend.red : ThemeBackend.subtext0
                        text: {
                            if (root.loading) return I18n.t("widgets.github.fetching");
                            if (root.hasError) return I18n.t("widgets.github.fetch_error", { user: root.username }).replace("{user}", root.username);
                            if (root.username === "") return I18n.t("widgets.github.enter_username");
                            return I18n.t("widgets.github.no_contributions");
                        }
                    }
                }
            }
        }
    }
}
