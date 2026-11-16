import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias avatarDropdown: avatarDropdown
    property alias langDropdown: langDropdown
    property alias keyboardLayoutDropdown: keyboardLayoutDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰀄"
        title: I18n.t("guide.general.avatar.title") || "Profile picture"
        description: I18n.t("guide.general.avatar.desc") || "Choose profile picture"
        searchKeywords: "avatar profile picture photo image"

        RowLayout {
            spacing: rootObj.s(12)

            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: rootObj.s(8)

                ClickButton {
                    Layout.alignment: Qt.AlignRight
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.avatar.select")
                    buttonIcon: "󰉋"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(11)
                    onTriggered: section.tab.openImagePicker(section.tab.currentAvatarSourcePath)
                }

                Dropdown {
                    id: avatarDropdown
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: rootObj.s(280)
                    implicitHeight: rootObj.s(32)
                    options: section.tab.currentAvatarSourcePath !== "" ? [section.tab.currentAvatarSourcePath] : []
                    currentIndex: 0
                    isPathSelector: true
                    fuzzySearch: true
                    placeholderText: section.tab.currentAvatarSourcePath !== "" ? section.tab.currentAvatarSourcePath : "Select image path..."
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        let gs = Object.assign({}, section.tab.generalSettings);
                        gs.avatarPath = value;
                        section.tab.generalSettings = gs;
                        section.tab.updateGeneralSettings();
                    }
                    onSelected: function(index, value) {
                        let gs = Object.assign({}, section.tab.generalSettings);
                        gs.avatarPath = value;
                        section.tab.generalSettings = gs;
                        section.tab.updateGeneralSettings();
                    }
                }
            }

            AvatarPreview {
                tab: section.tab
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰗊"
        title: I18n.t("guide.general.language.title")
        description: I18n.t("guide.general.language.desc")

        Dropdown {
            id: langDropdown
            implicitWidth: rootObj.s(180)
            implicitHeight: rootObj.s(32)
            options: section.tab.languageNames
            currentIndex: {
                let idx = section.tab.languageCodes.indexOf(section.tab.currentLanguage);
                return idx !== -1 ? idx : 0;
            }
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            hoverColor: ThemeBackend.surface1
            dropdownColor: ThemeBackend.surface0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onValueChanged: function(index, value) {
                section.tab.currentLanguage = section.tab.languageCodes[index];
                section.tab.updateGeneralSettings();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        visible: ["hyprland", "niri", "sway", "mango"].includes(Compositor.name)
        icon: "󰌌"
        title: I18n.t("guide.general.keyboard_layout.title")
        description: I18n.t("guide.general.keyboard_layout.desc")
        searchKeywords: "keyboard layout xkb typing input language"

        ColumnLayout {
            spacing: rootObj.s(8)

            RowLayout {
                spacing: rootObj.s(8)

                Dropdown {
                    id: keyboardLayoutDropdown
                    Layout.fillWidth: true
                    implicitWidth: rootObj.s(240)
                    implicitHeight: rootObj.s(32)
                    options: section.tab.keyboardLayoutNames
                    currentIndex: section.tab.selectedKeyboardLayoutIndex
                    fuzzySearch: true
                    placeholderText: I18n.t("guide.general.keyboard_layout.available_title")
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        section.tab.selectedKeyboardLayoutIndex = index;
                    }
                }

                ClickButton {
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.keyboard_layout.add")
                    buttonIcon: "󰐕"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    iconFontSize: rootObj.s(14)
                    textFontSize: rootObj.s(11)
                    enabled: section.tab.keyboardLayoutCatalog.length > 0 && section.tab.keyboardLayoutsInitialized
                    onTriggered: section.tab.addKeyboardLayout(section.tab.selectedKeyboardLayoutIndex)
                }
            }

            Text {
                visible: section.tab.keyboardLayouts.length > 0
                text: I18n.t("guide.general.keyboard_layout.active_title")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(10)
                font.weight: Font.DemiBold
            }

            Text {
                visible: section.tab.keyboardLayouts.length === 0
                text: I18n.t("guide.general.keyboard_layout.empty")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(10)
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: section.tab.keyboardLayouts
                delegate: RowLayout {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: rootObj.s(8)

                    Text {
                        Layout.fillWidth: true
                        text: section.tab.keyboardLayoutLabel(modelData)
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        elide: Text.ElideRight
                    }

                    ClickButton {
                        implicitHeight: rootObj.s(28)
                        buttonText: I18n.t("guide.general.keyboard_layout.remove")
                        accentColor: ThemeBackend.red
                        textColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: rootObj.s(10)
                        textFontSize: rootObj.s(10)
                        enabled: section.tab.keyboardLayouts.length > 1
                        onTriggered: section.tab.removeKeyboardLayout(index)
                    }
                }
            }
        }
    }

}
