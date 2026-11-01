import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.bluetooth", "Bluetooth")
    moduleId: "bt"
    styles: card.tab.btStyles
    currentStyle: card.tab.btStyle
    styleSettingId: "bar_bt_style"
    styleKeywords: "bluetooth style look button text layout"
    styleIcon: "󰂲"
    styleTitle: I18n.t("guide.bar.bt.style.title", "Style")
    styleDescription: I18n.t("guide.bar.bt.style.desc", "Choose the visual appearance of the bluetooth module")
    onStyleSelected: id => card.tab.setBtStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string btStyle: variantId !== "" ? variantId : tab.btStyle
            property bool btShowIcon: tab.btShowIcon
            property bool btShowName: tab.btShowName
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_bt_show_icon"
        searchKeywords: "bluetooth icon symbol indicator"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰂲"
        title: I18n.t("guide.bar.bt.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.bt.show_icon.desc", "Display the bluetooth status icon")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.btShowIcon
            enabled: !checked || card.tab.btShowName
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setBtShowIcon(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_bt_show_name"
        searchKeywords: "bluetooth device name title connected"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰂯"
        title: I18n.t("guide.bar.bt.show_name.title", "Show name")
        description: I18n.t("guide.bar.bt.show_name.desc", "Display the connected bluetooth device name")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.btShowName
            enabled: !checked || card.tab.btShowIcon
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setBtShowName(c);
            }
        }
    }
}
