import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"
import "../../reusables/guide"

DisplayWidgetsState {
    id: displayWidgetsRoot
    subTabIndex: 1

    GuideScrollView {
        rootObj: displayWidgetsRoot.rootObj

        SettingsRow {
            rootObj: displayWidgetsRoot.rootObj
            settingId: "widgets_hide_bar"
            icon: "󰘓"
            title: I18n.t("guide.display.widgets.hide_bar.title", "Hide the bar in the redactor")
            description: I18n.t("guide.display.widgets.hide_bar.desc", "Automatically hide the bar when editing widgets in redactor mode")
            searchKeywords: "widgets redactor hide bar panel"

            Toggle {
                id: hideBarToggle
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                checked: displayWidgetsRoot.currentHideBarInRedactor
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(val) {
                    displayWidgetsRoot.currentHideBarInRedactor = val;
                    displayWidgetsRoot.updateWidgetsSetting("hideBarInRedactor", val);
                }
            }
        }

        SettingsRow {
            rootObj: displayWidgetsRoot.rootObj
            settingId: "widgets_show_distances"
            icon: "󰑭"
            title: I18n.t("guide.display.widgets.show_distances.title", "Show distances")
            description: I18n.t("guide.display.widgets.show_distances.desc", "Show the distances between widgets while moving or resizing them in the redactor")
            searchKeywords: "widgets redactor distances spacing gaps measurements"

            Toggle {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                checked: displayWidgetsRoot.currentShowDistances
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(val) {
                    displayWidgetsRoot.currentShowDistances = val;
                    displayWidgetsRoot.updateWidgetsSetting("showDistances", val);
                }
            }
        }

        Repeater {
            model: displayWidgetsRoot.monitorsList
            delegate: WidgetMonitorCard { tab: displayWidgetsRoot }
        }
    }
}
