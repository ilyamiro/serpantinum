import QtQuick
import QtQuick.Layouts
import "../../"

Loader {
    id: delegateLoader
    required property var tab
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj
    property var themeData: modelData
    property int itemIndex: index
    readonly property bool isDiv: modelData.isDivider === true

    active: isDiv || itemIndex < tab.revealedCount
    asynchronous: true
    sourceComponent: isDiv ? dividerComp : tileComp

    Layout.columnSpan: isDiv ? 3 : 1
    Layout.fillWidth: true
    Layout.preferredWidth: isDiv ? tab.gridAvailableWidth : tab.tileWidth
    Layout.minimumWidth: isDiv ? 0 : tab.tileWidth
    Layout.preferredHeight: isDiv ? rootObj.s(17) : rootObj.s(44)
    Layout.alignment: Qt.AlignLeft | Qt.AlignTop

    Component {
        id: dividerComp
        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.4)
            }
        }
    }

    Component {
        id: tileComp
        ThemePresetTile {
            tab: delegateLoader.tab
            modelData: delegateLoader.themeData
            itemIndex: delegateLoader.itemIndex
        }
    }
}
