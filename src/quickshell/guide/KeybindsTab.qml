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

    readonly property var visibleBinds: {
        let query = keybindsTabRoot.bindFilter.trim().toLowerCase();
        if (query === "") return keybindsTabRoot.allBinds;
        return keybindsTabRoot.allBinds.filter(function(bind) {
            let haystack = (keybindsTabRoot.comboFor(bind) + " " + keybindsTabRoot.describeBind(bind)).toLowerCase();
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

    function describeBind(bind) {
        if (bind.description && bind.description !== "") return bind.description;
        return bind.dispatcher || "";
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
                    description: I18n.t("guide.keybinds.shortcuts.desc", "Read from the running compositor. Edit them in ~/.config/hypr/config/keybinds.lua")
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
                }

                Repeater {
                    model: keybindsTabRoot.visibleBinds

                    delegate: SettingsRow {
                        required property var modelData
                        rootObj: keybindsTabRoot.rootObj
                        icon: "󰌌"
                        title: keybindsTabRoot.comboFor(modelData)
                        description: keybindsTabRoot.describeBind(modelData)
                        searchable: true
                    }
                }
            }
        }
    }
}
