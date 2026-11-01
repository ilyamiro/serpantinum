import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "OcrLanguages.js" as OcrLanguages

GuideTab {
    id: screenshotTabRoot

    readonly property string scriptPath: Caching.serpantinumDir + "/scripts/ocr_langs.sh"

    property bool captureOnRelease: false
    property var allLanguages: []
    property bool online: true
    property bool loaded: false
    property bool failed: false
    property real lastLoadMs: 0
    property string busyCode: ""
    property string busyAction: ""
    property string search: ""

    ListModel { id: languageModel }

    onSearchChanged: rebuildModel()

    function rebuildModel() {
        let q = screenshotTabRoot.search.trim().toLowerCase();
        languageModel.clear();
        let items = screenshotTabRoot.allLanguages;
        for (let i = 0; i < items.length; i++) {
            let l = items[i];
            if (q === "" || l.name.toLowerCase().indexOf(q) !== -1 || l.code.indexOf(q) !== -1) {
                languageModel.append({ code: l.code, name: l.name, size: l.size, installed: l.installed });
            }
        }
    }

    function syncInstalled() {
        let byCode = {};
        for (let i = 0; i < screenshotTabRoot.allLanguages.length; i++) {
            byCode[screenshotTabRoot.allLanguages[i].code] = screenshotTabRoot.allLanguages[i];
        }
        for (let j = 0; j < languageModel.count; j++) {
            let row = languageModel.get(j);
            let l = byCode[row.code];
            if (l && row.installed !== l.installed) languageModel.setProperty(j, "installed", l.installed);
        }
    }

    function applyList(list) {
        let sorted = list.map(l => ({
            code: l.code,
            size: l.size,
            installed: l.installed,
            name: OcrLanguages.name(l.code)
        }));
        sorted.sort((a, b) => a.name.localeCompare(b.name));
        let current = screenshotTabRoot.allLanguages;
        let same = sorted.length === current.length && sorted.every((l, i) => l.code === current[i].code);
        screenshotTabRoot.allLanguages = sorted;
        if (same) screenshotTabRoot.syncInstalled();
        else screenshotTabRoot.rebuildModel();
    }

    function markInstalled(code, value) {
        let items = screenshotTabRoot.allLanguages.slice();
        for (let i = 0; i < items.length; i++) {
            if (items[i].code === code || (value && items[i].code === "eng")) {
                items[i] = Object.assign({}, items[i], { installed: value });
            }
        }
        screenshotTabRoot.allLanguages = items;
        screenshotTabRoot.syncInstalled();
    }

    function syncSettings() {
        let gs = (typeof Config !== "undefined" && typeof Config.getSetting === "function") ? Config.getSetting("general", {}) : {};
        screenshotTabRoot.captureOnRelease = gs && gs.screenshotCaptureOnRelease === true;
    }

    function updateCaptureOnRelease(value) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("general", {}));
        current.screenshotCaptureOnRelease = value;
        Config.setSetting("general", current);
        screenshotTabRoot.captureOnRelease = value;
    }

    function loadLanguages() {
        if (listProc.running) return;
        listProc.running = true;
    }

    function runAction(action, code) {
        if (opProc.running) return;
        screenshotTabRoot.failed = false;
        screenshotTabRoot.busyCode = code;
        screenshotTabRoot.busyAction = action;
        opProc.command = ["bash", screenshotTabRoot.scriptPath, action, code];
        opProc.running = true;
    }

    function formatSize(bytes) {
        return (bytes / 1048576).toFixed(1) + " MB";
    }

    Process {
        id: listProc
        command: ["bash", screenshotTabRoot.scriptPath, "list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    let data = JSON.parse(listOut.text);
                    screenshotTabRoot.applyList(data.languages || []);
                    screenshotTabRoot.online = data.online === true;
                } catch (e) {
                    screenshotTabRoot.online = false;
                }
                screenshotTabRoot.loaded = true;
                screenshotTabRoot.lastLoadMs = Date.now();
            }
        }
    }

    Process {
        id: opProc
        onExited: function(exitCode) {
            let code = screenshotTabRoot.busyCode;
            let action = screenshotTabRoot.busyAction;
            screenshotTabRoot.failed = exitCode !== 0;
            screenshotTabRoot.busyCode = "";
            screenshotTabRoot.busyAction = "";
            if (exitCode === 0) screenshotTabRoot.markInstalled(code, action === "install");
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            if (!screenshotTabRoot.loaded || Date.now() - screenshotTabRoot.lastLoadMs > 60000) loadLanguages();
        }
    }

    Component.onCompleted: syncSettings()

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            screenshotTabRoot.syncSettings();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        spacing: rootObj.s(6)

        SettingsBlob {
            SettingsRow {
                rootObj: screenshotTabRoot.rootObj
                settingId: "screenshot_capture_on_release"
                searchKeywords: "screenshot capture release mouse region shutter"
                icon: "󰹑"
                title: I18n.t("guide.general.screenshot_on_release.title", "Capture region on mouse release")
                description: I18n.t("guide.general.screenshot_on_release.desc", "Take the screenshot as soon as you finish dragging, without clicking the shutter")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: screenshotTabRoot.captureOnRelease
                    accentColor: ThemeBackend.accent
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { screenshotTabRoot.updateCaptureOnRelease(c); }
                }
            }
        }

        SettingsBlob {
            SettingsRow {
                rootObj: screenshotTabRoot.rootObj
                settingId: "screenshot_ocr_languages"
                searchKeywords: "ocr text recognition language tesseract download install"
                icon: "󱄽"
                title: I18n.t("guide.screenshot.ocr.title", "OCR languages")
                description: I18n.t("guide.screenshot.ocr.desc", "Text recognition detects the language automatically from the ones you install")

                Input {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(220)
                    implicitHeight: rootObj.s(32)
                    text: screenshotTabRoot.search
                    placeholderText: I18n.t("guide.screenshot.ocr.search", "Search languages...")
                    showClearButton: true
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.accent
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onTextEdited: function(newText) { screenshotTabRoot.search = newText; }
                    onCleared: screenshotTabRoot.search = ""
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.margins: rootObj.s(12)
                visible: !screenshotTabRoot.loaded || !screenshotTabRoot.online || screenshotTabRoot.failed
                wrapMode: Text.WordWrap
                color: (screenshotTabRoot.failed || (screenshotTabRoot.loaded && !screenshotTabRoot.online)) ? ThemeBackend.red : ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                text: screenshotTabRoot.failed
                    ? I18n.t("guide.screenshot.ocr.failed", "Download failed. Check your connection.")
                    : (screenshotTabRoot.loaded
                        ? I18n.t("guide.screenshot.ocr.offline", "Can't reach the language list. Showing installed languages only.")
                        : I18n.t("guide.screenshot.ocr.loading", "Loading languages..."))
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.surface0, 0.4)
            clip: true

            ListView {
                id: languageList
                anchors.fill: parent
                anchors.margins: rootObj.s(6)
                spacing: rootObj.s(4)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: rootObj.s(200)
                model: languageModel

                HoverHandler {
                    id: listHover
                }

                ScrollBar.vertical: ScrollBar {
                    active: listHover.hovered
                    width: rootObj.s(4)
                    policy: listHover.hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: rootObj.s(4)
                        radius: rootObj.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                delegate: Rectangle {
                    id: languageRow
                    required property string code
                    required property string name
                    required property real size
                    required property bool installed

                    readonly property bool isBusy: screenshotTabRoot.busyCode === languageRow.code
                    readonly property bool isBase: languageRow.code === "eng" && languageRow.installed

                    width: languageList.width
                    height: rootObj.s(48)
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface1, 0.35)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: rootObj.s(12)
                        anchors.rightMargin: rootObj.s(10)
                        spacing: rootObj.s(10)

                        Text {
                            text: languageRow.installed ? "󰄬" : "󰗊"
                            color: languageRow.installed ? ThemeBackend.green : ThemeBackend.subtext0
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: rootObj.s(16)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: languageRow.name
                                elide: Text.ElideRight
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: languageRow.code + " · " + screenshotTabRoot.formatSize(languageRow.size)
                                elide: Text.ElideRight
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                            }
                        }

                        Text {
                            visible: languageRow.isBase
                            text: I18n.t("guide.screenshot.ocr.installed", "Installed")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ClickButton {
                            visible: !languageRow.isBase
                            enabled: screenshotTabRoot.busyCode === ""
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: rootObj.s(30)
                            implicitWidth: rootObj.s(120)
                            cornerRadius: ThemeBackend.borderRadius
                            textFontSize: rootObj.s(11)
                            iconFontSize: rootObj.s(13)
                            opacity: enabled || languageRow.isBusy ? 1.0 : 0.5
                            buttonIcon: languageRow.isBusy ? "󰦖" : (languageRow.installed ? "󰆴" : "󰇚")
                            buttonText: languageRow.isBusy
                                ? (screenshotTabRoot.busyAction === "install" ? I18n.t("guide.screenshot.ocr.installing", "Installing...") : I18n.t("guide.screenshot.ocr.removing", "Removing..."))
                                : (languageRow.installed ? I18n.t("guide.screenshot.ocr.remove", "Remove") : I18n.t("guide.screenshot.ocr.install", "Install"))
                            accentColor: languageRow.installed ? ThemeBackend.surface0 : ThemeBackend.accent
                            textColor: languageRow.installed ? ThemeBackend.text : ThemeBackend.crust
                            onClicked: screenshotTabRoot.runAction(languageRow.installed ? "remove" : "install", languageRow.code)
                        }
                    }
                }
            }
        }
    }
}
