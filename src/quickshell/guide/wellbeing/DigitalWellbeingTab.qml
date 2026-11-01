import QtQuick
import QtQuick.Layouts
import "../../reusables"

WellbeingState {
    id: tabRoot

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

            WellbeingWeekView { tab: tabRoot }

            WellbeingSettingsView { tab: tabRoot }
        }
    }

    WellbeingAppPicker { tab: tabRoot }
}
