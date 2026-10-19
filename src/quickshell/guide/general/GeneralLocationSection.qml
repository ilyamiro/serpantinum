import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias latInput: latInput
    property alias lonInput: lonInput
    property alias weatherIntervalSelector: weatherIntervalSelector
    property alias weatherUnitDropdown: weatherUnitDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰍎"
        title: I18n.t("guide.general.location.title")
        description: I18n.t("guide.general.location.desc")
        searchKeywords: "location coordinates city latitude longitude gps"
        showDivider: section.tab.isLocEditOpen
        dividerColor: Qt.alpha(ThemeBackend.surface1, 0.2)
        innerSpacing: section.tab.isLocEditOpen ? rootObj.s(12) : 0
        Behavior on innerSpacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        animateHeight: true
        animationDuration: 300

        LoaderIcon {
            id: detectLoader
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            running: Location.isDetecting
            visible: Location.isDetecting
            accentColor: ThemeBackend.mauve
        }

        ClickButton {
            implicitHeight: rootObj.s(32)
            buttonText: "Auto-detect"
            buttonIcon: "󰢹"
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: rootObj.s(12)
            iconFontSize: rootObj.s(15)
            textFontSize: rootObj.s(12)
            onTriggered: {
                section.tab.isLocEditOpen = false;
                Location.detectAuto();
            }
        }

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰏫"
            iconFontSize: rootObj.s(16)
            accentColor: section.tab.isLocEditOpen ? ThemeBackend.surface1 : ThemeBackend.surface0
            textColor: section.tab.isLocEditOpen ? ThemeBackend.mauve : ThemeBackend.text
            onClicked: section.tab.isLocEditOpen = !section.tab.isLocEditOpen
        }

        ClickButton {
            implicitHeight: rootObj.s(32)
            buttonText: Location.city
            buttonIcon: "󰍎"
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: rootObj.s(12)
            iconFontSize: rootObj.s(15)
            textFontSize: rootObj.s(12)
            onTriggered: section.tab.locationPopup.open()
        }

        bottomContent: [
            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(12)
                visible: section.tab.isLocEditOpen || opacity > 0.01
                opacity: section.tab.isLocEditOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Input {
                    id: latInput
                    Layout.fillWidth: true
                    placeholderText: "Latitude"
                    text: Location.latitude !== 0.0 ? Location.latitude.toString() : (Location.locationData.latitude !== undefined ? Location.locationData.latitude.toString() : "")
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    verticalPadding: rootObj.s(6)
                    fontPixelSize: rootObj.s(12)
                }

                Input {
                    id: lonInput
                    Layout.fillWidth: true
                    placeholderText: "Longitude"
                    text: Location.longitude !== 0.0 ? Location.longitude.toString() : (Location.locationData.longitude !== undefined ? Location.locationData.longitude.toString() : "")
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    verticalPadding: rootObj.s(6)
                    fontPixelSize: rootObj.s(12)
                }

                ClickButton {
                    Layout.preferredHeight: rootObj.s(32)
                    buttonText: "Apply"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(16)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        Location.setManual(latInput.text, lonInput.text);
                    }
                }
            }
        ]
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰔛"
        title: I18n.t("guide.general.weatherinterval.title") || "Weather Polling Interval"
        description: I18n.t("guide.general.weatherinterval.desc") || "Polling frequency in minutes"

        NumberSelector {
            id: weatherIntervalSelector
            implicitWidth: rootObj.s(180)
            implicitHeight: rootObj.s(32)
            from: 1
            to: 1440
            stepSize: 1
            decimals: 0
            suffix: " min"
            value: section.tab.weatherInterval
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            buttonColor: ThemeBackend.surface1
            buttonTextColor: ThemeBackend.text
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onValueChanged: {
                let val = Math.round(value);
                if (val !== section.tab.weatherInterval && val >= 1) {
                    section.tab.weatherInterval = val;
                    section.tab.updateGeneralSettings();
                    if (typeof Weather !== "undefined") {
                        Weather.refreshInterval = section.tab.weatherInterval * 60000;
                    }
                }
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰔏"
        title: I18n.t("guide.general.weatherunit.title") || "Weather Unit"
        description: I18n.t("guide.general.weatherunit.desc") || "Temperature scale for weather displays"

        Dropdown {
            id: weatherUnitDropdown
            implicitWidth: rootObj.s(180)
            implicitHeight: rootObj.s(32)
            options: section.tab.weatherUnitNames
            currentIndex: {
                let idx = section.tab.weatherUnitCodes.indexOf(section.tab.weatherUnit);
                return idx !== -1 ? idx : 0;
            }
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
                section.tab.weatherUnit = section.tab.weatherUnitCodes[index];
                section.tab.updateGeneralSettings();
                if (typeof Weather !== "undefined") {
                    Weather.unit = section.tab.weatherUnit;
                }
            }
        }
    }
}
