import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "modules"

BarModulesSettings {
    id: barModulesRoot
    subTabIndex: 1
    deferredStages: 10

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

    GuideScrollView {
        id: modulesFlick
        rootObj: barModulesRoot.rootObj
        spacing: rootObj.s(12)

        BarMenuCard { tab: barModulesRoot }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 1
            sourceComponent: BarWorkspacesCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 2
            sourceComponent: BarTimeDateCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 3
            sourceComponent: BarVisualizerCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 4
            sourceComponent: BarSysmonCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 5
            sourceComponent: BarBatteryCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 6
            sourceComponent: BarNetworkCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 7
            sourceComponent: BarBluetoothCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 8
            sourceComponent: BarVolumeCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 9
            sourceComponent: BarKeyboardCard { tab: barModulesRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barModulesRoot.deferredStage >= 10
            sourceComponent: BarMediaCard { tab: barModulesRoot }
        }
    }
}
