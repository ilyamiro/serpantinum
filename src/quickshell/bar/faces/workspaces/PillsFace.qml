import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"
import "."

Item {
    id: pillsFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property int activeIdx: widget ? Number(widget.activeIndex) : -1
    readonly property var shownIndices: widget ? widget.shownIndices : []

    readonly property real spacingVal: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
    readonly property real activeLen: widget ? widget.s(widget.isCompact ? 34 : 36) : 36
    readonly property real inactiveLen: widget ? widget.s(widget.isCompact ? 16 : 18) : 18

    readonly property real settledLength: {
        const shown = pillsFaceRoot.shownIndices;
        if (!shown || shown.length === 0) return 0;
        let total = 0;
        for (let i = 0; i < shown.length; i++) {
            total += (shown[i] === activeIdx) ? activeLen : inactiveLen;
        }
        return total + Math.max(0, shown.length - 1) * spacingVal;
    }

    function getHighlightPos(index) {
        if (index < 0) return 0;
        let pos = 0;
        const shown = pillsFaceRoot.shownIndices;
        for (let i = 0; i < shown.length; i++) {
            if (shown[i] === index) break;
            pos += (shown[i] === activeIdx ? activeLen : inactiveLen) + spacingVal;
        }
        return pos;
    }

    implicitWidth: isVertical ? wsLayout.implicitWidth : settledLength
    implicitHeight: isVertical ? settledLength : wsLayout.implicitHeight

    SlidingHighlight {
        id: activeHighlight
        z: 3
        widget: pillsFaceRoot.widget
        isVertical: pillsFaceRoot.isVertical
        crossThickness: pillsFaceRoot.inactiveLen
        radius: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
        layoutOffsetX: wsLayout.x
        layoutOffsetY: wsLayout.y
        layoutWidth: wsLayout.width
        layoutHeight: wsLayout.height
        useLayoutOffsetOnMain: true
        curIdx: widget ? widget.activeIndex : -1
        targetStart: curIdx >= 0 ? pillsFaceRoot.getHighlightPos(curIdx) : 0
        targetEnd: curIdx >= 0 ? (targetStart + pillsFaceRoot.activeLen) : 0
        fastDuration: 300
        slowDuration: 400
        baseDuration: 380
        slideEasing: Easing.OutQuint
        opacityDuration: 150
    }

    AxisFlow {
        id: wsLayout
        vertical: pillsFaceRoot.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        z: 2
        anchors.centerIn: parent
        spacing: pillsFaceRoot.spacingVal

        Repeater {
            model: widget ? (widget.slotModel || widget.workspaceCount) : 0

            delegate: WorkspaceSlot {
                id: wsPill
                widget: pillsFaceRoot.widget
                isVertical: pillsFaceRoot.isVertical
                slideDuration: 650

                readonly property real length: shown
                    ? (isActive ? pillsFaceRoot.activeLen : pillsFaceRoot.inactiveLen)
                    : 0
                readonly property real thickness: pillsFaceRoot.inactiveLen
                width: pillsFaceRoot.isVertical ? thickness : length
                height: pillsFaceRoot.isVertical ? length : thickness

                Behavior on width {
                    enabled: !pillsFaceRoot.isVertical
                    NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                }
                Behavior on height {
                    enabled: pillsFaceRoot.isVertical
                    NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                }

                Rectangle {
                    id: wsVisualShape
                    anchors.fill: parent
                    radius: widget ? widget.s(widget.isCompact ? 8 : 10) : 10
                    color: (wsPill.isActive || pillsShapeGlass.active) ? "transparent" : Qt.alpha(wsPill.isOccupied ? ThemeBackend.surface2 : ((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0), ThemeBackend.elementOpacity)

                    GlassFill {
                        id: pillsShapeGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: !wsPill.isActive
                        tintColor: wsPill.isOccupied ? ThemeBackend.surface2 : ThemeBackend.surface0
                        tintAmount: 0.3
                        press: wsPill.pressed ? 0.8 : (wsPill.isHovered ? 0.25 : 0)
                    }

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.pressed ? 0.88 : (wsPill.isHovered ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }
            }
        }
    }
}
