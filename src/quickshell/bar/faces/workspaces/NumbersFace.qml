import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"
import "."

Item {
    id: numbersFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    property real pillSize: widget ? widget.s(widget.isCompact ? 20 : 24) : 24
    property real pillRadius: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
    property real layoutSpacing: widget ? widget.s(widget.isCompact ? 5 : 6) : 6

    readonly property var shownIndices: widget ? widget.shownIndices : []

    function getHighlightPos(index) {
        if (index < 0) return 0;
        let pos = 0;
        const shown = numbersFaceRoot.shownIndices;
        for (let i = 0; i < shown.length; i++) {
            if (shown[i] === index) break;
            pos += numbersFaceRoot.pillSize + numbersFaceRoot.layoutSpacing;
        }
        return (numbersFaceRoot.isVertical ? wsLayout.y : wsLayout.x) + pos;
    }

    implicitWidth: wsLayout.implicitWidth
    implicitHeight: wsLayout.implicitHeight

    SlidingHighlight {
        id: activeHighlight
        z: 0
        widget: numbersFaceRoot.widget
        isVertical: numbersFaceRoot.isVertical
        crossThickness: numbersFaceRoot.pillSize
        radius: numbersFaceRoot.pillRadius
        layoutOffsetX: wsLayout.x
        layoutOffsetY: wsLayout.y
        layoutWidth: wsLayout.width
        layoutHeight: wsLayout.height
        curIdx: widget ? widget.activeIndex : -1
        targetStart: curIdx >= 0 ? numbersFaceRoot.getHighlightPos(curIdx) : 0
        targetEnd: curIdx >= 0 ? (targetStart + numbersFaceRoot.pillSize) : 0
        fastDuration: 200
        slowDuration: 350
        baseDuration: 250
        slideEasing: Easing.OutExpo
        opacityDuration: 250
    }

    AxisFlow {
        id: wsLayout
        vertical: numbersFaceRoot.isVertical
        z: 1
        anchors.centerIn: parent
        spacing: numbersFaceRoot.layoutSpacing

        Repeater {
            model: widget ? (widget.slotModel || widget.workspaceCount) : 0

            delegate: WorkspaceSlot {
                id: wsPill
                widget: numbersFaceRoot.widget
                isVertical: numbersFaceRoot.isVertical
                cascadeBaseDelay: 0
                cascadeStepDelay: 60
                slideDuration: 500
                slideEasing: Easing.OutBack
                opacityDuration: 500

                width: numbersFaceRoot.isVertical ? numbersFaceRoot.pillSize : (shown ? numbersFaceRoot.pillSize : 0)
                height: numbersFaceRoot.isVertical ? (shown ? numbersFaceRoot.pillSize : 0) : numbersFaceRoot.pillSize

                Rectangle {
                    anchors.fill: parent
                    radius: numbersFaceRoot.pillRadius
                    color: numbersHoverGlass.active ? "transparent" : wsPill.isHovered
                        ? Qt.alpha(ThemeBackend.text, 0.1)
                        : (wsPill.isActive ? "transparent" : (wsPill.isOccupied ? Qt.alpha(ThemeBackend.text, 0.15) : "transparent"))

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.isHovered && !wsPill.isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    GlassFill {
                        id: numbersHoverGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: wsPill.isHovered && !wsPill.isActive
                        tintColor: ThemeBackend.text
                        tintAmount: 0.15
                        press: wsPill.pressed ? 0.8 : 0.25
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: (wsPill.index + 1).toString()
                    font.family: "JetBrains Mono"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 12 : 14) : 14
                    font.weight: wsPill.isActive ? Font.Black : (wsPill.isOccupied ? Font.Bold : Font.Medium)

                    color: wsPill.isActive
                        ? (activeHighlight.glassActive ? ThemeBackend.text : ThemeBackend.crust)
                        : (wsPill.isHovered
                            ? ThemeBackend.text
                            : (wsPill.isOccupied
                                ? ThemeBackend.text
                                : (ThemeBackend.overlay0 !== undefined ? ThemeBackend.overlay0 : ThemeBackend.subtext0)))

                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }
        }
    }
}
