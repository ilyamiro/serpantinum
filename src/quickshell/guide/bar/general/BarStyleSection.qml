import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsGroup {
        rootObj: section.tab.rootObj
        icon: "󰏘"
        title: I18n.t("guide.bar.style.title")
        description: I18n.t("guide.bar.style.desc")
        expanded: section.tab.barStyle === "solid" || section.tab.barStyle === "fill"

        Switch {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(210)
            implicitHeight: rootObj.s(32)
            options: [I18n.t("guide.bar.style.modular"), I18n.t("guide.bar.style.solid"), I18n.t("guide.bar.style.fill")]
            currentIndex: section.tab.barStyle === "fill" ? 2 : (section.tab.barStyle === "solid" ? 1 : 0)
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface0
            textColor: ThemeBackend.subtext0
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onToggled: function(index) {
                section.tab.clearPendingGroup();
                if (index === 0) section.tab.barStyle = "modular";
                else if (index === 1) section.tab.barStyle = "solid";
                else if (index === 2) section.tab.barStyle = "fill";
                section.tab.updateBarSettings();
            }
        }

        subSettings: [
            SettingsRow {
                rootObj: section.tab.rootObj
                icon: "󰍜"
                title: I18n.t("guide.bar.distinct_pills.title")
                description: I18n.t("guide.bar.distinct_pills.desc")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: section.tab.distinctPills
                    accentColor: ThemeBackend.accent
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        section.tab.clearPendingGroup();
                        section.tab.distinctPills = c;
                        section.tab.updateBarSettings();
                    }
                }
            }
        ]
    }
}
