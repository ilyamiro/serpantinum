import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"

Flickable {
    id: dailyViewWrapper
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property real focusAway: Math.max(dailyViewWrapper.tab.weekViewFocus, dailyViewWrapper.tab.settingsViewFocus)

    anchors.fill: parent
    contentWidth: width
    contentHeight: dailyColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    opacity: 1.0 - focusAway
    visible: opacity > 0
    transform: Translate { x: rootObj.s(-40) * dailyViewWrapper.focusAway }
    scale: 0.95 + (0.05 * (1.0 - dailyViewWrapper.focusAway))

    Behavior on contentY {
        id: contentYBehavior
        enabled: false
        NumberAnimation { duration: 550; easing.type: Easing.OutExpo }
    }

    Connections {
        target: dailyViewWrapper.tab
        function onSelectedAppClassChanged() {
            contentYBehavior.enabled = true;
            dailyViewWrapper.contentY = 0;
            contentYReset.restart();
        }
    }

    Timer {
        id: contentYReset
        interval: 600
        onTriggered: contentYBehavior.enabled = false
    }

    ScrollBar.vertical: ScrollBar {
        active: dailyViewWrapper.moving
        width: rootObj.s(4)
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
    }

    ColumnLayout {
        id: dailyColumn
        width: dailyViewWrapper.width
        spacing: rootObj.s(8)

        WellbeingStatsRow { tab: dailyViewWrapper.tab }

        WellbeingMidRow { tab: dailyViewWrapper.tab }

        WellbeingBottomPanel { tab: dailyViewWrapper.tab }

        Item { Layout.preferredHeight: rootObj.s(4) }
    }
}
