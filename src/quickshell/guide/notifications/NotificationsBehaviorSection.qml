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
