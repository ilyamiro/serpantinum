import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

Rectangle {
    id: monWidgetCard
    required property var tab
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    clip: true
    radius: ThemeBackend.borderRadius
    color: widgetCardGlass1.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    GlassFill {
        id: widgetCardGlass1
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }

    property string monName: modelData.name
    property var widgetsList: (monWidgetCard.tab.monitorWidgetsMap && monWidgetCard.tab.monitorWidgetsMap[monName]) ? monWidgetCard.tab.monitorWidgetsMap[monName] : []
    property bool showPresets: false

    implicitHeight: cardLayout.implicitHeight + rootObj.s(12)

    ColumnLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        SettingsRow {
            id: monHeaderRow
            rootObj: monWidgetCard.tab.rootObj
            settingId: "widgets_screen_" + monWidgetCard.monName.toLowerCase().replace(/[^a-z0-9_]/g, "_")
            icon: "󰍹"
            title: monWidgetCard.monName
            description: I18n.t("guide.display.widgets.screen_desc", "Configure and edit desktop widgets")
            searchKeywords: "widgets redactor edit layout preset presets monitor screen " + monWidgetCard.monName.toLowerCase()
            baseColor: "transparent"
            hoverColor: "transparent"
            borderWidth: 0
            color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.accent.r, ThemeBackend.accent.g, ThemeBackend.accent.b, highlightFlash * 0.18) : "transparent"

            titleBadge: Component {
                Text {
                    text: "(" + monWidgetCard.widgetsList.length + " " + (monWidgetCard.widgetsList.length === 1 ? I18n.t("widgets.redactor.widget_singular", "widget") : I18n.t("widgets.redactor.widgets_plural", "widgets")) + ")"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                }
            }

            IconButton {
                size: rootObj.s(32)
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰐕"
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: {
                    monWidgetCard.tab.savePresetPopup.openForMonitor(monWidgetCard.monName, monWidgetCard.widgetsList);
                }
            }

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                maxWidth: rootObj.s(200)
                implicitHeight: rootObj.s(32)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: monWidgetCard.showPresets ? I18n.t("guide.display.widgets.hide_presets", "Hide Presets") : I18n.t("guide.display.widgets.choose_preset", "Choose a preset")
                buttonIcon: "󰄛"
                iconFontSize: rootObj.s(14)
                textFontSize: rootObj.s(12)
                accentColor: monWidgetCard.showPresets ? ThemeBackend.surface2 : ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: {
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                    }
                    monWidgetCard.showPresets = !monWidgetCard.showPresets;
                }
            }

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                maxWidth: rootObj.s(140)
                implicitHeight: rootObj.s(32)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("guide.display.widgets.open", "Open Redactor")
                buttonIcon: "󰕰"
                iconFontSize: rootObj.s(14)
                textFontSize: rootObj.s(12)
                accentColor: ThemeBackend.accent
                textColor: ThemeBackend.crust
                onClicked: {
                    monWidgetCard.tab.openRedactor(monWidgetCard.monName);
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(ThemeBackend.surface1, 0.3)
        }

        Loader {
            id: presetsSectionLoader
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(12)
            Layout.rightMargin: rootObj.s(12)
            Layout.topMargin: rootObj.s(12)
            active: monWidgetCard.showPresets && monWidgetCard.tab.visible
            visible: active

            sourceComponent: Component {
                WidgetPresetsPanel {
                    tab: monWidgetCard.tab
                    monName: monWidgetCard.monName
                    cardWidth: cardLayout.width
                }
            }
        }

        Grid {
            id: widgetsGrid
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(12)
            Layout.rightMargin: rootObj.s(12)
            Layout.topMargin: rootObj.s(12)
            Layout.bottomMargin: rootObj.s(4)
            columns: 3
            rowSpacing: rootObj.s(8)
            columnSpacing: rootObj.s(8)
            visible: monWidgetCard.widgetsList.length > 0

            readonly property real colWidth: Math.max(0, ((cardLayout.width - rootObj.s(24)) - columnSpacing * 2) / 3)

            Repeater {
                model: monWidgetCard.widgetsList
                delegate: WidgetItemCard {
                    tab: monWidgetCard.tab
                    monName: monWidgetCard.monName
                    colWidth: widgetsGrid.colWidth
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: rootObj.s(40)
            Layout.leftMargin: rootObj.s(12)
            Layout.rightMargin: rootObj.s(12)
            Layout.topMargin: rootObj.s(12)
            Layout.bottomMargin: rootObj.s(12)
            visible: !monWidgetCard.showPresets && monWidgetCard.widgetsList.length === 0

            Text {
                anchors.centerIn: parent
                text: I18n.t("widgets.redactor.no_widgets_active", "No widgets configured for this screen")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                color: ThemeBackend.subtext0
            }
        }
    }
}
