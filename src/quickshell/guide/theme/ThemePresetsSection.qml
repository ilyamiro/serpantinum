import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

Rectangle {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    implicitHeight: themesSectionCol.implicitHeight + rootObj.s(12)
    radius: ThemeBackend.borderRadius
    color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    GlassFill {
        id: gf2
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }
    clip: true

    ColumnLayout {
        id: themesSectionCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        SettingsRow {
            id: colorSchemesRow
            rootObj: section.tab.rootObj
            settingId: "colors"
            icon: "󰏘"
            title: I18n.t("guide.theme.colors.title")
            description: I18n.t("guide.theme.colors.desc")
            searchKeywords: "colors theme presets scheme palette matugen catppuccin"
            baseColor: "transparent"
            hoverColor: "transparent"
            borderWidth: 0
            color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.18) : "transparent"

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                size: rootObj.s(32)
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                cornerRadius: rootObj.s(8)
                buttonIcon: "󰐕"
                iconFontSize: rootObj.s(14)
                accentColor: ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                onClicked: {
                    if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                    section.tab.themeEditorPopup.openForNew();
                }
            }

            Input {
                id: themeSearchInput
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rootObj.s(180)
                placeholderText: I18n.t("guide.theme.colors.search")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj.s(11)
                charSpacing: 1
                onTextEdited: newText => section.tab.themeSearchText = newText
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(ThemeBackend.surface1, 0.3)
        }

        GridLayout {
            id: themesGrid
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(12)
            Layout.rightMargin: rootObj.s(12)
            Layout.topMargin: rootObj.s(12)
            Layout.bottomMargin: rootObj.s(12)
            columns: 3
            rowSpacing: rootObj.s(10)
            columnSpacing: rootObj.s(10)

            Repeater {
                model: section.tab.filteredUserPresets
                delegate: ThemePresetDelegate { tab: section.tab }
            }

            Repeater {
                model: section.tab.filteredSystemPresets
                delegate: ThemePresetDelegate { tab: section.tab }
            }
        }
    }
}
