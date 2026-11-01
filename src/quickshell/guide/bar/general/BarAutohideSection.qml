import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

SettingsGroup {
    id: section
    required property var tab
    rootObj: section.tab.rootObj
    icon: "󰈉"
    title: I18n.t("guide.bar.autohide.title")
    description: I18n.t("guide.bar.autohide.desc")
    expanded: section.tab.autohide

    Toggle {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        checked: section.tab.autohide
        accentColor: ThemeBackend.accent
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(c) {
            section.tab.clearPendingGroup();
            section.tab.autohide = c;
            section.tab.updateBarSettings();
        }
    }

    subSettings: [
        SettingsRow {
            rootObj: section.tab.rootObj
            icon: "󰔛"
            title: I18n.t("guide.bar.timeout.title")
            description: I18n.t("guide.bar.timeout.desc")

            Draggable {
                id: timeoutSlider
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.rightMargin: rootObj.s(8)
                implicitWidth: rootObj.s(220)
                implicitHeight: rootObj.s(18)
                from: 250
                to: 10000
                stepSize: 50
                defaultValue: 1000
                showValueBubble: true
                valueFormatter: function(v) { return Math.round(v) + " ms" }
                value: section.tab.autohideTimeout
                backgroundColor: ThemeBackend.surface0
                accentColor: ThemeBackend.accent
                handleColor: ThemeBackend.text
                handleBorderColor: ThemeBackend.mantle
                onMoved: function(val) {
                    section.tab.clearPendingGroup();
                    let rounded = Math.round(val);
                    if (section.tab.autohideTimeout !== rounded) {
                        section.tab.autohideTimeout = rounded;
                        section.tab.barWidthDebounceTimer.restart();
                    }
                }
                onDragFinished: {
                    section.tab.barWidthDebounceTimer.stop();
                    section.tab.updateBarSettings();
                }
            }
        }
    ]
}
