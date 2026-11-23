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

    property var presets: PresetsCache.presets

    readonly property string presetsDir: Caching.stateDir + "/presets"
    readonly property string widgetsDir: Caching.stateDir + "/widgets"

    property var pendingRuns: []

    readonly property var machineSpecificPaths: [["general", "location"], ["general", "avatarPath"], ["notifications", "soundFile"], ["wallpaperDir"], ["wallpaper_dir"], ["screenshotDir"]]
    readonly property string stripSettingsFilter: "del(.general.location, .general.avatarPath, .notifications.soundFile, .wallpaperDir, .wallpaper_dir, .screenshotDir)"
    readonly property string stripPresetFilter: "del(.wallpapers) | if (.settings | type) == \"object\" then .settings |= " + stripSettingsFilter + " else . end"

    function runPresets(args) {
        if (presetsProc.running) {
            pendingRuns = pendingRuns.concat([args]);
            return;
        }
        presetsProc.command = ["serpantinum-core", "presets"].concat(args);
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

    property var exportTarget: null

    function exportPreset(preset) {
        if (!preset || !preset.id) return;
        exportTarget = preset;
        let name = String(preset.name || preset.id).replace(/[^A-Za-z0-9_\- ]/g, "").trim().replace(/ +/g, "_") || preset.id;
        let home = Quickshell.env("HOME") || "";
        let dir = Quickshell.env("XDG_DOWNLOAD_DIR") || (home + "/Downloads");
        exportPicker.openSave(dir, name + ".json");
    }

    function deletePreset(preset) {
        if (!preset || !preset.id) return;
        presets = presets.filter(p => p.id !== preset.id);
        PresetsCache.presets = presets;
        PresetsCache.raw = "";
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

    function withLocalMachineSettings(settings) {
        let result = JSON.parse(JSON.stringify(settings));
        let current = Config.rawSettings || {};
        for (let i = 0; i < machineSpecificPaths.length; i++) {
            let path = machineSpecificPaths[i];
            let key = path[path.length - 1];
            let src = path.length > 1 ? current[path[0]] : current;
            if (!src || src[key] === undefined) continue;
            let dst = result;
            if (path.length > 1) {
                if (!dst[path[0]] || typeof dst[path[0]] !== "object") dst[path[0]] = {};
                dst = dst[path[0]];
            }
            if (dst[key] === undefined) dst[key] = src[key];
        }
        return result;
    }

    function applyPreset(preset) {
        preset = presets.find(p => preset && p.id === preset.id) || preset;
        if (!preset || !preset.settings) return;
        Config.replaceSettings(withLocalMachineSettings(withInstalledDockApps(preset.settings)));

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
                if (out !== PresetsCache.raw) {
                    try {
                        let res = JSON.parse(out);
                        let list = Array.isArray(res) ? res : [];
                        presetsTabRoot.presets = list;
                        PresetsCache.presets = list;
                        PresetsCache.raw = out;
                    } catch (e) {}
                }
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
            exportPicker.close();
            copySettingsBtn.reset();
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
        if (visible) reloadPresets();
    }

    Process {
        id: exportProc
        running: false
    }

    FilePicker {
        id: exportPicker
        rootObj: presetsTabRoot.rootObj
        titleText: I18n.t("guide.general.presets.export.dialog", "Export preset")
        doneButtonText: I18n.t("guide.general.presets.export.button", "Export")
        nameFilters: ["*.json"]
        onFileSelected: function(filePath, fileName) {
            if (!presetsTabRoot.exportTarget) return;
            let dest = /\.json$/i.test(filePath) ? filePath : filePath + ".json";
            exportProc.command = ["bash", "-c", "jq \"$2\" \"$1\" > \"$3\"", "_", presetsTabRoot.presetPath(presetsTabRoot.exportTarget.id), presetsTabRoot.stripPresetFilter, dest];
            exportProc.running = true;
        }
    }

    Process {
        id: importProc
        onExited: presetsTabRoot.reloadPresets()
    }

    FilePicker {
        id: importPicker
        rootObj: presetsTabRoot.rootObj
        titleText: I18n.t("guide.general.presets.import.picker", "Select preset file")
        nameFilters: ["*.json"]
        onFileSelected: function(filePath, fileName) {
            let path = String(filePath).replace(/^file:\/\//, "");
            importProc.command = ["bash", "-c", "mkdir -p \"$2\" && jq -e \"$3\" \"$1\" > \"$2/.import.tmp\" && mv -f \"$2/.import.tmp\" \"$2/$(basename \"$1\")\"", "_", path, presetsTabRoot.presetsDir, presetsTabRoot.stripPresetFilter];
            importProc.running = true;
        }
    }

    SaveSettingsPresetPopup {
        id: savePresetPopup
        rootObj: presetsTabRoot.rootObj
        onSaveRequested: function(presetName) {
            presetsTabRoot.savePreset(presetName);
        }
    }

    GuideScrollView {
        rootObj: presetsTabRoot.rootObj

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
            settingId: "presets_import"
            icon: "󰋺"
            title: I18n.t("guide.general.presets.import.title", "Import and export presets")
            description: I18n.t("guide.general.presets.import.desc", "Add a preset from a JSON file. Use the export button on a preset to save a shareable copy")
            searchKeywords: "presets preset import export file load save share json"

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitHeight: rootObj.s(32)
                buttonText: I18n.t("guide.general.presets.import.button", "Import")
                buttonIcon: "󰋺"
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: rootObj.s(14)
                iconFontSize: rootObj.s(15)
                textFontSize: rootObj.s(12)
                onTriggered: importPicker.openWithOptionalPath("")
            }
        }

        SettingsRow {
            rootObj: presetsTabRoot.rootObj
            settingId: "copy_settings"
            icon: "󰆏"
            title: I18n.t("guide.general.copysettings.title", "Copy settings")
            description: I18n.t("guide.general.copysettings.desc", "Copy configuration JSON to clipboard. This includes sensitive data such as your location and custom paths")
            searchKeywords: "copy export settings json clipboard"

            Item {
                id: copySettingsBtn
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitHeight: rootObj.s(32)
                implicitWidth: Math.ceil(copyBtnIconBox.width + copyBtnRow.spacing + animatedTextWidth + horizontalPadding * 2)

                property bool copied: false
                property real copiedMix: copied ? 1.0 : 0.0
                property real checkProgress: 0.0
                property real checkOpacity: 0.0
                property real checkPop: 1.0
                property real popScale: 1.0
                property real flashOpacity: 0.0
                readonly property real horizontalPadding: rootObj.s(14)
                readonly property string copyLabel: I18n.t("guide.general.copysettings.title", "Copy settings")
                readonly property string copiedLabel: I18n.t("quickactions.calculator.copied", "Copied")
                readonly property color targetAccent: copied ? ThemeBackend.green : ThemeBackend.surface0
                readonly property color targetSurfaceColor: copyBtnMa.pressed ? Qt.darker(targetAccent, 1.24) : (copyBtnMa.containsMouse ? Qt.darker(targetAccent, 1.12) : targetAccent)
                readonly property color targetTextColor: copied ? ThemeBackend.crust : ThemeBackend.text
                readonly property color displayTextColor: (copyBtnGlass.active && (0.2126 * animatedTextColor.r + 0.7152 * animatedTextColor.g + 0.0722 * animatedTextColor.b) < 0.5) ? ThemeBackend.text : animatedTextColor
                property color animatedAccent: targetAccent
                property color animatedSurfaceColor: targetSurfaceColor
                property color animatedTextColor: targetTextColor
                property real animatedTextWidth: Math.ceil(copied ? copiedTextMetrics.advanceWidth : copyTextMetrics.advanceWidth)

                Behavior on copiedMix { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                Behavior on animatedAccent { ColorAnimation { duration: 320; easing.type: Easing.InOutCubic } }
                Behavior on animatedSurfaceColor { ColorAnimation { duration: 260; easing.type: Easing.InOutCubic } }
                Behavior on animatedTextColor { ColorAnimation { duration: 280; easing.type: Easing.InOutCubic } }
                Behavior on animatedTextWidth { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }

                activeFocusOnTab: enabled
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        copySettingsBtn.triggerCopy();
                        event.accepted = true;
                    }
                }

                function reset() {
                    copySequence.stop();
                    copied = false;
                    checkProgress = 0.0;
                    checkOpacity = 0.0;
                    checkPop = 1.0;
                }

                function triggerCopy() {
                    Quickshell.execDetached(["bash", "-c", "wl-copy < \"$1\"", "_", Config.settingsJsonPath]);
                    copyBtnPopAnim.restart();
                    flashOpacity = 0.18;
                    copyBtnFlashAnim.restart();
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                    }
                    copySequence.restart();
                }

                TextMetrics {
                    id: copyTextMetrics
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: rootObj.s(12)
                    text: copySettingsBtn.copyLabel
                }

                TextMetrics {
                    id: copiedTextMetrics
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: rootObj.s(12)
                    text: copySettingsBtn.copiedLabel
                }

                SequentialAnimation {
                    id: copyBtnPopAnim
                    NumberAnimation { target: copySettingsBtn; property: "popScale"; to: 1.025; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: copySettingsBtn; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
                }

                SequentialAnimation {
                    id: copySequence
                    ScriptAction {
                        script: {
                            copySettingsBtn.copied = true;
                            copySettingsBtn.checkProgress = 0.0;
                            copySettingsBtn.checkOpacity = 0.0;
                            copySettingsBtn.checkPop = 0.72;
                        }
                    }
                    PauseAnimation { duration: 85 }
                    ParallelAnimation {
                        NumberAnimation { target: copySettingsBtn; property: "checkOpacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: copySettingsBtn; property: "checkProgress"; from: 0.0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
                        NumberAnimation { target: copySettingsBtn; property: "checkPop"; from: 0.72; to: 1.0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.9 }
                    }
                    PauseAnimation { duration: 1450 }
                    ParallelAnimation {
                        NumberAnimation { target: copySettingsBtn; property: "checkProgress"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                        NumberAnimation { target: copySettingsBtn; property: "checkOpacity"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
                        NumberAnimation { target: copySettingsBtn; property: "checkPop"; to: 0.8; duration: 220; easing.type: Easing.InQuad }
                    }
                    ScriptAction {
                        script: {
                            copySettingsBtn.copied = false;
                            copySettingsBtn.checkPop = 1.0;
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    clip: !copyBtnGlass.active
                    color: copyBtnGlass.active ? "transparent" : copySettingsBtn.animatedSurfaceColor
                    scale: (copyBtnMa.pressed ? 0.975 : (copyBtnMa.containsMouse ? 1.015 : 1.0)) * copySettingsBtn.popScale
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    GlassFill {
                        id: copyBtnGlass
                        anchors.fill: parent
                        shadow: 1
                        radius: ThemeBackend.borderRadius
                        tintColor: copySettingsBtn.animatedAccent
                        press: copyBtnMa.pressed ? 1 : (copyBtnMa.containsMouse ? 0.25 : 0)
                        pulse: Math.min(1, copySettingsBtn.flashOpacity * 2.5)
                        tintAmount: copyBtnMa.pressed ? 0.55 : (copyBtnMa.containsMouse ? 0.42 : (copySettingsBtn.copied ? 0.46 : 0.3))
                        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on tintAmount { NumberAnimation { duration: 200 } }
                    }

                    RowLayout {
                        id: copyBtnRow
                        layoutDirection: I18n.layoutDirection
                        anchors.centerIn: parent
                        spacing: rootObj.s(8)

                        Item {
                            id: copyBtnIconBox
                            Layout.preferredWidth: rootObj.s(16)
                            Layout.preferredHeight: rootObj.s(16)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰆏"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: rootObj.s(15)
                                color: copySettingsBtn.displayTextColor
                                opacity: Math.max(0.0, 1.0 - copySettingsBtn.copiedMix * 1.45)
                                scale: 1.0 - 0.38 * copySettingsBtn.copiedMix
                                rotation: -35 * copySettingsBtn.copiedMix
                                visible: opacity > 0.001
                            }

                            Canvas {
                                id: checkCanvas
                                anchors.fill: parent
                                antialiasing: true
                                opacity: copySettingsBtn.checkOpacity
                                scale: copySettingsBtn.checkPop
                                visible: opacity > 0.001 && copySettingsBtn.checkProgress > 0.001

                                onPaint: {
                                    let ctx = getContext("2d");
                                    ctx.reset();
                                    let p = copySettingsBtn.checkProgress;
                                    if (p <= 0.001) return;
                                    let w = width;
                                    let h = height;
                                    let x0 = w * 0.16;
                                    let y0 = h * 0.53;
                                    let x1 = w * 0.41;
                                    let y1 = h * 0.77;
                                    let x2 = w * 0.84;
                                    let y2 = h * 0.26;
                                    let split = 0.34;
                                    ctx.strokeStyle = copySettingsBtn.displayTextColor.toString();
                                    ctx.lineWidth = Math.max(1.8, w * 0.14);
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(x0, y0);
                                    if (p <= split) {
                                        let t = p / split;
                                        ctx.lineTo(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
                                    } else {
                                        let t = Math.min(1.0, (p - split) / (1.0 - split));
                                        ctx.lineTo(x1, y1);
                                        ctx.lineTo(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
                                    }
                                    ctx.stroke();
                                }

                                Connections {
                                    target: copySettingsBtn
                                    function onCheckProgressChanged() { checkCanvas.requestPaint(); }
                                    function onDisplayTextColorChanged() { checkCanvas.requestPaint(); }
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }
                        }

                        Item {
                            Layout.preferredWidth: copySettingsBtn.animatedTextWidth
                            Layout.preferredHeight: rootObj.s(20)
                            Layout.alignment: Qt.AlignVCenter
                            clip: true

                            Text {
                                width: parent.width
                                y: (parent.height - height) / 2 - parent.height * 0.45 * copySettingsBtn.copiedMix
                                text: copySettingsBtn.copyLabel
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: rootObj.s(12)
                                color: copySettingsBtn.displayTextColor
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                opacity: Math.max(0.0, 1.0 - copySettingsBtn.copiedMix)
                                visible: opacity > 0.001
                            }

                            Text {
                                width: parent.width
                                y: (parent.height - height) / 2 + parent.height * 0.45 * (1.0 - copySettingsBtn.copiedMix)
                                text: copySettingsBtn.copiedLabel
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: rootObj.s(12)
                                color: copySettingsBtn.displayTextColor
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                opacity: copySettingsBtn.copiedMix
                                visible: opacity > 0.001
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: "#ffffff"
                        opacity: copySettingsBtn.flashOpacity
                        visible: !copyBtnGlass.active
                        PropertyAnimation on opacity { id: copyBtnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
                    }
                }

                MouseArea {
                    id: copyBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: copySettingsBtn.triggerCopy()
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
