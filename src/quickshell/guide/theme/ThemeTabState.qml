import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../wallpaper"
import "ThemePresetCache.js" as PresetCache

GuideTab {
    id: themeTabRoot

    property var defaultThemeSettings: ({
        "fontFamily": ThemeBackend.fontFamily,
        "borderRadius": ThemeBackend.borderRadius,
        "elementOpacity": 100,
        "blurBackground": false,
        "blurStyle": "blur",
        "activePreset": "Matugen",
        "matugen": true,
        "mode": "dark",
        "colors": {}
    })

    ConfigSection {
        id: themeCfg
        section: "theme"
        defaults: themeTabRoot.defaultThemeSettings
    }

    readonly property var themeSettings: themeCfg.values
    readonly property string currentFontFamily: themeSettings.fontFamily !== undefined ? String(themeSettings.fontFamily) : ThemeBackend.fontFamily
    readonly property int currentBorderRadius: themeSettings.borderRadius !== undefined ? Number(themeSettings.borderRadius) : ThemeBackend.borderRadius
    readonly property int currentElementOpacity: themeSettings.elementOpacity !== undefined ? Number(themeSettings.elementOpacity) : 100
    readonly property string currentBlurStyle: themeSettings.blurStyle === "liquid" ? "liquid" : "blur"
    readonly property bool currentBlurBackground: themeSettings.blurBackground !== undefined ? Boolean(themeSettings.blurBackground) : false
    readonly property string currentPreset: themeSettings.activePreset !== undefined ? String(themeSettings.activePreset) : "Matugen"
    readonly property bool useMatugen: themeSettings.matugen !== undefined ? Boolean(themeSettings.matugen) : true
    readonly property string currentMode: themeSettings.mode === "light" ? "light" : "dark"
    readonly property string effectiveMode: useMatugen ? currentMode : Matugen.modeOfColors(themeSettings.colors)

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

    readonly property var matugenColors: (typeof ThemeBackend !== "undefined" && ThemeBackend.matugenColors) ? ThemeBackend.matugenColors : ({})
    readonly property color prevMatugenBase: (matugenColors && matugenColors.base) ? matugenColors.base : ThemeBackend.base
    readonly property color prevMatugenText: (matugenColors && matugenColors.text) ? matugenColors.text : ThemeBackend.text
    readonly property color prevMatugenBlue: (matugenColors && matugenColors.blue) ? matugenColors.blue : ThemeBackend.blue
    readonly property color prevMatugenMauve: (matugenColors && matugenColors.mauve) ? matugenColors.mauve : ThemeBackend.mauve
    readonly property color prevMatugenPeach: (matugenColors && matugenColors.peach) ? matugenColors.peach : ThemeBackend.peach
    readonly property color prevMatugenGreen: (matugenColors && matugenColors.green) ? matugenColors.green : ThemeBackend.green
    readonly property color prevMatugenRed: (matugenColors && matugenColors.red) ? matugenColors.red : ThemeBackend.red

    property alias currentWallpaperPath: currentWallpaper.path
    property alias wallpaperRevision: currentWallpaper.revision
    property alias isWallpaperVideo: currentWallpaper.isVideo

    CurrentWallpaper { id: currentWallpaper }

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

    Timer {
        id: activateDebounceTimer
        interval: 220
        repeat: false
        onTriggered: {
            currentWallpaper.refresh();
            if (themeTabRoot._needsReload) {
                themeTabRoot._needsReload = false;
                themeTabRoot.reloadThemes();
            }
        }
    }

    function activateTab() {
        themeTabRoot.loadAvailableFonts();
        if (themeTabRoot.systemPresets.length === 0 && PresetCache.systemPresets.length > 0) {
            themeTabRoot._lastPresetsStr = PresetCache.text;
            themeTabRoot.systemPresets = PresetCache.systemPresets;
            themeTabRoot.userPresets = PresetCache.userPresets;
        }
        activateDebounceTimer.restart();
    }

    onVisibleChanged: {
        if (visible) {
            activateTab();
        } else {
            themeCfg.flush();
            activateDebounceTimer.stop();
        }
    }

    function getCardBase(m) { return m.isMatugen ? themeTabRoot.prevMatugenBase : (m.colors && m.colors.base ? m.colors.base : ThemeBackend.base); }
    function getCardText(m) { return m.isMatugen ? themeTabRoot.prevMatugenText : (m.colors && m.colors.text ? m.colors.text : ThemeBackend.text); }
    function getCardDots(m) {
        if (m.isMatugen) return [themeTabRoot.prevMatugenBase, themeTabRoot.prevMatugenBlue, themeTabRoot.prevMatugenMauve, themeTabRoot.prevMatugenPeach, themeTabRoot.prevMatugenGreen, themeTabRoot.prevMatugenRed];
        if (m.colors) return [m.colors.text || ThemeBackend.text, m.colors.blue || ThemeBackend.blue, m.colors.mauve || ThemeBackend.mauve, m.colors.peach || ThemeBackend.peach, m.colors.green || ThemeBackend.green, m.colors.red || ThemeBackend.red];
        return [];
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
            let userPath = Caching.stateDir + "/themes";
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
                        let sysStr = JSON.stringify(sys);
                        if (themeTabRoot.systemPresets.length === 0 || sysStr !== PresetCache.systemStr) {
                            themeTabRoot.systemPresets = sys;
                        }
                        themeTabRoot.userPresets = usr;
                        PresetCache.text = txt;
                        PresetCache.systemStr = sysStr;
                        PresetCache.systemPresets = themeTabRoot.systemPresets;
                        PresetCache.userPresets = usr;
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

    FileView {
        id: presetWriter
        printErrors: false
        preload: false
    }

    function saveCustomTheme(themeObj) {
        let userPath = Caching.stateDir + "/themes";
        let sanitizeName = themeObj.name.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        if (sanitizeName === "") sanitizeName = "CustomTheme";
        themeObj.name = sanitizeName;
        themeObj.isCustom = true;
        themeObj.category = "user";
        presetWriter.path = userPath + "/" + sanitizeName + ".json";
        presetWriter.setText(JSON.stringify(themeObj, null, 2) + "\n");

        let arr = themeTabRoot.userPresets.filter(t => t.name !== themeObj.name);
        arr.push(themeObj);
        themeTabRoot.userPresets = arr;
        PresetCache.userPresets = arr;
    }

    function deleteCustomTheme(themeName) {
        let userPath = Caching.stateDir + "/themes";
        let sanitizeName = themeName.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        let filePath = userPath + "/" + sanitizeName + ".json";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let cmd = "rm -f \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        themeTabRoot.userPresets = themeTabRoot.userPresets.filter(t => t.name !== themeName);
        PresetCache.userPresets = themeTabRoot.userPresets;
    }

    function setFontFamily(family) {
        themeCfg.set("fontFamily", family);
    }

    function setBorderRadius(val) {
        themeCfg.set("borderRadius", val);
        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.reloadColors();
        }
    }

    function setBorderRadiusDebounced(val) {
        themeCfg.setDebounced("borderRadius", val, 250);
    }

    function setElementOpacityDebounced(val) {
        themeCfg.setDebounced("elementOpacity", val, 100);
    }

    function flushThemeSettings() {
        themeCfg.flush();
    }

    function updateBlurBackgroundSetting(val) {
        themeCfg.set("blurBackground", val);
    }

    function updateBlurStyleSetting(val) {
        themeCfg.set("blurStyle", val);
    }

    function updateModeSetting(mode) {
        themeCfg.set("mode", mode);
        AppTheming.requestColorSchemeSync();

        let wallpaper = themeTabRoot.currentWallpaperPath || Matugen.lastWallpaper;
        if (wallpaper && wallpaper !== "") {
            Matugen.generate(wallpaper, mode, themeSettings.schemeType);
        }
    }

    function applyPreset(modelData) {
        if (!modelData) return;

        let isMatugen = modelData.isMatugen === true;
        let patch = {
            "activePreset": modelData.name,
            "matugen": isMatugen
        };
        if (!isMatugen) {
            patch.colors = modelData.colors;
        }
        themeCfg.setMany(patch);
        AppTheming.requestColorSchemeSync();

        if (isMatugen) {
            if (typeof ThemeBackend !== "undefined") {
                let applied = (typeof ThemeBackend.applyMatugenColors === "function") && ThemeBackend.applyMatugenColors();
                if (!applied && themeTabRoot.matugenColors && Object.keys(themeTabRoot.matugenColors).length > 0) {
                    ThemeBackend.applyColorObject(themeTabRoot.matugenColors.colors || themeTabRoot.matugenColors);
                }
            }

            if (themeTabRoot.currentWallpaperPath && themeTabRoot.currentWallpaperPath !== "") {
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                    Matugen.generate(themeTabRoot.currentWallpaperPath, themeTabRoot.currentMode, themeSettings.schemeType);
                }
            } else if (typeof ThemeBackend !== "undefined") {
                ThemeBackend.reloadColors();
            }
        } else {
            if (typeof ThemeBackend !== "undefined" && typeof ThemeBackend.applyColorObject === "function") {
                ThemeBackend.applyColorObject(modelData.colors);
            }
            if (typeof Matugen !== "undefined" && typeof Matugen.generateFromStatic === "function") {
                Matugen.generateFromStatic(modelData.colors, themeTabRoot.currentMode);
            }
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

            if (fontPickerLoader.item) fontPickerLoader.item.close();
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

                        ThemeBackend.scanFonts();

                        themeTabRoot.setFontFamily(fName);

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

        let userFontsPath = Caching.stateDir + "/fonts";
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

    function openFontPicker() {
        fontPickerLoader.active = true;
        fontPickerLoader.item.openPicker();
    }

    Loader {
        id: fontPickerLoader
        active: false
        sourceComponent: FontPicker {
            rootObj: themeTabRoot.rootObj
            onFontSelected: function(filePath, fileName) {
                if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                    themeTabRoot.installFont(filePath, fileName);
                }
            }
        }
    }
}
