import QtQuick
import "../../../reusables"
import "../../../"

Rectangle {
    id: highlight

    property var widget: null
    property bool isVertical: false
    property real crossThickness: 18
    property real layoutOffsetX: 0
    property real layoutOffsetY: 0
    property real layoutWidth: 0
    property real layoutHeight: 0
    property real targetStart: 0
    property real targetEnd: 0
    property int curIdx: -1
    property int fastDuration: 200
    property int slowDuration: 350
    property int baseDuration: 250
    property int slideEasing: Easing.OutExpo
    property int opacityDuration: 250
    property bool useLayoutOffsetOnMain: false

    readonly property bool glassActive: highlightGlass.active

    color: highlightGlass.active ? "transparent" : ((widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve)

    GlassFill {
        id: highlightGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: ThemeBackend.mauve
        tintAmount: 0.5
        press: 0.3 + 0.7 * highlight.lift
    }

    property int prevIdx: 0

    onCurIdxChanged: {
        if (curIdx >= 0 && prevIdx >= 0) {
            if (curIdx > prevIdx) {
                endAnim.duration = highlight.fastDuration;
                startAnim.duration = highlight.slowDuration;
            } else if (curIdx < prevIdx) {
                startAnim.duration = highlight.fastDuration;
                endAnim.duration = highlight.slowDuration;
            }
        }
        if (curIdx >= 0) {
            prevIdx = curIdx;
        }
    }

    property real actualStart: targetStart
    property real actualEnd: targetEnd

    Behavior on actualStart { NumberAnimation { id: startAnim; duration: highlight.baseDuration; easing.type: highlight.slideEasing } }
    Behavior on actualEnd { NumberAnimation { id: endAnim; duration: highlight.baseDuration; easing.type: highlight.slideEasing } }

    readonly property bool isMoving: Math.abs(actualStart - targetStart) > 0.5 || Math.abs(actualEnd - targetEnd) > 0.5
    property real lift: (highlightGlass.active && isMoving) ? 1.0 : 0.0
    Behavior on lift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    scale: 1.0 + 0.14 * lift
    transformOrigin: Item.Center

    x: isVertical ? layoutOffsetX + (layoutWidth - width) / 2 : (useLayoutOffsetOnMain ? layoutOffsetX + actualStart : actualStart)
    y: isVertical ? (useLayoutOffsetOnMain ? layoutOffsetY + actualStart : actualStart) : layoutOffsetY + (layoutHeight - height) / 2
    width: isVertical ? crossThickness : actualEnd - actualStart
    height: isVertical ? actualEnd - actualStart : crossThickness

    opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: highlight.opacityDuration } }
}
