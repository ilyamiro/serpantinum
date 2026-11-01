import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.volume", "Volume")
    moduleId: "vol"
    styles: card.tab.volStyles
    currentStyle: card.tab.volStyle
    styleSettingId: "bar_vol_style"
    styleKeywords: "volume audio style look button text layout"
    styleIcon: "󰕾"
    styleTitle: I18n.t("guide.bar.vol.style.title", "Style")
    styleDescription: I18n.t("guide.bar.vol.style.desc", "Choose the visual appearance of the volume module")
    onStyleSelected: id => card.tab.setVolStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string volStyle: variantId !== "" ? variantId : tab.volStyle
            property bool volShowIcon: tab.volShowIcon
            property bool volShowPercent: tab.volShowPercent
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_vol_show_icon"
        searchKeywords: "volume audio sound icon symbol indicator"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰕾"
        title: I18n.t("guide.bar.vol.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.vol.show_icon.desc", "Display the volume speaker icon")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.volShowIcon
            enabled: !checked || card.tab.volShowPercent
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setVolShowIcon(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_vol_show_percent"
        searchKeywords: "volume percentage percent level audio sound"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰚥"
        title: I18n.t("guide.bar.vol.show_percent.title", "Show percentage")
        description: I18n.t("guide.bar.vol.show_percent.desc", "Display the numeric audio volume percentage")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.volShowPercent
            enabled: !checked || card.tab.volShowIcon
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setVolShowPercent(c);
            }
        }
    }
}
