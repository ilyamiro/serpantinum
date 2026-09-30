import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import "../../"
import "../../reusables"

Item {
    id: root
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 2

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Settings {
        id: lockLayoutSettings
        category: "LockScreen"
        property string layout: "default"
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: settingsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: rootObj.s(8)

            SettingsRow {
                rootObj: root.rootObj
                icon: "󰌾"
                title: "Lockscreen layout"
                description: "Choose the visual arrangement used by the lockscreen"

                Dropdown {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(190)
                    implicitHeight: rootObj.s(32)
                    options: ["Default", "Compact", "Focus"]
                    currentIndex: lockLayoutSettings.layout === "compact" ? 1 : (lockLayoutSettings.layout === "focus" ? 2 : 0)
                    placeholderText: "Select layout..."
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onSelected: function(index, value) {
                        lockLayoutSettings.layout = index === 1 ? "compact" : (index === 2 ? "focus" : "default");
                    }
                }
            }

            SettingsRow {
                rootObj: root.rootObj
                icon: "󰍹"
                title: "Shared security flow"
                description: "All layouts use the same PAM authentication, password handling, and unlock animation"
                titlePixelSize: 12
                descriptionPixelSize: 10
            }
        }
    }
}
