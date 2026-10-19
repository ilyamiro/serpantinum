import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: dailyViewWrapper
    required property var tab
    readonly property var rootObj: tab.rootObj
    anchors.fill: parent
    spacing: rootObj.s(6)

    opacity: 1.0 - Math.max(dailyViewWrapper.tab.weekViewFocus, dailyViewWrapper.tab.settingsViewFocus)
    visible: opacity > 0
    transform: Translate { x: rootObj.s(-40) * Math.max(dailyViewWrapper.tab.weekViewFocus, dailyViewWrapper.tab.settingsViewFocus) }
    scale: 0.95 + (0.05 * (1.0 - Math.max(dailyViewWrapper.tab.weekViewFocus, dailyViewWrapper.tab.settingsViewFocus)))


    WellbeingStatsRow { tab: dailyViewWrapper.tab }

    WellbeingMidRow { tab: dailyViewWrapper.tab }

    WellbeingBottomPanel { tab: dailyViewWrapper.tab }
}
