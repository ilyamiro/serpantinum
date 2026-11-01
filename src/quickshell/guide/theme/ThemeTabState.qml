import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"

GuideTab {
    id: themeTabRoot

    property var defaultThemeSettings: {
        "fontFamily": ThemeBackend.fontFamily,
        "borderRadius": ThemeBackend.borderRadius,
        "elementOpacity": 100,
        "blurBackground": false,
        "blurStyle": "blur",
        "activePreset": "Matugen",
        "matugen": true,
        "colors": {},
        "accent": "mauve",
        "accentByTheme": {}
    }

    property alias fontPickerPopup: fontPickerPopup
    property alias wallpaperDirScanner: wallpaperDirScanner
    property alias borderRadiusDebounceTimer: borderRadiusDebounceTimer
    property alias elementOpacityDebounceTimer: elementOpacityDebounceTimer

    property var themeSettings: Config.getSetting("theme", defaultThemeSettings)
    property string currentFontFamily: themeSettings.fontFamily !== undefined ? themeSettings.fontFamily : ThemeBackend.fontFamily
    property int currentBorderRadius: themeSettings.borderRadius !== undefined ? themeSettings.borderRadius : ThemeBackend.borderRadius
    property int currentElementOpacity: themeSettings.elementOpacity !== undefined ? Number(themeSettings.elementOpacity) : 100
    property string currentBlurStyle: themeSettings.blurStyle === "liquid" ? "liquid" : "blur"
    property bool currentBlurBackground: themeSettings.blurBackground !== undefined ? Boolean(themeSettings.blurBackground) : false
    property string currentPreset: themeSettings.activePreset !== undefined ? themeSettings.activePreset : "Matugen"
    property bool useMatugen: themeSettings.matugen !== undefined ? themeSettings.matugen : true

    readonly property string activePresetName: themeSettings.activePreset !== undefined ? themeSettings.activePreset : "Matugen"
    property string currentAccent: {
        if (!themeSettings) return "mauve";
        let map = themeSettings.accentByTheme;
        if (map && map[activePresetName] !== undefined && map[activePresetName] !== null) return String(map[activePresetName]);
        if (themeSettings.accent !== undefined && themeSettings.accent !== null) return String(themeSettings.accent);
        return "mauve";
    }

    property string currentWallpaperDir: Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property var availableWallpaperDirs: []

    property var curatedFonts: ThemeBackend.bundledNames
    property var blockedFontPatterns: [".notdef", "cursor", "emoji", "symbol", "pcf"]
    property var availableFonts: []

    function loadAvailableFonts() {
        if (availableFonts.length > 0) return;
        let curated = themeTabRoot.curatedFonts;
        let dedupedCurated = [];
        let seen = new Set();

        for (let i = 0; i < curated.length; i++) {
            let key = curated[i].toLowerCase().trim();
            if (!seen.has(key)) {
                seen.add(key);
                dedupedCurated.push(curated[i]);
            }
        }

        let rest = [];
        let raw = Qt.fontFamilies();
        for (let i = 0; i < raw.length; i++) {
            let name = raw[i];
            let key = name.toLowerCase().trim();

            if (seen.has(key)) continue;

            let blocked = false;
            for (let j = 0; j < themeTabRoot.blockedFontPatterns.length; j++) {
                if (key.indexOf(themeTabRoot.blockedFontPatterns[j]) !== -1) {
                    blocked = true;
                    break;
                }
            }
            if (blocked) continue;

            seen.add(key);
            rest.push(name);
        }
        rest.sort(function(a, b) { return a.localeCompare(b); });
        let combined = dedupedCurated.concat(rest);
        if (themeTabRoot.currentFontFamily && combined.indexOf(themeTabRoot.currentFontFamily) === -1) {
            combined.push(themeTabRoot.currentFontFamily);
        }
        themeTabRoot.availableFonts = combined;
    }

    property var systemPresets: []
    property var userPresets: []
    property string themeSearchText: ""
    property string _lastPresetsStr: ""
    property bool _needsReload: true

    property var filteredUserPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        if (txt === "") return themeTabRoot.userPresets;
        let res = [];
        for (let i = 0; i < themeTabRoot.userPresets.length; i++) {
            let p = themeTabRoot.userPresets[i];
            if (p && p.name && p.name.toLowerCase().indexOf(txt) !== -1) {
                res.push(p);
            }
        }
        return res;
    }

    property var filteredSystemPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        let result = [];
        let pendingDivider = false;
        for (let i = 0; i < themeTabRoot.systemPresets.length; i++) {
            let p = themeTabRoot.systemPresets[i];
            if (p.isDivider) {
                pendingDivider = true;
            } else {
                if (txt === "" || (p.name && p.name.toLowerCase().indexOf(txt) !== -1)) {
                    if (pendingDivider) {
                        result.push({ isDivider: true });
                        pendingDivider = false;
                    }
                    result.push(p);
                }
            }
        }
        return result;
    }

    readonly property int presetTotal: Math.max(filteredUserPresets.length, filteredSystemPresets.length)
    property int revealedCount: 0

    function restartReveal() {
        themeTabRoot.revealedCount = Math.min(themeTabRoot.presetTotal, 12);
        if (themeTabRoot.revealedCount < themeTabRoot.presetTotal) revealTimer.restart();
        else revealTimer.stop();
    }

    onFilteredUserPresetsChanged: restartReveal()
    onFilteredSystemPresetsChanged: restartReveal()

    FrameAnimation {
        id: revealTimer
        onTriggered: {
            themeTabRoot.revealedCount = Math.min(themeTabRoot.presetTotal, themeTabRoot.revealedCount + 8);
            if (themeTabRoot.revealedCount >= themeTabRoot.presetTotal) revealTimer.stop();
        }
    }

    property var matugenColors: ({})
    property color prevMatugenBase: ThemeBackend.base
    property color prevMatugenText: ThemeBackend.text
    property color prevMatugenBlue: ThemeBackend.blue
    property color prevMatugenMauve: ThemeBackend.mauve
    property color prevMatugenPeach: ThemeBackend.peach
    property color prevMatugenGreen: ThemeBackend.green
    property color prevMatugenRed: ThemeBackend.red

    property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""
    property string currentWallpaperPath: ""
    property int wallpaperRevision: 0
    property bool isWallpaperVideo: {
        let lp = currentWallpaperPath.toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm") || lp.indexOf("000_") !== -1;
    }


    Timer {
        id: borderRadiusDebounceTimer
        interval: 250
        repeat: false
        onTriggered: {
            themeTabRoot.updateBorderRadiusSetting();
        }
    }

    Timer {
        id: elementOpacityDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            themeTabRoot.updateElementOpacitySetting();
        }
    }

    Timer {
        id: snapshotDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            themeTabRoot.wallpaperRevision++;
        }
    }

    function getSnappedRadius(rawVal) {
        let snapPoints = [0, 2, 4, 8, 10, 16, 24, 32, 48, 52, 58, 64];
        let rounded = Math.round(rawVal);
        let closest = snapPoints[0];
        let minDiff = Math.abs(rounded - snapPoints[0]);
        for (let i = 1; i < snapPoints.length; i++) {
            let diff = Math.abs(rounded - snapPoints[i]);
            if (diff < minDiff) {
                minDiff = diff;
                closest = snapPoints[i];
            }
        }
        if (minDiff <= 2) {
            return closest;
        }
        return rounded;
    }

    FileView {
        id: wpStateWatcher
        path: themeTabRoot.activeScreenName !== "" ? (Caching.getCacheDir("wallpaper") + "/current_" + themeTabRoot.activeScreenName) : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let res = text().trim();
            if (res !== "" && res !== themeTabRoot.currentWallpaperPath) {
                themeTabRoot.currentWallpaperPath = res;
                themeTabRoot.wallpaperRevision++;
            }
        }
    }

    FileView {
        id: wpSnapshotWatcher
        path: Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"
        watchChanges: true
        onFileChanged: snapshotDebounceTimer.restart()
        onLoaded: snapshotDebounceTimer.restart()
    }

    Process {
        id: wallFetcher
        running: false
        command: {
            let screenName = themeTabRoot.activeScreenName;
            let mainQmlPath = Caching.mainQml || "";
            let curDir = themeTabRoot.currentWallpaperDir || "";
            let pyScript =
                "import os, subprocess, sys\n" +
                "home = os.path.expanduser('~')\n" +
                "main_qml = sys.argv[1]\n" +
                "screen = sys.argv[2]\n" +
                "cur_dir = sys.argv[3]\n" +
                "if not main_qml or not screen:\n" +
                "    print('')\n" +
                "    sys.exit(0)\n" +
                "try:\n" +
                "    p = subprocess.run(['quickshell', '-p', main_qml, 'ipc', 'call', 'wallpaper', 'getWallpaperPath', screen], capture_output=True, text=True)\n" +
                "    val = p.stdout.strip() if p.returncode == 0 else ''\n" +
                "except Exception:\n" +
                "    val = ''\n" +
                "if not val:\n" +
                "    try:\n" +
                "        p = subprocess.run(['quickshell', '-p', main_qml, 'ipc', 'call', 'wallpaper', 'getWallpaper', screen], capture_output=True, text=True)\n" +
                "        val = p.stdout.strip() if p.returncode == 0 else ''\n" +
                "    except Exception:\n" +
                "        val = ''\n" +
                "if not val:\n" +
                "    print('')\n" +
                "    sys.exit(0)\n" +
                "if os.path.isabs(val) and os.path.exists(val):\n" +
                "    print(val)\n" +
                "    sys.exit(0)\n" +
                "candidates = []\n" +
                "if cur_dir and os.path.isdir(cur_dir):\n" +
                "    candidates.append(cur_dir)\n" +
                "candidates.extend([\n" +
                "    os.path.join(home, 'Pictures', 'Wallpapers'),\n" +
                "    os.path.join(home, 'Wallpapers'),\n" +
                "    os.path.join(home, 'Pictures'),\n" +
                "    os.path.join(home, 'Videos'),\n" +
                "    os.path.join(home, 'Videos', 'Wallpapers'),\n" +
                "    os.path.join(home, '.local/share/wallpapers'),\n" +
                "    '/usr/share/backgrounds',\n" +
                "    '/usr/share/wallpapers'\n" +
                "])\n" +
                "base_name = os.path.basename(val)\n" +
                "found = ''\n" +
                "for d in candidates:\n" +
                "    target = os.path.join(d, base_name)\n" +
                "    if os.path.isfile(target):\n" +
                "        found = target\n" +
                "        break\n" +
                "if not found:\n" +
                "    for root_dir in [os.path.join(home, 'Pictures'), os.path.join(home, 'Wallpapers'), '/usr/share/backgrounds']:\n" +
                "        if os.path.isdir(root_dir):\n" +
                "            for root, dirs, files in os.walk(root_dir):\n" +
                "                if base_name in files:\n" +
                "                    found = os.path.join(root, base_name)\n" +
                "                    break\n" +
                "            if found:\n" +
                "                break\n" +
                "if not found:\n" +
                "    found = os.path.join(cur_dir, val) if cur_dir else val\n" +
                "print(found)\n";
            return ["python3", "-c", pyScript, mainQmlPath, screenName, curDir];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let res = this.text.trim();
                if (res !== "" && res !== themeTabRoot.currentWallpaperPath) {
                    themeTabRoot.currentWallpaperPath = res;
                    themeTabRoot.wallpaperRevision++;
                }
            }
        }
    }

    Process {
        id: wallpaperDirScanner
        running: false
        command: [
            "bash", "-c",
            "python3 -c '\n" +
            "import os\n" +
            "home = os.path.expanduser(\"~\")\n" +
            "exts = {\".jpg\", \".jpeg\", \".png\", \".webp\", \".bmp\", \".mp4\", \".mkv\", \".mov\", \".webm\"}\n" +
            "dirs = set()\n" +
            "candidates = [\n" +
            "    os.path.join(home, \"Pictures\"),\n" +
            "    os.path.join(home, \"Pictures\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Videos\"),\n" +
            "    os.path.join(home, \"Videos\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \".local/share/wallpapers\"),\n" +
            "    \"/usr/share/backgrounds\",\n" +
            "    \"/usr/share/wallpapers\"\n" +
            "]\n" +
            "for c in candidates:\n" +
            "    if not os.path.isdir(c):\n" +
            "        continue\n" +
            "    dirs.add(c)\n" +
            "    for root, subdirs, files in os.walk(c, followlinks=True):\n" +
            "        depth = root[len(c):].count(os.sep)\n" +
            "        if depth > 3:\n" +
            "            subdirs[:] = []\n" +
            "            continue\n" +
            "        subdirs[:] = [d for d in subdirs if not d.startswith(\".\")]\n" +
            "        if any(os.path.splitext(f)[1].lower() in exts for f in files):\n" +
            "            dirs.add(root)\n" +
            "sorted_dirs = sorted(list(dirs), key=lambda x: (x.count(os.sep), x.lower()))\n" +
            "print(\"\\n\".join(sorted_dirs))\n" +
            "'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                if (themeTabRoot.currentWallpaperDir && lines.indexOf(themeTabRoot.currentWallpaperDir) === -1) {
                    lines.unshift(themeTabRoot.currentWallpaperDir);
                }
                themeTabRoot.availableWallpaperDirs = lines;
            }
        }
    }

    Timer {
        id: activateDebounceTimer
        interval: 220
        repeat: false
        onTriggered: {
            wallpaperDirScanner.running = false;
            wallpaperDirScanner.running = true;
            wallFetcher.running = false;
            wallFetcher.running = true;
            if (themeTabRoot._needsReload) {
                themeTabRoot._needsReload = false;
                themeTabRoot.reloadThemes();
            }
        }
    }

    function activateTab() {
        themeTabRoot.loadAvailableFonts();
        activateDebounceTimer.restart();
    }

    onVisibleChanged: {
        if (visible) {
            activateTab();
        } else {
            activateDebounceTimer.stop();
        }
    }

    onMatugenColorsChanged: {
        prevMatugenBase = matugenColors.base || ThemeBackend.base;
        prevMatugenText = matugenColors.text || ThemeBackend.text;
        prevMatugenBlue = matugenColors.blue || ThemeBackend.blue;
        prevMatugenMauve = matugenColors.mauve || ThemeBackend.mauve;
        prevMatugenPeach = matugenColors.peach || ThemeBackend.peach;
        prevMatugenGreen = matugenColors.green || ThemeBackend.green;
        prevMatugenRed = matugenColors.red || ThemeBackend.red;
    }

    function getCardBase(m) { return m.isMatugen ? themeTabRoot.prevMatugenBase : (m.colors && m.colors.base ? m.colors.base : ThemeBackend.base); }
    function getCardText(m) { return m.isMatugen ? themeTabRoot.prevMatugenText : (m.colors && m.colors.text ? m.colors.text : ThemeBackend.text); }
    function getCardDots(m) {
        if (m.isMatugen) return [themeTabRoot.prevMatugenBase, themeTabRoot.prevMatugenBlue, themeTabRoot.prevMatugenMauve, themeTabRoot.prevMatugenPeach, themeTabRoot.prevMatugenGreen, themeTabRoot.prevMatugenRed];
        if (m.colors) return [m.colors.text || ThemeBackend.text, m.colors.blue || ThemeBackend.blue, m.colors.mauve || ThemeBackend.mauve, m.colors.peach || ThemeBackend.peach, m.colors.green || ThemeBackend.green, m.colors.red || ThemeBackend.red];
        return [];
    }

    FileView {
        id: matugenColorsWatcher
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") ?? "") + "/.local/state/serpantinum")) + "/qs_matugen_colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                themeTabRoot.matugenColors = data.colors || data;
            } catch(e) {}
        }
    }

    function reloadThemes() {
        themesLoader.running = false;
        themesLoader.running = true;
    }

    Process {
        id: themesLoader
        running: false
        command: {
            let assetsPath = Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/themes") : "";
            let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
            let cachePath = Caching.getCacheDir("themes") + "/theme_sort_cache.json";
            let scriptPath = Caching.qsDir ? (Caching.qsDir + "/guide/theme/theme_sorter.py") : "theme_sorter.py";
            return ["python3", scriptPath, assetsPath, userPath, cachePath];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt === "" || txt === themeTabRoot._lastPresetsStr) return;
                    themeTabRoot._lastPresetsStr = txt;
                    let data = JSON.parse(txt);
                    if (Array.isArray(data) && data.length > 0) {
                        let sys = [];
                        let usr = [];
                        let len = data.length;
                        for (let i = 0; i < len; i++) {
                            let item = data[i];
                            if (item.isCustom === true || item.category === "user") {
                                usr.push(item);
                            } else {
                                sys.push(item);
                            }
                        }
                        if (themeTabRoot.systemPresets.length === 0) {
                            themeTabRoot.systemPresets = sys;
                        }
                        themeTabRoot.userPresets = usr;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: reloadThemesTimer
        interval: 150
        repeat: false
        onTriggered: themeTabRoot.reloadThemes()
    }

    Component.onCompleted: {
        themeTabRoot.loadAvailableFonts();
        if (visible) {
            activateTab();
        }
    }

    function saveCustomTheme(themeObj) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
        let sanitizeName = themeObj.name.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        if (sanitizeName === "") sanitizeName = "CustomTheme";
        themeObj.name = sanitizeName;
        themeObj.isCustom = true;
        themeObj.category = "user";
        let jsonStr = JSON.stringify(themeObj, null, 2);
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let filePath = userPath + "/" + sanitizeName + ".json";
        let cmd = "mkdir -p \"" + escapeBash(userPath) + "\" && echo \"" + escapeBash(jsonStr) + "\" > \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        let arr = themeTabRoot.userPresets.filter(t => t.name !== themeObj.name);
        arr.push(themeObj);
        themeTabRoot.userPresets = arr;
    }

    function deleteCustomTheme(themeName) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
        let sanitizeName = themeName.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        let filePath = userPath + "/" + sanitizeName + ".json";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let cmd = "rm -f \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        themeTabRoot.userPresets = themeTabRoot.userPresets.filter(t => t.name !== themeName);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let ts = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
            themeTabRoot.currentFontFamily = ts.fontFamily !== undefined ? ts.fontFamily : ThemeBackend.fontFamily;
            themeTabRoot.currentBorderRadius = ts.borderRadius !== undefined ? ts.borderRadius : ThemeBackend.borderRadius;
            themeTabRoot.currentElementOpacity = ts.elementOpacity !== undefined ? Number(ts.elementOpacity) : 100;
            themeTabRoot.currentBlurBackground = ts.blurBackground !== undefined ? Boolean(ts.blurBackground) : false;
            themeTabRoot.currentBlurStyle = ts.blurStyle === "liquid" ? "liquid" : "blur";
            themeTabRoot.currentPreset = ts.activePreset !== undefined ? ts.activePreset : "Matugen";
            themeTabRoot.useMatugen = ts.matugen !== undefined ? ts.matugen : true;
            themeTabRoot.themeSettings = ts;

            let wpDir = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "");
            if (wpDir && wpDir !== "") {
                themeTabRoot.currentWallpaperDir = wpDir;
            }
        }
    }

    function updateWallpaperDirSetting() {
        Config.setSetting("wallpaperDir", themeTabRoot.currentWallpaperDir);
    }

    function updateFontSetting() {
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.fontFamily = themeTabRoot.currentFontFamily;
        Config.setSetting("theme", current);
    }

    function updateBorderRadiusSetting() {
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.borderRadius = themeTabRoot.currentBorderRadius;
        Config.setSetting("theme", current);
        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.reloadColors();
        }
    }

    function updateElementOpacitySetting() {
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.elementOpacity = themeTabRoot.currentElementOpacity;
        Config.setSetting("theme", current);
    }

    function updateBlurBackgroundSetting(val) {
        themeTabRoot.currentBlurBackground = val;
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.blurBackground = val;
        Config.setSetting("theme", current);
    }

    function updateBlurStyleSetting(val) {
        themeTabRoot.currentBlurStyle = val;
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.blurStyle = val;
        Config.setSetting("theme", current);
    }

    function setAccentValue(value) {
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        let preset = current.activePreset !== undefined ? current.activePreset : "Matugen";
        let map = {};
        if (current.accentByTheme && typeof current.accentByTheme === "object") {
            map = JSON.parse(JSON.stringify(current.accentByTheme));
        }
        if (value === null) {
            delete map[preset];
            current.accent = "mauve";
        } else {
            map[preset] = value;
            current.accent = value;
        }
        current.accentByTheme = map;
        Config.setSetting("theme", current);
        themeTabRoot.themeSettings = current;
        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.setAccent(current.accent);
        }
    }

    function resetAccentValue() {
        themeTabRoot.setAccentValue(null);
    }

    function activePalette() {
        let t = Config.getSetting("theme", {});
        let isMatugen = t.matugen === true || t.activePreset === "Matugen";
        if (isMatugen) {
            let mc = themeTabRoot.matugenColors || {};
            if (mc.colors) mc = mc.colors;
            if (mc && Object.keys(mc).length > 0) return mc;
        }
        return t.colors || {};
    }

    function applyPreset(modelData) {
        if (!modelData) return;

        let isMatugen = modelData.isMatugen === true;
        themeTabRoot.currentPreset = modelData.name;
        themeTabRoot.useMatugen = isMatugen;

        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.activePreset = modelData.name;
        current.matugen = isMatugen;
        if (!isMatugen) {
            current.colors = modelData.colors;
        }

        if (typeof ThemeBackend !== "undefined" && typeof ThemeBackend.accentFromConfig === "function") {
            current.accent = ThemeBackend.accentFromConfig(current);
        }

        Config.setSetting("theme", current);

        if (isMatugen) {
            if (typeof ThemeBackend !== "undefined") {
                let applied = (typeof ThemeBackend.applyMatugenColors === "function") && ThemeBackend.applyMatugenColors();
                if (!applied && themeTabRoot.matugenColors && Object.keys(themeTabRoot.matugenColors).length > 0) {
                    ThemeBackend.applyColorObject(themeTabRoot.matugenColors.colors || themeTabRoot.matugenColors);
                }
            }

            if (themeTabRoot.currentWallpaperPath && themeTabRoot.currentWallpaperPath !== "") {
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                    Matugen.generate(themeTabRoot.currentWallpaperPath, current.mode, current.schemeType);
                }
            } else if (typeof ThemeBackend !== "undefined") {
                ThemeBackend.reloadColors();
            }
        } else {
            if (typeof ThemeBackend !== "undefined" && typeof ThemeBackend.applyColorObject === "function") {
                ThemeBackend.applyColorObject(modelData.colors);
            }
            if (typeof Matugen !== "undefined" && typeof Matugen.generateFromStatic === "function") {
                Matugen.generateFromStatic(modelData.colors, current.mode);
            }
        }

        themeTabRoot.themeSettings = current;
        if (typeof ThemeBackend !== "undefined" && typeof ThemeBackend.accentFromConfig === "function") {
            ThemeBackend.syncAccent(ThemeBackend.accentFromConfig(current));
        }
    }


    property var currentPreviewLoader: null

    Component {
        id: dynamicFontLoaderComp
        FontLoader {}
    }

    Timer {
        id: fontLoadDelay
        interval: 100
        property string targetPath: ""
        onTriggered: {
            if (themeTabRoot.currentPreviewLoader) {
                themeTabRoot.currentPreviewLoader.destroy();
                themeTabRoot.currentPreviewLoader = null;
            }

            if (targetPath !== "") {
                themeTabRoot.currentPreviewLoader = dynamicFontLoaderComp.createObject(themeTabRoot, { source: "file://" + targetPath });
            }

            fontPickerPopup.close();
        }
    }

    Process {
        id: fontInstallProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let idx = out.indexOf('|');
                    if (idx !== -1) {
                        let fName = out.substring(0, idx).trim();
                        let fPath = out.substring(idx + 1).trim();

                        let mainQmlPath = Caching.mainQml;
                        if (mainQmlPath !== "") {
                            let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); }
                            Quickshell.execDetached(["bash", "-c", "quickshell -p \"" + escapeBash(mainQmlPath) + "\" ipc call fonts rescan"]);
                        }

                        themeTabRoot.currentFontFamily = fName;
                        themeTabRoot.updateFontSetting();

                        if (themeTabRoot.availableFonts.indexOf(fName) === -1) {
                            let arr = themeTabRoot.availableFonts.slice();
                            arr.push(fName);
                            themeTabRoot.availableFonts = arr;
                        }

                        fontLoadDelay.targetPath = fPath;
                        fontLoadDelay.start();
                    }
                }
            }
        }
    }

    function installFont(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") {
            return;
        }

        let userFontsPath = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/serpantinum/fonts");
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };

        let script = 
            "D=\"" + escapeBash(userFontsPath) + "\"; " +
            "B=\"" + escapeBash(fileName) + "\"; " +
            "S=\"" + escapeBash(filePath) + "\"; " +
            "mkdir -p \"$D\"; " +
            "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
            "F=\"$D/$B\"; " +
            "FAM=$(fc-query -f \"%{family}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -z \"$FAM\" ]; then FAM=$(basename \"$F\" | sed 's/\\.[^.]*$//'); fi; " +
            "STL=$(fc-query -f \"%{style}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -n \"$STL\" ] && [ \"$STL\" != \"Regular\" ]; then " +
                "echo \"$FAM $STL|$F\"; " +
            "else " +
                "echo \"$FAM|$F\"; " +
            "fi;";

        fontInstallProcess.command = ["bash", "-c", script];
        fontInstallProcess.running = true;
    }

    FontPicker {
        id: fontPickerPopup
        rootObj: themeTabRoot.rootObj
        onFontSelected: function(filePath, fileName) {
            if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                themeTabRoot.installFont(filePath, fileName);
            }
        }
    }
}
