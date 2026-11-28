import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../launcher/SearchProviders.js" as SearchProviders

GuideTab {
    id: launcherTabRoot

    ConfigSection {
        id: launcherCfg
        section: "launcher"
        defaults: ({
            "position": "top",
            "width": 600,
            "itemCount": 6,
            "terminalCommand": "kitty -e",
            "smartRanking": true,
            "searchProvider": SearchProviders.DEFAULT_ID
        })
    }

    readonly property string currentPosition: String(launcherCfg.values.position !== undefined ? launcherCfg.values.position : "top")
    readonly property int currentWidth: Number(launcherCfg.values.width !== undefined ? launcherCfg.values.width : 600)
    readonly property int currentItemCount: Number(launcherCfg.values.itemCount !== undefined ? launcherCfg.values.itemCount : 6)
    readonly property string currentTerminalCommand: String(launcherCfg.values.terminalCommand !== undefined ? launcherCfg.values.terminalCommand : "kitty -e")
    readonly property bool currentSmartRanking: Boolean(launcherCfg.values.smartRanking !== undefined ? launcherCfg.values.smartRanking : true)
    readonly property string currentSearchProvider: String(launcherCfg.values.searchProvider !== undefined ? launcherCfg.values.searchProvider : SearchProviders.DEFAULT_ID)

    onVisibleChanged: {
        if (!visible) {
            launcherCfg.flush();
            if (posDropdown.isOpen) posDropdown.closePopup();
            if (searchDropdown.isOpen) searchDropdown.closePopup();
        }
    }

    GuideScrollView {
        rootObj: launcherTabRoot.rootObj

        SettingsBlob {
            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_position"
                searchKeywords: "launcher position edge side top bottom left right center placement"
                icon: "󰍹"
                title: I18n.t("guide.launcher.position.title", "Screen position")
                description: I18n.t("guide.launcher.position.desc", "Select which screen edge the launcher attaches to")

                Dropdown {
                    id: posDropdown
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    options: [
                        I18n.t("guide.launcher.position.top", "Top"),
                        I18n.t("guide.launcher.position.bottom", "Bottom"),
                        I18n.t("guide.launcher.position.left", "Left"),
                        I18n.t("guide.launcher.position.right", "Right"),
                        I18n.t("guide.launcher.position.center", "Center")
                    ]
                    currentIndex: {
                        if (launcherTabRoot.currentPosition === "bottom") return 1;
                        if (launcherTabRoot.currentPosition === "left") return 2;
                        if (launcherTabRoot.currentPosition === "right") return 3;
                        if (launcherTabRoot.currentPosition === "center") return 4;
                        return 0;
                    }
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        let pos = "top";
                        if (index === 1) pos = "bottom";
                        else if (index === 2) pos = "left";
                        else if (index === 3) pos = "right";
                        else if (index === 4) pos = "center";
                        launcherCfg.set("position", pos);
                    }
                }
            }

            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_width"
                searchKeywords: "launcher width size pixels horizontal window"
                icon: "󰘖"
                title: I18n.t("guide.launcher.width.title", "Launcher width")
                description: I18n.t("guide.launcher.width.desc", "Total width of the launcher window in pixels")

                NumberSelector {
                    id: widthSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(150)
                    implicitHeight: rootObj.s(32)
                    from: 320
                    to: 1400
                    stepSize: 10
                    decimals: 0
                    suffix: "px"
                    value: launcherTabRoot.currentWidth
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(val) {
                        let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                        let rounded = Math.round(num);
                        if (!isNaN(rounded) && rounded >= 320 && rounded <= 1400 && launcherTabRoot.currentWidth !== rounded) {
                            launcherCfg.setDebounced("width", rounded, 150);
                        }
                    }
                    onTriggered: {
                        launcherCfg.set("width", Math.round(widthSelector.value));
                    }
                }
            }

            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_visible_items"
                searchKeywords: "launcher visible items rows count results list height"
                icon: "󰅫"
                title: I18n.t("guide.launcher.items.title", "Visible items")
                description: I18n.t("guide.launcher.items.desc", "Number of search results displayed simultaneously")

                NumberSelector {
                    id: itemsSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(150)
                    implicitHeight: rootObj.s(32)
                    from: 3
                    to: 15
                    stepSize: 1
                    decimals: 0
                    value: launcherTabRoot.currentItemCount
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(val) {
                        let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                        let rounded = Math.round(num);
                        if (!isNaN(rounded) && rounded >= 3 && rounded <= 15 && launcherTabRoot.currentItemCount !== rounded) {
                            launcherCfg.setDebounced("itemCount", rounded, 150);
                        }
                    }
                    onTriggered: {
                        launcherCfg.set("itemCount", Math.round(itemsSelector.value));
                    }
                }
            }
        }

        SettingsBlob {
            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_smart_ranking"
                searchKeywords: "launcher smart rank frequency recency frecency sort usage apps"
                icon: "󰓥"
                title: I18n.t("guide.launcher.smart_ranking.title", "Smart rank by usage")
                description: I18n.t("guide.launcher.smart_ranking.desc", "Rank apps and widgets based on usage frequency and recency")

                Toggle {
                    id: smartRankToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: launcherTabRoot.currentSmartRanking
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        launcherCfg.set("smartRanking", val);
                    }
                }
            }

            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_terminal_command"
                searchKeywords: "launcher terminal command shell kitty alacritty foot wezterm ghostty exec run"
                icon: "󰆍"
                title: I18n.t("guide.launcher.terminal.title", "Terminal command")
                description: I18n.t("guide.launcher.terminal.desc", "Command prefix used for > executions (e.g. kitty -e, alacritty -e, foot -e)")

                Input {
                    id: terminalInput
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(220)
                    implicitHeight: rootObj.s(32)
                    text: launcherTabRoot.currentTerminalCommand
                    placeholderText: "kitty -e"
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onTextEdited: function(newText) {
                        launcherCfg.setDebounced("terminalCommand", newText, 150);
                    }
                    onAccepted: function(finalText) {
                        launcherCfg.set("terminalCommand", finalText);
                    }
                    onHasFocusChanged: {
                        if (!hasFocus) launcherCfg.flush();
                    }
                }
            }

            SettingsRow {
                rootObj: launcherTabRoot.rootObj
                settingId: "launcher_search_provider"
                searchKeywords: "launcher web search engine browser google duckduckgo bing kagi query"
                icon: "󰖟"
                title: I18n.t("guide.launcher.search.title", "Web search provider")
                description: I18n.t("guide.launcher.search.desc", "Search engine used when a query starts with ?")

                Dropdown {
                    id: searchDropdown
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    options: SearchProviders.names()
                    currentIndex: SearchProviders.indexOf(launcherTabRoot.currentSearchProvider)
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        let id = SearchProviders.PROVIDERS[index].id;
                        launcherCfg.set("searchProvider", id);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: rootObj.s(4)
            Layout.leftMargin: rootObj.s(4)
            Layout.rightMargin: rootObj.s(4)
            spacing: rootObj.s(12)

            Item { Layout.fillWidth: true }

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitHeight: rootObj.s(36)
                horizontalPadding: rootObj.s(16)
                buttonText: I18n.t("guide.launcher.test", "Open launcher")
                buttonIcon: "󰵆"
                iconFontSize: rootObj.s(16)
                textFontSize: rootObj.s(12)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                onClicked: ShellRouter.toggle("launcher")
            }
        }
    }
}
