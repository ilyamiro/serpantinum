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
            property bool showCpu: card.tab.sysmonShowCpu
            property bool showGpu: card.tab.sysmonShowGpu
            property bool hackerstatsShowCpu: card.tab.sysmonShowCpu
            property bool hackerstatsShowGpu: card.tab.sysmonShowGpu
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_sysmon_enabled"
        searchKeywords: "sysmon hackerstats system monitor enable show bar"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍛"
        title: I18n.t("guide.bar.sysmon.enabled.title", "Show on bar")
        description: I18n.t("guide.bar.sysmon.enabled.desc", "Display the system monitor widget on the bar")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.sysmonEnabled
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setSysmonEnabled(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_sysmon_cpu"
        searchKeywords: "sysmon hackerstats cpu processor load usage"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍛"
        title: I18n.t("guide.bar.sysmon.cpu.title", "CPU usage")
        description: I18n.t("guide.bar.sysmon.cpu.desc", "Display processor utilization percentage")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.sysmonShowCpu
            enabled: !checked || card.tab.sysmonShowGpu
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setSysmonShowCpu(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_sysmon_gpu"
        searchKeywords: "sysmon hackerstats gpu graphics video load usage"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰢮"
        title: I18n.t("guide.bar.sysmon.gpu.title", "GPU usage")
        description: I18n.t("guide.bar.sysmon.gpu.desc", "Display graphics processor utilization percentage")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.sysmonShowGpu
            enabled: !checked || card.tab.sysmonShowCpu
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setSysmonShowGpu(c);
            }
        }
    }
}
