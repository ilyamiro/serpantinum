import QtQuick
import QtQuick.Layouts
import "general"

BarGeneralState {
    id: barTabRoot

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            loadModuleModels();
        } else {
            clearPendingGroup();
            if (placementSection.barPosDropdown.isOpen) placementSection.barPosDropdown.closePopup();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onMovementStarted: {
            barTabRoot.clearPendingGroup();
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                barTabRoot.clearPendingGroup();
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            BarPlacementSection { id: placementSection; tab: barTabRoot }

            BarStyleSection { tab: barTabRoot }

            BarAutohideSection { tab: barTabRoot }

            BarLayoutEditor { tab: barTabRoot }
        }
    }
}
