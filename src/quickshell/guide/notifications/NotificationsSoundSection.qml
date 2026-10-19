import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias soundDropdown: soundDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰂚"
        title: I18n.t("guide.notifications.sound.title")
        description: I18n.t("guide.notifications.sound.desc")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.soundEnabled
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.soundEnabled = c;
                section.tab.updateNotifSetting("sound", c);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        visible: section.tab.soundEnabled
        icon: "󰎆"
        title: I18n.t("guide.notifications.sound_file.title")
        description: I18n.t("guide.notifications.sound_file.desc")

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: rootObj.s(6)
            buttonIcon: "󰉋"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: {
                let userSoundsPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/serpantinum/sounds/notifications");
                let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(userSoundsPath) + "\" && xdg-open \"" + escapeBash(userSoundsPath) + "\""]);
            }
        }

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: rootObj.s(6)
            buttonIcon: "󰐕"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: section.tab.soundPickerPopup.openPicker()
        }

        Dropdown {
            id: soundDropdown
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: rootObj.s(180)
            Layout.preferredHeight: rootObj.s(32)
            options: section.tab.availableSounds
            currentIndex: {
                for (let i = 0; i < section.tab.soundList.length; i++) {
                    if (section.tab.soundList[i].path === section.tab.selectedSound) {
                        return i;
                    }
                }
                return 0;
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
            onSelected: function(index, value) {
                if (index >= 0 && index < section.tab.soundList.length) {
                    let targetPath = section.tab.soundList[index].path;
                    section.tab.selectedSound = targetPath;
                    section.tab.updateNotifSetting("soundFile", targetPath);
                    if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                        Sounds.play(targetPath);
                    }
                }
            }
        }
    }
}
