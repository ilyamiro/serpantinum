import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.keyboard", "Keyboard")
    moduleId: "kb"
    styles: card.tab.kbStyles
    currentStyle: card.tab.kbStyle
    styleSettingId: "bar_kb_style"
    styleKeywords: "keyboard layout style look button text layout"
    styleIcon: "󰌌"
    styleTitle: I18n.t("guide.bar.kb.style.title", "Style")
    styleDescription: I18n.t("guide.bar.kb.style.desc", "Choose the visual appearance of the keyboard module")
    onStyleSelected: id => card.tab.setKbStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string kbStyle: variantId !== "" ? variantId : tab.kbStyle
            property bool kbShowIcon: tab.kbShowIcon
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_kb_show_icon"
        searchKeywords: "keyboard layout icon symbol indicator"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰌌"
        title: I18n.t("guide.bar.kb.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.kb.show_icon.desc", "Display the keyboard layout icon")
        visible: !card.tab.isSideBar
        searchable: !card.tab.isSideBar
        hiddenByConfig: card.tab.isSideBar

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.kbShowIcon
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setKbShowIcon(c);
            }
        }
    }
}
