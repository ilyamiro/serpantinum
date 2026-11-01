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
                    accentColor: ThemeBackend.accent
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(11)
                    onTriggered: section.tab.imagePicker.openPicker(section.tab.currentAvatarSourcePath)
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
                    accentColor: ThemeBackend.accent
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
            accentColor: ThemeBackend.accent
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
}
