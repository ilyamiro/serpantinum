import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../bar"
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
            property var menuItems: tab.menuItems
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_menu_items"
        searchKeywords: "menu buttons order reorder drag settings launcher night light caffeine shuffle wallpaper show hide"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍜"
        title: I18n.t("guide.bar.menu.items.title", "Buttons")
        description: I18n.t("guide.bar.menu.items.desc", "Drag buttons to reorder them, or move them to available to hide them")

        bottomContent: DragChipEditor {
            rootObj: card.rootObj
            items: BarModuleRegistry.menuItemIds.map(id => ({
                id: id,
                icon: BarModuleRegistry.menuItemIcon(id),
                label: I18n.t("guide.bar.menu.items." + (id === "nightlight" ? "night_light" : id))
            }))
            lists: [
                { key: "shown", title: I18n.t("guide.bar.config.shown", "Shown"), ids: card.tab.menuItems, minCount: 1 },
                { key: "available", title: I18n.t("guide.bar.config.available", "Available") }
            ]
            onEdited: result => card.tab.setMenuItems(result.shown)
        }
    }
}
