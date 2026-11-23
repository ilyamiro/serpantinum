import QtQuick
import QtQuick.Layouts
import "../../reusables"
import "general"

BarGeneralState {
    id: barTabRoot
    deferredStages: 2

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            loadModuleModels();
            placementSection.barMonitorSelector.reloadMonitors();
        } else {
            clearPendingGroup();
            if (placementSection.barPosDropdown.isOpen) placementSection.barPosDropdown.closePopup();
        }
    }

    GuideScrollView {
        rootObj: barTabRoot.rootObj
        backgroundClickable: true
        onMovementStarted: barTabRoot.clearPendingGroup()
        onBackgroundClicked: barTabRoot.clearPendingGroup()

        BarPlacementSection { id: placementSection; tab: barTabRoot }

        BarStyleSection { tab: barTabRoot }

        Loader {
            Layout.fillWidth: true
            active: barTabRoot.deferredStage >= 1
            sourceComponent: BarAutohideSection { tab: barTabRoot }
        }

        Loader {
            Layout.fillWidth: true
            active: barTabRoot.deferredStage >= 2
            sourceComponent: BarLayoutEditor { tab: barTabRoot }
        }
    }
}
