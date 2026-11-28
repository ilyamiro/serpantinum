import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"
import "."

Item {
    id: pacmanFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    property real slotSize: widget ? widget.s(widget.isCompact ? 16 : 18) : 18
    property real slotSpacing: widget ? widget.s(widget.isCompact ? 7 : 8) : 8

    property real pacmanSize: slotSize * 1.15

    readonly property var shownIndices: widget ? widget.shownIndices : []
    readonly property int shownCount: widget ? widget.shownCount : 0
    readonly property int activeShownSlot: shownIndices.indexOf(activeIdx)
    readonly property real settledLength: shownCount > 0 ? shownCount * slotSize + (shownCount - 1) * slotSpacing : 0

    implicitWidth: isVertical ? slotSize : settledLength
    implicitHeight: isVertical ? settledLength : slotSize

    property int activeIdx: widget ? widget.activeIndex : 0
    property int prevIdx: 0
    property bool facingLeft: false
    property real pacmanAngle: 90

    property real stepSize: slotSize + slotSpacing
    property real targetPacmanPos: activeShownSlot >= 0 ? ((isVertical ? pelletsLayout.y : pelletsLayout.x) + activeShownSlot * stepSize) : 0
    property real currentPacmanPos: targetPacmanPos

    Behavior on currentPacmanPos {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
    }

    property real mouthAngle: 0.18

    SequentialAnimation {
        id: chompAnim
        loops: 3
        NumberAnimation {
            target: pacmanFaceRoot
            property: "mouthAngle"
            to: 0.02
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: pacmanFaceRoot
            property: "mouthAngle"
            to: 0.18
            duration: 80
            easing.type: Easing.InOutQuad
        }
    }

    readonly property color pacmanColor: (ThemeBackend && ThemeBackend.primary)
        ? ThemeBackend.primary
        : ((ThemeBackend && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7")

    readonly property color ghostColor: (ThemeBackend && ThemeBackend.surface2)
        ? ThemeBackend.surface2
        : ((ThemeBackend && ThemeBackend.surface1) ? ThemeBackend.surface1 : "#585b70")

    onActiveIdxChanged: {
        if (activeIdx < prevIdx) {
            facingLeft = true;
            pacmanAngle = 270;
        } else if (activeIdx > prevIdx) {
            facingLeft = false;
            pacmanAngle = 90;
        }
        prevIdx = activeIdx;
        chompAnim.restart();
    }

    AxisFlow {
        id: pelletsLayout
        vertical: pacmanFaceRoot.isVertical
        z: 1
        anchors.centerIn: parent
        spacing: pacmanFaceRoot.slotSpacing

        Repeater {
            model: widget ? (widget.slotModel || widget.workspaceCount) : 0

            delegate: WorkspaceSlot {
                id: pelletSlot
                widget: pacmanFaceRoot.widget
                isVertical: pacmanFaceRoot.isVertical
                slideDuration: 650

                width: pacmanFaceRoot.isVertical ? pacmanFaceRoot.slotSize : (shown ? pacmanFaceRoot.slotSize : 0)
                height: pacmanFaceRoot.isVertical ? (shown ? pacmanFaceRoot.slotSize : 0) : pacmanFaceRoot.slotSize

                property bool isPowerPellet: index % 2 === 1

                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    visible: !pelletSlot.isOccupied
                    width: pelletSlot.isPowerPellet
                        ? (widget ? widget.s(widget.isCompact ? 10 : 12) : 12)
                        : (widget ? widget.s(widget.isCompact ? 7 : 9) : 9)
                    height: width
                    radius: width / 2
                    color: Qt.alpha((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0, ThemeBackend.elementOpacity)
                    opacity: pelletSlot.isActive ? 0.0 : (pelletSlot.isHovered ? 1.0 : 0.85)

                    scale: pelletSlot.isActive ? 0.0 : (pelletSlot.pressed ? 0.88 : (pelletSlot.isHovered ? 1.2 : 1.0))
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Item {
                    id: ghostItem
                    anchors.centerIn: parent
                    visible: pelletSlot.isOccupied
                    width: pacmanFaceRoot.slotSize * 1.2
                    height: width * 1.1

                    scale: pelletSlot.isActive ? 0.0 : (pelletSlot.pressed ? 0.88 : (pelletSlot.isHovered ? 1.15 : 1.0))
                    opacity: pelletSlot.isActive ? 0.0 : (pelletSlot.isHovered ? 1.0 : 0.85)

                    Behavior on scale {
                        NumberAnimation {
                            duration: pelletSlot.isActive ? 180 : 250
                            easing.type: pelletSlot.isActive ? Easing.InBack : Easing.OutBack
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Canvas {
                        id: ghostCanvas
                        anchors.fill: parent

                        Connections {
                            target: ThemeBackend
                            ignoreUnknownSignals: true
                            function onSurface2Changed() { ghostCanvas.requestPaint(); }
                            function onSurface1Changed() { ghostCanvas.requestPaint(); }
                            function onOverlay0Changed() { ghostCanvas.requestPaint(); }
                            function onCrustChanged() { ghostCanvas.requestPaint(); }
                        }

                        Connections {
                            target: pacmanFaceRoot
                            ignoreUnknownSignals: true
                            function onActiveIdxChanged() { ghostCanvas.requestPaint(); }
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.reset();

                            let pad = 1.0;
                            let w = width - 2 * pad;
                            let h = height - 2 * pad;
                            let r = w / 2;
                            let x0 = pad;
                            let y0 = pad;
                            let bottomY = y0 + h;
                            let waveH = h * 0.14;

                            let c = pacmanFaceRoot.ghostColor;

                            ctx.beginPath();
                            ctx.moveTo(x0, y0 + r);
                            ctx.arc(x0 + r, y0 + r, r, Math.PI, 0, false);
                            ctx.lineTo(x0 + w, bottomY);
                            ctx.quadraticCurveTo(x0 + w * 5 / 6, bottomY - waveH, x0 + w * 2 / 3, bottomY);
                            ctx.quadraticCurveTo(x0 + w / 2, bottomY - waveH, x0 + w / 3, bottomY);
                            ctx.quadraticCurveTo(x0 + w / 6, bottomY - waveH, x0, bottomY);
                            ctx.lineTo(x0, y0 + r);
                            ctx.closePath();
                            ctx.fillStyle = c;
                            ctx.fill();

                            let eyeR = w * 0.16;
                            let eye1X = x0 + w * 0.32;
                            let eye2X = x0 + w * 0.68;
                            let eyeY = y0 + r * 0.95;

                            ctx.beginPath();
                            ctx.arc(eye1X, eyeY, eyeR, 0, 2 * Math.PI, false);
                            ctx.arc(eye2X, eyeY, eyeR, 0, 2 * Math.PI, false);
                            ctx.fillStyle = "#ffffff";
                            ctx.fill();

                            let pupilR = eyeR * 0.55;
                            let pShift = (pacmanFaceRoot.activeIdx > pelletSlot.index)
                                ? (eyeR * 0.35)
                                : ((pacmanFaceRoot.activeIdx < pelletSlot.index) ? (-eyeR * 0.35) : 0);

                            ctx.beginPath();
                            let pShiftX = pacmanFaceRoot.isVertical ? 0 : pShift;
                            let pShiftY = pacmanFaceRoot.isVertical ? pShift : 0;
                            ctx.arc(eye1X + pShiftX, eyeY + pShiftY, pupilR, 0, 2 * Math.PI, false);
                            ctx.arc(eye2X + pShiftX, eyeY + pShiftY, pupilR, 0, 2 * Math.PI, false);
                            ctx.fillStyle = (ThemeBackend && ThemeBackend.crust) ? ThemeBackend.crust : "#11111b";
                            ctx.fill();
                        }
                    }
                }
            }
        }
    }

    Item {
        id: pacmanActor
        z: 3
        x: pacmanFaceRoot.isVertical ? pelletsLayout.x + (pelletsLayout.width - width) / 2 : pacmanFaceRoot.currentPacmanPos + (pacmanFaceRoot.slotSize - width) / 2
        y: pacmanFaceRoot.isVertical ? pacmanFaceRoot.currentPacmanPos + (pacmanFaceRoot.slotSize - height) / 2 : pelletsLayout.y + (pelletsLayout.height - height) / 2
        width: pacmanFaceRoot.pacmanSize
        height: pacmanFaceRoot.pacmanSize
        visible: widget && widget.workspaceCount > 0 && pacmanFaceRoot.activeShownSlot >= 0
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        rotation: pacmanFaceRoot.isVertical ? pacmanFaceRoot.pacmanAngle : 0

        transform: Scale {
            origin.x: pacmanActor.width / 2
            origin.y: pacmanActor.height / 2
            xScale: (!pacmanFaceRoot.isVertical && pacmanFaceRoot.facingLeft) ? -1 : 1
        }

        ShaderEffect {
            id: pacmanCanvas
            anchors.fill: parent

            property vector2d itemSize: Qt.vector2d(width, height)
            property real mouth: pacmanFaceRoot.mouthAngle
            property color bodyColor: (widget && widget.isCompact)
                ? Qt.lighter(pacmanFaceRoot.pacmanColor, 1.05)
                : pacmanFaceRoot.pacmanColor
            property color eyeColor: (ThemeBackend && ThemeBackend.crust) ? ThemeBackend.crust : "#11111b"

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/widgets/pacman.frag.qsb"
        }
    }
}
