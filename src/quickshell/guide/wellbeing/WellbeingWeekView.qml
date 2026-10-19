import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: weekViewWrapper
    required property var tab
    readonly property var rootObj: tab.rootObj
    anchors.fill: parent
    spacing: rootObj.s(6)

    opacity: weekViewWrapper.tab.weekViewFocus
    visible: opacity > 0
    transform: Translate { x: rootObj.s(40) * (1 - weekViewWrapper.tab.weekViewFocus) }
    scale: 0.95 + (0.05 * weekViewWrapper.tab.weekViewFocus)

    WellbeingWeekChart { tab: weekViewWrapper.tab }

    WellbeingWeekDetails { tab: weekViewWrapper.tab }
}
