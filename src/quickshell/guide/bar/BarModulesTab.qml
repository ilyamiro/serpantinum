import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "modules"

BarModulesSettings {
    id: barModulesRoot
    subTabIndex: 1

    function inView(item) {
        if (!item || !visible) return false;
        void modulesFlick.contentY;
        void modulesFlick.contentHeight;
        void modulesFlick.height;
        void item.y;
        void item.height;
        const top = item.mapToItem(modulesFlick.contentItem, 0, 0).y;
        const margin = modulesFlick.height * 0.5;
        return top + item.height > modulesFlick.contentY - margin && top < modulesFlick.contentY + modulesFlick.height + margin;
    }

    Flickable {
        id: modulesFlick
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: modulesCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: modulesCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            BarMenuCard { tab: barModulesRoot }

            BarWorkspacesCard { tab: barModulesRoot }

            BarTimeDateCard { tab: barModulesRoot }

            BarVisualizerCard { tab: barModulesRoot }

            BarSysmonCard { tab: barModulesRoot }

            BarBatteryCard { tab: barModulesRoot }

            BarNetworkCard { tab: barModulesRoot }

            BarBluetoothCard { tab: barModulesRoot }

            BarVolumeCard { tab: barModulesRoot }

            BarKeyboardCard { tab: barModulesRoot }

            BarMediaCard { tab: barModulesRoot }
        }
    }
}
