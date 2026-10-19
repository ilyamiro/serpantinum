import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"
import "../../reusables/guide"

DisplayWidgetsState {
    id: displayWidgetsRoot
    subTabIndex: 1

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: widgetsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: widgetsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_hide_bar"
                icon: "󰘓"
                title: I18n.t("guide.display.widgets.hide_bar.title", "Hide Bar in Redactor")
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

            Repeater {
                model: displayWidgetsRoot.monitorsList
                delegate: WidgetMonitorCard { tab: displayWidgetsRoot }
            }
        }
    }
}
