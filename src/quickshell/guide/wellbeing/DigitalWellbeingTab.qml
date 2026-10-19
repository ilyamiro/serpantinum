import QtQuick
import QtQuick.Layouts
import "../../reusables"

WellbeingState {
    id: tabRoot

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(6)

        WellbeingHeader { tab: tabRoot }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WellbeingDailyView { tab: tabRoot }

            WellbeingWeekView { tab: tabRoot }

            Item {
                id: settingsWrapper
                anchors.fill: parent
                opacity: tabRoot.settingsViewFocus
                visible: opacity > 0
                transform: Translate { y: rootObj.s(40) * (1 - tabRoot.settingsViewFocus) }

                Reserved {
                    anchors.centerIn: parent
                    imageSize: rootObj.s(220)
                    textSize: rootObj.s(15)
                }
            }
        }
    }
}
