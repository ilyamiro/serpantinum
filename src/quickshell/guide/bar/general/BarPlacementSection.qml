import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias barPosDropdown: barPosDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󱂬"
        title: I18n.t("guide.bar.position.title")
        description: I18n.t("guide.bar.position.desc")

        Dropdown {
            id: barPosDropdown
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(180)
            implicitHeight: rootObj.s(32)
            options: [I18n.t("guide.bar.position.top"), I18n.t("guide.bar.position.bottom"), I18n.t("guide.bar.position.left"), I18n.t("guide.bar.position.right")]
            currentIndex: section.tab.barPosition === "bottom" ? 1 : (section.tab.barPosition === "left" ? 2 : (section.tab.barPosition === "right" ? 3 : 0))
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            hoverColor: ThemeBackend.surface1
            dropdownColor: ThemeBackend.surface0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onValueChanged: function(index, value) {
                section.tab.clearPendingGroup();
                if (index === 0) section.tab.barPosition = "top";
                else if (index === 1) section.tab.barPosition = "bottom";
                else if (index === 2) section.tab.barPosition = "left";
                else if (index === 3) section.tab.barPosition = "right";
                section.tab.updateBarSettings();
            }
        }
    }

    SettingsRow {
        id: widthInnerBox
        rootObj: section.tab.rootObj
        icon: "󰘖"
        title: {
            if (section.tab.barPosition === "left" || section.tab.barPosition === "right") {
                let h = I18n.t("guide.bar.height.title");
                if (h && h !== "guide.bar.height.title") return h;
                let w = I18n.t("guide.bar.width.title");
                if (w && w.indexOf("Width") !== -1) return w.replace("Width", "Height");
                if (w && w.indexOf("width") !== -1) return w.replace("width", "height");
                return w;
            }
            return I18n.t("guide.bar.width.title");
        }
        description: {
            if (section.tab.barPosition === "left" || section.tab.barPosition === "right") {
                let h = I18n.t("guide.bar.height.desc");
                if (h && h !== "guide.bar.height.desc") return h;
                let w = I18n.t("guide.bar.width.desc");
                if (w && w.indexOf("Width") !== -1) return w.replace("Width", "Height");
                if (w && w.indexOf("width") !== -1) return w.replace("width", "height");
                return w;
            }
            return I18n.t("guide.bar.width.desc");
        }

        Draggable {
            id: barWidthSlider
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 5
            to: 100
            stepSize: 1
            defaultValue: 100
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v) + "%" }
            value: section.tab.currentBarWidth
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                section.tab.clearPendingGroup();
                let rounded = Math.round(val);
                if (section.tab.currentBarWidth !== rounded) {
                    section.tab.currentBarWidth = rounded;
                    section.tab.barWidthDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.barWidthDebounceTimer.stop();
                section.tab.updateBarSettings();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰘖"
        title: I18n.t("guide.bar.thickness.title", "Bar thickness")
        description: I18n.t("guide.bar.thickness.desc", "Change how thick the bar is, modules scale to fit")

        Draggable {
            id: barThicknessSlider
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 28
            to: 48
            stepSize: 1
            defaultValue: 40
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v / 40 * 100) + "%" }
            value: section.tab.currentBarThickness
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                section.tab.clearPendingGroup();
                let rounded = Math.round(val);
                if (section.tab.currentBarThickness !== rounded) {
                    section.tab.currentBarThickness = rounded;
                    section.tab.barWidthDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.barWidthDebounceTimer.stop();
                section.tab.updateBarSettings();
            }
        }
    }

    SettingsRow {
        id: centerByEdgesBox
        rootObj: section.tab.rootObj
        icon: "󰉹"
        title: I18n.t("guide.bar.center_by_edges.title")
        description: (section.tab.barPosition === "left" || section.tab.barPosition === "right") ? I18n.t("guide.bar.center_by_edges.desc_vertical") : I18n.t("guide.bar.center_by_edges.desc")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.centerByEdges
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.clearPendingGroup();
                section.tab.centerByEdges = c;
                section.tab.updateBarSettings();
            }
        }
    }
}
