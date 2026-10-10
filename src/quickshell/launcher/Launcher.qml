import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"
import "../WindowRegistry.js" as WindowRegistry
import "./EmojiData.js" as EmojiData

PanelWindow {
    id: launcherWindow

    screen: LauncherController.screen

    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: launcherWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeLauncher() {
        LauncherController.hide();
    }

    property bool isVisible: LauncherController.isVisible
    property int configRevision: 0
    property bool appsLoaded: false
    property real introItems: 0.0
    property int currentTabIndex: 0

    property string tabAppsTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_applications", "Applications") : "Applications"
    property string tabFilesTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_files", "Files") : "Files"
    property string tabEmojisTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_emojis", "Emojis") : "Emojis"

    function saveLastTab() {
        let dir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? Caching.getCacheDir("launcher") : "";
        if (dir) {
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + dir + "' && echo '" + currentTabIndex + "' > '" + dir + "/last_tab.txt'"]);
        }
    }

    onCurrentTabIndexChanged: {
        saveLastTab();
        if (tabSwitch.currentIndex !== currentTabIndex) {
            tabSwitch.currentIndex = currentTabIndex;
        }
        if (currentTabIndex === 0) {
            executeFilter(searchInput.text);
        } else if (currentTabIndex === 1) {
            executeFileSearch(searchInput.text);
        } else {
            executeEmojiFilter(searchInput.text);
        }
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
                    if (!isNaN(idx) && (idx >= 0 && idx <= 2)) {
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
        if (currentTabIndex === 0) {
            executeFilter("");
        } else if (currentTabIndex === 1) {
            executeFileSearch("");
        } else {
            executeEmojiFilter("");
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
            launcherWindow.tabAppsTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_applications", "Applications") : "Applications";
            launcherWindow.tabFilesTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_files", "Files") : "Files";
            launcherWindow.tabEmojisTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_emojis", "Emojis") : "Emojis";
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                } else if (launcherWindow.currentTabIndex === 1) {
                    launcherWindow.executeFileSearch(searchInput.text);
                } else {
                    launcherWindow.executeEmojiFilter(searchInput.text);
                }
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
        "smartRanking": true
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

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    property string barPosition: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "top";
        return Config.rawSettings.bar.position || "top";
    }

    property real barOpacity: {
        let dummy = configRevision;
        if (!rawBarSettings || rawBarSettings.opacity === undefined) return 1.0;
        let op = Number(rawBarSettings.opacity);
        return op > 1.0 ? (op / 100.0) : op;
    }

    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false

    readonly property bool isToplevelFullscreen: {
        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                let atl = ToplevelManager.activeToplevel;
                if (atl.screens && atl.screens.length > 0) {
                    return atl.screens.indexOf(launcherWindow.screen) !== -1;
                }
                return true;
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isHyprlandFullscreen: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isFullscreenActive: isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property bool isBarSolid: (barStyle === "solid" || barStyle === "fill") && Math.round(barOpacity * 100) >= 100
    property bool barMatchesLauncher: isBarSolid && (attachEdge === barPosition) && !isBarEffectivelyHidden

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
            let totalRows = Math.ceil(emojiModel.count / 5);
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
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    visible: isVisible || container.animProgress > 0.001

    property var allApps: []
    property var usageRanks: ({ "focus": {}, "launch": {}, "context": {} })
    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function grabInputFocus() {
        searchInput.forceActiveFocus();
        if (typeof searchInput.forceInputFocus === "function") {
            searchInput.forceInputFocus();
        }
    }

    Process {
        id: rankFetcher
        running: false
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"] : []

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

    property string fileSearchScript: "import os, sys, json\nq = sys.argv[1] if len(sys.argv) > 1 else ''\nhome = os.path.expanduser('~')\nres = []\nif q.startswith('/') or q.startswith('~'):\n    p = os.path.expanduser(q)\n    d = p if (os.path.isdir(p) and (q.endswith('/') or q.endswith('\\\\'))) else (os.path.dirname(p) or home)\n    pref = '' if (os.path.isdir(p) and (q.endswith('/') or q.endswith('\\\\'))) else os.path.basename(p).lower()\n    if os.path.isdir(d):\n        try:\n            entries = sorted(os.listdir(d), key=lambda x: (not os.path.isdir(os.path.join(d, x)), x.lower()))\n            for item in entries:\n                if item.startswith('.') and not pref.startswith('.'):\n                    continue\n                if not pref or pref in item.lower():\n                    full = os.path.join(d, item)\n                    res.append({'name': item, 'path': full, 'isDir': os.path.isdir(full)})\n                    if len(res) >= 40: break\n        except Exception: pass\nelse:\n    s = q.lower().strip()\n    targets = [home, os.path.join(home, 'Desktop'), os.path.join(home, 'Documents'), os.path.join(home, 'Downloads'), os.path.join(home, 'Pictures'), os.path.join(home, 'Videos'), os.path.join(home, 'Music')]\n    seen = set()\n    for t in targets:\n        if not os.path.isdir(t): continue\n        try:\n            for root, dirs, files in os.walk(t):\n                rel = os.path.relpath(root, t)\n                if rel != '.' and rel.count(os.sep) >= 2:\n                    dirs.clear()\n                    continue\n                dirs[:] = [dr for dr in dirs if not dr.startswith('.') and dr not in ('node_modules', '.git', '.cache', 'target', 'build', '.local')]\n                if s:\n                    for dr in dirs:\n                        if s in dr.lower():\n                            full = os.path.join(root, dr)\n                            if full not in seen:\n                                seen.add(full)\n                                res.append({'name': dr, 'path': full, 'isDir': True})\n                                if len(res) >= 40: break\n                for fn in files:\n                    if fn.startswith('.'): continue\n                    if not s or s in fn.lower():\n                        full = os.path.join(root, fn)\n                        if full not in seen:\n                            seen.add(full)\n                            res.append({'name': fn, 'path': full, 'isDir': False})\n                            if len(res) >= 40: break\n                if len(res) >= 40: break\n        except Exception: pass\n        if len(res) >= 40: break\nprint(json.dumps(res[:40]))"

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
                            items.push({
                                name: p.name,
                                description: p.path,
                                desktop_id: "",
                                icon: "",
                                fontIcon: launcherWindow.getFileFontIcon(p.name, p.isDir),
                                score: 0,
                                isCommand: false,
                                command: "",
                                isCalc: false,
                                calcResult: "",
                                isWidget: false,
                                widgetTarget: "",
                                isFile: true,
                                filePath: p.path,
                                isDir: p.isDir
                            });
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
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
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
            executeFilter(launcherWindow.pendingQuery);
        }
    }

    Timer {
        id: fileDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            executeFileSearch(launcherWindow.pendingQuery);
        }
    }

    Timer {
        id: emojiDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            executeEmojiFilter(launcherWindow.pendingQuery);
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
                filterDebounceTimer.stop();
                fileDebounceTimer.stop();
                emojiDebounceTimer.stop();
            } else {
                filterDebounceTimer.stop();
                fileDebounceTimer.stop();
                emojiDebounceTimer.stop();
            }
            if (launcherWindow.currentTabIndex === 0) {
                executeFilter("");
            } else if (launcherWindow.currentTabIndex === 1) {
                executeFileSearch("");
            } else {
                executeEmojiFilter("");
            }
            if (launcherWindow.smartRanking && !rankFetcher.running) {
                rankFetcher.running = true;
            }
            launcherWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            itemsIntroSequence.stop();
            introItems = 0.0;
            launcherWindow.appsLoaded = false;
            appList.resetScroll();
            emojiGrid.resetScroll();
            filterDebounceTimer.stop();
            fileDebounceTimer.stop();
            emojiDebounceTimer.stop();
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
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

    function evaluateMath(expr) {
        if (!expr) return null;
        let trimmed = expr.trim();
        if (trimmed.length === 0 || trimmed.startsWith(">")) return null;

        let parsed = trimmed
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
                    let baseName = e.id.toLowerCase().replace(".desktop", "");
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
                    name: e.name,
                    description: e.comment || "",
                    desktop_id: e.id,
                    icon: e.icon || "",
                    fontIcon: "",
                    score: score,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
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
                name: w.name,
                description: w.description || "",
                desktop_id: "qs-widget-" + w.id,
                icon: w.icon || "",
                fontIcon: w.fontIcon || "",
                score: wScore,
                isCommand: false,
                command: "",
                isCalc: false,
                calcResult: "",
                isWidget: true,
                widgetTarget: w.id,
                isFile: false,
                filePath: "",
                isDir: false
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

    function filterApps(query) {
        launcherWindow.pendingQuery = query;
        filterDebounceTimer.restart();
    }

    function filterFiles(query) {
        launcherWindow.pendingQuery = query;
        fileDebounceTimer.restart();
    }

    function filterEmojis(query) {
        launcherWindow.pendingQuery = query;
        emojiDebounceTimer.restart();
    }

    function executeEmojiFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let results = EmojiData.search(query ? query.trim() : "", 150);
        applyEmojiModelItems(results);
    }

    function applyEmojiModelItems(filtered) {
        let minCount = Math.min(emojiModel.count, filtered.length);
        for (let i = 0; i < minCount; i++) {
            let cur = emojiModel.get(i);
            let target = filtered[i];
            if (cur.emoji !== target.emoji || cur.name !== target.name || cur.category !== target.category) {
                emojiModel.set(i, {
                    emoji: target.emoji,
                    name: target.name,
                    category: target.category,
                    keywordsText: target.keywords ? target.keywords.join(", ") : ""
                });
            }
        }

        if (emojiModel.count > filtered.length) {
            for (let i = emojiModel.count - 1; i >= filtered.length; i--) {
                emojiModel.remove(i);
            }
        } else if (emojiModel.count < filtered.length) {
            for (let i = emojiModel.count; i < filtered.length; i++) {
                let target = filtered[i];
                emojiModel.append({
                    emoji: target.emoji,
                    name: target.name,
                    category: target.category,
                    keywordsText: target.keywords ? target.keywords.join(", ") : ""
                });
            }
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
        fileSearchProcess.command = ["python3", "-c", launcherWindow.fileSearchScript, query ? query.trim() : ""];
        fileSearchProcess.running = true;
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
            if (cur.name !== target.name
                || cur.desktop_id !== target.desktop_id
                || cur.description !== target.description
                || cur.icon !== target.icon
                || cur.fontIcon !== target.fontIcon
                || cur.score !== target.score
                || cur.command !== target.command
                || cur.calcResult !== target.calcResult
                || cur.isCommand !== target.isCommand
                || cur.isCalc !== target.isCalc
                || cur.isWidget !== target.isWidget
                || cur.widgetTarget !== target.widgetTarget
                || cur.isFile !== target.isFile
                || cur.filePath !== target.filePath
                || cur.isDir !== target.isDir) {
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
                filtered.push({
                    name: "> " + cmd,
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_run", { cmd: cmd }) : ("Execute command: " + cmd),
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: true,
                    command: cmd,
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            } else {
                filtered.push({
                    name: "> ...",
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_hint") : "Type a command to execute",
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            }
        }

        let mathResult = evaluateMath(rawTrimmed);
        if (mathResult !== null) {
            filtered.push({
                name: rawTrimmed + " = " + mathResult,
                description: typeof I18n !== "undefined" ? I18n.t("applauncher.calc_result") : "Calculation result (Enter to copy)",
                desktop_id: "",
                icon: "",
                fontIcon: "󰃬",
                score: 9000000,
                isCommand: false,
                command: "",
                isCalc: true,
                calcResult: mathResult,
                isWidget: false,
                widgetTarget: "",
                isFile: false,
                filePath: "",
                isDir: false
            });
        }

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let nameLower = app.name ? app.name.toLowerCase() : "";
            let descLower = app.description ? app.description.toLowerCase() : "";

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
                } else if (isSubsequence(q, nameLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                filtered.push({
                    name: app.name,
                    description: app.description,
                    desktop_id: app.desktop_id,
                    icon: app.icon,
                    fontIcon: app.fontIcon || "",
                    score: app.score + matchQuality,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: app.isWidget || false,
                    widgetTarget: app.widgetTarget || "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
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
        if (!item) return;

        if (item.isFile) {
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
                + "if command -v nautilus >/dev/null 2>&1; then\n"
                + "  nautilus --select \"$p\" >/dev/null 2>&1 &\n"
                + "else\n"
                + "  xdg-open \"$(dirname \"$p\")\" >/dev/null 2>&1 &\n"
                + "fi";
            Quickshell.execDetached(["bash", "-c", script, "_", item.filePath]);
            closeLauncher();
            return;
        }

        if (item.isCommand) {
            if (item.command && item.command.trim().length > 0) {
                let term = launcherWindow.terminalCommand ? launcherWindow.terminalCommand.trim() : "";
                let fullCmd = term !== "" ? (term + " " + item.command) : item.command;
                Quickshell.execDetached(["bash", "-c", fullCmd]);
            }
            closeLauncher();
            return;
        }

        if (item.isCalc) {
            Quickshell.execDetached(["wl-copy", "--", item.calcResult]);
            closeLauncher();
            return;
        }

        if (item.isWidget) {
            launchWidget(item.name, item.widgetTarget);
            return;
        }

        launchApp(item.name, item.desktop_id);
    }

    function activateEmoji(index) {
        if (index < 0 || index >= emojiModel.count) return;
        let item = emojiModel.get(index);
        if (!item) return;
        Quickshell.execDetached(["wl-copy", "--", item.emoji]);
        closeLauncher();
    }

    function launchWidget(widgetName, widgetTarget) {
        if (Caching.qsDir) {
            Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/qs_manager.sh", "open", widgetTarget]);
        } else {
            Quickshell.execDetached(["qs_manager", "open", widgetTarget]);
        }
        closeLauncher();
    }

    function launchApp(appName, desktopId) {
        let entry = DesktopEntries.byId(desktopId);
        if (entry) {
            entry.execute();
        }
        if (Caching.qsDir) {
            Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", appName]);
        }
        closeLauncher();
    }

    Item {
        id: topBarHole

        property int barThickness: launcherWindow.barHeight
        property string bp: launcherWindow.barPosition
        property bool activeBar: !launcherWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return launcherWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return launcherWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return launcherWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return launcherWindow.height;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isVisible
        onClicked: closeLauncher()
    }

    Item {
        id: container

        MouseArea {
            anchors.fill: parent
        }

        property real animProgress: launcherWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: launcherWindow.isVisible ? (launcherWindow.isCentered ? 420 : 340) : (launcherWindow.isCentered ? 200 : 150)
                easing.type: launcherWindow.isVisible ? Easing.OutBack : Easing.InQuad
                easing.overshoot: launcherWindow.isVisible ? 1.28 : 1.0
            }
        }

        property real dynamicCornerRadius: Math.max(0, Math.min(launcherWindow.outerCornerRadius, (launcherWindow.isSideAttached ? width : height) * 0.5))

        x: {
            if (launcherWindow.attachEdge === "left") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "right") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.width - offset) - width;
            }
            return Math.floor((launcherWindow.width - width) / 2);
        }

        y: {
            if (launcherWindow.attachEdge === "top") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "bottom") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.height - offset) - height;
            }
            return Math.floor((launcherWindow.height - height) / 2);
        }

        width: launcherWindow.isSideAttached
               ? (launcherWindow.baseLauncherWidth * animProgress)
               : launcherWindow.baseLauncherWidth

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

        ShaderEffect {
            visible: !launcherWindow.isCentered && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return -container.dynamicCornerRadius;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return -container.dynamicCornerRadius;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 3.0;
                if (launcherWindow.attachEdge === "left") return 2.0;
                if (launcherWindow.attachEdge === "right") return 3.0;
                return 1.0;
            }
            property color color: ThemeBackend.base
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: !launcherWindow.isCentered && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return parent.width;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return parent.height;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 2.0;
                if (launcherWindow.attachEdge === "left") return 0.0;
                if (launcherWindow.attachEdge === "right") return 1.0;
                return 0.0;
            }
            property color color: ThemeBackend.base
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: container.dynamicCornerRadius
            color: ThemeBackend.base
            border.width: 0
            border.color: launcherWindow.isCentered ? Qt.alpha(ThemeBackend.surface2, 0.6) : "transparent"
            clip: true

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

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
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(12)
                    charSpacing: 1

                    placeholderText: {
                        if (launcherWindow.currentTabIndex === 1) {
                            return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder_files", "Search files or enter path...") : "Search files or enter path...";
                        } else if (launcherWindow.currentTabIndex === 2) {
                            return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder_emojis", "Search emojis by name or keyword...") : "Search emojis by name or keyword...";
                        }
                        return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder", "Start with > for a command...") : "Start with > for a command...";
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
                        if (launcherWindow.currentTabIndex === 0) {
                            filterApps(newText);
                        } else if (launcherWindow.currentTabIndex === 1) {
                            filterFiles(newText);
                        } else {
                            filterEmojis(newText);
                        }
                    }
                    onCleared: {
                        if (launcherWindow.currentTabIndex === 0) {
                            filterApps("");
                        } else if (launcherWindow.currentTabIndex === 1) {
                            filterFiles("");
                        } else {
                            filterEmojis("");
                        }
                    }

                    Keys.onTabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 1) % 3;
                        tabSwitch.currentIndex = launcherWindow.currentTabIndex;
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 2) % 3;
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
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    options: [launcherWindow.tabAppsTitle, launcherWindow.tabFilesTitle, launcherWindow.tabEmojisTitle]
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
                        duration: 260
                        easing.type: Easing.OutCubic
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

                        onContentYChanged: {
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
                            color: ThemeBackend.mauve

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
                                    duration: 260
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

                            opacity: launcherWindow.getItemOpacity(index)
                            transform: Translate {
                                x: launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(index))
                            }

                            Item {
                                id: delegateContent
                                anchors.fill: parent

                                scale: ma.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: ThemeBackend.borderRadius
                                    color: ThemeBackend.surface0
                                    opacity: ma.containsMouse && !delegateRoot.isSelected ? 0.45 : 0
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
                                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                    Behavior on anchors.rightMargin {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.boxRadius
                                            color: delegateRoot.isSelected ? Qt.tint(ThemeBackend.surface2, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface2

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

                                                visible: (!model.fontIcon || model.fontIcon === "") && source !== "" && status === Image.Ready && !failedLoad

                                                source: {
                                                    if (model.fontIcon && model.fontIcon !== "") return "";
                                                    let ic = model.icon || "";
                                                    if (!ic) return "";
                                                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                    if (ic.startsWith("/")) return "file://" + ic;

                                                    let baseName = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
                                                    if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
                                                        let resolved = Quickshell.iconPath(ic) || Quickshell.iconPath(baseName);
                                                        if (resolved && resolved.length > 0) {
                                                            return resolved.startsWith("/") ? ("file://" + resolved) : resolved;
                                                        }
                                                    }

                                                    return "image://icon/" + baseName;
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
                                                    if (model.isCalc) return "󰃬";
                                                    if (model.isCommand) return "󰆍";
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
                                            color: delegateRoot.isSelected ? ThemeBackend.crust : ThemeBackend.text
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
                                            color: delegateRoot.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
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
                        cacheBuffer: launcherWindow.s(400)
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

                        NumberAnimation {
                            id: emojiScrollAnim
                            target: emojiGrid
                            property: "contentY"
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        delegate: Item {
                            id: emojiDelegateRoot
                            width: emojiGrid.cellWidth
                            height: emojiGrid.cellHeight
                            clip: false

                            readonly property bool isSelected: index === emojiGrid.currentIndex

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
                                    color: emojiDelegateRoot.isSelected
                                           ? ThemeBackend.mauve
                                           : (emojiMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.45))
                                    border.width: emojiDelegateRoot.isSelected ? 0 : 1
                                    border.color: emojiDelegateRoot.isSelected ? "transparent" : Qt.alpha(ThemeBackend.surface2, 0.3)

                                    Behavior on color {
                                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: launcherWindow.s(4)
                                    spacing: launcherWindow.s(1)

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                        text: model.emoji
                                        font.pixelSize: launcherWindow.s(22)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                                        text: model.name
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: launcherWindow.s(9)
                                        font.weight: emojiDelegateRoot.isSelected ? Font.Bold : Font.Normal
                                        color: emojiDelegateRoot.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 1

                                        Behavior on color {
                                            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                                        }
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
                        visible: launcherWindow.currentTabIndex === 2 && emojiModel.count === 0
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
