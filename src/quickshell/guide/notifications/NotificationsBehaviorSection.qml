import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_dnd"
        searchKeywords: "notifications do not disturb dnd silent mute pause hide"
        icon: "󰂛"
        title: I18n.t("guide.notifications.dnd.title")
        description: I18n.t("guide.notifications.dnd.desc")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.dnd
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.dnd = c;
                section.tab.updateNotifSetting("dnd", c);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_empty_graphic"
        searchKeywords: "notifications center empty illustration graphic image placeholder"
        icon: "󰋑"
        title: I18n.t("guide.notifications.empty_graphic.title")
        description: I18n.t("guide.notifications.empty_graphic.desc")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.showEmptyGraphic
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.showEmptyGraphic = c;
                section.tab.updateNotifSetting("showEmptyGraphic", c);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_empty_graphic_file"
        searchKeywords: "notifications center empty custom image picture gif file"
        visible: section.tab.showEmptyGraphic
        icon: "󰋩"
        title: I18n.t("guide.notifications.empty_graphic_file.title")
        description: section.tab.emptyGraphicFile !== ""
            ? section.tab.emptyGraphicFile.substring(section.tab.emptyGraphicFile.lastIndexOf("/") + 1)
            : I18n.t("guide.notifications.empty_graphic_file.default")

        IconButton {
            visible: section.tab.emptyGraphicFile !== ""
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: rootObj.s(6)
            buttonIcon: "󰜉"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: {
                section.tab.emptyGraphicFile = "";
                section.tab.updateNotifSetting("emptyGraphicFile", "");
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
            onClicked: section.tab.emptyGraphicPicker.openPicker(section.tab.emptyGraphicFile)
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_empty_graphic_size"
        searchKeywords: "notifications center empty image size small medium large fill"
        visible: section.tab.showEmptyGraphic
        icon: "󰩨"
        title: I18n.t("guide.notifications.empty_graphic_size.title")
        description: I18n.t("guide.notifications.empty_graphic_size.desc")

        Dropdown {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: rootObj.s(140)
            Layout.preferredHeight: rootObj.s(32)
            options: section.tab.emptyGraphicSizes.map(k => I18n.t("guide.notifications.empty_graphic_size." + k))
            currentIndex: {
                let i = section.tab.emptyGraphicSizes.indexOf(section.tab.emptyGraphicSize);
                return i >= 0 ? i : 1;
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
                let key = section.tab.emptyGraphicSizes[index];
                if (!key) return;
                section.tab.emptyGraphicSize = key;
                section.tab.updateNotifSetting("emptyGraphicSize", key);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_right_click_close"
        searchKeywords: "notifications right click dismiss close mouse button"
        icon: "󰍽"
        title: I18n.t("guide.notifications.right_click_close.title", "Close with right click")
        description: I18n.t("guide.notifications.right_click_close.desc", "Dismiss a notification by right-clicking it")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.rightClickClose
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.rightClickClose = c;
                section.tab.updateNotifSetting("rightClickClose", c);
            }
        }
    }
}
