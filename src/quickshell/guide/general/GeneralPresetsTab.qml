import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

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
        "    write(sys.argv[4], payload)\n" +
        "elif mode == 'image':\n" +
        "    with open(sys.argv[4], encoding='utf-8') as fp:\n" +
        "        obj = json.load(fp)\n" +
        "    obj['image'] = sys.argv[5]\n" +
        "    write(sys.argv[4], obj)\n" +
        "elif mode == 'delete':\n" +
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

    function savePreset(name, image) {
        let payload = {
            name: name,
            image: image || "",
            created: Date.now(),
            settings: JSON.parse(JSON.stringify(Config.rawSettings || {})),
            wallpapers: Object.assign({}, Wallpaper.screenWallpaperPaths)
        };
        runPresets(["save", presetsDir, widgetsDir, presetPath(presetIdFor(name)), JSON.stringify(payload)]);
    }

    function setPresetImage(preset, image) {
        if (!preset || !preset.id) return;
        runPresets(["image", presetsDir, widgetsDir, presetPath(preset.id), image]);
    }

    property var imageTarget: null

    function pickImage(target, currentPath) {
        imageTarget = target;
        imagePicker.openPicker(currentPath || "");
    }

    function imageSource(path) {
        if (!path) return "";
        return path.indexOf("://") !== -1 ? path : ("file://" + path);
    }

    ImagePicker {
        id: imagePicker
        rootObj: presetsTabRoot.rootObj
        onImageSelected: function(filePath, fileName) {
            if (presetsTabRoot.imageTarget === "new") {
                savePresetPopup.imagePath = filePath;
            } else {
                presetsTabRoot.setPresetImage(presetsTabRoot.imageTarget, filePath);
            }
            presetsTabRoot.imageTarget = null;
        }
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

    function applyPreset(preset) {
        if (!preset || !preset.settings) return;
        Config.replaceSettings(preset.settings);

        let widgets = preset.widgets || {};
        for (let mon in widgets) {
            let list = widgets[mon];
            if (Array.isArray(list) && list.length > 0) {
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
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            reloadPresets();
        } else {
            savePresetPopup.close();
            confirmPopup.close();
            imagePicker.close();
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

    Component.onCompleted: reloadPresets()

    SaveSettingsPresetPopup {
        id: savePresetPopup
        rootObj: presetsTabRoot.rootObj
        tab: presetsTabRoot
        onSaveRequested: function(presetName, imagePath) {
            presetsTabRoot.savePreset(presetName, imagePath);
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

                    readonly property int gridColumns: Math.max(2, Math.floor(width / rootObj.s(220)))
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
