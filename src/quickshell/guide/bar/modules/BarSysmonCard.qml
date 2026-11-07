import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.sysmon", "System monitor")
    moduleId: "sysmon"
    previewSideHeight: 150

    widgetComponent: Component {
        BarPreviewWidget {
            property string sysmonStyle: tab.sysmonStyle
            property var sysmonStats: tab.sysmonStats
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_sysmon_style"
        searchKeywords: "sysmon system monitor circle style wave ring"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󱐋"
        title: I18n.t("guide.bar.sysmon.style.title", "Circle style")
        description: I18n.t("guide.bar.sysmon.style.desc", "Visual appearance of the progress rings")

        Switch {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(200)
            implicitHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            options: [
                I18n.t("guide.bar.sysmon.style.wave", "Wave"),
                I18n.t("guide.bar.sysmon.style.circle", "Circle")
            ]
            currentIndex: card.tab.sysmonStyle === "circle" ? 1 : 0
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            onValueChanged: function(index, value) {
                card.tab.setSysmonStyle(index === 1 ? "circle" : "wave");
            }
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
