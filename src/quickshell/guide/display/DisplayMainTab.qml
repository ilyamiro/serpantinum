import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

DisplayMainState {
    id: displayTabRoot
    subTabIndex: 0

    GuideScrollView {
        rootObj: displayTabRoot.rootObj
        spacing: rootObj.s(12)

        Repeater {
            model: displayTabRoot.monitorsList
            delegate: DisplayMonitorCard { tab: displayTabRoot }
        }
    }
}
