import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.network", "Network")
    moduleId: "wifi"
    styles: card.tab.wifiStyles
    currentStyle: card.tab.wifiStyle
    styleSettingId: "bar_wifi_style"
    styleKeywords: "network wifi style look button text layout"
    styleIcon: "󰤨"
    styleTitle: I18n.t("guide.bar.wifi.style.title", "Style")
    styleDescription: I18n.t("guide.bar.wifi.style.desc", "Choose the visual appearance of the network module")
    onStyleSelected: id => card.tab.setWifiStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string wifiStyle: variantId !== "" ? variantId : tab.wifiStyle
            property bool wifiShowIcon: tab.wifiShowIcon
            property bool wifiShowName: tab.wifiShowName
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_wifi_show_icon"
        searchKeywords: "network wifi ethernet icon symbol indicator"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰤨"
        title: I18n.t("guide.bar.wifi.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.wifi.show_icon.desc", "Display the network icon or signal indicator")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.wifiShowIcon
            enabled: !checked || card.tab.wifiShowName
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setWifiShowIcon(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_wifi_show_name"
        searchKeywords: "network wifi ethernet ssid name title"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰤥"
        title: I18n.t("guide.bar.wifi.show_name.title", "Show name")
        description: I18n.t("guide.bar.wifi.show_name.desc", "Display the network SSID or connection status text")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.wifiShowName
            enabled: !checked || card.tab.wifiShowIcon
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setWifiShowName(c);
            }
        }
    }
}
