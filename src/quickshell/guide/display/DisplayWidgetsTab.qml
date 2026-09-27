import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../widgets"

Item {
    id: displayWidgetsRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property var defaultWidgetsSettings: ({
        "hideBarInRedactor": true
    })

    property var widgetsSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["widgets"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("widgets", displayWidgetsRoot.defaultWidgetsSettings);
        }
        return displayWidgetsRoot.defaultWidgetsSettings;
    }

    property bool currentHideBarInRedactor: widgetsSettings && widgetsSettings.hideBarInRedactor !== undefined ? widgetsSettings.hideBarInRedactor : true
    property int wallpaperRevision: 0

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("widgets", displayWidgetsRoot.defaultWidgetsSettings)
            : displayWidgetsRoot.defaultWidgetsSettings;
        displayWidgetsRoot.widgetsSettings = s;
        displayWidgetsRoot.currentHideBarInRedactor = s.hideBarInRedactor !== undefined ? s.hideBarInRedactor : true;
    }

    function updateWidgetsSetting(key, value) {
        let current = JSON.parse(JSON.stringify((typeof Config !== "undefined" && typeof Config.getSetting === "function") ? (Config.getSetting("widgets", defaultWidgetsSettings) || defaultWidgetsSettings) : defaultWidgetsSettings));
        current[key] = value;
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
            Config.setSetting("widgets", current);
        }
        displayWidgetsRoot.widgetsSettings = current;
    }

    property var monitorsList: []
    property var monitorWidgetsMap: ({})
    property var systemPresets: []
    property var userPresets: []
    property var availablePresets: []

    function reloadPresets() {
        presetsLoader.running = false;
        presetsLoader.running = true;
    }

    function getScreen(monName) {
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            let target = String(monName || "").trim().toLowerCase();
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name) {
                    let nm = String(scr.name).trim().toLowerCase();
                    let safe = nm.replace(/[^a-zA-Z0-9_-]/g, "_");
                    if (nm === target || safe === target) return scr;
                }
            }
            return Quickshell.screens[0];
        }
        return null;
    }

    function getScreenDimensions(monName) {
        let sw = 1920;
        let sh = 1080;
        let scr = getScreen(monName);
        if (scr) {
            if (scr.width > 0) sw = scr.width;
            if (scr.height > 0) sh = scr.height;
        }
        return { w: sw, h: sh };
    }

    function getWallpaperSource(monName) {
        let p = "";
        if (typeof Wallpaper !== "undefined" && Wallpaper.screenWallpaperPaths) {
            if (Wallpaper.screenWallpaperPaths[monName]) {
                p = Wallpaper.screenWallpaperPaths[monName];
            } else {
                let target = String(monName || "").toLowerCase();
                for (let k in Wallpaper.screenWallpaperPaths) {
                    if (String(k).toLowerCase() === target) {
                        p = Wallpaper.screenWallpaperPaths[k];
                        break;
                    }
                }
            }
        }
        let isVid = false;
        if (p) {
            let lp = p.toLowerCase();
            isVid = lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
        }
        let cacheDir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function")
            ? Caching.getCacheDir("wallpaper") : "";
        if (isVid || !p) {
            let monSnap = cacheDir ? (cacheDir + "/current_wallpaper_" + monName + ".png") : "";
            if (monSnap) return "file://" + monSnap;
            let genSnap = cacheDir ? (cacheDir + "/current_wallpaper.png") : "";
            if (genSnap) return "file://" + genSnap;
        }
        if (p) {
            return p.indexOf("://") !== -1 ? p : ("file://" + p);
        }
        return "";
    }

    function resolveDimension(val, screenDim, defVal) {
        if (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.resolveDimension === "function") {
            return WidgetRegistry.resolveDimension(val, screenDim, defVal);
        }
        if (typeof val === "string" && val.indexOf("%") !== -1) {
            return (parseFloat(val) / 100) * screenDim;
        }
        let n = parseFloat(val);
        return !isNaN(n) ? n : defVal;
    }

    function resolvePosition(cfg, sw, sh, w, h) {
        if (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.resolvePosition === "function") {
            return WidgetRegistry.resolvePosition(cfg, sw, sh, w, h);
        }
        let isStretchW = !!(cfg.stretchWidth || cfg.wStretchWidth);
        let isStretchH = !!(cfg.stretchHeight || cfg.wStretchHeight);
        let anchor = (cfg.anchor || "").toLowerCase().trim();
        let rawX = cfg.x !== undefined ? cfg.x : (cfg.wX !== undefined ? cfg.wX : 0);
        let rawY = cfg.y !== undefined ? cfg.y : (cfg.wY !== undefined ? cfg.wY : 0);
        let x = resolveDimension(rawX, sw, 0);
        let y = resolveDimension(rawY, sh, 0);

        if (isStretchW) x = 0;
        if (isStretchH) y = 0;

        if (!anchor) {
            return { x: x, y: y };
        }

        let resX = isStretchW ? 0 : x;
        let resY = isStretchH ? 0 : y;
        if (!isStretchW) {
            if (anchor.indexOf("right") !== -1) {
                resX = sw - w - x;
            } else if (anchor.indexOf("center") !== -1 && anchor.indexOf("left") === -1) {
                resX = (sw - w) / 2 + x;
            }
        }
        if (!isStretchH) {
            if (anchor.indexOf("bottom") !== -1) {
                resY = sh - h - y;
            } else if (anchor.indexOf("vcenter") !== -1 || (anchor.indexOf("center") !== -1 && anchor.indexOf("top") === -1 && anchor.indexOf("bottom") === -1)) {
                resY = (sh - h) / 2 + y;
            }
        }
        return { x: resX, y: resY };
    }

    function getFaceUrl(type, variant) {
        if (!type) return "";
        let vKey = variant || "";
        if (typeof WidgetRegistry !== "undefined") {
            if (typeof WidgetRegistry.faceFile === "function") {
                let f = WidgetRegistry.faceFile(type, vKey);
                if (f && f !== "") return f;
            }
            if (WidgetRegistry.types && WidgetRegistry.types[type]) {
                let t = WidgetRegistry.types[type];
                let v = (vKey && t.variants && t.variants[vKey]) ? t.variants[vKey] : (t.variants ? t.variants[t.defaultVariant] : null);
                if (v && v.file) {
                    return Qt.resolvedUrl("../../widgets/" + v.file);
                }
            }
        }
        let cap = type.charAt(0).toUpperCase() + type.slice(1);
        return Qt.resolvedUrl("../../widgets/faces/" + cap + "Face.qml");
    }

    Process {
        id: presetsLoader
        running: false
        command: {
            let assetsDir = Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/widgets") : "";
            let userDir = Caching.stateDir ? (Caching.stateDir + "/widgets/presets") : (Caching.home + "/.local/state/serpantinum/widgets/presets");
            let pyScript =
                "import os, json, glob, sys\n" +
                "assets_d = sys.argv[1]\n" +
                "user_d = sys.argv[2]\n" +
                "dirs = [d for d in [user_d, assets_d] if d and os.path.isdir(d)]\n" +
                "res = []\n" +
                "seen = set()\n" +
                "for d in dirs:\n" +
                "    is_user = (d == user_d)\n" +
                "    for f in sorted(glob.glob(os.path.join(d, '*.json'))):\n" +
                "        base = os.path.splitext(os.path.basename(f))[0]\n" +
                "        if base in seen:\n" +
                "            continue\n" +
                "        try:\n" +
                "            with open(f, 'r', encoding='utf-8') as fp:\n" +
                "                obj = json.load(fp)\n" +
                "            if isinstance(obj, dict):\n" +
                "                obj['id'] = base\n" +
                "                if is_user or obj.get('category') == 'user' or obj.get('isCustom'):\n" +
                "                    obj['isCustom'] = True\n" +
                "                    obj['category'] = 'user'\n" +
                "                else:\n" +
                "                    obj['isCustom'] = False\n" +
                "                    obj['category'] = 'system'\n" +
                "                if not obj.get('name'):\n" +
                "                    obj['name'] = 'widgets.presets.' + base + '.name'\n" +
                "                res.append(obj)\n" +
                "                seen.add(base)\n" +
                "        except Exception:\n" +
                "            pass\n" +
                "print(json.dumps(res))\n";
            return ["python3", "-c", pyScript, assetsDir, userDir];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (!out) return;
                try {
                    let arr = JSON.parse(out);
                    if (Array.isArray(arr) && arr.length > 0) {
                        displayWidgetsRoot.availablePresets = arr;
                        let sys = [];
                        let usr = [];
                        for (let i = 0; i < arr.length; i++) {
                            let item = arr[i];
                            if (item.isCustom === true || item.category === "user") {
                                usr.push(item);
                            } else {
                                sys.push(item);
                            }
                        }
                        displayWidgetsRoot.userPresets = usr;
                        displayWidgetsRoot.systemPresets = sys;
                    }
                } catch(e) {
                }
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 350
        repeat: false
        onTriggered: displayWidgetsRoot.reloadAllWidgetFiles()
    }

    function applyWidgetPreset(monName, presetData) {
        if (!monName || !presetData) {
            return;
        }
        let widgetsList = presetData.widgets;
        if (!widgetsList) {
            return;
        }

        let len = widgetsList.length !== undefined ? widgetsList.length : 0;
        let safeM = (monName || "default").replace(/[^a-zA-Z0-9_-]/g, "_");
        let screenDims = displayWidgetsRoot.getScreenDimensions(monName);
        let sw = screenDims.w > 0 ? screenDims.w : 1920;
        let sh = screenDims.h > 0 ? screenDims.h : 1080;
        let formattedList = [];

        for (let i = 0; i < len; i++) {
            let w = widgetsList[i];
            let type = w.type || w.wType || "time";
            let defSize = (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultSize === "function")
                ? WidgetRegistry.defaultSize(type)
                : { w: 250, h: 120 };
            let defVariant = (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultVariant === "function")
                ? WidgetRegistry.defaultVariant(type)
                : "default";

            let isStretchW = !!(w.stretchWidth || w.wStretchWidth);
            let isStretchH = !!(w.stretchHeight || w.wStretchHeight);

            let rawW = w.w !== undefined ? w.w : (w.width !== undefined ? w.width : (w.wWidth !== undefined ? w.wWidth : defSize.w));
            let rawH = w.h !== undefined ? w.h : (w.height !== undefined ? w.height : (w.wHeight !== undefined ? w.wHeight : defSize.h));
            let resW = isStretchW ? sw : displayWidgetsRoot.resolveDimension(rawW, sw, defSize.w);
            let resH = isStretchH ? sh : displayWidgetsRoot.resolveDimension(rawH, sh, defSize.h);

            let rawX = w.x !== undefined ? w.x : (w.wX !== undefined ? w.wX : 100);
            let rawY = w.y !== undefined ? w.y : (w.wY !== undefined ? w.wY : 100);

            let hasAnchor = !!(w.anchor || w.anchors || w.anchorH || w.anchorV || w.anchorX || w.anchorY || w.horizontalAnchor || w.verticalAnchor || w.hAnchor || w.vAnchor);
            let resPos = hasAnchor
                ? displayWidgetsRoot.resolvePosition(w, sw, sh, resW, resH)
                : { x: displayWidgetsRoot.resolveDimension(rawX, sw, 100), y: displayWidgetsRoot.resolveDimension(rawY, sh, 100) };

            if (isStretchW) resPos.x = 0;
            if (isStretchH) resPos.y = 0;

            formattedList.push({
                type: type,
                wType: type,
                wVariant: w.variant || w.wVariant || defVariant,
                anchor: "",
                wX: resPos.x,
                wY: resPos.y,
                wWidth: resW,
                wHeight: resH,
                stretchWidth: isStretchW,
                stretchHeight: isStretchH,
                wOpacity: w.opacity !== undefined ? w.opacity : (w.wOpacity !== undefined ? w.wOpacity : 1.0),
                wRotation: w.rotation !== undefined ? w.rotation : (w.wRotation !== undefined ? w.wRotation : 0),
                wImagePath: w.imagePath || w.wImagePath || "",
                imagePath: w.imagePath || w.wImagePath || "",
                wId: "w_" + Date.now() + "_" + i + "_" + Math.floor(Math.random() * 1000)
            });
        }

        let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
        m[monName] = formattedList;
        displayWidgetsRoot.monitorWidgetsMap = m;

        WidgetSync.applyPreset(safeM, formattedList, true);
    }

    function deleteWidget(monName, widgetId) {
        if (!widgetId) return;
        let safeM = (monName || "default").replace(/[^a-zA-Z0-9_-]/g, "_");
        let targetId = String(widgetId).trim();
        let curList = (displayWidgetsRoot.monitorWidgetsMap && displayWidgetsRoot.monitorWidgetsMap[monName]) ? displayWidgetsRoot.monitorWidgetsMap[monName] : [];
        let newList = [];
        for (let i = 0; i < curList.length; i++) {
            let item = curList[i];
            let id = String(item.wId || item.id || "").trim();
            if (id !== targetId) {
                newList.push(item);
            }
        }
        let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
        m[monName] = newList;
        displayWidgetsRoot.monitorWidgetsMap = m;

        WidgetSync.removeWidget(safeM, targetId);
    }

    function deleteCustomPreset(presetName) {
        if (!presetName) return;
        let userPath = Caching.stateDir ? (Caching.stateDir + "/widgets/presets") : (Caching.home + "/.local/state/serpantinum/widgets/presets");
        let sanitizeName = String(presetName).replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        let filePath = userPath + "/" + sanitizeName + ".json";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let cmd = "rm -f \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        displayWidgetsRoot.userPresets = displayWidgetsRoot.userPresets.filter(p => p.name !== presetName && p.id !== presetName && p.name !== sanitizeName && p.id !== sanitizeName);
        displayWidgetsRoot.availablePresets = displayWidgetsRoot.availablePresets.filter(p => p.name !== presetName && p.id !== presetName && p.name !== sanitizeName && p.id !== sanitizeName);
    }

    function saveCustomPreset(presetName, monName, widgetsList) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/widgets/presets") : (Caching.home + "/.local/state/serpantinum/widgets/presets");
        let sanitizeName = presetName.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        if (sanitizeName === "") sanitizeName = "CustomPreset";

        let cleanWidgets = [];
        let list = widgetsList || [];
        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            cleanWidgets.push({
                type: item.type || item.wType || "time",
                variant: item.variant || item.wVariant || "default",
                anchor: "",
                x: item.wX !== undefined ? item.wX : (item.x !== undefined ? item.x : 0),
                y: item.wY !== undefined ? item.wY : (item.y !== undefined ? item.y : 0),
                width: item.wWidth !== undefined ? item.wWidth : (item.width !== undefined ? item.width : (item.w !== undefined ? item.w : 250)),
                height: item.wHeight !== undefined ? item.wHeight : (item.height !== undefined ? item.height : (item.h !== undefined ? item.h : 120)),
                stretchWidth: !!(item.stretchWidth || item.wStretchWidth),
                stretchHeight: !!(item.stretchHeight || item.wStretchHeight),
                opacity: item.opacity !== undefined ? item.opacity : (item.wOpacity !== undefined ? item.wOpacity : 1.0),
                rotation: item.rotation !== undefined ? item.rotation : (item.wRotation !== undefined ? item.wRotation : 0),
                imagePath: item.imagePath || item.wImagePath || ""
            });
        }

        let presetObj = {
            id: sanitizeName.toLowerCase().replace(/ /g, "_"),
            name: sanitizeName,
            description: "",
            widgets: cleanWidgets,
            isCustom: true,
            category: "user"
        };

        let jsonStr = JSON.stringify(presetObj, null, 2);
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let filePath = userPath + "/" + sanitizeName + ".json";
        let cmd = "mkdir -p \"" + escapeBash(userPath) + "\" && echo \"" + escapeBash(jsonStr) + "\" > \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        let uArr = displayWidgetsRoot.userPresets.filter(p => p.name !== sanitizeName && p.id !== presetObj.id);
        uArr.push(presetObj);
        displayWidgetsRoot.userPresets = uArr;

        let arr = displayWidgetsRoot.availablePresets.filter(p => p.name !== sanitizeName && p.id !== presetObj.id);
        arr.push(presetObj);
        displayWidgetsRoot.availablePresets = arr;
    }

    Process {
        id: screenDetector
        running: false
        command: ["bash", "-c", "hyprctl monitors all -j 2>/dev/null || hyprctl monitors -j 2>/dev/null || niri msg -j outputs 2>/dev/null || swaymsg -t get_outputs -r 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text;
                if (!out) return;
                let list = [];
                try {
                    let data = JSON.parse(out.trim());
                    if (Array.isArray(data)) {
                        for (let i = 0; i < data.length; i++) {
                            let item = data[i];
                            let name = item.name || "";
                            if (name) list.push({ name: name });
                        }
                    } else if (typeof data === "object") {
                        let keys = Object.keys(data);
                        for (let i = 0; i < keys.length; i++) {
                            list.push({ name: keys[i] });
                        }
                    }
                } catch(e) {
                }

                if (list.length === 0 && Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        list.push({ name: Quickshell.screens[i].name });
                    }
                }
                displayWidgetsRoot.monitorsList = list;
                displayWidgetsRoot.reloadAllWidgetFiles();
            }
        }
    }

    function reloadAllWidgetFiles() {
        if (monitorsList.length === 0) {
            displayWidgetsRoot.monitorWidgetsMap = {};
            return;
        }
        let paths = [];
        for (let i = 0; i < monitorsList.length; i++) {
            let mName = monitorsList[i].name;
            let safeM = (mName || "default").replace(/[^a-zA-Z0-9_-]/g, "_");
            paths.push(Caching.getStateDir("widgets/" + safeM) + "/layout.json");
        }
        readWidgetsProcess.exec(paths);
    }

    Process {
        id: readWidgetsProcess
        property var monitorNames: []

        function exec(paths) {
            monitorNames = displayWidgetsRoot.monitorsList.map(m => m.name);

            let script = "";
            for (let i = 0; i < paths.length; i++) {
                script += "echo '___WSPLIT___'; cat '" + paths[i] + "' 2>/dev/null || echo '[]'; ";
            }

            command = ["bash", "-c", script];
            running = false;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text || "";
                let chunks = raw.split("___WSPLIT___");
                let m = {};
                for (let i = 0; i < readWidgetsProcess.monitorNames.length; i++) {
                    let mon = readWidgetsProcess.monitorNames[i];
                    let txt = (chunks[i + 1] || "[]").trim();
                    try {
                        let arr = JSON.parse(txt);
                        m[mon] = Array.isArray(arr) ? arr : [];
                    } catch (e) {
                        m[mon] = [];
                    }
                }
                displayWidgetsRoot.monitorWidgetsMap = m;
            }
        }
    }

    function openRedactor(mon) {
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/redactor.sh") : "redactor.sh";
        Quickshell.execDetached(["bash", scriptPath, mon || ""]);
        if (rootObj && typeof rootObj.closePopup === "function") {
            rootObj.closePopup();
        } else {
            Quickshell.execDetached(["bash", dir ? (dir + "/scripts/qs_manager.sh") : "qs_manager.sh", "close"]);
        }
    }

    Timer {
        id: screenDetectorDebounceTimer
        interval: 220
        repeat: false
        onTriggered: screenDetector.running = true
    }

    Component.onCompleted: {
        syncSettings();
        reloadPresets();
        if (visible) {
            screenDetectorDebounceTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            reloadPresets();
            screenDetectorDebounceTimer.restart();
        } else {
            screenDetectorDebounceTimer.stop();
            savePresetPopup.close();
        }
    }

    Connections {
        target: WidgetSync

        function onPresetApplied(monitor, widgetsList) {
            let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
            for (let mon in m) {
                let safe = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                if (safe === monitor || mon === monitor) {
                    m[mon] = widgetsList;
                }
            }
            displayWidgetsRoot.monitorWidgetsMap = m;
        }

        function onPositionChanged(monitor, widgetId, x, y) {
            let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
            let targetId = String(widgetId).trim();
            for (let mon in m) {
                let safe = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                if (safe === monitor || mon === monitor) {
                    m[mon] = m[mon].map(item => {
                        if (String(item.wId || item.id).trim() === targetId) {
                            let updated = Object.assign({}, item);
                            updated.wX = x;
                            updated.wY = y;
                            return updated;
                        }
                        return item;
                    });
                }
            }
            displayWidgetsRoot.monitorWidgetsMap = m;
        }

        function onGeometryChanged(monitor, widgetId, x, y, w, h, opacity, rotation) {
            let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
            let targetId = String(widgetId).trim();
            for (let mon in m) {
                let safe = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                if (safe === monitor || mon === monitor) {
                    m[mon] = m[mon].map(item => {
                        if (String(item.wId || item.id).trim() === targetId) {
                            let updated = Object.assign({}, item);
                            updated.wX = x;
                            updated.wY = y;
                            updated.wWidth = w;
                            updated.wHeight = h;
                            if (opacity !== undefined) updated.wOpacity = opacity;
                            if (rotation !== undefined && !isNaN(rotation)) updated.wRotation = rotation;
                            return updated;
                        }
                        return item;
                    });
                }
            }
            displayWidgetsRoot.monitorWidgetsMap = m;
        }

        function onWidgetRemoved(monitor, widgetId) {
            let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
            let targetId = String(widgetId).trim();
            for (let mon in m) {
                let safe = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                if (safe === monitor || mon === monitor) {
                    m[mon] = m[mon].filter(item => String(item.wId || item.id).trim() !== targetId);
                }
            }
            displayWidgetsRoot.monitorWidgetsMap = m;
        }

        function onWidgetsCleared(monitor) {
            let m = Object.assign({}, displayWidgetsRoot.monitorWidgetsMap);
            for (let mon in m) {
                let safe = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                if (safe === monitor || mon === monitor) {
                    m[mon] = [];
                }
            }
            displayWidgetsRoot.monitorWidgetsMap = m;
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            displayWidgetsRoot.syncSettings();
        }
    }

    Connections {
        target: typeof Wallpaper !== "undefined" ? Wallpaper : null
        function onWallpaperChanged(screenName, path, transition) {
            displayWidgetsRoot.wallpaperRevision++;
        }
        function onWallpaperCleared(screenName) {
            displayWidgetsRoot.wallpaperRevision++;
        }
    }

    Connections {
        target: rootObj
        function onVisibleChanged() {
            if (rootObj && rootObj.visible && displayWidgetsRoot.visible) {
                screenDetector.running = true;
            }
        }
    }

    SavePresetPopup {
        id: savePresetPopup
        rootObj: displayWidgetsRoot.rootObj
        onSaveRequested: function(presetName, monName, widgetsList) {
            displayWidgetsRoot.saveCustomPreset(presetName, monName, widgetsList);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: widgetsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: widgetsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_hide_bar"
                icon: "󰘓"
                title: I18n.t("guide.display.widgets.hide_bar.title", "Hide Bar in Redactor")
                description: I18n.t("guide.display.widgets.hide_bar.desc", "Automatically hide the bar when editing widgets in redactor mode")
                searchKeywords: "widgets redactor hide bar panel"

                Toggle {
                    id: hideBarToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayWidgetsRoot.currentHideBarInRedactor
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        displayWidgetsRoot.currentHideBarInRedactor = val;
                        displayWidgetsRoot.updateWidgetsSetting("hideBarInRedactor", val);
                    }
                }
            }

            Repeater {
                model: displayWidgetsRoot.monitorsList
                delegate: Rectangle {
                    id: monWidgetCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    clip: true
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                    border.width: 1

                    property string monName: modelData.name
                    property var widgetsList: (displayWidgetsRoot.monitorWidgetsMap && displayWidgetsRoot.monitorWidgetsMap[monName]) ? displayWidgetsRoot.monitorWidgetsMap[monName] : []
                    property bool showPresets: false

                    implicitHeight: cardLayout.implicitHeight + rootObj.s(12)
                    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        SettingsRow {
                            id: monHeaderRow
                            rootObj: displayWidgetsRoot.rootObj
                            settingId: "widgets_screen_" + monWidgetCard.monName.toLowerCase().replace(/[^a-z0-9_]/g, "_")
                            icon: "󰍹"
                            title: monWidgetCard.monName
                            description: I18n.t("guide.display.widgets.screen_desc", "Configure and edit desktop widgets")
                            searchKeywords: "widgets redactor edit layout preset presets monitor screen " + monWidgetCard.monName.toLowerCase()
                            baseColor: "transparent"
                            hoverColor: "transparent"
                            borderWidth: 0
                            color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.18) : "transparent"

                            titleBadge: Component {
                                Text {
                                    text: "(" + monWidgetCard.widgetsList.length + " " + (monWidgetCard.widgetsList.length === 1 ? I18n.t("widgets.redactor.widget_singular", "widget") : I18n.t("widgets.redactor.widgets_plural", "widgets")) + ")"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    color: ThemeBackend.subtext0
                                }
                            }

                            IconButton {
                                size: rootObj.s(32)
                                Layout.preferredWidth: rootObj.s(32)
                                Layout.preferredHeight: rootObj.s(32)
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰐕"
                                iconFontSize: rootObj.s(16)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: {
                                    savePresetPopup.openForMonitor(monWidgetCard.monName, monWidgetCard.widgetsList);
                                }
                            }

                            ClickButton {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                maxWidth: rootObj.s(200)
                                implicitHeight: rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: monWidgetCard.showPresets ? I18n.t("guide.display.widgets.hide_presets", "Hide Presets") : I18n.t("guide.display.widgets.choose_preset", "Choose a preset")
                                buttonIcon: "󰄛"
                                iconFontSize: rootObj.s(14)
                                textFontSize: rootObj.s(12)
                                accentColor: monWidgetCard.showPresets ? ThemeBackend.surface2 : ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: {
                                    if (typeof Sounds !== "undefined") {
                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                    }
                                    monWidgetCard.showPresets = !monWidgetCard.showPresets;
                                }
                            }

                            ClickButton {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                maxWidth: rootObj.s(140)
                                implicitHeight: rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: I18n.t("guide.display.widgets.open", "Open Redactor")
                                buttonIcon: "󰕰"
                                iconFontSize: rootObj.s(14)
                                textFontSize: rootObj.s(12)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.crust
                                onClicked: {
                                    displayWidgetsRoot.openRedactor(monWidgetCard.monName);
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        }

                        Loader {
                            id: presetsSectionLoader
                            Layout.fillWidth: true
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            active: monWidgetCard.showPresets && displayWidgetsRoot.visible
                            visible: active

                            sourceComponent: Component {
                                Column {
                                    id: presetsContainerCol
                                    width: Math.max(0, cardLayout.width - rootObj.s(24))
                                    spacing: rootObj.s(10)

                                    readonly property real containerWidth: Math.max(0, width)
                                    readonly property int gridColumns: Math.max(3, Math.floor(containerWidth / rootObj.s(180)))
                                    readonly property real gridColumnSpacing: rootObj.s(8)
                                    readonly property real gridRowSpacing: rootObj.s(8)
                                    readonly property real presetTileWidth: gridColumns > 0 ? Math.max(0, (containerWidth - gridColumnSpacing * (gridColumns - 1)) / gridColumns) : 0

                                    Component {
                                        id: presetCardComp

                                        Rectangle {
                                            id: presetCard
                                            required property var modelData
                                            required property int index

                                            property color accentColor: ThemeBackend.surface0
                                            property real popScale: 1.0
                                            property real flashOpacity: 0.0

                                            width: presetsContainerCol.presetTileWidth
                                            height: presetPreviewBox.height + rootObj.s(28)
                                            radius: ThemeBackend.borderRadius
                                            clip: true

                                            color: presetMouse.pressed ? Qt.darker(presetCard.accentColor, 1.28) : (presetHover.hovered ? Qt.darker(presetCard.accentColor, 1.14) : presetCard.accentColor)
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                            Behavior on opacity { NumberAnimation { duration: 180 } }

                                            scale: (presetMouse.pressed ? 0.985 : (presetHover.hovered ? 1.015 : 1.0)) * presetCard.popScale
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                            HoverHandler {
                                                id: presetHover
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: ThemeBackend.borderRadius
                                                color: "#ffffff"
                                                opacity: presetCard.flashOpacity
                                                PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
                                            }

                                            SequentialAnimation {
                                                id: popAnim
                                                NumberAnimation { target: presetCard; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
                                                NumberAnimation { target: presetCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
                                            }

                                            MouseArea {
                                                id: presetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    popAnim.start();
                                                    presetCard.flashOpacity = 0.15;
                                                    flashAnim.start();
                                                    if (typeof Sounds !== "undefined") {
                                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                                    }
                                                    displayWidgetsRoot.applyWidgetPreset(monWidgetCard.monName, presetCard.modelData);
                                                }
                                            }

                                            Rectangle {
                                                id: presetPreviewBox
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top

                                                property var screenDims: displayWidgetsRoot.getScreenDimensions(monWidgetCard.monName)
                                                property real sWidth: screenDims.w > 0 ? screenDims.w : 1920
                                                property real sHeight: screenDims.h > 0 ? screenDims.h : 1080
                                                property real sAspect: (sWidth > 0 && sHeight > 0) ? (sWidth / sHeight) : (16 / 9)

                                                height: Math.round(width / sAspect)
                                                color: Qt.darker(presetCard.accentColor, 1.15)
                                                clip: true

                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: previewMask
                                                }

                                                Item {
                                                    id: previewMask
                                                    anchors.fill: parent
                                                    visible: false
                                                    layer.enabled: true

                                                    Rectangle {
                                                        width: parent.width
                                                        height: parent.height + ThemeBackend.borderRadius * 2
                                                        radius: ThemeBackend.borderRadius
                                                        color: "white"
                                                    }
                                                }

                                                Item {
                                                    id: virtualScreenWrapper
                                                    anchors.fill: parent
                                                    clip: true

                                                    Item {
                                                        id: virtualScreen
                                                        width: presetPreviewBox.sWidth
                                                        height: presetPreviewBox.sHeight
                                                        transformOrigin: Item.TopLeft
                                                        scale: presetPreviewBox.width / presetPreviewBox.sWidth
                                                        enabled: false

                                                        Image {
                                                            id: presetWpImg
                                                            anchors.fill: parent
                                                            source: displayWidgetsRoot.getWallpaperSource(monWidgetCard.monName)
                                                            fillMode: Image.PreserveAspectCrop
                                                            smooth: true
                                                            cache: true
                                                            asynchronous: false
                                                            onStatusChanged: {
                                                                if (status === Image.Error) {
                                                                    let snap = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                                                                    if (source.toString() !== snap) {
                                                                        source = snap;
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "#000000"
                                                            opacity: 0.25
                                                        }

                                                        Item {
                                                            id: presetWidgetsLayer
                                                            anchors.fill: parent

                                                            Repeater {
                                                                model: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets : []
                                                                delegate: Item {
                                                                    id: miniWidgetContainer
                                                                    required property var modelData
                                                                    required property int index

                                                                    readonly property string typeStr: modelData.type || modelData.wType || "time"
                                                                    readonly property var defSize: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultSize === "function")
                                                                        ? WidgetRegistry.defaultSize(typeStr)
                                                                        : ({ w: 250, h: 120 })

                                                                    readonly property string defVariant: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultVariant === "function")
                                                                        ? WidgetRegistry.defaultVariant(typeStr)
                                                                        : "default"

                                                                    readonly property string variantStr: modelData.variant || modelData.wVariant || miniWidgetContainer.defVariant

                                                                    readonly property bool isStretchW: !!(modelData.stretchWidth || modelData.wStretchWidth)
                                                                    readonly property bool isStretchH: !!(modelData.stretchHeight || modelData.wStretchHeight)

                                                                    readonly property real rawW: modelData.w !== undefined ? modelData.w : (modelData.width !== undefined ? modelData.width : (modelData.wWidth !== undefined ? modelData.wWidth : defSize.w))
                                                                    readonly property real rawH: modelData.h !== undefined ? modelData.h : (modelData.height !== undefined ? modelData.height : (modelData.wHeight !== undefined ? modelData.wHeight : defSize.h))

                                                                    readonly property real resolvedW: isStretchW ? presetPreviewBox.sWidth : displayWidgetsRoot.resolveDimension(rawW, presetPreviewBox.sWidth, defSize.w)
                                                                    readonly property real resolvedH: isStretchH ? presetPreviewBox.sHeight : displayWidgetsRoot.resolveDimension(rawH, presetPreviewBox.sHeight, defSize.h)

                                                                    readonly property var resolvedPos: displayWidgetsRoot.resolvePosition(modelData, presetPreviewBox.sWidth, presetPreviewBox.sHeight, resolvedW, resolvedH)

                                                                    x: isStretchW ? 0 : resolvedPos.x
                                                                    y: isStretchH ? 0 : resolvedPos.y
                                                                    width: resolvedW
                                                                    height: resolvedH
                                                                    opacity: modelData.opacity !== undefined ? modelData.opacity : 1.0
                                                                    rotation: modelData.rotation !== undefined ? modelData.rotation : 0

                                                                    Loader {
                                                                        id: widgetFaceLoader
                                                                        anchors.fill: parent
                                                                        asynchronous: false
                                                                        source: displayWidgetsRoot.getFaceUrl(miniWidgetContainer.typeStr, miniWidgetContainer.variantStr)

                                                                        onLoaded: {
                                                                            if (item) {
                                                                                if ("variant" in item) item.variant = miniWidgetContainer.variantStr;
                                                                                if ("wVariant" in item) item.wVariant = miniWidgetContainer.variantStr;
                                                                                if ("type" in item) item.type = miniWidgetContainer.typeStr;
                                                                                if ("wType" in item) item.wType = miniWidgetContainer.typeStr;
                                                                                if ("wWidth" in item) item.wWidth = miniWidgetContainer.width;
                                                                                if ("wHeight" in item) item.wHeight = miniWidgetContainer.height;
                                                                                if ("imagePath" in item) item.imagePath = modelData.imagePath || modelData.wImagePath || "";
                                                                                if ("wImagePath" in item) item.wImagePath = modelData.imagePath || modelData.wImagePath || "";
                                                                                if ("previewMode" in item) item.previewMode = true;
                                                                                if ("screen" in item) item.screen = displayWidgetsRoot.getScreen(monWidgetCard.monName);
                                                                            }
                                                                        }
                                                                    }

                                                                    Rectangle {
                                                                        anchors.fill: parent
                                                                        visible: widgetFaceLoader.status === Loader.Error
                                                                        radius: ThemeBackend.borderRadius
                                                                        color: Qt.alpha(ThemeBackend.surface0, 0.72)
                                                                        border.width: 1
                                                                        border.color: Qt.alpha(ThemeBackend.mauve, 0.65)

                                                                        readonly property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[miniWidgetContainer.typeStr]) ? WidgetRegistry.types[miniWidgetContainer.typeStr] : null

                                                                        Text {
                                                                            anchors.centerIn: parent
                                                                            text: (parent.typeInfo && parent.typeInfo.icon) ? parent.typeInfo.icon : "󰕰"
                                                                            font.family: ThemeBackend.fontFamily
                                                                            font.pixelSize: Math.max(12, Math.min(parent.width * 0.4, parent.height * 0.45))
                                                                            color: ThemeBackend.mauve
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: "transparent"
                                                    border.width: 1
                                                    border.color: Qt.alpha(ThemeBackend.surface2, 0.3)
                                                }
                                            }

                                            Item {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.top: presetPreviewBox.bottom

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: rootObj.s(8)
                                                    anchors.rightMargin: rootObj.s(8)
                                                    spacing: rootObj.s(4)

                                                    Text {
                                                        property int widgetCount: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets.length : 0
                                                        property string rawName: (presetCard.modelData && presetCard.modelData.name) ? presetCard.modelData.name : ((presetCard.modelData && presetCard.modelData.id) ? presetCard.modelData.id : "")
                                                        text: (rawName ? I18n.t(rawName, rawName) : "") + " (" + widgetCount + ")"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(12)
                                                        font.bold: true
                                                        color: ThemeBackend.text
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    DeleteButton {
                                                        visible: presetCard.modelData.isCustom === true || presetCard.modelData.category === "user"
                                                        size: rootObj.s(22)
                                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                                                        iconFontSize: rootObj.s(11)
                                                        Layout.alignment: Qt.AlignVCenter
                                                        onClicked: {
                                                            displayWidgetsRoot.deleteCustomPreset(presetCard.modelData.name || presetCard.modelData.id);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Grid {
                                        id: userPresetsGrid
                                        width: parent.width
                                        columns: presetsContainerCol.gridColumns
                                        rowSpacing: presetsContainerCol.gridRowSpacing
                                        columnSpacing: presetsContainerCol.gridColumnSpacing
                                        visible: displayWidgetsRoot.userPresets.length > 0

                                        Repeater {
                                            model: displayWidgetsRoot.userPresets
                                            delegate: presetCardComp
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                        visible: displayWidgetsRoot.userPresets.length > 0 && displayWidgetsRoot.systemPresets.length > 0
                                    }

                                    Grid {
                                        id: systemPresetsGrid
                                        width: parent.width
                                        columns: presetsContainerCol.gridColumns
                                        rowSpacing: presetsContainerCol.gridRowSpacing
                                        columnSpacing: presetsContainerCol.gridColumnSpacing
                                        visible: displayWidgetsRoot.systemPresets.length > 0

                                        Repeater {
                                            model: displayWidgetsRoot.systemPresets
                                            delegate: presetCardComp
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                    }
                                }
                            }
                        }

                        Grid {
                            id: widgetsGrid
                            Layout.fillWidth: true
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            Layout.bottomMargin: rootObj.s(12)
                            columns: 3
                            rowSpacing: rootObj.s(8)
                            columnSpacing: rootObj.s(8)
                            visible: monWidgetCard.widgetsList.length > 0

                            readonly property real colWidth: Math.max(0, ((cardLayout.width - rootObj.s(24)) - columnSpacing * 2) / 3)

                            Repeater {
                                model: monWidgetCard.widgetsList
                                delegate: Rectangle {
                                    id: widgetItemCard
                                    required property var modelData
                                    required property int index

                                    width: widgetsGrid.colWidth
                                    height: rootObj.s(48)
                                    radius: ThemeBackend.borderRadius
                                    color: Qt.alpha(ThemeBackend.surface1, 0.3)
                                    border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                    border.width: 1

                                    property string wType: modelData.wType || modelData.type || "time"
                                    property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[wType]) ? WidgetRegistry.types[wType] : null

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: rootObj.s(8)
                                        anchors.rightMargin: rootObj.s(8)
                                        spacing: rootObj.s(8)

                                        IconButton {
                                            size: rootObj.s(32)
                                            iconOffsetX: (widgetItemCard.typeInfo && widgetItemCard.typeInfo.iconOffsetX !== undefined) ? rootObj.s(widgetItemCard.typeInfo.iconOffsetX) : 0
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: (widgetItemCard.typeInfo && widgetItemCard.typeInfo.icon) ? widgetItemCard.typeInfo.icon : "󰕰"
                                            iconFontSize: rootObj.s(16)
                                            accentColor: ThemeBackend.surface1
                                            textColor: ThemeBackend.mauve
                                            Layout.alignment: Qt.AlignVCenter
                                            enabled: false
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: rootObj.s(1)

                                            Text {
                                                text: widgetItemCard.typeInfo && widgetItemCard.typeInfo.name ? widgetItemCard.typeInfo.name : widgetItemCard.wType
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(12)
                                                font.bold: true
                                                color: ThemeBackend.text
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: (widgetItemCard.modelData.wVariant || "default") + " • " + Math.round(widgetItemCard.modelData.wWidth || 0) + "x" + Math.round(widgetItemCard.modelData.wHeight || 0) + " @ (" + Math.round(widgetItemCard.modelData.wX || 0) + ", " + Math.round(widgetItemCard.modelData.wY || 0) + ")"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(10)
                                                color: ThemeBackend.subtext0
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        DeleteButton {
                                            size: rootObj.s(28)
                                            cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                            iconFontSize: rootObj.s(14)
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                let wId = widgetItemCard.modelData.wId || widgetItemCard.modelData.id;
                                                displayWidgetsRoot.deleteWidget(monWidgetCard.monName, wId);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rootObj.s(40)
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            Layout.bottomMargin: rootObj.s(12)
                            visible: !monWidgetCard.showPresets && monWidgetCard.widgetsList.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("widgets.redactor.no_widgets_active", "No widgets configured for this screen")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }
        }
    }
}
