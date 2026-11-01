import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.actions", "Menu")
    moduleId: "left"
    styles: card.tab.menuStyles
    currentStyle: card.tab.menuStyle
    styleSettingId: "bar_menu_style"
    styleKeywords: "menu style look button icon layout"
    styleIcon: "󰒓"
    styleTitle: I18n.t("guide.bar.menu.style.title", "Style")
    styleDescription: I18n.t("guide.bar.menu.style.desc", "Choose the visual appearance of the menu module")
    onStyleSelected: id => card.tab.setMenuStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string menuStyle: variantId !== "" ? variantId : tab.menuStyle
            property bool menuShowSettings: tab.menuShowSettings
            property bool menuShowLauncher: tab.menuShowLauncher
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_menu_show_settings"
        searchKeywords: "menu settings gear guide icon button"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰒓"
        title: I18n.t("guide.bar.menu.show_settings.title", "Show settings icon")
        description: I18n.t("guide.bar.menu.show_settings.desc", "Display the button that opens settings")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.menuShowSettings
            enabled: !checked || card.tab.menuShowLauncher
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setMenuShowSettings(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_menu_show_launcher"
        searchKeywords: "menu launcher search apps icon button"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍉"
        title: I18n.t("guide.bar.menu.show_launcher.title", "Show launcher icon")
        description: I18n.t("guide.bar.menu.show_launcher.desc", "Display the search button that opens the launcher")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.menuShowLauncher
            enabled: !checked || card.tab.menuShowSettings
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setMenuShowLauncher(c);
            }
        }
    }
}
