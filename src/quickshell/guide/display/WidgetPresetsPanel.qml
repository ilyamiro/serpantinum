import QtQuick
import "../../"

Column {
    id: presetsContainerCol
    required property var tab
    required property string monName
    required property real cardWidth
    readonly property var rootObj: tab.rootObj

    width: Math.max(0, cardWidth - rootObj.s(24))
    spacing: rootObj.s(10)

    readonly property real containerWidth: Math.max(0, width)
    readonly property int gridColumns: Math.max(3, Math.floor(containerWidth / rootObj.s(180)))
    readonly property real gridColumnSpacing: rootObj.s(8)
    readonly property real gridRowSpacing: rootObj.s(8)
    readonly property real presetTileWidth: gridColumns > 0 ? Math.max(0, (containerWidth - gridColumnSpacing * (gridColumns - 1)) / gridColumns) : 0


    Grid {
        id: userPresetsGrid
        width: parent.width
        columns: presetsContainerCol.gridColumns
        rowSpacing: presetsContainerCol.gridRowSpacing
        columnSpacing: presetsContainerCol.gridColumnSpacing
        visible: presetsContainerCol.tab.userPresets.length > 0

        Repeater {
            model: presetsContainerCol.tab.userPresets
            delegate: WidgetPresetCard {
                tab: presetsContainerCol.tab
                monName: presetsContainerCol.monName
                tileWidth: presetsContainerCol.presetTileWidth
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(ThemeBackend.surface2, 0.35)
        visible: presetsContainerCol.tab.userPresets.length > 0 && presetsContainerCol.tab.systemPresets.length > 0
    }

    Grid {
        id: systemPresetsGrid
        width: parent.width
        columns: presetsContainerCol.gridColumns
        rowSpacing: presetsContainerCol.gridRowSpacing
        columnSpacing: presetsContainerCol.gridColumnSpacing
        visible: presetsContainerCol.tab.systemPresets.length > 0

        Repeater {
            model: presetsContainerCol.tab.systemPresets
            delegate: WidgetPresetCard {
                tab: presetsContainerCol.tab
                monName: presetsContainerCol.monName
                tileWidth: presetsContainerCol.presetTileWidth
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(ThemeBackend.surface2, 0.35)
    }
}
