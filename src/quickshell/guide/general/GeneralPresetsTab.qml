import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../widgets"
import "../display"

GuideTab {
    id: presetsTabRoot
    subTabIndex: 1

    property var presets: []

    readonly property string presetsDir: Caching.stateDir + "/presets"
    readonly property string widgetsDir: Caching.stateDir + "/widgets"

    readonly property string presetsScript:
        "import os, sys, json, glob\n" +
        "mode, presets_d, widgets_d = sys.argv[1], sys.argv[2], sys.argv[3]\n" +
        "def read_widgets():\n" +
        "    res = {}\n" +
        "    for f in glob.glob(os.path.join(widgets_d, '*', 'layout.json')):\n" +
        "        try:\n" +
        "            with open(f, encoding='utf-8') as fp:\n" +
        "                data = json.load(fp)\n" +
        "            if isinstance(data, list):\n" +
        "                res[os.path.basename(os.path.dirname(f))] = data\n" +
        "        except Exception:\n" +
        "            pass\n" +
        "    return res\n" +
        "def snapshot_files(path):\n" +
        "    try:\n" +
        "        with open(path, encoding='utf-8') as fp:\n" +
        "            snap = json.load(fp).get('snapshot') or {}\n" +
        "    except Exception:\n" +
        "        return set()\n" +
        "    layers = [snap.get('bar'), snap.get('dock'), snap.get('widgets')]\n" +
        "    return {os.path.basename(l['file']) for l in layers if isinstance(l, dict) and l.get('file')}\n" +
        "def remove_files(names):\n" +
        "    for name in names:\n" +
        "        try:\n" +
        "            os.remove(os.path.join(presets_d, name))\n" +
        "        except FileNotFoundError:\n" +
        "            pass\n" +
        "def write(target, obj):\n" +
        "    os.makedirs(presets_d, exist_ok=True)\n" +
        "    tmp = target + '.tmp'\n" +
        "    with open(tmp, 'w', encoding='utf-8') as fp:\n" +
        "        json.dump(obj, fp, indent=2, ensure_ascii=False)\n" +
        "        fp.write('\\n')\n" +
        "    os.replace(tmp, target)\n" +
        "if mode == 'save':\n" +
        "    payload = json.loads(sys.argv[5])\n" +
        "    payload['widgets'] = read_widgets()\n" +
        "    old_files = snapshot_files(sys.argv[4])\n" +
        "    write(sys.argv[4], payload)\n" +
        "    remove_files(old_files - snapshot_files(sys.argv[4]))\n" +
        "elif mode == 'widgets':\n" +
        "    with open(sys.argv[4], encoding='utf-8') as fp:\n" +
        "        obj = json.load(fp)\n" +
        "    if isinstance(obj.get('snapshot'), dict):\n" +
        "        obj['snapshot']['widgets'] = json.loads(sys.argv[5])\n" +
        "        write(sys.argv[4], obj)\n" +
        "    sys.exit(0)\n" +
        "elif mode == 'delete':\n" +
        "    remove_files(snapshot_files(sys.argv[4]))\n" +
        "    try:\n" +
        "        os.remove(sys.argv[4])\n" +
        "    except FileNotFoundError:\n" +
        "        pass\n" +
        "presets = []\n" +
        "for f in glob.glob(os.path.join(presets_d, '*.json')):\n" +
        "    try:\n" +
        "        with open(f, encoding='utf-8') as fp:\n" +
        "            obj = json.load(fp)\n" +
        "        if isinstance(obj, dict) and isinstance(obj.get('settings'), dict):\n" +
        "            obj['id'] = os.path.splitext(os.path.basename(f))[0]\n" +
        "            presets.append(obj)\n" +
        "    except Exception:\n" +
        "        pass\n" +
        "presets.sort(key=lambda p: p.get('created', 0))\n" +
        "print(json.dumps(presets))\n"

    property var pendingRuns: []

    function runPresets(args) {
        if (presetsProc.running) {
            pendingRuns = pendingRuns.concat([args]);
            return;
        }
        presetsProc.command = ["python3", "-c", presetsScript].concat(args);
        presetsProc.running = true;
    }

    function reloadPresets() {
        runPresets(["list", presetsDir, widgetsDir]);
    }

    function presetPath(id) {
        return presetsDir + "/" + id + ".json";
    }

    function presetIdFor(name) {
        let lower = name.toLowerCase();
        for (let i = 0; i < presets.length; i++) {
            if (String(presets[i].name || "").toLowerCase() === lower) return presets[i].id;
        }
        let id = lower.replace(/[^a-z0-9_\- ]/g, "").trim().replace(/ +/g, "_");
        if (id === "" || presets.some(p => p.id === id)) id = "preset_" + Date.now();
        return id;
    }

    readonly property var paletteKeys: ["base", "mantle", "crust", "surface0", "surface1", "surface2", "overlay0", "overlay1", "overlay2", "_text", "_subtext0", "_subtext1", "blue", "sapphire", "teal", "green", "yellow", "peach", "maroon", "red", "pink", "mauve"]

    function currentPalette() {
        let palette = {};
        for (let i = 0; i < paletteKeys.length; i++) {
            let key = paletteKeys[i];
            palette[key.replace(/^_/, "")] = String(ThemeBackend[key]);
        }
        return palette;
    }

    function surfaceRect(win, screenWidth, screenHeight) {
        let a = win.anchors;
        let m = win.margins;
        let w = win.width;
        let h = win.height;
        return {
            x: a.left ? m.left : (a.right ? screenWidth - w - m.right : (screenWidth - w) / 2),
            y: a.top ? m.top : (a.bottom ? screenHeight - h - m.bottom : (screenHeight - h) / 2),
            w: w,
            h: h
        };
    }

    function captureSurfaces(id, onDone) {
        let screen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        if (!screen) {
            onDone(null);
            return;
        }
        let snapshot = { screen: screen.name, width: screen.width, height: screen.height };
        let surfaces = [
            { key: "bar", win: ShellSurfaces.bars[screen.name] },
            { key: "dock", win: ShellSurfaces.docks[screen.name] }
        ];
        let pending = 1;
        let finish = function() {
            pending--;
            if (pending === 0) onDone(snapshot);
        };
        surfaces.forEach(function(surface) {
            let win = surface.win;
            if (!win || !win.visible || !win.snapshotItem || win.width <= 0 || win.height <= 0) return;
            let file = id + "_" + surface.key + ".png";
            let target = presetsTabRoot.presetsDir + "/" + file;
            let started = win.snapshotItem.grabToImage(function(result) {
                result.saveToFile(target);
                finish();
            });
            if (!started) return;
            pending++;
            snapshot[surface.key] = Object.assign({ file: file }, presetsTabRoot.surfaceRect(win, screen.width, screen.height));
        });

        finish();
    }

    function getScreen(monName) {
        let target = String(monName || "").toLowerCase();
        for (let i = 0; i < Quickshell.screens.length; i++) {
            let scr = Quickshell.screens[i];
            let name = String(scr.name).toLowerCase();
            if (name === target || name.replace(/[^a-zA-Z0-9_-]/g, "_") === target) return scr;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function resolveDimension(val, screenDim, defVal) {
        return WidgetRegistry.resolveDimension(val, screenDim, defVal);
    }

    function resolvePosition(cfg, sw, sh, w, h) {
        return WidgetRegistry.resolvePosition(cfg, sw, sh, w, h);
    }

    function getFaceUrl(type, variant) {
        return WidgetRegistry.faceFile(type, variant || "");
    }

    property var widgetCaptureQueue: []
    property var capturedWidgets: ({})

    function startWidgetCapture() {
        if (widgetStage.preset) return;
        while (widgetCaptureQueue.length > 0) {
            let id = widgetCaptureQueue[0];
            widgetCaptureQueue = widgetCaptureQueue.slice(1);
            let preset = presets.find(p => p.id === id);
            let snapshot = preset ? preset.snapshot : null;
            let list = (snapshot && preset.widgets) ? preset.widgets[snapshot.screen.replace(/[^a-zA-Z0-9_-]/g, "_")] : null;
            if (list && list.length > 0) {
                widgetStage.preset = preset;
                widgetStage.widgets = list;
                widgetStage.waited = 0;
                widgetStage.settled = 0;
                widgetStageTimer.restart();
                return;
            }
        }
    }

    Item {
        id: widgetStage
        property var preset: null
        property var widgets: []
        property int waited: 0
        property int settled: 0
        x: -width - 100
        width: preset ? preset.snapshot.width : 0
        height: preset ? preset.snapshot.height : 0

        Repeater {
            id: widgetStageRepeater
            model: widgetStage.widgets
            delegate: WidgetPresetMiniWidget {
                tab: presetsTabRoot
                monName: widgetStage.preset ? widgetStage.preset.snapshot.screen : ""
                previewWidth: widgetStage.width
                previewHeight: widgetStage.height
            }
        }

        function finish() {
            preset = null;
            widgets = [];
            Qt.callLater(presetsTabRoot.startWidgetCapture);
        }
    }

    Timer {
        id: widgetStageTimer
        interval: 50
        repeat: true
        onTriggered: {
            widgetStage.waited += interval;
            let ready = widgetStageRepeater.count === widgetStage.widgets.length;
            for (let i = 0; ready && i < widgetStageRepeater.count; i++) {
                let face = widgetStageRepeater.itemAt(i).children[0];
                if (face.status === Loader.Loading || face.status === Loader.Null) ready = false;
            }
            if (ready) widgetStage.settled += interval;
            if (widgetStage.settled < 300 && widgetStage.waited < 3000) return;
            stop();
            let id = widgetStage.preset.id;
            let file = id + "_widgets.png";
            let layer = { file: file, x: 0, y: 0, w: widgetStage.width, h: widgetStage.height };
            let started = widgetStage.grabToImage(function(result) {
                if (result.saveToFile(presetsTabRoot.presetsDir + "/" + file)) {
                    let captured = Object.assign({}, presetsTabRoot.capturedWidgets);
                    captured[id] = layer;
                    presetsTabRoot.capturedWidgets = captured;
                    presetsTabRoot.runPresets(["widgets", presetsTabRoot.presetsDir, presetsTabRoot.widgetsDir, presetsTabRoot.presetPath(id), JSON.stringify(layer)]);
                }
                widgetStage.finish();
            });
            if (!started) widgetStage.finish();
        }
    }

    function savePreset(name) {
        let id = presetIdFor(name);
        let payload = {
            name: name,
            created: Date.now(),
            palette: currentPalette(),
            settings: JSON.parse(JSON.stringify(Config.rawSettings || {})),
            wallpapers: Object.assign({}, Wallpaper.screenWallpaperPaths)
        };
        if (capturedWidgets[id]) {
            let captured = Object.assign({}, capturedWidgets);
            delete captured[id];
            capturedWidgets = captured;
        }
        captureSurfaces(id, function(snapshot) {
            payload.snapshot = snapshot;
            if (snapshot) widgetCaptureQueue = widgetCaptureQueue.concat([id]);
            presetsTabRoot.runPresets(["save", presetsTabRoot.presetsDir, presetsTabRoot.widgetsDir, presetsTabRoot.presetPath(id), JSON.stringify(payload)]);
        });
    }

    function deletePreset(preset) {
        if (!preset || !preset.id) return;
        presets = presets.filter(p => p.id !== preset.id);
        runPresets(["delete", presetsDir, widgetsDir, presetPath(preset.id)]);
    }

    property bool skipConfirm: false
    readonly property string skipConfirmPath: Caching.stateDir + "/guide/skip_preset_confirm"

    FileView {
        path: presetsTabRoot.skipConfirmPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: presetsTabRoot.skipConfirm = text().trim() === "1"
    }

    function requestApply(preset) {
        if (skipConfirm) {
            applyPreset(preset);
        } else {
            confirmPopup.openFor(preset);
        }
    }

    function desktopEntryExists(id) {
        id = String(id || "");
        return id !== "" && !!(DesktopEntries.byId(id) || DesktopEntries.byId(id.replace(/\.desktop$/, "")));
    }

    function withInstalledDockApps(settings) {
        let entries = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        if (!settings.dock || !Array.isArray(settings.dock.apps) || !entries || entries.length === 0) return settings;
        let result = JSON.parse(JSON.stringify(settings));
        result.dock.apps = result.dock.apps.filter(app => app && desktopEntryExists(app.desktop_id || app.id));
        return result;
    }

    function applyPreset(preset) {
        preset = presets.find(p => preset && p.id === preset.id) || preset;
        if (!preset || !preset.settings) return;
        Config.replaceSettings(withInstalledDockApps(preset.settings));

        let widgets = preset.widgets || {};
        for (let mon in widgets) {
            let list = (Array.isArray(widgets[mon]) ? widgets[mon] : []).map((w, i) => Object.assign({}, w, {
                wId: "w_" + Date.now() + "_" + i + "_" + Math.floor(Math.random() * 1000)
            }));
            Quickshell.execDetached(["bash", "-c",
                "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/layout.json\"",
                "_", Caching.getStateDir("widgets/" + mon), JSON.stringify(list)]);
            if (list.length > 0) {
                WidgetSync.applyPreset(mon, list, true);
            } else {
                WidgetSync.clearWidgets(mon);
            }
        }

        let walls = preset.wallpapers || {};
        for (let scr in walls) {
            let path = walls[scr];
            if (path && Wallpaper.getWallpaperPath(scr) !== path) {
                Wallpaper.setWallpaper(scr, path, "fade");
            }
        }
    }

    Process {
        id: presetsProc
        running: false
        onExited: {
            if (presetsTabRoot.pendingRuns.length === 0) return;
            let next = presetsTabRoot.pendingRuns[0];
            presetsTabRoot.pendingRuns = presetsTabRoot.pendingRuns.slice(1);
            Qt.callLater(() => presetsTabRoot.runPresets(next));
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (!out) return;
                try {
                    let res = JSON.parse(out);
                    presetsTabRoot.presets = Array.isArray(res) ? res : [];
                } catch (e) {}
                presetsTabRoot.startWidgetCapture();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            reloadPresets();
        } else {
            savePresetPopup.close();
            confirmPopup.close();
        }
    }

    ApplyPresetConfirmPopup {
        id: confirmPopup
        rootObj: presetsTabRoot.rootObj
        onConfirmed: function(preset, dontShowAgain) {
            if (dontShowAgain) {
                presetsTabRoot.skipConfirm = true;
                Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '1\\n' > \"$1\"", "_", presetsTabRoot.skipConfirmPath]);
            }
            presetsTabRoot.applyPreset(preset);
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", presetsDir]);
        reloadPresets();
    }

    SaveSettingsPresetPopup {
        id: savePresetPopup
        rootObj: presetsTabRoot.rootObj
        onSaveRequested: function(presetName) {
            presetsTabRoot.savePreset(presetName);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: presetsTabRoot.rootObj
                settingId: "presets_save"
                icon: "󰆓"
                title: I18n.t("guide.general.presets.save.title", "Save current setup")
                description: I18n.t("guide.general.presets.save.desc", "Save all settings, widgets and wallpapers as a preset")
                searchKeywords: "presets preset save snapshot profile settings widgets theme wallpaper"

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.presets.save.button", "Save preset")
                    buttonIcon: "󰐕"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        presetsTabRoot.reloadPresets();
                        savePresetPopup.openPopup();
                    }
                }
            }

            SettingsRow {
                rootObj: presetsTabRoot.rootObj
                settingId: "copy_settings"
                icon: "󰆏"
                title: I18n.t("guide.general.copysettings.title", "Copy settings")
                description: I18n.t("guide.general.copysettings.desc", "Copy configuration JSON to clipboard")
                searchKeywords: "copy export settings json clipboard"

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.copysettings.title", "Copy settings")
                    buttonIcon: "󰆏"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-c", "wl-copy < \"$1\"", "_", Config.settingsJsonPath]);
                    }
                }
            }

            Rectangle {
                id: presetsCard
                Layout.fillWidth: true
                implicitHeight: presetsCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: presetsCardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

                GlassFill {
                    id: presetsCardGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                    tintAmount: 0.25
                }

                Column {
                    id: presetsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)

                    readonly property int gridColumns: Math.min(2, Math.max(1, Math.floor(width / rootObj.s(260))))
                    readonly property real tileWidth: Math.max(0, (width - rootObj.s(8) * (gridColumns - 1)) / gridColumns)

                    Grid {
                        width: parent.width
                        columns: presetsCol.gridColumns
                        rowSpacing: rootObj.s(8)
                        columnSpacing: rootObj.s(8)
                        visible: presetsTabRoot.presets.length > 0

                        Repeater {
                            model: presetsTabRoot.presets
                            delegate: SettingsPresetCard {
                                tab: presetsTabRoot
                                tileWidth: presetsCol.tileWidth
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: rootObj.s(40)
                        visible: presetsTabRoot.presets.length === 0

                        Text {
                            anchors.centerIn: parent
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: I18n.t("guide.general.presets.empty", "No presets yet. Save your current setup to create one")
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
