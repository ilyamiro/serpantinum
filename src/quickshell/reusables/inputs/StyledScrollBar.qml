import QtQuick
import QtQuick.Controls
import "../../"

ScrollBar {
    id: root

    property var rootObj: null
    function s(val) {
        return (rootObj && typeof rootObj.s === "function") ? rootObj.s(val) : Scaler.s(val);
    }

    property real barWidth: s(4)
    property color barColor: ThemeBackend.surface2
    property bool hoveredActive: false

    active: hoveredActive || (parent !== null && (parent.moving === true || parent.movingVertically === true || parent.movingHorizontally === true))
    width: orientation === Qt.Vertical ? (barWidth + leftPadding + rightPadding) : undefined
    height: orientation === Qt.Horizontal ? (barWidth + topPadding + bottomPadding) : undefined
    policy: ScrollBar.AsNeeded

    contentItem: Rectangle {
        implicitWidth: root.barWidth
        implicitHeight: root.barWidth
        radius: root.barWidth / 2
        color: root.barColor
    }
}
