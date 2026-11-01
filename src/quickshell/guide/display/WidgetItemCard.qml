import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../widgets"

Rectangle {
    id: widgetItemCard
    required property var tab
    required property string monName
    required property real colWidth
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    width: widgetItemCard.colWidth
    height: rootObj.s(48)
    radius: ThemeBackend.borderRadius
    color: widgetCardGlass2.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.3)

    GlassFill {
        id: widgetCardGlass2
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface1, 0.3)
        tintAmount: 0.25
    }

    property string wType: modelData.wType || modelData.type || "time"
    property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[wType]) ? WidgetRegistry.types[wType] : null

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        spacing: rootObj.s(8)

        IconButton {
            size: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: (widgetItemCard.typeInfo && widgetItemCard.typeInfo.icon) ? widgetItemCard.typeInfo.icon : "󰕰"
            iconFontSize: rootObj.s(16)
            accentColor: ThemeBackend.surface1
            textColor: ThemeBackend.accent
            Layout.alignment: Qt.AlignVCenter
            enabled: false
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: rootObj.s(1)

            Text {
                text: widgetItemCard.typeInfo && widgetItemCard.typeInfo.name ? widgetItemCard.typeInfo.name : widgetItemCard.wType
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                font.bold: true
                color: ThemeBackend.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: (widgetItemCard.modelData.wVariant || "default") + " • " + Math.round(widgetItemCard.modelData.wWidth || 0) + "x" + Math.round(widgetItemCard.modelData.wHeight || 0) + " @ (" + Math.round(widgetItemCard.modelData.wX || 0) + ", " + Math.round(widgetItemCard.modelData.wY || 0) + ")"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(10)
                color: ThemeBackend.subtext0
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        DeleteButton {
            size: rootObj.s(28)
            cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
            iconFontSize: rootObj.s(14)
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                let wId = widgetItemCard.modelData.wId || widgetItemCard.modelData.id;
                widgetItemCard.tab.deleteWidget(widgetItemCard.monName, wId);
            }
        }
    }
}
