import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../bar"
import "../../../reusables"
import "../../../reusables/guide"

Rectangle {
    id: card
    required property var tab
    readonly property var rootObj: tab.rootObj

    property string title
    property string moduleId
    property bool showPreview: true
    property real previewSideHeight: 120
    property real variantPreviewSideHeight: 140
    property Component widgetComponent: null
    property Component variantFallback: null

    property var styles: []
    property string currentStyle
    property string styleSettingId
    property string styleKeywords
    property string styleIcon: "󰒓"
    property string styleTitle
    property string styleDescription

    signal styleSelected(string id)

    default property alias content: contentCol.data

    Layout.fillWidth: true
    implicitHeight: cardLayout.implicitHeight + rootObj.s(24)
    radius: ThemeBackend.borderRadius
    color: ThemeBackend.liquidGlass ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
    border.width: ThemeBackend.liquidGlass ? 0 : 1
    clip: true

    GlassFill {
        anchors.fill: parent
        allowed: card.tab.inView(parent)
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }

    ColumnLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(6)

        Text {
            Layout.bottomMargin: rootObj.s(6)
            Layout.leftMargin: rootObj.s(4)
            Layout.rightMargin: rootObj.s(4)
            text: card.title
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(16)
            font.bold: true
            color: ThemeBackend.text
        }

        BarModulePreview {
            visible: card.showPreview
            tab: card.tab
            source: BarModuleRegistry.faceFile(card.moduleId)
            widgetComponent: card.widgetComponent
            sideHeight: card.previewSideHeight
        }

        ColumnLayout {
            id: contentCol
            Layout.fillWidth: true
            spacing: rootObj.s(6)
        }

        Loader {
            Layout.fillWidth: true
            active: card.styles.length > 0
            visible: active
            sourceComponent: styleRow
        }
    }

    Component {
        id: styleRow

        SettingsRow {
            rootObj: card.rootObj
            settingId: card.styleSettingId
            searchKeywords: card.styleKeywords
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: card.styleIcon
            title: card.styleTitle
            description: card.styleDescription

            bottomContent: GridLayout {
                id: stylesGrid
                Layout.fillWidth: true
                columns: Math.max(1, Math.min(3, Math.floor(cardLayout.width / rootObj.s(160))))
                rowSpacing: rootObj.s(10)
                columnSpacing: rootObj.s(10)

                Repeater {
                    model: card.styles
                    delegate: BarModuleStyleCard {
                        required property var modelData
                        tab: card.tab
                        variant: modelData
                        moduleId: card.moduleId
                        selected: card.currentStyle === modelData.id
                        widgetComponent: card.widgetComponent
                        fallback: card.variantFallback
                        previewSideHeight: card.variantPreviewSideHeight
                        onPicked: id => card.styleSelected(id)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: stylesGrid.columns === 3
                }
            }
        }
    }
}
