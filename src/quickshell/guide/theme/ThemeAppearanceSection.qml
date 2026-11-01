import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias fontDropdown: fontDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "font"
        icon: "󰛖"
        title: I18n.t("guide.theme.font.title")
        description: I18n.t("guide.theme.font.desc")
        searchKeywords: "font typeface family typography text"

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: rootObj.s(6)
            buttonIcon: "󰉋"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: {
                let userFontsPath = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/serpantinum/fonts");
                let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(userFontsPath) + "\" && xdg-open \"" + escapeBash(userFontsPath) + "\""]);
            }
        }

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: rootObj.s(6)
            buttonIcon: "󰐕"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: section.tab.fontPickerPopup.openPicker()
        }

        Dropdown {
            id: fontDropdown
            Layout.preferredWidth: rootObj.s(220)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            options: section.tab.availableFonts
            currentIndex: options.indexOf(section.tab.currentFontFamily) >= 0 ? options.indexOf(section.tab.currentFontFamily) : 0
            placeholderText: I18n.t("guide.theme.font.select")
            fontFamily: ThemeBackend.fontFamily
            useOptionAsFontFamily: true
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
                section.tab.currentFontFamily = value;
                section.tab.updateFontSetting();
            }
            onClicked: {
                section.tab.loadAvailableFonts();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "border_radius"
        icon: "󰞁"
        title: I18n.t("guide.theme.radius.title")
        description: I18n.t("guide.theme.radius.desc")
        searchKeywords: "border radius corner round curvature rounding px"

        NumberSelector {
            id: radiusSelector
            implicitWidth: rootObj.s(150)
            implicitHeight: rootObj.s(32)
            from: 0
            to: 64
            stepSize: 1
            decimals: 0
            suffix: "px"
            value: section.tab.currentBorderRadius
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            buttonColor: ThemeBackend.surface1
            buttonTextColor: ThemeBackend.text
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontFamily: ThemeBackend.fontFamily
            fontPixelSize: rootObj.s(11)
            onValueChanged: function(val) {
                let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                let rounded = Math.round(num);
                let snapped = section.tab.getSnappedRadius(rounded);
                if (!isNaN(snapped) && snapped >= 0 && snapped <= 64 && section.tab.currentBorderRadius !== snapped) {
                    section.tab.currentBorderRadius = snapped;
                    section.tab.borderRadiusDebounceTimer.restart();
                }
            }
            onTriggered: {
                let rounded = Math.round(radiusSelector.value);
                let snapped = section.tab.getSnappedRadius(rounded);
                section.tab.currentBorderRadius = snapped;
                section.tab.updateBorderRadiusSetting();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "element_opacity"
        visible: !(section.tab.currentBlurBackground && section.tab.currentBlurStyle === "liquid")
        icon: "󰃟"
        title: I18n.t("guide.theme.element_opacity.title", "Element opacity")
        description: I18n.t("guide.theme.element_opacity.desc", "Opacity of the bar, dock, widgets and every other shell element")
        searchKeywords: "element opacity transparency transparent translucent alpha bar dock widgets"

        Draggable {
            id: elementOpacitySlider
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 0
            to: 100
            stepSize: 1
            defaultValue: 100
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v) + "%" }
            value: section.tab.currentElementOpacity
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                let rounded = Math.round(val);
                if (section.tab.currentElementOpacity !== rounded) {
                    section.tab.currentElementOpacity = rounded;
                    section.tab.elementOpacityDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.elementOpacityDebounceTimer.stop();
                section.tab.updateElementOpacitySetting();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "blur_background"
        icon: "󰂵"
        title: I18n.t("guide.theme.blur_background.title", "Add a blurred wallpaper background")
        description: I18n.t("guide.theme.blur_background.desc", "Blur the wallpaper behind every element that uses transparency")
        searchKeywords: "blur blurred wallpaper background frosted glass liquid glass apple transparency opacity"

        Switch {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(200)
            implicitHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            enabled: section.tab.currentBlurBackground
            options: [
                I18n.t("guide.theme.blur_background.style.blur", "Blur"),
                I18n.t("guide.theme.blur_background.style.liquid", "Liquid glass")
            ]
            currentIndex: section.tab.currentBlurStyle === "liquid" ? 1 : 0
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            onValueChanged: function(index, value) {
                section.tab.updateBlurStyleSetting(index === 1 ? "liquid" : "blur");
            }
        }

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.currentBlurBackground
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(val) {
                section.tab.updateBlurBackgroundSetting(val);
            }
        }
    }

}
