import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../reusables"
import "../WindowRegistry.js" as WindowRegistry
import "./SearchProviders.js" as SearchProviders

ShellOverlayWindow {
    id: launcherWindow

    screen: LauncherController.screen

    WlrLayershell.namespace: "qs-applauncher"
    overlayOpen: LauncherController.isVisible
    carveBarHole: true
    barHoleThickness: SurfaceRegistry.barInset
    dismissOnOutsideClick: true
    focusTarget: searchInput
    focusRetryInterval: 60
    maxFocusRetries: 4

    onOutsideClicked: closeLauncher()
    onEscapeDismissed: closeLauncher()

    function closeLauncher() {
        LauncherController.hide();
    }

    readonly property bool isVisible: LauncherController.isVisible
    property int configRevision: 0
    property bool appsLoaded: false
    property real introItems: 0.0
    property int currentTabIndex: 0

    readonly property var tabs: [
        { id: "apps", labelKey: "applauncher.tab_applications", fallback: "Applications", placeholderKey: "applauncher.placeholder", placeholderFallback: "Start with > for a command...", debounce: 80, run: q => launcherWindow.executeFilter(q) },
        { id: "files", labelKey: "applauncher.tab_files", fallback: "Files", placeholderKey: "applauncher.placeholder_files", placeholderFallback: "Search files or enter path...", debounce: 80, run: q => launcherWindow.executeFileSearch(q) },
        { id: "emojis", labelKey: "applauncher.tab_emojis", fallback: "Emojis", placeholderKey: "applauncher.placeholder_emojis", placeholderFallback: "Search emojis by name or keyword...", debounce: 60, run: q => launcherWindow.executeEmojiFilter(q) },
        { id: "windows", labelKey: "applauncher.tab_windows", fallback: "Windows", placeholderKey: "applauncher.placeholder_windows", placeholderFallback: "Search open windows...", debounce: 60, run: q => launcherWindow.executeWindowFilter(q) }
    ]

    readonly property var activeTab: tabs[currentTabIndex] || tabs[0]
    readonly property var tabTitles: {
        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "";
        return tabs.map(t => (typeof I18n !== "undefined") ? I18n.t(t.labelKey, t.fallback) : t.fallback);
    }

    function runCurrentTabFilter(query) {
        let tab = tabs[currentTabIndex] || tabs[0];
        if (tab && typeof tab.run === "function") tab.run(query);
    }

    function scheduleCurrentTabFilter(query) {
        launcherWindow.pendingQuery = query;
        let tab = tabs[currentTabIndex] || tabs[0];
        filterDebounceTimer.interval = tab ? tab.debounce : 80;
        filterDebounceTimer.restart();
    }

    function saveLastTab() {
        if (lastTabWatcher.path !== "") {
            lastTabWatcher.setText(currentTabIndex + "\n");
        }
    }

    onCurrentTabIndexChanged: {
        saveLastTab();
        if (tabSwitch.currentIndex !== currentTabIndex) {
            tabSwitch.currentIndex = currentTabIndex;
        }
        if (currentTabIndex !== 2 && emojiBatchAnim.running) {
            emojiBatchAnim.running = false;
            lastEmojiQuery = "\0";
        }
        runCurrentTabFilter(searchInput.text);
        launcherWindow.grabInputFocus();
    }

    FileView {
        id: lastTabWatcher
        path: (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? (Caching.getCacheDir("launcher") + "/last_tab.txt") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") {
                    let idx = parseInt(val);
                    if (!isNaN(idx) && (idx >= 0 && idx <= 3)) {
                        launcherWindow.currentTabIndex = idx;
                        tabSwitch.currentIndex = idx;
                    }
                }
            } catch(e) {}
        }
    }

    function getItemProgress(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let start = Math.min(idx, 10) * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introItems - start) / 0.42));
        if (p <= 0.0) return 0.0;
        if (p >= 1.0) return 1.0;
        let c1 = 0.85;
        let c3 = c1 + 1;
        return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
    }

    function getItemOpacity(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let start = Math.min(idx, 10) * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introItems - start) / 0.28));
        return p;
    }

    function restartItemsIntro() {
        introItems = 0.0;
        itemsIntroSequence.restart();
    }

    SequentialAnimation {
        id: itemsIntroSequence
        running: false
        PauseAnimation { duration: 60 }
        NumberAnimation {
            target: launcherWindow
            property: "introItems"
            from: 0.0
            to: 1.0
            duration: 520
            easing.type: Easing.Linear
        }
    }

    Component.onCompleted: {
        if (smartRanking) {
            rankFetcher.running = true;
        }
        loadApps();
        appsLoaded = true;
        runCurrentTabFilter("");
        if (currentTabIndex !== 2) {
            emojiPreloadTimer.start();
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            LauncherController.hide();
            launcherWindow.configRevision++;
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() {
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                launcherWindow.runCurrentTabFilter(searchInput.text);
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined") ? DesktopEntries : null
        function onApplicationsChanged() {
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                }
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                }
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    property var defaultLauncherSettings: ({
        "position": "top",
        "width": 600,
        "itemCount": 6,
        "terminalCommand": "kitty -e",
        "smartRanking": true,
        "searchProvider": "google"
    })

    property var rawLauncherSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.launcher) {
            return Config.rawSettings.launcher;
        }
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("launcher", defaultLauncherSettings);
        }
        return defaultLauncherSettings;
    }

    property string launcherPosition: (rawLauncherSettings && rawLauncherSettings.position !== undefined) ? rawLauncherSettings.position : "top"
    property real customWidth: (rawLauncherSettings && rawLauncherSettings.width !== undefined && !isNaN(rawLauncherSettings.width) && rawLauncherSettings.width > 0) ? rawLauncherSettings.width : 600
    property int customItemCount: (rawLauncherSettings && rawLauncherSettings.itemCount !== undefined && !isNaN(rawLauncherSettings.itemCount) && rawLauncherSettings.itemCount > 0) ? rawLauncherSettings.itemCount : 6
    property string terminalCommand: (rawLauncherSettings && rawLauncherSettings.terminalCommand !== undefined) ? rawLauncherSettings.terminalCommand : "kitty -e"
    property string searchProvider: (rawLauncherSettings && rawLauncherSettings.searchProvider !== undefined) ? rawLauncherSettings.searchProvider : SearchProviders.DEFAULT_ID
    property bool smartRanking: (rawLauncherSettings && rawLauncherSettings.smartRanking !== undefined) ? rawLauncherSettings.smartRanking : true

    onSmartRankingChanged: {
        if (launcherWindow.isVisible) {
            loadApps();
            if (launcherWindow.currentTabIndex === 0) {
                executeFilter(searchInput.text);
            }
        } else {
            launcherWindow.appsLoaded = false;
        }
    }

    readonly property string barStyle: SurfaceRegistry.barStyle
    readonly property string barPosition: SurfaceRegistry.barPosition
    readonly property bool barAutohide: SurfaceRegistry.barAutohide
    readonly property real barHeight: Math.round(s(SurfaceRegistry.barRawHeight))
    readonly property real barInset: SurfaceRegistry.barInset

    readonly property bool isBarAttachable: SurfaceRegistry.isSolidBar || SurfaceRegistry.isFillBar
    readonly property bool barMatchesLauncher: isBarAttachable && (attachEdge === barPosition) && !isBarEffectivelyHidden

    property string attachEdge: launcherPosition
    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"
    property bool isCentered: attachEdge === "center"

    onAttachEdgeChanged: {
        LauncherController.hide();
    }

    onBarStyleChanged: {
        LauncherController.hide();
    }

    onBarPositionChanged: {
        LauncherController.hide();
    }

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseLauncherWidth: s(customWidth)
    property real collapsedCenterHeight: s(110)

    property real targetLauncherHeight: {
        let headerH = s(36) + s(28) + s(8) + s(28);
        if (currentTabIndex === 2) {
            let totalRows = Math.ceil(emojiTargetCount / 5);
            if (totalRows <= 0) {
                return headerH;
            }
            return headerH + s(8) + (Math.min(totalRows, customItemCount) * s(60));
        }
        let count = Math.min(appModel.count, customItemCount);
        if (count <= 0) {
            return headerH;
        }
        return headerH + s(8) + (count * s(48));
    }

    property real animatedLauncherHeight: targetLauncherHeight
    Behavior on animatedLauncherHeight {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    visible: launcherReveal.active

    property var allApps: []
    property var usageRanks: ({ "focus": {}, "launch": {}, "context": {} })
    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function makeItem(kind, name, description, icon, fontIcon, score, payload) {
        return {
            kind: kind,
            payload: payload || "",
            name: name || "",
            description: description || "",
            icon: icon || "",
            fontIcon: fontIcon || "",
            score: score || 0
        };
    }

    function grabInputFocus() {
        launcherWindow.acquireFocus();
    }

    Process {
        id: rankFetcher
        running: false
        command: ["serpantinum-core", "launcher", "rank"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        launcherWindow.usageRanks = JSON.parse(this.text);
                        if (!launcherWindow.isVisible || appModel.count === 0) {
                            launcherWindow.loadApps();
                            launcherWindow.appsLoaded = true;
                            if (launcherWindow.currentTabIndex === 0) {
                                launcherWindow.executeFilter(searchInput.text);
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }


    Process {
        id: fileSearchProcess
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let parsed = JSON.parse(this.text);
                        let items = [];
                        for (let i = 0; i < parsed.length; i++) {
                            let p = parsed[i];
                            items.push(launcherWindow.makeItem(
                                "file",
                                p.name,
                                p.path,
                                "",
                                launcherWindow.getFileFontIcon(p.name, p.isDir),
                                0,
                                p.path
                            ));
                        }
                        if (launcherWindow.currentTabIndex === 1) {
                            launcherWindow.applyModelItems(items);
                        }
                    } else if (launcherWindow.currentTabIndex === 1) {
                        launcherWindow.applyModelItems([]);
                    }
                } catch(e) {}
            }
        }
    }

    function getFileFontIcon(name, isDir) {
        if (isDir) return "󰉋";
        let ext = name.split(".").pop().toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "svg"].indexOf(ext) !== -1) return "󰋩";
        if (["mp4", "mkv", "webm", "avi", "mov"].indexOf(ext) !== -1) return "󰕧";
        if (["mp3", "wav", "flac", "ogg", "m4a"].indexOf(ext) !== -1) return "󰎆";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].indexOf(ext) !== -1) return "󰛫";
        if (["pdf"].indexOf(ext) !== -1) return "󰈦";
        if (["js", "ts", "qml", "py", "sh", "rs", "c", "cpp", "h", "json", "html", "css", "nix"].indexOf(ext) !== -1) return "󰅩";
        if (["txt", "md", "doc", "docx", "odt"].indexOf(ext) !== -1) return "󰈙";
        return "󰈔";
    }

    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            launcherWindow.isKeyboardNav = false;
        }
    }

    Timer {
        id: filterDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            launcherWindow.runCurrentTabFilter(launcherWindow.pendingQuery);
        }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            tabSwitch.currentIndex = launcherWindow.currentTabIndex;
            restartItemsIntro();
            if (!launcherWindow.appsLoaded) {
                launcherWindow.loadApps();
                launcherWindow.appsLoaded = true;
            }
            if (searchInput.text !== "") {
                searchInput.clear();
            }
            filterDebounceTimer.stop();
            runCurrentTabFilter("");
            if (launcherWindow.smartRanking && !rankFetcher.running) {
                rankFetcher.running = true;
            }
            launcherWindow.acquireFocus();
        } else {
            if (emojiBatchAnim.running) {
                emojiBatchAnim.running = false;
                lastEmojiQuery = "\0";
            }
            itemsIntroSequence.stop();
            introItems = 0.0;
            launcherWindow.appsLoaded = false;
            appList.resetScroll();
            emojiGrid.resetScroll();
            filterDebounceTimer.stop();
            launcherWindow.stopFocusAcquire();
            keyboardNavTimer.stop();
            if (fileSearchProcess.running) {
                fileSearchProcess.running = false;
            }
            if (launcherWindow.smartRanking) {
                loadApps();
                executeFilter("");
            }
        }
    }

    function normalizeDecimalCommas(expr) {
        let out = "";
        let parens = [];
        for (let i = 0; i < expr.length; i++) {
            let ch = expr[i];
            if (ch === "(") {
                parens.push({ isPow: /pow\s*$/i.test(expr.substring(0, i)), commas: 0 });
            } else if (ch === ")") {
                parens.pop();
            } else if (ch === ",") {
                let top = parens.length > 0 ? parens[parens.length - 1] : null;
                if (top && top.isPow) {
                    if (++top.commas > 1) return null;
                    out += ch;
                    continue;
                }
                if (/\d/.test(expr[i - 1] || "") && /\d/.test(expr[i + 1] || "")) {
                    out += ".";
                    continue;
                }
                return null;
            }
            out += ch;
        }
        return out;
    }

    function evaluateMath(expr) {
        if (!expr) return null;
        let trimmed = expr.trim();
        if (trimmed.length === 0 || trimmed.startsWith(">")) return null;

        let normalized = normalizeDecimalCommas(trimmed);
        if (normalized === null) return null;

        let parsed = normalized
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/gi, "Math.E")
            .replace(/\bsqrt\b/gi, "Math.sqrt")
            .replace(/\bsin\b/gi, "Math.sin")
            .replace(/\bcos\b/gi, "Math.cos")
            .replace(/\btan\b/gi, "Math.tan")
            .replace(/\babs\b/gi, "Math.abs")
            .replace(/\blog\b/gi, "Math.log")
            .replace(/\bpow\b/gi, "Math.pow")
            .replace(/\^/g, "**");

        let testStr = parsed.replace(/Math\.(PI|E|sqrt|sin|cos|tan|abs|log|pow)/g, "");
        if (!/^[\d\s\+\-\*\/\%\(\)\.\,]+$/.test(testStr)) {
            return null;
        }

        if (!/[\+\-\*\/\%\^]/.test(trimmed) && !/\b(sqrt|sin|cos|tan|abs|log|pow|pi|e)\b/i.test(trimmed)) {
            return null;
        }

        try {
            let res = Function('"use strict"; return (' + parsed + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return Number(Math.round(res * 1e12) / 1e12).toString();
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    function loadApps() {
        let arr = [];

        if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) {
            let entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                let e = entries[i];
                if (e.noDisplay) continue;

                let score = 0;
                if (launcherWindow.smartRanking) {
                    let wmclassLower = (e.startupClass || "").toLowerCase();
                    let idLower = e.id.toLowerCase();
                    let baseName = idLower.endsWith(".desktop") ? idLower.slice(0, -8) : idLower;
                    let appNameLower = (e.name || "").toLowerCase();

                    let f_score = usageRanks.focus[wmclassLower] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[baseName] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[appNameLower] || 0;

                    let l_score = usageRanks.launch[e.name] || 0;

                    let c_score = (usageRanks.context && usageRanks.context[wmclassLower]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[baseName]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[appNameLower]) || 0;

                    score = f_score + l_score + (0.5 * c_score);
                }

                arr.push({
                    kind: "app",
                    payload: e.id,
                    name: e.name,
                    description: e.comment || "",
                    searchTerms: [e.genericName || ""].concat(e.keywords || []).join(" ").toLowerCase(),
                    icon: e.icon || "",
                    fontIcon: "",
                    score: score
                });
            }
        }

        let widgetList = (typeof WindowRegistry !== "undefined" && WindowRegistry.getWidgetLauncherEntries)
            ? WindowRegistry.getWidgetLauncherEntries(typeof I18n !== "undefined" ? I18n : null)
            : [];

        for (let j = 0; j < widgetList.length; j++) {
            let w = widgetList[j];
            let wScore = 0;
            if (launcherWindow.smartRanking) {
                wScore = (usageRanks.launch && (usageRanks.launch[w.id] || usageRanks.launch[w.name] || usageRanks.launch["qs-widget-" + w.id])) || 0;
            }
            arr.push({
                kind: "widget",
                payload: w.id,
                name: w.name,
                description: w.description || "",
                searchTerms: "",
                icon: w.icon || "",
                fontIcon: w.fontIcon || "",
                score: wScore
            });
        }

        arr.sort(function(a, b) {
            if (launcherWindow.smartRanking && a.score !== b.score) {
                return b.score - a.score;
            }
            return a.name.localeCompare(b.name);
        });

        let unique = {};
        let finalArr = [];
        for (let i = 0; i < arr.length; i++) {
            if (!unique[arr[i].name]) {
                unique[arr[i].name] = true;
                finalArr.push(arr[i]);
            }
        }

        launcherWindow.allApps = finalArr;
    }

    ListModel {
        id: appModel
    }

    ListModel {
        id: emojiModel
    }

    property var emojiSearch: null
    property var emojiSearchComponent: null
    property bool emojiFilterPending: false
    property var pendingEmojiResults: []
    property int pendingEmojiCursor: 0
    property int emojiTargetCount: 0
    property string lastEmojiQuery: "\0"

    Timer {
        id: emojiPreloadTimer
        interval: 1200
        repeat: false
        onTriggered: launcherWindow.preloadEmojiSearch()
    }

    FrameAnimation {
        id: emojiBatchAnim
        running: false
        onTriggered: launcherWindow.pumpEmojiBatch()
    }

    function preloadEmojiSearch() {
        if (emojiSearch || emojiSearchComponent) return;
        let comp = Qt.createComponent(Qt.resolvedUrl("EmojiSearch.qml"), Component.Asynchronous);
        emojiSearchComponent = comp;
        if (comp.status === Component.Ready) {
            finishEmojiSearchLoad();
        } else if (comp.status === Component.Loading) {
            comp.statusChanged.connect(finishEmojiSearchLoad);
        } else {
            console.warn("Failed to load emoji search:", comp.errorString());
            emojiSearchComponent = null;
        }
    }

    function finishEmojiSearchLoad() {
        let comp = emojiSearchComponent;
        if (!comp) return;
        if (comp.status === Component.Ready) {
            if (!emojiSearch) {
                emojiSearch = comp.createObject(launcherWindow);
            }
            if (emojiFilterPending) {
                emojiFilterPending = false;
                if (launcherWindow.currentTabIndex === 2) {
                    executeEmojiFilter(searchInput.text);
                }
            }
        } else if (comp.status === Component.Error) {
            console.warn("Failed to load emoji search:", comp.errorString());
            emojiSearchComponent = null;
            emojiFilterPending = false;
        }
    }

    function ensureEmojiSearch() {
        if (!emojiSearch) {
            preloadEmojiSearch();
        }
        return emojiSearch;
    }

    function executeEmojiFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let normalizedQuery = query ? query.trim() : "";
        let search = ensureEmojiSearch();
        if (!search) {
            emojiFilterPending = true;
            return;
        }

        if (normalizedQuery === lastEmojiQuery && !emojiBatchAnim.running && emojiModel.count === emojiTargetCount) {
            emojiGrid.resetScroll();
            emojiGrid.currentIndex = emojiModel.count > 0 ? 0 : -1;
            return;
        }

        let results = search.search(normalizedQuery, 150);
        applyEmojiModelItems(results, normalizedQuery);
    }

    function pumpEmojiBatch() {
        let list = pendingEmojiResults;
        let total = list.length;
        let cursor = pendingEmojiCursor;
        if (cursor >= total) {
            emojiBatchAnim.running = false;
            return;
        }

        let visibleBudget = (customItemCount + 2) * 5;
        let chunkSize = cursor < visibleBudget ? 10 : 30;
        let end = Math.min(total, cursor + chunkSize);

        for (let i = cursor; i < end; i++) {
            let target = list[i];
            if (i < emojiModel.count) {
                let cur = emojiModel.get(i);
                if (cur.emoji !== target.emoji || cur.name !== target.name) {
                    emojiModel.set(i, {
                        emoji: target.emoji,
                        name: target.name
                    });
                }
            } else {
                emojiModel.append({
                    emoji: target.emoji,
                    name: target.name
                });
            }
        }

        pendingEmojiCursor = end;
        if (pendingEmojiCursor >= total) {
            emojiBatchAnim.running = false;
        }
    }

    function applyEmojiModelItems(filtered, normalizedQuery) {
        emojiBatchAnim.running = false;
        pendingEmojiResults = filtered;
        pendingEmojiCursor = 0;
        emojiTargetCount = filtered.length;
        lastEmojiQuery = normalizedQuery;

        if (emojiModel.count > filtered.length) {
            emojiModel.remove(filtered.length, emojiModel.count - filtered.length);
        }

        let visibleCount = customItemCount * 5;
        let immediateExisting = Math.min(emojiModel.count, Math.min(filtered.length, visibleCount));
        for (let i = 0; i < immediateExisting; i++) {
            let cur = emojiModel.get(i);
            let target = filtered[i];
            if (cur.emoji !== target.emoji || cur.name !== target.name) {
                emojiModel.set(i, {
                    emoji: target.emoji,
                    name: target.name
                });
            }
        }
        pendingEmojiCursor = immediateExisting;

        if (pendingEmojiCursor < filtered.length && pendingEmojiCursor < 10) {
            pumpEmojiBatch();
        }
        if (pendingEmojiCursor < filtered.length) {
            emojiBatchAnim.running = true;
        }

        emojiGrid.resetScroll();
        if (emojiModel.count > 0) {
            emojiGrid.currentIndex = 0;
        } else {
            emojiGrid.currentIndex = -1;
        }
    }

    function executeFileSearch(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();
        if (fileSearchProcess.running) {
            fileSearchProcess.running = false;
        }
        fileSearchProcess.command = ["serpantinum-core", "launcher", "files", query ? query.trim() : ""];
        fileSearchProcess.running = true;
    }

    readonly property bool windowsTabActive: isVisible && currentTabIndex === 3

    SubscriptionGate {
        target: WindowTracker
        wanted: launcherWindow.windowsTabActive
    }

    Connections {
        target: WindowTracker
        function onUpdated() {
            if (!launcherWindow.windowsTabActive) return;
            let cur = (appList.currentIndex >= 0 && appList.currentIndex < appModel.count) ? appModel.get(appList.currentIndex) : null;
            let selected = (cur && cur.kind === "window") ? cur.payload : "";
            launcherWindow.executeWindowFilter(searchInput.text);
            if (selected === "") return;
            for (let i = 0; i < appModel.count; i++) {
                let it = appModel.get(i);
                if (it && it.kind === "window" && it.payload === selected) {
                    appList.currentIndex = i;
                    break;
                }
            }
        }
    }

    function executeWindowFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let q = query ? query.toLowerCase().trim() : "";
        let wins = WindowTracker.windows.slice();
        wins.sort(function(a, b) {
            if (a.output !== b.output) return String(a.output).localeCompare(String(b.output));
            if (a.workspace !== b.workspace) return a.workspace - b.workspace;
            return a.seq - b.seq;
        });

        let items = [];
        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            let entry = w.desktopId ? (DesktopEntries.byId(w.desktopId) || DesktopEntries.byId(w.desktopId.replace(/\.desktop$/, ""))) : null;
            let appName = (entry && entry.name) ? entry.name : (w.appId || "");
            let title = w.title || appName;

            if (q.length > 0) {
                let hay = (title + " " + appName + " " + (w.appId || "") + " " + (w.workspaceLabel || "")).toLowerCase();
                if (!hay.includes(q) && !isSubsequence(q, title.toLowerCase())) continue;
            }

            let parts = [];
            if (appName && appName !== title) parts.push(appName);
            if (w.workspaceLabel) {
                parts.push(typeof I18n !== "undefined" ? I18n.t("applauncher.window_workspace", { ws: w.workspaceLabel }) : ("Workspace " + w.workspaceLabel));
            }
            if (w.output) parts.push(w.output);

            let icon = (entry && entry.icon) ? entry.icon : w.appId;

            items.push(launcherWindow.makeItem(
                "window",
                title,
                parts.join(" · "),
                icon,
                icon ? "" : "󰖯",
                0,
                w.id
            ));
        }

        applyModelItems(items);
    }

    function isSubsequence(sub, str) {
        let i = 0;
        let j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) {
                i++;
            }
            j++;
        }
        return i === sub.length;
    }

    function applyModelItems(filtered) {
        let minCount = Math.min(appModel.count, filtered.length);
        for (let i = 0; i < minCount; i++) {
            let cur = appModel.get(i);
            let target = filtered[i];
            if (cur.kind !== target.kind
                || cur.payload !== target.payload
                || cur.name !== target.name
                || cur.description !== target.description
                || cur.icon !== target.icon
                || cur.fontIcon !== target.fontIcon
                || cur.score !== target.score) {
                appModel.set(i, target);
            }
        }

        if (appModel.count > filtered.length) {
            for (let i = appModel.count - 1; i >= filtered.length; i--) {
                appModel.remove(i);
            }
        } else if (appModel.count < filtered.length) {
            for (let i = appModel.count; i < filtered.length; i++) {
                appModel.append(filtered[i]);
            }
        }

        appList.resetScroll();

        if (appModel.count > 0) {
            appList.currentIndex = 0;
        } else {
            appList.currentIndex = -1;
        }
    }

    function executeFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = query.trim();
        let q = query.toLowerCase().trim();
        let filtered = [];

        if (rawTrimmed.startsWith(">")) {
            let cmd = rawTrimmed.substring(1).trim();
            if (cmd.length > 0) {
                filtered.push(launcherWindow.makeItem(
                    "command",
                    "> " + cmd,
                    typeof I18n !== "undefined" ? I18n.t("applauncher.command_run", { cmd: cmd }) : ("Execute command: " + cmd),
                    "",
                    "󰆍",
                    10000000,
                    cmd
                ));
            } else {
                filtered.push(launcherWindow.makeItem(
                    "hint",
                    "> ...",
                    typeof I18n !== "undefined" ? I18n.t("applauncher.command_hint") : "Type a command to execute",
                    "",
                    "󰆍",
                    10000000,
                    ""
                ));
            }
        }

        if (rawTrimmed.startsWith("?")) {
            let term = rawTrimmed.substring(1).trim();
            let provider = SearchProviders.find(launcherWindow.searchProvider);
            filtered.push(launcherWindow.makeItem(
                term.length > 0 ? "search" : "hint",
                term.length > 0 ? "? " + term : "? ...",
                term.length > 0
                    ? (typeof I18n !== "undefined" ? I18n.t("applauncher.search_run", { provider: provider.name }) : ("Search " + provider.name))
                    : (typeof I18n !== "undefined" ? I18n.t("applauncher.search_hint", { provider: provider.name }) : "Type to search the web"),
                "",
                "󰖟",
                10000000,
                term.length > 0 ? SearchProviders.urlFor(launcherWindow.searchProvider, term) : ""
            ));
            applyModelItems(filtered);
            return;
        }

        let mathResult = evaluateMath(rawTrimmed);
        if (mathResult !== null) {
            filtered.push(launcherWindow.makeItem(
                "calc",
                rawTrimmed + " = " + mathResult,
                typeof I18n !== "undefined" ? I18n.t("applauncher.calc_result") : "Calculation result (Enter to copy)",
                "",
                "󰃬",
                9000000,
                mathResult
            ));
        }

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let nameLower = app.name ? app.name.toLowerCase() : "";
            let descLower = app.description ? app.description.toLowerCase() : "";
            let termsLower = app.searchTerms || "";

            let matchQuality = 0;
            let matches = false;

            if (q.length === 0) {
                matches = true;
            } else if (!rawTrimmed.startsWith(">")) {
                if (nameLower === q) {
                    matchQuality = 100000;
                    matches = true;
                } else if (nameLower.startsWith(q)) {
                    matchQuality = 50000;
                    matches = true;
                } else if (nameLower.includes(q)) {
                    matchQuality = 10000;
                    matches = true;
                } else if (descLower.includes(q)) {
                    matchQuality = 5000;
                    matches = true;
                } else if (termsLower.includes(q)) {
                    matchQuality = 3000;
                    matches = true;
                } else if (isSubsequence(q, nameLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                filtered.push(launcherWindow.makeItem(
                    app.kind,
                    app.name,
                    app.description,
                    app.icon,
                    app.fontIcon || "",
                    app.score + matchQuality,
                    app.payload
                ));
            }
        }

        if (q.length > 0) {
            filtered.sort(function(a, b) {
                if (a.score !== b.score) {
                    return b.score - a.score;
                }
                return a.name.localeCompare(b.name);
            });
        }

        applyModelItems(filtered);
    }

    function activateIndex(index) {
        if (index < 0 || index >= appModel.count) return;
        let item = appModel.get(index);
        if (!item || item.kind === "hint") return;

        switch (item.kind) {
        case "file": {
            let script = "p=\"$1\"\n"
                + "if [ -d \"$p\" ]; then\n"
                + "  xdg-open \"$p\"\n"
                + "  exit 0\n"
                + "fi\n"
                + "mime=$(xdg-mime query filetype \"$p\" 2>/dev/null)\n"
                + "handler=\"\"\n"
                + "if [ -n \"$mime\" ]; then\n"
                + "  handler=$(xdg-mime query default \"$mime\" 2>/dev/null)\n"
                + "fi\n"
                + "if [ -n \"$handler\" ]; then\n"
                + "  xdg-open \"$p\" 2>/dev/null && exit 0\n"
                + "fi\n"
                + "if command -v ski >/dev/null 2>&1; then\n"
                + "  ski \"$p\" >/dev/null 2>&1 &\n"
                + "else\n"
                + "  xdg-open \"$(dirname \"$p\")\" >/dev/null 2>&1 &\n"
                + "fi";
            Quickshell.execDetached(["bash", "-c", script, "_", item.payload]);
            closeLauncher();
            return;
        }
        case "window": {
            let wins = WindowTracker.windows;
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].id === item.payload) {
                    WindowTracker.focusWindow(wins[i]);
                    break;
                }
            }
            closeLauncher();
            return;
        }
        case "search":
            if (item.payload) Quickshell.execDetached(["xdg-open", item.payload]);
            closeLauncher();
            return;
        case "command":
            if (item.payload && item.payload.trim().length > 0) {
                let term = launcherWindow.terminalCommand ? launcherWindow.terminalCommand.trim() : "";
                let fullCmd = term !== "" ? (term + " " + item.payload) : item.payload;
                Quickshell.execDetached(["bash", "-c", fullCmd]);
            }
            closeLauncher();
            return;
        case "calc":
            Quickshell.execDetached(["wl-copy", "--", item.payload]);
            closeLauncher();
            return;
        case "widget":
            launchWidget(item.name, item.payload);
            return;
        default:
            launchApp(item.name, item.payload);
            return;
        }
    }

    function activateEmoji(index) {
        if (index < 0 || index >= emojiModel.count) return;
        let item = emojiModel.get(index);
        if (!item) return;
        Quickshell.execDetached(["wl-copy", "--", item.emoji]);
        closeLauncher();
    }

    function launchWidget(widgetName, widgetTarget) {
        if (widgetTarget) {
            Quickshell.execDetached(["serpantinum-core", "launcher", "log", widgetTarget]);
        }
        if (widgetName && widgetName !== widgetTarget) {
            Quickshell.execDetached(["serpantinum-core", "launcher", "log", widgetName]);
        }
        closeLauncher();
        ShellRouter.open(widgetTarget, "", launcherWindow.screen);
    }

    function launchApp(appName, desktopId) {
        let entry = DesktopEntries.byId(desktopId);
        if (entry) {
            AppMatcher.launch(entry);
        }
        if (Caching.qsDir) {
            Quickshell.execDetached(["serpantinum-core", "launcher", "log", appName]);
        }
        closeLauncher();
    }

    AttachedSurface {
        id: launcherSurface
        kind: "launcher"
        visible: container.animProgress > 0.001 && container.width > 0 && container.height > 0
        opacity: container.opacity
        rects: [{ x: container.x, y: container.y, w: container.width, h: container.height, r: [bgCard.topLeftRadius, bgCard.topRightRadius, bgCard.bottomRightRadius, bgCard.bottomLeftRadius] }]
        filletRadius: launcherWindow.isCentered ? 0 : container.dynamicCornerRadius
        attachTo: launcherWindow.barMatchesLauncher ? ["bar"] : []
        publishShape: launcherWindow.barMatchesLauncher
        edges: (launcherWindow.isCentered || launcherWindow.barMatchesLauncher) ? [] : [launcherWindow.attachEdge]
    }

    Item {
        id: container
        property Item glassBackdropItem: launcherSurface.backdrop

        MouseArea {
            anchors.fill: parent
        }

        SpringProgress {
            id: launcherReveal
            open: launcherWindow.isVisible
            openDuration: 520
            closeDuration: launcherWindow.isCentered ? 200 : 150
        }

        readonly property real animProgress: launcherReveal.value

        property real dynamicCornerRadius: Math.round(Math.max(0, Math.min(launcherWindow.outerCornerRadius, (launcherWindow.isSideAttached ? width : height) * 0.5)))

        x: {
            if (launcherWindow.attachEdge === "left") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barInset : 0;
            }
            if (launcherWindow.attachEdge === "right") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barInset : 0;
                return (launcherWindow.width - offset) - width;
            }
            return Math.floor((launcherWindow.width - width) / 2);
        }

        y: {
            if (launcherWindow.attachEdge === "top") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barInset : 0;
            }
            if (launcherWindow.attachEdge === "bottom") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barInset : 0;
                return (launcherWindow.height - offset) - height;
            }
            return Math.floor((launcherWindow.height - height) / 2);
        }

        width: launcherWindow.isSideAttached
               ? Math.round(launcherWindow.baseLauncherWidth * animProgress)
               : Math.round(launcherWindow.baseLauncherWidth)

        height: {
            if (launcherWindow.isCentered) {
                let baseH = launcherWindow.collapsedCenterHeight;
                let targetH = Math.max(baseH, launcherWindow.animatedLauncherHeight);
                return baseH + (targetH - baseH) * animProgress;
            }
            if (!launcherWindow.isSideAttached) {
                return launcherWindow.animatedLauncherHeight * animProgress;
            }
            return launcherWindow.animatedLauncherHeight;
        }

        opacity: launcherWindow.isCentered
                 ? Math.max(0.0, Math.min(1.0, animProgress * 1.5))
                 : ((launcherWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0)

        transformOrigin: Item.Center

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: container.dynamicCornerRadius
            readonly property bool flatCorners: !launcherWindow.isCentered
            topLeftRadius: (flatCorners && (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "left")) ? 0 : container.dynamicCornerRadius
            topRightRadius: (flatCorners && (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "right")) ? 0 : container.dynamicCornerRadius
            bottomLeftRadius: (flatCorners && (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "left")) ? 0 : container.dynamicCornerRadius
            bottomRightRadius: (flatCorners && (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "right")) ? 0 : container.dynamicCornerRadius
            color: "transparent"
            clip: true

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: launcherWindow.s(14)
                visible: width > 0 && height > 0
                clip: true

                readonly property bool isSearchAtBottom: launcherWindow.attachEdge === "bottom"

                Input {
                    id: searchInput
                    z: 10
                    focus: true
                    Keys.priority: Keys.BeforeItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom ? Math.max(0, parent.height - height) : 0
                    height: launcherWindow.s(36)

                    baseColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(12)
                    charSpacing: 1

                    placeholderText: {
                        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "";
                        let t = launcherWindow.activeTab;
                        return typeof I18n !== "undefined" ? I18n.t(t.placeholderKey, t.placeholderFallback) : t.placeholderFallback;
                    }
                    showClearButton: true

                    onHasFocusChanged: {
                        if (!searchInput.hasFocus && launcherWindow.isVisible) {
                            if (launcherWindow.currentTabIndex === 2) {
                                emojiGrid.forceActiveFocus();
                            } else {
                                appList.forceActiveFocus();
                            }
                        }
                    }

                    onTextEdited: function(newText) {
                        launcherWindow.scheduleCurrentTabFilter(newText);
                    }
                    onCleared: {
                        launcherWindow.scheduleCurrentTabFilter("");
                    }

                    Keys.onTabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 1) % 4;
                        tabSwitch.currentIndex = launcherWindow.currentTabIndex;
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 3) % 4;
                        tabSwitch.currentIndex = launcherWindow.currentTabIndex;
                        event.accepted = true;
                    }
                    Keys.onDownPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (launcherWindow.currentTabIndex === 2) {
                            if (emojiGrid.currentIndex + 5 < emojiModel.count) {
                                emojiGrid.currentIndex += 5;
                            } else if (emojiGrid.currentIndex < emojiModel.count - 1) {
                                emojiGrid.currentIndex = emojiModel.count - 1;
                            }
                        } else {
                            if (appList.currentIndex < appModel.count - 1) {
                                appList.currentIndex++;
                            }
                        }
                        event.accepted = true;
                    }
                    Keys.onUpPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (launcherWindow.currentTabIndex === 2) {
                            if (emojiGrid.currentIndex >= 5) {
                                emojiGrid.currentIndex -= 5;
                            }
                        } else {
                            if (appList.currentIndex > 0) {
                                appList.currentIndex--;
                            }
                        }
                        event.accepted = true;
                    }
                    Keys.onLeftPressed: function(event) {
                        if (launcherWindow.currentTabIndex === 2) {
                            launcherWindow.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (emojiGrid.currentIndex > 0) {
                                emojiGrid.currentIndex--;
                            }
                            event.accepted = true;
                        }
                    }
                    Keys.onRightPressed: function(event) {
                        if (launcherWindow.currentTabIndex === 2) {
                            launcherWindow.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (emojiGrid.currentIndex < emojiModel.count - 1) {
                                emojiGrid.currentIndex++;
                            }
                            event.accepted = true;
                        }
                    }
                    Keys.onReturnPressed: function(event) {
                        if (launcherWindow.currentTabIndex === 2) {
                            activateEmoji(emojiGrid.currentIndex);
                        } else {
                            activateIndex(appList.currentIndex);
                        }
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: function(event) {
                        closeLauncher();
                        event.accepted = true;
                    }
                }

                Switch {
                    id: tabSwitch
                    z: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom
                       ? (searchInput.y - height - launcherWindow.s(8))
                       : (searchInput.y + searchInput.height + launcherWindow.s(8))
                    height: launcherWindow.s(28)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(11)
                    baseColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    options: launcherWindow.tabTitles
                    currentIndex: launcherWindow.currentTabIndex
                    onValueChanged: function(index, value) {
                        launcherWindow.currentTabIndex = index;
                    }
                    onToggled: function(index) {
                        launcherWindow.currentTabIndex = index;
                    }
                }

                Item {
                    id: listContainer
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom ? 0 : (tabSwitch.y + tabSwitch.height + launcherWindow.s(8))
                    height: contentContainer.isSearchAtBottom
                            ? Math.max(0, tabSwitch.y - launcherWindow.s(8))
                            : Math.max(0, parent.height - y)
                    clip: true

                    opacity: launcherWindow.isCentered
                             ? Math.max(0.0, Math.min(1.0, (container.animProgress - 0.2) / 0.8))
                             : 1.0

                    NumberAnimation {
                        id: scrollAnim
                        target: appList
                        property: "contentY"
                        duration: 250
                        easing.type: Easing.OutCubic
                    }

                    Item {
                        id: highlightGlassLayer
                        visible: ThemeBackend.liquidGlass && appList.visible && morphHighlight.visible
                        width: appList.width
                        height: morphHighlight.height
                        x: morphHighlight.x + launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(appList.currentIndex))
                        y: morphHighlight.y - appList.contentY
                        opacity: morphHighlight.opacity

                        readonly property bool isMoving: Math.abs(morphHighlight.y - morphHighlight.targetY) > 0.5
                        property real lift: (highlightLayerGlass.active && isMoving) ? 1.0 : 0.0
                        Behavior on lift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        transform: Scale {
                            origin.x: highlightGlassLayer.width / 2
                            origin.y: highlightGlassLayer.height / 2
                            xScale: 1.0 + 0.015 * highlightGlassLayer.lift
                            yScale: 1.0 + 0.1 * highlightGlassLayer.lift
                        }

                        GlassFill {
                            id: highlightLayerGlass
                            anchors.fill: parent
                            radius: morphHighlight.radius
                            forceOpaque: true
                            tintColor: ThemeBackend.text
                            tintAmount: 0
                            tintStrength: 1.0
                            press: 0.6 + 0.4 * highlightGlassLayer.lift
                        }
                    }

                    HoverHandler {
                        id: listHover
                        enabled: appList.visible
                    }

                    ListView {
                        id: appList
                        anchors.fill: parent
                        visible: launcherWindow.currentTabIndex !== 2
                        clip: true
                        model: appModel
                        spacing: launcherWindow.s(4)
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: launcherWindow.s(500)
                        highlightFollowsCurrentItem: false

                        Keys.forwardTo: [searchInput]

                        Keys.onPressed: function(event) {
                            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                                launcherWindow.grabInputFocus();
                                searchInput.text += event.text;
                                event.accepted = true;
                            }
                        }

                        function getItemY(idx) {
                            return idx * (launcherWindow.s(44) + spacing);
                        }

                        function resetScroll() {
                            scrollAnim.stop();
                            contentY = 0;
                        }

                        property bool scrolling: false

                        Timer {
                            id: scrollSettleTimer
                            interval: 200
                            onTriggered: appList.scrolling = false
                        }

                        function refreshHover() {
                            if (!listHover.hovered || !visible) {
                                hoverItem = null;
                                return;
                            }
                            const px = contentX + listHover.point.position.x;
                            const py = contentY + listHover.point.position.y;
                            const item = itemAt(px, py) || itemAt(px, py - spacing);
                            hoverItem = (item && !item.isSelected) ? item : null;
                        }

                        onCountChanged: refreshHover()

                        readonly property point cursorPos: listHover.point.position
                        onCursorPosChanged: refreshHover()

                        Connections {
                            target: listHover
                            function onHoveredChanged() { appList.refreshHover(); }
                        }

                        onContentYChanged: {
                            scrolling = true;
                            scrollSettleTimer.restart();
                            refreshHover();
                            if (contentY < 0 && !moving && !flicking) {
                                contentY = 0;
                            }
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || appModel.count === 0) return;
                            let itemH = launcherWindow.s(44);
                            let step = itemH + spacing;
                            let itemTop = idx * step;
                            let itemBottom = itemTop + itemH;

                            let curContentY = scrollAnim.running ? scrollAnim.to : contentY;
                            let totalH = Math.max(0, appModel.count * step - spacing);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;

                            if (itemTop < curContentY) {
                                newContentY = itemTop;
                            } else if (itemBottom > curContentY + height) {
                                newContentY = itemBottom - height;
                            }

                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                            if (Math.abs(newContentY - contentY) > 0.5) {
                                if (animated) {
                                    scrollAnim.stop();
                                    scrollAnim.from = contentY;
                                    scrollAnim.to = newContentY;
                                    scrollAnim.start();
                                } else {
                                    scrollAnim.stop();
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                            }
                            refreshHover();
                        }

                        property Item hoverItem: null

                        GlassLens {
                            id: rowHoverLens
                            parent: appList.contentItem
                            z: -1
                            instant: appList.scrolling
                            targetX: appList.hoverItem ? appList.hoverItem.x : 0
                            targetY: appList.hoverItem ? appList.hoverItem.y : 0
                            targetWidth: appList.hoverItem ? appList.hoverItem.width : 0
                            targetHeight: appList.hoverItem ? appList.hoverItem.height : 0
                            radius: ThemeBackend.borderRadius
                            tintColor: ThemeBackend.surface0
                            tintAmount: 0.3
                            shadow: 0
                            restPress: 0.2
                            magnify: launcherWindow.s(4)
                            press: appList.hoverItem && appList.hoverItem.pressed ? 0.8 : 0
                        }

                        Rectangle {
                            id: morphHighlight
                            parent: appList.contentItem
                            z: 0
                            visible: opacity > 0.001
                            opacity: (appList.count > 0 && appList.currentIndex >= 0)
                                     ? launcherWindow.getItemOpacity(appList.currentIndex)
                                     : 0.0
                            Behavior on opacity {
                                enabled: !itemsIntroSequence.running
                                NumberAnimation {
                                    duration: 170
                                    easing.type: Easing.OutCubic
                                }
                            }
                            x: 0
                            width: appList.width
                            height: launcherWindow.s(44)
                            radius: ThemeBackend.borderRadius
                            color: ThemeBackend.liquidGlass ? "transparent" : ThemeBackend.mauve

                            property real targetY: (appList.currentIndex >= 0 && appModel.count > 0)
                                                   ? appList.getItemY(appList.currentIndex)
                                                   : 0
                            y: targetY

                            transform: Translate {
                                x: launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(appList.currentIndex))
                            }

                            Behavior on y {
                                enabled: launcherWindow.isKeyboardNav
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: ListView.view ? ListView.view.width : 0
                            height: launcherWindow.s(44)
                            clip: false
                            z: 1

                            property bool isSelected: index === appList.currentIndex
                            readonly property bool pressed: ma.pressed
                            Component.onDestruction: {
                                if (appList.hoverItem === delegateRoot) appList.hoverItem = null;
                            }

                            opacity: launcherWindow.getItemOpacity(index)
                            transform: Translate {
                                x: launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(index))
                            }

                            Item {
                                id: delegateContent
                                anchors.fill: parent

                                scale: ma.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: ThemeBackend.borderRadius
                                    color: (ThemeBackend.liquidGlass || rowHoverGlass.active) ? "transparent" : ThemeBackend.surface0
                                    opacity: ma.containsMouse && !delegateRoot.isSelected ? (ThemeBackend.liquidGlass ? 1.0 : 0.45) : 0

                                    GlassFill {
                                        id: rowHoverGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        allowed: ma.containsMouse && !delegateRoot.isSelected && !rowHoverLens.glassActive
                                        tintColor: ThemeBackend.surface0
                                        tintAmount: 0.3
                                        press: ma.pressed ? 0.8 : 0.2
                                    }
                                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutSine } }
                                }

                                RowLayout {
                                    layoutDirection: I18n.layoutDirection
                                    anchors.fill: parent
                                    anchors.margins: launcherWindow.s(6)
                                    anchors.leftMargin: I18n.rtl ? launcherWindow.s(10) : (launcherWindow.s(10) + (delegateRoot.isSelected ? launcherWindow.s(2) : 0))
                                    anchors.rightMargin: I18n.rtl ? (launcherWindow.s(10) + (delegateRoot.isSelected ? launcherWindow.s(2) : 0)) : launcherWindow.s(10)
                                    spacing: launcherWindow.s(10)

                                    Behavior on anchors.leftMargin {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                    Behavior on anchors.rightMargin {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }

                                    Item {
                                        id: delegateIconArea
                                        Layout.preferredWidth: launcherWindow.s(32)
                                        Layout.preferredHeight: launcherWindow.s(32)
                                        Layout.alignment: Qt.AlignVCenter

                                        readonly property real boxRadius: launcherWindow.s(8)
                                        readonly property real boxPadding: launcherWindow.s(4)

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.topMargin: launcherWindow.s(1.5)
                                            anchors.bottomMargin: -launcherWindow.s(1.5)
                                            radius: parent.boxRadius
                                            color: Qt.rgba(0, 0, 0, 0.12)
                                            visible: !iconBoxGlass.active
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.boxRadius
                                            color: iconBoxGlass.active ? "transparent" : (delegateRoot.isSelected ? Qt.tint(ThemeBackend.surface2, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface2)

                                            GlassFill {
                                                id: iconBoxGlass
                                                anchors.fill: parent
                                                radius: parent.radius
                                                forceClear: delegateRoot.isSelected
                                                tintColor: delegateRoot.isSelected ? ThemeBackend.text : ThemeBackend.surface2
                                                tintAmount: delegateRoot.isSelected ? 0.1 : 0.3
                                            }

                                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            id: iconContainer
                                            anchors.fill: parent
                                            anchors.margins: parent.boxPadding
                                            radius: Math.max(0, parent.boxRadius - parent.boxPadding)
                                            color: "transparent"
                                            clip: true

                                            Image {
                                                id: delegateIcon
                                                anchors.fill: parent
                                                property bool failedLoad: false
                                                cache: false

                                                visible: (!model.fontIcon || model.fontIcon === "") && source !== "" && status === Image.Ready && !failedLoad && !AppMatcher.iconMissing(source)

                                                source: {
                                                    if (model.fontIcon && model.fontIcon !== "") return "";
                                                    return AppMatcher.iconSource(model.icon);
                                                }

                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                mipmap: true

                                                onStatusChanged: {
                                                    if (status === Image.Error) {
                                                        failedLoad = true;
                                                    }
                                                }
                                            }

                                            Text {
                                                id: delegateFontIcon
                                                anchors.centerIn: parent
                                                visible: !delegateIcon.visible
                                                text: {
                                                    if (model.fontIcon && model.fontIcon !== "") return model.fontIcon;
                                                    if (model.kind === "calc") return "󰃬";
                                                    if (model.kind === "command") return "󰆍";
                                                    return "󰵆";
                                                }
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: launcherWindow.s(16)
                                                color: delegateRoot.isSelected ? ThemeBackend.mauve : ThemeBackend.subtext0
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter

                                                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: launcherWindow.s(1)

                                        Text {
                                            id: delegateText
                                            Layout.fillWidth: true
                                            text: model.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(12)
                                            font.weight: delegateRoot.isSelected ? Font.Bold : Font.Medium
                                            color: delegateRoot.isSelected ? (ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust) : ThemeBackend.text
                                            horizontalAlignment: I18n.textAlignment
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter

                                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }

                                        Text {
                                            id: delegateDesc
                                            Layout.fillWidth: true
                                            visible: model.description !== undefined && model.description !== null && model.description !== ""
                                            text: model.description || ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(10)
                                            font.weight: Font.Normal
                                            color: delegateRoot.isSelected ? (ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust) : ThemeBackend.subtext0
                                            horizontalAlignment: I18n.textAlignment
                                            opacity: delegateRoot.isSelected ? 0.9 : 0.85
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter

                                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcherWindow.isKeyboardNav = false;
                                        appList.currentIndex = index;
                                        activateIndex(index);
                                    }
                                }
                            }
                        }
                    }

                    GridView {
                        id: emojiGrid
                        anchors.fill: parent
                        visible: launcherWindow.currentTabIndex === 2
                        clip: true
                        model: emojiModel
                        cellWidth: width / 5
                        cellHeight: launcherWindow.s(60)
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: launcherWindow.s(120)
                        reuseItems: true
                        highlightFollowsCurrentItem: false

                        Keys.forwardTo: [searchInput]

                        Keys.onPressed: function(event) {
                            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                                launcherWindow.grabInputFocus();
                                searchInput.text += event.text;
                                event.accepted = true;
                            }
                        }

                        function resetScroll() {
                            emojiScrollAnim.stop();
                            contentY = 0;
                        }

                        onContentYChanged: {
                            if (contentY < 0 && !moving && !flicking) {
                                contentY = 0;
                            }
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || emojiModel.count === 0) return;
                            let row = Math.floor(idx / 5);
                            let rowH = cellHeight;
                            let itemTop = row * rowH;
                            let itemBottom = itemTop + rowH;

                            let curContentY = emojiScrollAnim.running ? emojiScrollAnim.to : contentY;
                            let totalRows = Math.ceil(emojiModel.count / 5);
                            let totalH = Math.max(0, totalRows * rowH);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;

                            if (itemTop < curContentY) {
                                newContentY = itemTop;
                            } else if (itemBottom > curContentY + height) {
                                newContentY = itemBottom - height;
                            }

                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                            if (Math.abs(newContentY - contentY) > 0.5) {
                                if (animated) {
                                    emojiScrollAnim.stop();
                                    emojiScrollAnim.from = contentY;
                                    emojiScrollAnim.to = newContentY;
                                    emojiScrollAnim.start();
                                } else {
                                    emojiScrollAnim.stop();
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                            }
                        }

                        GlassLens {
                            id: emojiLens
                            z: -1
                            readonly property bool valid: emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < emojiGrid.count
                            targetX: valid ? (emojiGrid.currentIndex % 5) * emojiGrid.cellWidth + launcherWindow.s(3) : 0
                            targetY: valid ? Math.floor(emojiGrid.currentIndex / 5) * emojiGrid.cellHeight + launcherWindow.s(3) : 0
                            targetWidth: valid ? Math.max(0, emojiGrid.cellWidth - launcherWindow.s(6)) : 0
                            targetHeight: valid ? Math.max(0, emojiGrid.cellHeight - launcherWindow.s(6)) : 0
                            radius: ThemeBackend.borderRadius
                            forceOpaque: true
                            tintColor: ThemeBackend.text
                            tintAmount: 0
                            tintStrength: 1.0
                            shadow: 0
                            restPress: 0.6
                            followBackdropHover: false
                            fastDuration: 260
                            slowDuration: 260
                        }

                        NumberAnimation {
                            id: emojiScrollAnim
                            target: emojiGrid
                            property: "contentY"
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                        delegate: Item {
                            id: emojiDelegateRoot
                            width: emojiGrid.cellWidth
                            height: emojiGrid.cellHeight
                            clip: false

                            readonly property bool isSelected: index === emojiGrid.currentIndex
                            readonly property bool lensHandled: isSelected && emojiLens.glassActive

                            opacity: launcherWindow.getItemOpacity(Math.floor(index / 5))
                            transform: Translate {
                                y: launcherWindow.s(15) * (1.0 - launcherWindow.getItemProgress(Math.floor(index / 5)))
                            }

                            Item {
                                id: emojiDelegateContent
                                anchors.fill: parent
                                anchors.margins: launcherWindow.s(3)

                                scale: emojiMa.pressed ? 0.92 : (emojiDelegateRoot.isSelected ? 1.04 : (emojiMa.containsMouse ? 1.02 : 1.0))
                                Behavior on scale {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                }

                                Rectangle {
                                    id: emojiBg
                                    anchors.fill: parent
                                    radius: ThemeBackend.borderRadius
                                    color: (emojiGlass.active || emojiDelegateRoot.lensHandled) ? "transparent" : (emojiDelegateRoot.isSelected
                                           ? ThemeBackend.mauve
                                           : (emojiMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.45)))

                                    GlassFill {
                                        id: emojiGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        backdropOverride: launcherSurface.backdrop
                                        allowed: !emojiDelegateRoot.lensHandled
                                        forceOpaque: emojiDelegateRoot.isSelected
                                        tintColor: emojiDelegateRoot.isSelected ? ThemeBackend.text : ThemeBackend.surface0
                                        tintStrength: emojiDelegateRoot.isSelected ? 1.0 : 0.5
                                        tintAmount: emojiDelegateRoot.isSelected ? 0 : 0.25
                                        press: emojiMa.pressed ? 0.8 : (emojiDelegateRoot.isSelected ? 0.6 : (emojiMa.containsMouse ? 0.25 : 0))
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.bottom: emojiNameText.top
                                    anchors.topMargin: launcherWindow.s(4)
                                    anchors.bottomMargin: launcherWindow.s(1)
                                    text: model.emoji
                                    font.pixelSize: launcherWindow.s(22)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    id: emojiNameText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: launcherWindow.s(4)
                                    anchors.rightMargin: launcherWindow.s(4)
                                    anchors.bottomMargin: launcherWindow.s(4)
                                    text: model.name
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: launcherWindow.s(9)
                                    font.weight: emojiDelegateRoot.isSelected ? Font.Bold : Font.Normal
                                    color: emojiDelegateRoot.isSelected ? ((emojiGlass.active || emojiDelegateRoot.lensHandled) ? ThemeBackend.text : ThemeBackend.crust) : ThemeBackend.subtext0
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 1

                                    Behavior on color {
                                        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    id: emojiMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcherWindow.isKeyboardNav = false;
                                        emojiGrid.currentIndex = index;
                                        activateEmoji(index);
                                    }
                                    onEntered: {
                                        if (!launcherWindow.isKeyboardNav) {
                                            emojiGrid.currentIndex = index;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        visible: launcherWindow.currentTabIndex === 2 && launcherWindow.emojiTargetCount === 0 && !launcherWindow.emojiFilterPending && launcherWindow.emojiSearch !== null
                        width: parent.width
                        height: launcherWindow.s(60)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: launcherWindow.s(6)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "🔍"
                                font.pixelSize: launcherWindow.s(24)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: typeof I18n !== "undefined" ? I18n.t("applauncher.no_emojis_found", "No emojis found") : "No emojis found"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: launcherWindow.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }
        }
    }
}
