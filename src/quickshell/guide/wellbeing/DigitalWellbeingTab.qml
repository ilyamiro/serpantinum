import QtQuick
import QtQuick.Layouts
import "../../reusables"

WellbeingState {
    id: tabRoot
    deferredStages: 3

    ColumnLayout {
        width: Math.min(parent.width - rootObj.s(24), rootObj.s(1000))
        height: parent.height - rootObj.s(24)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: rootObj.s(12)
        spacing: rootObj.s(8)

        WellbeingHeader { tab: tabRoot }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WellbeingDailyView { tab: tabRoot }

            Loader {
                anchors.fill: parent
                active: tabRoot.deferredStage >= 1
                sourceComponent: WellbeingWeekView { tab: tabRoot }
            }

            Loader {
                anchors.fill: parent
                active: tabRoot.deferredStage >= 2
                sourceComponent: WellbeingSettingsView { tab: tabRoot }
            }
        }
    }

    Loader {
        anchors.fill: parent
        z: 50
        active: tabRoot.deferredStage >= 3
        sourceComponent: WellbeingAppPicker { tab: tabRoot }
    }
}
