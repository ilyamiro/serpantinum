import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.battery", "Battery")
    moduleId: "bat"
    styles: card.tab.batStyles
    currentStyle: card.tab.batStyle
    styleSettingId: "bar_bat_style"
    styleKeywords: "battery style look visual classic minimal text button ios android capsule"
    styleIcon: "󰂄"
    styleTitle: I18n.t("guide.bar.bat.style.title", "Battery style")
    styleDescription: I18n.t("guide.bar.bat.style.desc", "Choose the visual appearance of the battery indicator")
    onStyleSelected: id => card.tab.setBatStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string batStyle: variantId !== "" ? variantId : tab.batStyle
            property bool batShowPercent: tab.batShowPercent
            property bool batShowIcon: tab.batShowIcon
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_bat_show_percent"
        searchKeywords: "battery charge percentage percent number"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰚥"
        title: I18n.t("guide.bar.bat.show_percent.title", "Show percentage")
        description: I18n.t("guide.bar.bat.show_percent.desc", "Display the numeric battery charge percentage")
        visible: !card.tab.isSideBar
        searchable: !card.tab.isSideBar
        hiddenByConfig: card.tab.isSideBar

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.batShowPercent
            enabled: !checked || card.tab.batShowIcon
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setBatShowPercent(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_bat_show_icon"
        searchKeywords: "battery icon symbol indicator"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰁹"
        title: I18n.t("guide.bar.bat.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.bat.show_icon.desc", "Display the battery icon or graphic indicator")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.batShowIcon
            enabled: !checked || card.tab.batShowPercent
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setBatShowIcon(c);
            }
        }
    }
}
