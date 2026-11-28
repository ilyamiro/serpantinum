import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.sysmon", "System monitor")
    moduleId: "sysmon"
    previewSideHeight: 150
    styles: card.tab.sysmonStyles
    currentStyle: card.tab.sysmonStyle
    styleSettingId: "bar_sysmon_style"
    styleKeywords: "sysmon system monitor circle style wave ring"
    styleIcon: "󱐋"
    styleTitle: I18n.t("guide.bar.sysmon.style.title", "Circle style")
    styleDescription: I18n.t("guide.bar.sysmon.style.desc", "Visual appearance of the progress rings")
    stylesFirst: true
    onStyleSelected: id => card.tab.setSysmonStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string sysmonStyle: variantId !== "" ? variantId : tab.sysmonStyle
            property var sysmonStats: tab.sysmonStats
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_sysmon_stats"
        searchKeywords: "sysmon stats order reorder drag cpu processor ram memory temperature disk storage show hide"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍛"
        title: I18n.t("guide.bar.sysmon.items.title", "Stats")
        description: I18n.t("guide.bar.sysmon.items.desc", "Drag stats to reorder them, or move them to available to hide them")

        bottomContent: DragChipEditor {
            rootObj: card.rootObj
            items: [
                { id: "cpu", icon: "󰍛", label: I18n.t("guide.bar.sysmon.items.cpu", "CPU") },
                { id: "ram", icon: "󰘚", label: I18n.t("guide.bar.sysmon.items.ram", "Memory") },
                { id: "temp", icon: "󰔏", label: I18n.t("guide.bar.sysmon.items.temp", "Temperature") },
                { id: "disk", icon: "󰋊", label: I18n.t("guide.bar.sysmon.items.disk", "Disk") }
            ]
            lists: [
                { key: "shown", title: I18n.t("guide.bar.config.shown", "Shown"), ids: card.tab.sysmonStats },
                { key: "available", title: I18n.t("guide.bar.config.available", "Available") }
            ]
            onEdited: result => card.tab.setSysmonStats(result.shown)
        }
    }
}
