import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../reusables"
import "../../../"
import "."

Item {
    id: morphFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property int activeIdx: widget ? Number(widget.activeIndex) : -1

    readonly property real slotSize: widget ? widget.s(widget.isCompact ? 20 : 24) : 24
    readonly property real slotSpacing: widget ? widget.s(widget.isCompact ? 4 : 5) : 5
    property int activeShapeIdx: 0

    readonly property int shownCount: widget ? widget.shownCount : 0
    readonly property real settledLength: shownCount > 0 ? shownCount * slotSize + (shownCount - 1) * slotSpacing : 0

    implicitWidth: isVertical ? slotSize : settledLength
    implicitHeight: isVertical ? settledLength : slotSize

    AxisFlow {
        id: wsLayout
        vertical: morphFaceRoot.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        anchors.centerIn: parent
        spacing: morphFaceRoot.slotSpacing

        Repeater {
            model: widget ? (widget.slotModel || widget.workspaceCount) : 0

            delegate: WorkspaceSlot {
                id: wsSlot
                widget: morphFaceRoot.widget
                isVertical: morphFaceRoot.isVertical

                readonly property var emptyShapes: [0, 1, 2, 3]
                readonly property var takenShapes: [4, 5, 6, 7]
                readonly property var activeShapes: [8, 9, 10, 11]

                property bool ready: false
                property real hoverAnim: (!isActive && isHovered) ? 1.0 : 0.0
                Behavior on hoverAnim {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                property int emptyIdx: index % 4
                property int takenIdx: index % 4
                property real shapeFrom: isActive ? activeShapes[morphFaceRoot.activeShapeIdx] : (isOccupied ? takenShapes[takenIdx] : emptyShapes[emptyIdx])
                property real shapeTo: shapeFrom
                property real shapeBlend: 1.0
                property real activeAmt: isActive ? 1.0 : 0.0
                property real spinAngle: 0.0
                property real idleSpin: 0.0

                Behavior on activeAmt {
                    enabled: wsSlot.ready
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }

                Behavior on shapeBlend {
                    id: blendBehavior
                    enabled: wsSlot.ready
                    SpringAnimation {
                        spring: 4.4
                        damping: 0.56
                        mass: 1.0
                        epsilon: 0.0008
                    }
                }

                Behavior on spinAngle {
                    enabled: wsSlot.ready
                    SpringAnimation {
                        spring: 4.2
                        damping: 0.58
                        mass: 1.0
                        epsilon: 0.01
                    }
                }

                NumberAnimation on idleSpin {
                    from: 0.0
                    to: 360.0
                    duration: 18000
                    loops: Animation.Infinite
                    running: wsSlot.isActive && morphFaceRoot.visible && (!widget || widget.moduleActive)
                }

                NumberAnimation {
                    id: activeMorphAnim
                    target: wsSlot
                    property: "shapeBlend"
                    from: 0.0
                    to: 1.0
                    duration: 950
                    easing.type: Easing.InOutSine
                }

                function morphTo(nextShape, turnDeg) {
                    if (nextShape === wsSlot.shapeTo) return;
                    let smoothActive = wsSlot.ready && wsSlot.isActive && wsSlot.shapeTo >= 8.0 && nextShape >= 8.0;
                    activeMorphAnim.stop();
                    blendBehavior.enabled = false;
                    wsSlot.shapeFrom = wsSlot.shapeTo;
                    wsSlot.shapeBlend = 0.0;
                    wsSlot.shapeTo = nextShape;
                    if (smoothActive) {
                        activeMorphAnim.start();
                    } else {
                        blendBehavior.enabled = wsSlot.ready;
                        wsSlot.shapeBlend = 1.0;
                    }
                    if (wsSlot.ready && turnDeg !== 0) {
                        if (wsSlot.isActive) {
                            wsSlot.spinAngle += turnDeg;
                        } else {
                            let total = wsSlot.spinAngle + wsSlot.idleSpin;
                            let snapped = Math.round((total + turnDeg) / 90.0) * 90.0;
                            wsSlot.spinAngle = snapped - wsSlot.idleSpin;
                        }
                    }
                }

                function syncStateShape(turnDeg) {
                    let target = wsSlot.isActive
                        ? wsSlot.activeShapes[morphFaceRoot.activeShapeIdx]
                        : (wsSlot.isOccupied ? wsSlot.takenShapes[wsSlot.takenIdx] : wsSlot.emptyShapes[wsSlot.emptyIdx]);
                    morphTo(target, turnDeg);
                }

                onIsActiveChanged: {
                    if (!ready) {
                        let target = isActive ? activeShapes[morphFaceRoot.activeShapeIdx] : (isOccupied ? takenShapes[takenIdx] : emptyShapes[emptyIdx]);
                        shapeFrom = target;
                        shapeTo = target;
                        shapeBlend = 1.0;
                        return;
                    }
                    syncStateShape(90.0);
                }

                onIsOccupiedChanged: {
                    if (!ready) {
                        let target = isActive ? activeShapes[morphFaceRoot.activeShapeIdx] : (isOccupied ? takenShapes[takenIdx] : emptyShapes[emptyIdx]);
                        shapeFrom = target;
                        shapeTo = target;
                        shapeBlend = 1.0;
                        return;
                    }
                    if (!isActive) syncStateShape(90.0);
                }

                Timer {
                    id: activeMorphTimer
                    interval: 2800
                    repeat: true
                    running: wsSlot.ready && wsSlot.isActive && wsSlot.shown && morphFaceRoot.visible && (!widget || widget.moduleActive)
                    onTriggered: {
                        let step = 1 + Math.floor(Math.random() * (wsSlot.activeShapes.length - 1));
                        morphFaceRoot.activeShapeIdx = (morphFaceRoot.activeShapeIdx + step) % wsSlot.activeShapes.length;
                        wsSlot.morphTo(wsSlot.activeShapes[morphFaceRoot.activeShapeIdx], 0.0);
                    }
                }

                Timer {
                    id: familyMorphTimer
                    interval: 4600 + ((wsSlot.index * 1733) % 4200)
                    repeat: true
                    running: wsSlot.ready && !wsSlot.isActive && wsSlot.shown && morphFaceRoot.visible && (!widget || widget.moduleActive)
                    onTriggered: {
                        if (Math.random() > 0.55) return;
                        if (wsSlot.isOccupied) {
                            let step = 1 + Math.floor(Math.random() * (wsSlot.takenShapes.length - 1));
                            wsSlot.takenIdx = (wsSlot.takenIdx + step) % wsSlot.takenShapes.length;
                            wsSlot.morphTo(wsSlot.takenShapes[wsSlot.takenIdx], 90.0);
                        } else {
                            let step = 1 + Math.floor(Math.random() * (wsSlot.emptyShapes.length - 1));
                            wsSlot.emptyIdx = (wsSlot.emptyIdx + step) % wsSlot.emptyShapes.length;
                            wsSlot.morphTo(wsSlot.emptyShapes[wsSlot.emptyIdx], 90.0);
                        }
                    }
                }

                width: morphFaceRoot.isVertical ? morphFaceRoot.slotSize : (shown ? morphFaceRoot.slotSize : 0)
                height: morphFaceRoot.isVertical ? (shown ? morphFaceRoot.slotSize : 0) : morphFaceRoot.slotSize

                readonly property color targetColor: isActive
                    ? ((widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve)
                    : (isOccupied
                        ? Qt.alpha(ThemeBackend.surface2, ThemeBackend.elementOpacity)
                        : Qt.alpha((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0, ThemeBackend.elementOpacity))

                property color currentColor: targetColor
                Behavior on currentColor {
                    enabled: wsSlot.ready
                    ColorAnimation { duration: 280 }
                }

                Item {
                    id: glassShape
                    anchors.fill: morphShader
                    scale: morphShader.scale
                    layer.enabled: slotGlass.active
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: glassMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    GlassFill {
                        id: slotGlass
                        anchors.fill: parent
                        radius: width / 2
                        tintColor: wsSlot.isActive ? ThemeBackend.mauve : (wsSlot.isOccupied ? ThemeBackend.surface2 : ThemeBackend.surface0)
                        tintAmount: wsSlot.isActive ? 0.5 : 0.3
                        press: wsSlot.pressed ? 0.8 : (wsSlot.isActive ? 0.3 : 0.25 * wsSlot.hoverAnim)
                    }
                }

                ShaderEffect {
                    id: glassMask
                    anchors.fill: morphShader
                    visible: false
                    layer.enabled: slotGlass.active

                    property vector2d itemSize: morphShader.itemSize
                    property real shapeFrom: morphShader.shapeFrom
                    property real shapeTo: morphShader.shapeTo
                    property real shapeBlend: morphShader.shapeBlend
                    property real angleRad: morphShader.angleRad
                    property real hoverAmt: morphShader.hoverAmt
                    property real activeAmt: morphShader.activeAmt
                    property real glassMode: 0.0
                    property color fillColor: "white"
                    property color rimColor: "white"

                    fragmentShader: morphShader.fragmentShader
                }

                ShaderEffect {
                    id: morphShader
                    anchors.centerIn: parent
                    width: morphFaceRoot.slotSize * 1.24
                    height: morphFaceRoot.slotSize * 1.24

                    scale: wsSlot.pressed ? 0.86 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                    property vector2d itemSize: Qt.vector2d(width, height)
                    property real shapeFrom: wsSlot.shapeFrom
                    property real shapeTo: wsSlot.shapeTo
                    property real shapeBlend: wsSlot.shapeBlend
                    property real angleRad: (wsSlot.spinAngle + wsSlot.idleSpin + wsSlot.hoverAnim * 10.0) * Math.PI / 180.0
                    property real hoverAmt: wsSlot.hoverAnim
                    property real activeAmt: wsSlot.activeAmt
                    property real glassMode: ThemeBackend.liquidGlass ? 1.0 : 0.0
                    property color fillColor: slotGlass.active ? Qt.alpha(wsSlot.currentColor, 0) : wsSlot.currentColor
                    property color rimColor: ThemeBackend.text

                    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/widgets/workspace_morph.frag.qsb"
                }

                Component.onCompleted: {
                    let initial = isActive ? activeShapes[morphFaceRoot.activeShapeIdx] : (isOccupied ? takenShapes[takenIdx] : emptyShapes[emptyIdx]);
                    shapeFrom = initial;
                    shapeTo = initial;
                    shapeBlend = 1.0;
                    Qt.callLater(function() { wsSlot.ready = true; });
                }
            }
        }
    }
}
