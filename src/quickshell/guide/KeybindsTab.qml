import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

GuideTab {
    id: keybindsTabRoot

    readonly property bool isHyprland: typeof Compositor !== "undefined" && Compositor.name === "hyprland"

    readonly property string scriptsDir: {
        if (typeof Caching !== "undefined" && Caching.serpantinumDir) return Caching.serpantinumDir;
        return Quickshell.env("HOME") + "/.local/share/serpantinum/src";
    }

    property var defaultWindowLayout: ({ "mode": "mixed" })
    property string layoutMode: "mixed"
    property var allBinds: []
    property string bindFilter: ""
    property bool layoutReconciled: false
    property var customDescriptions: ({})
    property var customBinds: []

    readonly property var visibleBinds: {
        let query = keybindsTabRoot.bindFilter.trim().toLowerCase();
        if (query === "") return keybindsTabRoot.allBinds;
        return keybindsTabRoot.allBinds.filter(function(bind) {
            let haystack = (keybindsTabRoot.comboFor(bind) + " " + keybindsTabRoot.descriptionFor(bind)).toLowerCase();
            return haystack.indexOf(query) !== -1;
        });
    }

    readonly property var layoutOptions: ["tiling", "mixed", "floating"]

    function syncSettings() {
        let settings = (typeof Config !== "undefined" && Config.getSetting)
            ? Config.getSetting("windowLayout", keybindsTabRoot.defaultWindowLayout)
            : keybindsTabRoot.defaultWindowLayout;
        let mode = settings && settings.mode ? settings.mode : "mixed";
        if (mode !== "tiling" && mode !== "mixed" && mode !== "floating") mode = "mixed";
        keybindsTabRoot.layoutMode = mode;

        let keybinds = (typeof Config !== "undefined" && Config.getSetting)
            ? Config.getSetting("keybinds", ({}))
            : ({});
        let descriptions = keybinds && keybinds.descriptions && typeof keybinds.descriptions === "object"
            ? keybinds.descriptions
            : ({});
        keybindsTabRoot.customDescriptions = descriptions;

        let custom = keybinds && Array.isArray(keybinds.custom) ? keybinds.custom : [];
        keybindsTabRoot.customBinds = custom;
    }

    function setLayoutMode(mode) {
        if (mode !== "tiling" && mode !== "mixed" && mode !== "floating") return;
        keybindsTabRoot.layoutMode = mode;
        keybindsTabRoot.layoutReconciled = true;
        if (typeof Config !== "undefined" && Config.setSetting) {
            Config.setSetting("windowLayout", { "mode": mode });
        }
        layoutProcess.command = ["bash", keybindsTabRoot.scriptsDir + "/scripts/layout.sh", mode];
        layoutProcess.running = true;
    }

    function modeTitle(mode) {
        if (mode === "tiling") return I18n.t("guide.keybinds.layout.tiling", "Tiling");
        if (mode === "floating") return I18n.t("guide.keybinds.layout.floating", "Floating");
        return I18n.t("guide.keybinds.layout.mixed", "Mixed");
    }

    function modeDescription(mode) {
        if (mode === "tiling") return I18n.t("guide.keybinds.layout.tiling_desc", "Every window tiles; floating is disabled.");
        if (mode === "floating") return I18n.t("guide.keybinds.layout.floating_desc", "Every window floats and opens centered.");
        return I18n.t("guide.keybinds.layout.mixed_desc", "Applications tile, dialogs and utilities float centered.");
    }

    function reloadBinds() {
        if (!keybindsTabRoot.isHyprland) return;
        if (bindsProcess.running) return;
        bindsProcess.running = true;
    }

    function modLabels(mask) {
        let labels = [];
        if (mask & 1) labels.push("SHIFT");
        if (mask & 4) labels.push("CTRL");
        if (mask & 8) labels.push("ALT");
        if (mask & 64) labels.push("SUPER");
        return labels;
    }

    function prettyKey(key) {
        let names = {
            "mouse:272": "LMB",
            "mouse:273": "RMB",
            "mouse:274": "MMB",
            "SPACE": "SPACE",
            "RETURN": "ENTER",
            "PRIOR": "PGUP",
            "NEXT": "PGDN",
            "Print": "PRINT",
            "XF86AudioRaiseVolume": "VOL+",
            "XF86AudioLowerVolume": "VOL-",
            "XF86AudioMute": "MUTE",
            "XF86AudioMicMute": "MIC MUTE",
            "XF86AudioPlay": "PLAY",
            "XF86AudioPause": "PAUSE",
            "XF86AudioNext": "NEXT",
            "XF86AudioPrev": "PREV",
            "XF86MonBrightnessUp": "BRI+",
            "XF86MonBrightnessDown": "BRI-",
            "XF86PowerOff": "POWER"
        };
        if (names[key]) return names[key];
        return key.length === 1 ? key.toUpperCase() : key;
    }

    function comboFor(bind) {
        let parts = keybindsTabRoot.modLabels(bind.modmask || 0);
        parts.push(keybindsTabRoot.prettyKey(bind.key || ""));
        return parts.join(" + ");
    }

    function bindId(bind) {
        return keybindsTabRoot.comboFor(bind) + "|" + (bind.description || "");
    }

    function localizedDescription(bind) {
        let raw = bind.description || bind.dispatcher || "";
        let workspace = raw.match(/^Workspace\s+(\d+)$/i);
        if (workspace) return I18n.t("guide.keybinds.workspace", { N: workspace[1] });
        let moveToWorkspace = raw.match(/^Move window to workspace\s+(\d+)$/i);
        if (moveToWorkspace) return I18n.t("guide.keybinds.move_to_workspace", { N: moveToWorkspace[1] });
        let slug = raw.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
        return I18n.t("guide.keybinds.descriptions." + slug, raw);
    }

    function descriptionFor(bind) {
        let custom = keybindsTabRoot.customDescriptions[keybindsTabRoot.bindId(bind)];
        if (custom !== undefined && custom !== null && custom !== "") return custom;
        if (keybindsTabRoot.customBindFor(bind)) return bind.description || "";
        return keybindsTabRoot.localizedDescription(bind);
    }

    function persistDescriptions(descriptions) {
        keybindsTabRoot.customDescriptions = descriptions;
        if (typeof Config === "undefined" || !Config.setSetting) return;
        let keybinds = Config.getSetting("keybinds", ({}));
        if (!keybinds || typeof keybinds !== "object") keybinds = ({});
        keybinds.descriptions = descriptions;
        Config.setSetting("keybinds", keybinds);
    }

    function saveDescription(bind, text) {
        if (!bind) return;
        let trimmed = String(text || "").trim();
        let map = Object.assign({}, keybindsTabRoot.customDescriptions);
        let id = keybindsTabRoot.bindId(bind);
        if (trimmed === "" || trimmed === keybindsTabRoot.localizedDescription(bind)) {
            delete map[id];
        } else {
            map[id] = trimmed;
        }
        keybindsTabRoot.persistDescriptions(map);
    }

    readonly property var cyrillicKeys: ({
        "й": "Q", "ц": "W", "у": "E", "к": "R", "е": "T", "н": "Y", "г": "U", "ш": "I", "щ": "O", "з": "P",
        "ф": "A", "ы": "S", "в": "D", "а": "F", "п": "G", "р": "H", "о": "J", "л": "K", "д": "L",
        "я": "Z", "ч": "X", "с": "C", "м": "V", "и": "B", "т": "N", "ь": "M",
        "х": "BRACKETLEFT", "ъ": "BRACKETRIGHT", "ж": "SEMICOLON", "э": "APOSTROPHE",
        "б": "COMMA", "ю": "PERIOD"
    })

    function isModifierKey(key) {
        return key === 0x01000020 // Shift
            || key === 0x01000021 // Control
            || key === 0x01000022 // Meta
            || key === 0x01000023 // Alt
            || key === 0x01001103 // AltGr
            || key === 0x01000053 // Super_L
            || key === 0x01000054 // Super_R
            || key === 0x01000055 // Hyper_L
            || key === 0x01000056 // Hyper_R
            || key === 0x01000024 // CapsLock
            || key === 0x01000025 // NumLock
            || key === 0x01000026 // ScrollLock
    }

    function keyNameFor(key, text) {
        if (key >= 0x41 && key <= 0x5a) return String.fromCharCode(key);
        if (key >= 0x30 && key <= 0x39) return String.fromCharCode(key);
        if (key >= 0x01000030 && key <= 0x01000052) return "F" + (key - 0x01000030 + 1);

        let names = {
            0x20: "SPACE",
            0x01000004: "RETURN",
            0x01000001: "TAB",
            0x01000003: "BACKSPACE",
            0x01000007: "DELETE",
            0x01000006: "INSERT",
            0x01000010: "HOME",
            0x01000011: "END",
            0x01000016: "PRIOR",
            0x01000017: "NEXT",
            0x01000012: "LEFT",
            0x01000014: "RIGHT",
            0x01000013: "UP",
            0x01000015: "DOWN",
            0x01000009: "PRINT",
            0x2d: "MINUS",
            0x3d: "EQUAL",
            0x5b: "BRACKETLEFT",
            0x5d: "BRACKETRIGHT",
            0x5c: "BACKSLASH",
            0x3b: "SEMICOLON",
            0x27: "APOSTROPHE",
            0x60: "GRAVE",
            0x2c: "COMMA",
            0x2e: "PERIOD",
            0x2f: "SLASH",
            0x3a: "SEMICOLON",
            0x21: "1",
            0x40: "2",
            0x23: "3",
            0x24: "4",
            0x25: "5",
            0x5e: "6",
            0x26: "7",
            0x2a: "8",
            0x28: "9",
            0x29: "0",
            0x5f: "MINUS",
            0x2b: "EQUAL",
            0x7b: "BRACKETLEFT",
            0x7d: "BRACKETRIGHT",
            0x7c: "BACKSLASH",
            0x22: "APOSTROPHE",
            0x3c: "COMMA",
            0x3e: "PERIOD",
            0x3f: "SLASH",
            0x7e: "GRAVE"
        };
        if (names[key] !== undefined) return names[key];

        let value = String(text || "");
        if (value.length === 1) {
            let lower = value.toLowerCase();
            if (keybindsTabRoot.cyrillicKeys[lower]) return keybindsTabRoot.cyrillicKeys[lower];
            if (/^[a-z0-9]$/i.test(value)) return value.toUpperCase();
        }
        return "";
    }

    function comboFromEvent(key, modifiers, text) {
        if (keybindsTabRoot.isModifierKey(key)) return "";
        let name = keybindsTabRoot.keyNameFor(key, text);
        if (name === "") return "";
        let parts = [];
        if (modifiers & Qt.ShiftModifier) parts.push("SHIFT");
        if (modifiers & Qt.ControlModifier) parts.push("CTRL");
        if (modifiers & Qt.AltModifier) parts.push("ALT");
        if (modifiers & Qt.MetaModifier) parts.push("SUPER");
        parts.push(name);
        return parts.join(" + ");
    }

    function prettyCombo(combo) {
        let parts = String(combo || "").split("+").map(function(part) { return part.trim(); }).filter(function(part) { return part !== ""; });
        let flags = { "SHIFT": false, "CTRL": false, "ALT": false, "SUPER": false };
        let key = "";
        for (let i = 0; i < parts.length; i++) {
            let upper = parts[i].toUpperCase();
            if (upper === "CONTROL") upper = "CTRL";
            if (upper === "WIN" || upper === "LOGO" || upper === "META" || upper === "MOD4") upper = "SUPER";
            if (flags.hasOwnProperty(upper)) flags[upper] = true;
            else key = parts[i];
        }
        let labels = [];
        if (flags.SHIFT) labels.push("SHIFT");
        if (flags.CTRL) labels.push("CTRL");
        if (flags.ALT) labels.push("ALT");
        if (flags.SUPER) labels.push("SUPER");
        if (key !== "") labels.push(keybindsTabRoot.prettyKey(key));
        return labels.join(" + ");
    }

    function customBindFor(bind) {
        if (!bind || !keybindsTabRoot.customBinds) return null;
        let combo = keybindsTabRoot.comboFor(bind);
        let raw = bind.description || "";
        for (let i = 0; i < keybindsTabRoot.customBinds.length; i++) {
            let entry = keybindsTabRoot.customBinds[i];
            if (!entry) continue;
            if (keybindsTabRoot.prettyCombo(entry.key) === combo && (entry.description || "") === raw) return entry;
        }
        return null;
    }

    function keybindsSettings() {
        if (typeof Config === "undefined" || !Config.getSetting) return ({});
        let keybinds = Config.getSetting("keybinds", ({}));
        return keybinds && typeof keybinds === "object" ? keybinds : ({});
    }

    function syncCustomBinds() {
        if (syncProcess.running) return;
        syncProcess.command = ["bash", keybindsTabRoot.scriptsDir + "/scripts/keybinds.sh", "sync"];
        syncProcess.running = true;
    }

    function saveCustomBind(id, data) {
        let keybinds = keybindsTabRoot.keybindsSettings();
        let list = Array.isArray(keybinds.custom) ? keybinds.custom.slice() : [];
        let index = -1;
        if (id) {
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === id) { index = i; break; }
            }
        }
        if (index >= 0) {
            list[index] = Object.assign({}, list[index], data);
        } else {
            list.push(Object.assign({ id: "cb" + Date.now() + Math.floor(Math.random() * 1000) }, data));
        }
        keybinds.custom = list;
        Config.setSetting("keybinds", keybinds);
        keybindsTabRoot.customBinds = list;
        keybindsTabRoot.syncCustomBinds();
    }

    function deleteCustomBind(entry) {
        if (!entry) return;
        let keybinds = keybindsTabRoot.keybindsSettings();
        let list = (Array.isArray(keybinds.custom) ? keybinds.custom : []).filter(function(item) {
            return !item || item.id !== entry.id;
        });
        keybinds.custom = list;
        Config.setSetting("keybinds", keybinds);
        keybindsTabRoot.customBinds = list;
        keybindsTabRoot.syncCustomBinds();
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            reloadBinds();
            variablesView.reload();
        }
    }

    Component.onCompleted: {
        syncSettings();
        reloadBinds();
        variablesView.reload();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            keybindsTabRoot.syncSettings();
        }
    }

    Process {
        id: bindsProcess
        command: ["hyprctl", "binds", "-j"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    let list = [];
                    for (let i = 0; i < parsed.length; i++) {
                        let bind = parsed[i];
                        if (!bind || !bind.key || bind.submap !== "") continue;
                        let description = bind.description || "";
                        if (description === "") continue;
                        list.push(bind);
                    }
                    keybindsTabRoot.allBinds = list;
                } catch (error) {
                    keybindsTabRoot.allBinds = [];
                }
            }
        }
    }

    Process {
        id: layoutProcess
        running: false
    }

    Process {
        id: syncProcess
        running: false

        onExited: {
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: keybindsTabRoot.reloadBinds()
    }

    FileView {
        id: variablesView
        path: (typeof Config !== "undefined" ? Config.homeDir : Quickshell.env("HOME")) + "/.config/hypr/config/variables.lua"
        watchChanges: false

        onLoaded: {
            if (!keybindsTabRoot.isHyprland || keybindsTabRoot.layoutReconciled) return;
            keybindsTabRoot.layoutReconciled = true;
            let raw = typeof text === "function" ? text() : text;
            let match = String(raw || "").match(/layoutMode\s*=\s*["']([^"']+)["']/);
            if (match && match[1] !== keybindsTabRoot.layoutMode) {
                keybindsTabRoot.setLayoutMode(keybindsTabRoot.layoutMode);
            }
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

            SettingsBlob {
                visible: keybindsTabRoot.isHyprland

                SettingsRow {
                    rootObj: keybindsTabRoot.rootObj
                    icon: "󰕰"
                    title: I18n.t("guide.keybinds.layout.title", "Window Layout")
                    description: keybindsTabRoot.modeDescription(keybindsTabRoot.layoutMode)

                    Dropdown {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
                        options: [
                            keybindsTabRoot.modeTitle("tiling"),
                            keybindsTabRoot.modeTitle("mixed"),
                            keybindsTabRoot.modeTitle("floating")
                        ]
                        currentIndex: Math.max(0, keybindsTabRoot.layoutOptions.indexOf(keybindsTabRoot.layoutMode))
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(index, value) {
                            let mode = keybindsTabRoot.layoutOptions[index];
                            if (mode === keybindsTabRoot.layoutMode) return;
                            keybindsTabRoot.setLayoutMode(mode);
                        }
                    }
                }
            }

            SettingsBlob {
                visible: !keybindsTabRoot.isHyprland

                SettingsRow {
                    rootObj: keybindsTabRoot.rootObj
                    icon: "󰌌"
                    title: I18n.t("guide.keybinds.unsupported.title", "Keybinds")
                    description: I18n.t("guide.keybinds.unsupported.desc", "This tab currently supports Hyprland only.")
                    searchable: false
                }
            }

            SettingsBlob {
                visible: keybindsTabRoot.isHyprland

                SettingsRow {
                    rootObj: keybindsTabRoot.rootObj
                    icon: "󰌌"
                    title: I18n.t("guide.keybinds.shortcuts.title", "Keyboard Shortcuts")
                    description: I18n.t("guide.keybinds.shortcuts.desc", "Read from the running compositor. Use the pencil to edit a description; key combinations live in ~/.config/hypr/config/keybinds.lua")
                    searchable: false

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(220)
                        implicitHeight: rootObj.s(32)
                        placeholderText: I18n.t("guide.keybinds.shortcuts.filter", "Filter shortcuts")
                        text: keybindsTabRoot.bindFilter
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: rootObj.s(11)
                        onTextChanged: {
                            if (text !== keybindsTabRoot.bindFilter) keybindsTabRoot.bindFilter = text;
                        }
                    }

                    IconButton {
                        size: keybindsTabRoot.rootObj.s(32)
                        Layout.preferredWidth: keybindsTabRoot.rootObj.s(32)
                        Layout.preferredHeight: keybindsTabRoot.rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰐕"
                        iconFontSize: keybindsTabRoot.rootObj.s(16)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        onClicked: customPopup.openFor(null)
                    }
                }

                Repeater {
                    model: keybindsTabRoot.visibleBinds

                    delegate: SettingsRow {
                        required property var modelData
                        readonly property var customEntry: keybindsTabRoot.customBindFor(modelData)
                        rootObj: keybindsTabRoot.rootObj
                        icon: "󰌌"
                        title: keybindsTabRoot.comboFor(modelData)
                        description: keybindsTabRoot.descriptionFor(modelData)
                        searchable: true

                        IconButton {
                            size: keybindsTabRoot.rootObj.s(28)
                            Layout.preferredWidth: keybindsTabRoot.rootObj.s(28)
                            Layout.preferredHeight: keybindsTabRoot.rootObj.s(28)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰏫"
                            iconFontSize: keybindsTabRoot.rootObj.s(14)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.subtext0
                            onClicked: {
                                if (customEntry) customPopup.openFor(customEntry);
                                else editPopup.openFor(modelData);
                            }
                        }

                        IconButton {
                            visible: customEntry !== null
                            size: keybindsTabRoot.rootObj.s(28)
                            Layout.preferredWidth: keybindsTabRoot.rootObj.s(28)
                            Layout.preferredHeight: keybindsTabRoot.rootObj.s(28)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰗨"
                            iconFontSize: keybindsTabRoot.rootObj.s(14)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.red
                            onClicked: keybindsTabRoot.deleteCustomBind(customEntry)
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: editPopup
        parent: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj : undefined
        x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
        y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
        modal: true
        dim: true
        width: keybindsTabRoot.rootObj ? Math.min(keybindsTabRoot.rootObj.width - keybindsTabRoot.rootObj.s(32), keybindsTabRoot.rootObj.s(480)) : 480
        padding: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(20) : 20
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property var bind: null

        function openFor(bind) {
            editPopup.bind = bind;
            descriptionInput.text = keybindsTabRoot.customDescriptions[keybindsTabRoot.bindId(bind)] || "";
            descriptionInput.placeholderText = keybindsTabRoot.localizedDescription(bind);
            open();
            descriptionInput.forceInputFocus();
        }

        function commit() {
            keybindsTabRoot.saveDescription(editPopup.bind, descriptionInput.text);
            close();
        }

        function reset() {
            descriptionInput.text = "";
            keybindsTabRoot.saveDescription(editPopup.bind, "");
            close();
        }

        Connections {
            target: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj : null
            function onVisibleChanged() {
                if (keybindsTabRoot.rootObj && !keybindsTabRoot.rootObj.visible) editPopup.close();
            }
        }

        background: Rectangle {
            radius: ThemeBackend.clampedBorderRadius
            color: editGlass.active ? "transparent" : ThemeBackend.base

            GlassFill {
                id: editGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.base
                tintAmount: 0.25
            }
        }

        contentItem: ColumnLayout {
            spacing: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(12) : 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("guide.keybinds.edit.title", "Edit description")
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(16) : 16
                    font.bold: true
                }

                CloseButton {
                    size: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(30) : 30
                    cornerRadius: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(8) : 8
                    iconFontSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(14) : 14
                    onClicked: editPopup.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: editPopup.bind ? keybindsTabRoot.comboFor(editPopup.bind) : ""
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(12) : 12
                elide: Text.ElideRight
            }

            Input {
                id: descriptionInput
                Layout.fillWidth: true
                Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(13) : 13
                onAccepted: editPopup.commit()
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.keybinds.edit.hint", "Leave empty to use the default description.")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(11) : 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(8) : 8

                Item { Layout.fillWidth: true }

                IconButton {
                    size: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredWidth: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰔄"
                    iconFontSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(18) : 18
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: editPopup.reset()
                }

                IconButton {
                    size: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredWidth: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰄬"
                    iconFontSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(18) : 18
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: editPopup.commit()
                }
            }
        }
    }

    Popup {
        id: customPopup
        parent: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj : undefined
        x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
        y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
        modal: true
        dim: true
        width: keybindsTabRoot.rootObj ? Math.min(keybindsTabRoot.rootObj.width - keybindsTabRoot.rootObj.s(32), keybindsTabRoot.rootObj.s(520)) : 520
        padding: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(20) : 20
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property var editing: null

        function openFor(entry) {
            customPopup.editing = entry;
            shortcutInput.capturing = false;
            shortcutInput.text = entry ? (entry.key || "") : "";
            commandInput.text = entry ? (entry.command || "") : "";
            customDescriptionInput.text = entry ? (entry.description || "") : "";
            open();
            Qt.callLater(function() {
                if (entry) shortcutInput.forceInputFocus();
                else shortcutInput.beginCapture();
            });
        }

        function commit() {
            let key = shortcutInput.text.trim();
            let command = commandInput.text.trim();
            if (key === "") {
                shortcutInput.triggerShake();
                return;
            }
            if (command === "") {
                commandInput.triggerShake();
                return;
            }
            let description = customDescriptionInput.text.trim();
            if (description === "") description = command;
            keybindsTabRoot.saveCustomBind(customPopup.editing ? customPopup.editing.id : "", {
                key: key,
                command: command,
                description: description
            });
            close();
        }

        Connections {
            target: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj : null
            function onVisibleChanged() {
                if (keybindsTabRoot.rootObj && !keybindsTabRoot.rootObj.visible) customPopup.close();
            }
        }

        background: Rectangle {
            radius: ThemeBackend.clampedBorderRadius
            color: customGlass.active ? "transparent" : ThemeBackend.base

            GlassFill {
                id: customGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.base
                tintAmount: 0.25
            }
        }

        contentItem: ColumnLayout {
            spacing: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(10) : 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: customPopup.editing
                        ? I18n.t("guide.keybinds.custom.edit_title", "Edit keybind")
                        : I18n.t("guide.keybinds.custom.add_title", "Add keybind")
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(16) : 16
                    font.bold: true
                }

                CloseButton {
                    size: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(30) : 30
                    cornerRadius: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(8) : 8
                    iconFontSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(14) : 14
                    onClicked: customPopup.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.keybinds.custom.shortcut", "Shortcut")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(11) : 11
            }

            Input {
                id: shortcutInput
                Layout.fillWidth: true
                Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                placeholderText: shortcutInput.capturing
                    ? I18n.t("guide.keybinds.custom.press_shortcut", "Press a key combination…")
                    : I18n.t("guide.keybinds.custom.shortcut_placeholder", "SUPER + SHIFT + T")
                baseColor: ThemeBackend.surface0
                accentColor: shortcutInput.capturing ? ThemeBackend.peach : ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(13) : 13
                captureKeys: shortcutInput.capturing
                recordOnClick: true

                property bool capturing: false

                function beginCapture() {
                    shortcutInput.capturing = true;
                    shortcutInput.text = "";
                    shortcutInput.forceInputFocus();
                }

                function stopCapture() {
                    shortcutInput.capturing = false;
                }

                onClicked: shortcutInput.beginCapture()
                onHasFocusChanged: {
                    if (!hasFocus) shortcutInput.stopCapture();
                }

                onKeyCaptured: function(key, modifiers, text) {
                    if (key === Qt.Key_Escape) {
                        shortcutInput.stopCapture();
                        return;
                    }
                    if (key === Qt.Key_Backspace || key === Qt.Key_Delete) {
                        shortcutInput.text = "";
                        return;
                    }
                    let combo = keybindsTabRoot.comboFromEvent(key, modifiers, text);
                    if (combo === "") return;
                    shortcutInput.text = combo;
                    shortcutInput.capturing = false;
                    Qt.callLater(function() { commandInput.forceInputFocus(); });
                }
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.keybinds.custom.shortcut_hint", "Click the field and press the combination — it is recorded automatically. Backspace clears it.")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(11) : 11
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.keybinds.custom.command", "Command")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(11) : 11
            }

            Input {
                id: commandInput
                Layout.fillWidth: true
                Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                placeholderText: I18n.t("guide.keybinds.custom.command_placeholder", "kitty")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(13) : 13
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.keybinds.custom.description", "Description")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(11) : 11
            }

            Input {
                id: customDescriptionInput
                Layout.fillWidth: true
                Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                placeholderText: I18n.t("guide.keybinds.custom.description_placeholder", "Optional, defaults to the command")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(13) : 13
                onAccepted: customPopup.commit()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(8) : 8

                Item { Layout.fillWidth: true }

                IconButton {
                    size: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredWidth: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    Layout.preferredHeight: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(38) : 38
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰄬"
                    iconFontSize: keybindsTabRoot.rootObj ? keybindsTabRoot.rootObj.s(18) : 18
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: customPopup.commit()
                }
            }
        }
    }
}
