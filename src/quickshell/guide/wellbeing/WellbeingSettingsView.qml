import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../reusables/buttons"
import "../../reusables/inputs"

Flickable {
    id: sv
    required property var tab
    readonly property var rootObj: tab.rootObj

    readonly property var limitedClasses: Object.keys(tab.appLimits)

    anchors.fill: parent
    contentWidth: width
    contentHeight: settingsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    opacity: tab.settingsViewFocus
    visible: opacity > 0
    transform: Translate { y: rootObj.s(40) * (1 - sv.tab.settingsViewFocus) }

    ScrollBar.vertical: ScrollBar {
        active: sv.moving
        width: rootObj.s(4)
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
    }

    component AppLabel: RowLayout {
        required property var view
        id: appLabel
        property string appClass: ""
        readonly property var info: view.tab.appInfo(appClass)
        spacing: view.rootObj.s(10)

        Rectangle {
            Layout.preferredWidth: view.rootObj.s(32)
            Layout.preferredHeight: view.rootObj.s(32)
            radius: Math.round(view.rootObj.s(32) * 0.28)
            color: ThemeBackend.surface0

            Image {
                anchors.fill: parent
                anchors.margins: view.rootObj.s(4)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                mipmap: true
                visible: status === Image.Ready
                source: view.tab.iconSource(appLabel.info.icon)
            }

            Text {
                anchors.centerIn: parent
                visible: !appLabel.info.icon
                text: appLabel.info.name ? appLabel.info.name.charAt(0).toUpperCase() : "?"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: view.rootObj.s(13)
                font.bold: true
                color: view.tab.textMain
            }
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: ThemeBackend.fontFamily
            font.pixelSize: view.rootObj.s(13)
            color: ThemeBackend.text
            text: appLabel.info.name
        }
    }

    component LimitStepper: NumberSelector {
        required property var view
        implicitWidth: view.rootObj.s(150)
        implicitHeight: view.rootObj.s(32)
        stepSize: 15
        decimals: 0
        suffix: " min"
        baseColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        buttonColor: ThemeBackend.surface1
        buttonTextColor: ThemeBackend.text
        textColor: ThemeBackend.text
        subTextColor: ThemeBackend.subtext0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: view.rootObj.s(11)
    }

    component AddButton: IconButton {
        required property var view
        size: view.rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰐕"
        iconFontSize: view.rootObj.s(15)
        accentColor: ThemeBackend.mauve
        textColor: ThemeBackend.crust
    }

    component RemoveButton: DeleteButton {
        required property var view
        Layout.preferredWidth: view.rootObj.s(32)
        Layout.preferredHeight: view.rootObj.s(32)
        size: view.rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        iconFontSize: view.rootObj.s(15)
        accentColor: ThemeBackend.surface1
    }

    component EmptyHint: Item {
        required property var view
        property alias text: hintText.text
        Layout.fillWidth: true
        Layout.preferredHeight: view.rootObj.s(40)
        Layout.margins: view.rootObj.s(12)

        Text {
            id: hintText
            anchors.centerIn: parent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: view.rootObj.s(12)
            color: ThemeBackend.subtext0
        }
    }

    ColumnLayout {
        id: settingsColumn
        width: sv.width
        spacing: rootObj.s(8)

        SettingsBlob {
            SettingsRow {
                rootObj: sv.rootObj
                icon: "󰔛"
                title: I18n.t("guide.wellbeing.settings.overall_limit")
                description: I18n.t("guide.wellbeing.settings.overall_limit_desc")

                LimitStepper {
                    view: sv
                    from: 0
                    to: 1440
                    specialZeroText: I18n.t("guide.wellbeing.settings.off")
                    value: Math.round(sv.tab.overallLimitSeconds / 60)
                    onValueChanged: sv.tab.setOverallLimit(Math.round(value) * 60)
                }
            }
        }

        SettingsBlob {
            SettingsRow {
                rootObj: sv.rootObj
                icon: "󰀻"
                title: I18n.t("guide.wellbeing.settings.app_limits")
                description: I18n.t("guide.wellbeing.settings.app_limits_desc")

                AddButton { view: sv; onClicked: sv.tab.openAppPicker("limit") }
            }

            EmptyHint {
                view: sv
                visible: sv.limitedClasses.length === 0
                text: I18n.t("guide.wellbeing.settings.no_limits")
            }

            Repeater {
                model: sv.limitedClasses

                delegate: SettingsRow {
                    id: limitRow
                    rootObj: sv.rootObj
                    required property string modelData
                    customLeftContent: Component { AppLabel { view: sv; appClass: limitRow.modelData } }

                    LimitStepper {
                        view: sv
                        from: 5
                        to: 1440
                        value: Math.round((Number(sv.tab.appLimits[limitRow.modelData]) || 0) / 60)
                        onValueChanged: {
                            let secs = Math.round(value) * 60;
                            if (secs >= 300 && secs !== Number(sv.tab.appLimits[limitRow.modelData])) sv.tab.setAppLimit(limitRow.modelData, secs);
                        }
                    }

                    RemoveButton { view: sv; onClicked: sv.tab.setAppLimit(limitRow.modelData, 0) }
                }
            }
        }

        SettingsBlob {
            SettingsRow {
                rootObj: sv.rootObj
                icon: "󰈉"
                title: I18n.t("guide.wellbeing.settings.excluded_apps")
                description: I18n.t("guide.wellbeing.settings.excluded_apps_desc")

                AddButton { view: sv; onClicked: sv.tab.openAppPicker("exclude") }
            }

            EmptyHint {
                view: sv
                visible: sv.tab.excludedApps.length === 0
                text: I18n.t("guide.wellbeing.settings.no_excluded")
            }

            Repeater {
                model: sv.tab.excludedApps

                delegate: SettingsRow {
                    id: excludedRow
                    rootObj: sv.rootObj
                    required property string modelData
                    customLeftContent: Component { AppLabel { view: sv; appClass: excludedRow.modelData } }

                    RemoveButton { view: sv; onClicked: sv.tab.setAppExcluded(excludedRow.modelData, false) }
                }
            }
        }

        Item { Layout.preferredHeight: rootObj.s(4) }
    }
}
