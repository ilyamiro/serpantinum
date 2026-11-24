import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../reusables"
import "../../../"

Item {
    id: traceFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property int activeIdx: widget ? Number(widget.activeIndex) : -1

    readonly property real slotSize: widget ? widget.s(widget.isCompact ? 19 : 22) : 22
    readonly property real slotSpacing: widget ? widget.s(widget.isCompact ? 6 : 8) : 8
    readonly property real stepSize: slotSize + slotSpacing
    readonly property real railThickness: widget ? widget.s(widget.isCompact ? 3 : 3.5) : 3.5
    readonly property real ripplePad: widget ? widget.s(3) : 3

    signal wavePulse(int fromSlot, int toSlot)

    function isShown(index) {
        if (!widget) return false;
        if (typeof widget.isShown === "function") return widget.isShown(index);
        return true;
    }

    readonly property var shownIndices: {
        if (!widget) return [];
        widget.activeIndex;
        widget.workspaceCount;
        if (typeof widget.hideEmptyWorkspaces !== "undefined") widget.hideEmptyWorkspaces;
        if (typeof widget.niriOccupiedMap !== "undefined") widget.niriOccupiedMap;
        if (typeof widget.swayOccupiedMap !== "undefined") widget.swayOccupiedMap;
        if (typeof widget.mangoOccupiedMap !== "undefined") widget.mangoOccupiedMap;
        if (typeof widget.umbrielOccupiedMap !== "undefined") widget.umbrielOccupiedMap;
        if (Compositor.name === "hyprland") Hyprland.workspaces.values;
        let ids = [];
        for (let i = 0; i < widget.workspaceCount; i++) {
            if (isShown(i)) ids.push(i);
        }
        return ids;
    }

    readonly property int shownCount: shownIndices.length
    readonly property int activeShownSlot: shownIndices.indexOf(activeIdx)
    readonly property real settledLength: shownCount > 0 ? shownCount * slotSize + (shownCount - 1) * slotSpacing : 0

    implicitWidth: isVertical ? slotSize + ripplePad * 2 : settledLength
    implicitHeight: isVertical ? settledLength : slotSize + ripplePad * 2

    property int prevSlot: 0
    property bool animReady: false

    readonly property real targetBeamPos: activeShownSlot >= 0 ? (activeShownSlot * stepSize + slotSize * 0.5) : 0
    property real beamStart: targetBeamPos
    property real beamEnd: targetBeamPos

    onActiveShownSlotChanged: {
        if (activeShownSlot >= 0) {
            if (animReady && prevSlot >= 0 && activeShownSlot !== prevSlot) {
                if (activeShownSlot > prevSlot) {
                    beamEndAnim.duration = 200;
                    beamStartAnim.duration = 400;
                } else {
                    beamStartAnim.duration = 200;
                    beamEndAnim.duration = 400;
                }
                if (Math.abs(activeShownSlot - prevSlot) > 1) {
                    traceFaceRoot.wavePulse(prevSlot, activeShownSlot);
                }
                rippleAnim.restart();
            }
            prevSlot = activeShownSlot;
        }
    }

    Behavior on beamStart {
        enabled: traceFaceRoot.animReady
        NumberAnimation { id: beamStartAnim; duration: 320; easing.type: Easing.OutQuint }
    }
    Behavior on beamEnd {
        enabled: traceFaceRoot.animReady
        NumberAnimation { id: beamEndAnim; duration: 320; easing.type: Easing.OutQuint }
    }

    Component.onCompleted: {
        prevSlot = activeShownSlot >= 0 ? activeShownSlot : 0;
        animReady = true;
    }

    Rectangle {
        id: baseRail
        z: 0
        visible: traceFaceRoot.shownCount > 1
        readonly property real railLen: Math.max(0, (traceFaceRoot.shownCount - 1) * traceFaceRoot.stepSize)
        x: traceFaceRoot.isVertical ? (parent.width - width) / 2 : wsLayout.x + traceFaceRoot.slotSize * 0.5
        y: traceFaceRoot.isVertical ? wsLayout.y + traceFaceRoot.slotSize * 0.5 : (parent.height - height) / 2
        width: traceFaceRoot.isVertical ? traceFaceRoot.railThickness : railLen
        height: traceFaceRoot.isVertical ? railLen : traceFaceRoot.railThickness
        radius: traceFaceRoot.railThickness / 2
        color: Qt.alpha(ThemeBackend.surface1, 0.55)
    }

    Rectangle {
        id: traceBeam
        z: 2
        readonly property real minPos: Math.min(traceFaceRoot.beamStart, traceFaceRoot.beamEnd)
        readonly property real maxPos: Math.max(traceFaceRoot.beamStart, traceFaceRoot.beamEnd)
        readonly property real span: Math.max(0, maxPos - minPos)
        readonly property real beamThick: traceFaceRoot.railThickness * 1.5

        x: traceFaceRoot.isVertical ? (parent.width - width) / 2 : wsLayout.x + minPos
        y: traceFaceRoot.isVertical ? wsLayout.y + minPos : (parent.height - height) / 2
        width: traceFaceRoot.isVertical ? beamThick : span
        height: traceFaceRoot.isVertical ? span : beamThick
        radius: beamThick / 2
        color: ThemeBackend.mauve
        opacity: span > 1.0 ? Math.min(1.0, span / Math.max(1.0, traceFaceRoot.slotSize * 0.5)) : 0.0
    }

    Rectangle {
        id: sonarRipple
        z: 2
        property real rippleScale: 0.78
        property real rippleOpacity: 0.0

        readonly property real activeCenter: traceFaceRoot.activeShownSlot >= 0
            ? (traceFaceRoot.activeShownSlot * traceFaceRoot.stepSize + traceFaceRoot.slotSize * 0.5)
            : 0
        readonly property real baseDim: traceFaceRoot.slotSize

        width: baseDim
        height: baseDim
        x: traceFaceRoot.isVertical
            ? (parent.width - width) / 2
            : wsLayout.x + activeCenter - width / 2
        y: traceFaceRoot.isVertical
            ? wsLayout.y + activeCenter - height / 2
            : (parent.height - height) / 2
        radius: width * 0.34
        color: "transparent"
        border.width: Math.max(1.5, widget ? widget.s(1.8) : 1.8)
        border.color: ThemeBackend.mauve
        scale: rippleScale
        opacity: rippleOpacity

        ParallelAnimation {
            id: rippleAnim
            NumberAnimation {
                target: sonarRipple
                property: "rippleScale"
                from: 0.82
                to: 1.48
                duration: 420
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: sonarRipple
                    property: "rippleOpacity"
                    from: 0.0
                    to: 0.65
                    duration: 70
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: sonarRipple
                    property: "rippleOpacity"
                    from: 0.65
                    to: 0.0
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    AxisFlow {
        id: wsLayout
        vertical: traceFaceRoot.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        z: 3
        anchors.centerIn: parent
        spacing: traceFaceRoot.slotSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: wsSlot
                required property int index

                readonly property bool isOccupied: widget ? widget.isOccupied(index) : false
                readonly property bool isActive: traceFaceRoot ? index === traceFaceRoot.activeIdx : false
                readonly property bool isHovered: wsMouse.containsMouse
                readonly property bool shown: traceFaceRoot.isShown(index)
                readonly property int shownPos: traceFaceRoot.shownIndices.indexOf(index)

                property bool initAnimTrigger: false
                property bool ready: false
                property real dominoBoost: 0.0
                property real landingScale: 1.0

                onIsActiveChanged: {
                    if (ready && isActive) {
                        landingAnim.restart();
                    }
                }

                SequentialAnimation {
                    id: landingAnim
                    NumberAnimation {
                        target: wsSlot
                        property: "landingScale"
                        to: 0.82
                        duration: 75
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: wsSlot
                        property: "landingScale"
                        to: 1.12
                        duration: 145
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: wsSlot
                        property: "landingScale"
                        to: 1.0
                        duration: 240
                        easing.type: Easing.OutBack
                    }
                }

                Connections {
                    target: traceFaceRoot
                    function onWavePulse(fromSlot, toSlot) {
                        const pos = wsSlot.shownPos;
                        if (pos < 0) return;
                        const lo = Math.min(fromSlot, toSlot);
                        const hi = Math.max(fromSlot, toSlot);
                        if (pos > lo && pos < hi) {
                            dominoDelay.interval = Math.abs(pos - fromSlot) * 40;
                            dominoDelay.restart();
                        }
                    }
                }

                Timer {
                    id: dominoDelay
                    repeat: false
                    onTriggered: dominoAnim.restart()
                }

                SequentialAnimation {
                    id: dominoAnim
                    NumberAnimation {
                        target: wsSlot
                        property: "dominoBoost"
                        to: 1.0
                        duration: 110
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: wsSlot
                        property: "dominoBoost"
                        to: 0.0
                        duration: 280
                        easing.type: Easing.OutBack
                    }
                }

                visible: shown
                width: traceFaceRoot.isVertical ? traceFaceRoot.slotSize : (shown ? traceFaceRoot.slotSize : 0)
                height: traceFaceRoot.isVertical ? (shown ? traceFaceRoot.slotSize : 0) : traceFaceRoot.slotSize

                readonly property real targetSize: isActive
                    ? traceFaceRoot.slotSize
                    : (isOccupied ? traceFaceRoot.slotSize * 0.84 : traceFaceRoot.slotSize * 0.68)

                readonly property real targetRadius: isActive
                    ? targetSize * 0.34
                    : (isOccupied
                        ? (isHovered ? targetSize * 0.48 : targetSize * 0.32)
                        : targetSize * 0.5)

                property real hoverScale: wsMouse.pressed ? 0.86 : (isHovered && !isActive ? 1.16 : 1.0)
                Behavior on hoverScale {
                    enabled: wsSlot.ready
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
                }

                Rectangle {
                    id: nodeShape
                    anchors.centerIn: parent
                    width: wsSlot.targetSize
                    height: wsSlot.targetSize
                    radius: wsSlot.targetRadius

                    Behavior on width {
                        enabled: wsSlot.ready
                        SpringAnimation { spring: 6.5; damping: 0.48; mass: 1.0; epsilon: 0.05 }
                    }
                    Behavior on height {
                        enabled: wsSlot.ready
                        SpringAnimation { spring: 6.5; damping: 0.48; mass: 1.0; epsilon: 0.05 }
                    }
                    Behavior on radius {
                        enabled: wsSlot.ready
                        NumberAnimation { duration: 240; easing.type: Easing.OutQuint }
                    }

                    scale: wsSlot.hoverScale * wsSlot.landingScale * (1.0 + 0.28 * wsSlot.dominoBoost)

                    border.width: (!wsSlot.isActive && !wsSlot.isOccupied && !nodeGlass.active) ? 1 : 0
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.45)

                    color: nodeGlass.active
                        ? "transparent"
                        : (wsSlot.isActive
                            ? ((widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve)
                            : (wsSlot.isOccupied
                                ? Qt.alpha(ThemeBackend.surface2, ThemeBackend.elementOpacity)
                                : Qt.alpha((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0, ThemeBackend.elementOpacity)))

                    Behavior on color {
                        enabled: wsSlot.ready
                        ColorAnimation { duration: 220 }
                    }

                    GlassFill {
                        id: nodeGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: wsSlot.isActive || wsSlot.isOccupied
                        tintColor: wsSlot.isActive ? ThemeBackend.mauve : ThemeBackend.surface2
                        tintAmount: wsSlot.isActive ? 0.5 : 0.32
                        press: wsMouse.pressed ? 0.8 : (wsSlot.isHovered ? 0.3 : (wsSlot.isActive ? 0.3 : 0.0))
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: ThemeBackend.mauve
                        opacity: wsSlot.isActive ? 0.0 : wsSlot.dominoBoost * 0.65
                    }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: (!traceFaceRoot.isVertical || wsSlot.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    y: (traceFaceRoot.isVertical || wsSlot.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                    Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                }

                Component.onCompleted: {
                    ready = true;
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 50 + 100;
                        if (widget.moduleActive) animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Timer {
                    id: animTimer
                    running: false
                    repeat: false
                    onTriggered: wsSlot.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widget) widget.focusWorkspace(wsSlot.index);
                    }
                }
            }
        }
    }

    Item {
        id: bridgeLayer
        anchors.fill: parent
        z: 1

        Repeater {
            model: Math.max(0, traceFaceRoot.shownCount - 1)

            delegate: Rectangle {
                required property int index
                readonly property bool leftOcc: {
                    const ids = traceFaceRoot.shownIndices;
                    if (!widget || index >= ids.length) return false;
                    return ids[index] === traceFaceRoot.activeIdx || widget.isOccupied(ids[index]);
                }
                readonly property bool rightOcc: {
                    const ids = traceFaceRoot.shownIndices;
                    if (!widget || index + 1 >= ids.length) return false;
                    return ids[index + 1] === traceFaceRoot.activeIdx || widget.isOccupied(ids[index + 1]);
                }
                readonly property bool linked: leftOcc && rightOcc

                x: traceFaceRoot.isVertical
                    ? (parent.width - width) / 2
                    : wsLayout.x + traceFaceRoot.slotSize * 0.5 + index * traceFaceRoot.stepSize
                y: traceFaceRoot.isVertical
                    ? wsLayout.y + traceFaceRoot.slotSize * 0.5 + index * traceFaceRoot.stepSize
                    : (parent.height - height) / 2
                width: traceFaceRoot.isVertical ? traceFaceRoot.railThickness * 1.15 : traceFaceRoot.stepSize
                height: traceFaceRoot.isVertical ? traceFaceRoot.stepSize : traceFaceRoot.railThickness * 1.15
                radius: traceFaceRoot.railThickness / 2
                color: Qt.alpha(ThemeBackend.surface2, ThemeBackend.elementOpacity)
                opacity: linked ? 0.85 : 0.0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
        }
    }
}
