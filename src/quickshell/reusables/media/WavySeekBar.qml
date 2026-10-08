import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import "../"
import "../../"

Item {
    id: bar
    implicitWidth: 200
    implicitHeight: 32

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0
    property bool playing: false
    property bool active: bar.visible && (!Window.window || Window.window.visible)

    property color waveColor: ThemeBackend.mauve || "#cba6f7"
    Behavior on waveColor { ColorAnimation { duration: 600 } }

    property real trackAlpha: 0.28
    property color handleHoverColor: Qt.lighter(waveColor, 1.15)

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    property real handleSize: height < 30 ? Math.max(8, Math.min(14, height * 0.75)) : bar.s(17)
    property real strokeWidth: height < 30 ? Math.max(2.5, handleSize * 0.35) : bar.s(9)
    property real amplitude: height < 30 ? Math.max(3, height * 0.35) : bar.s(14)
    property int cycleMs: 3000
    property real restingLevel: 0.0

    readonly property real cy: height - handleSize * (height < 30 ? 0.65 : 0.7)
    property real pad: handleSize / 2
    property real mouseAreaHeight: height < 30 ? height : Math.min(height, Math.max(handleSize * 1.4, bar.s(22)))
    property bool isDragging: mouseArea.pressed
    signal moved(real val)

    property real ampFactor: playing ? 1.0 : restingLevel
    Behavior on ampFactor {
        NumberAnimation { duration: 600; easing.type: Easing.OutQuad }
    }

    readonly property real liveAmp: ampFactor

    property real progressFraction: (to > from) ? Math.max(0.0, Math.min(1.0, (value - from) / (to - from))) : 0.0
    property real shownFraction: progressFraction
    Behavior on shownFraction {
        enabled: !bar.isDragging
        NumberAnimation { duration: 250; easing.type: Easing.Linear }
    }

    readonly property real progressX: pad + shownFraction * (width - 2 * pad)

    // sin(phase * mult) with mult 1.0, 2.2 and their halves repeats every 20 pi,
    // so the phase loops over 10 cycles without a jump.
    property real phase: 0
    NumberAnimation on phase {
        running: bar.active
        paused: running && !(bar.playing || bar.ampFactor > 0.001)
        from: 0
        to: Math.PI * 20
        duration: bar.cycleMs * 10
        loops: Animation.Infinite
    }

    property real startTaperMax: height < 30 ? 32 : bar.s(64)
    property real scaleFactor: height < 30 ? (height / 35) : 1.0
    readonly property real trackWidth: Math.max(10, bar.width - 2 * bar.pad)
    readonly property real baseLen: (trackWidth > 0 ? (trackWidth / 3.0) : bar.s(65))

    // Drawn by assets/shaders/seekbar_wave.frag: the track, two wave layers and the progress line.
    ShaderEffect {
        id: wave
        anchors.fill: parent

        opacity: (bar.isDragging || mouseArea.containsMouse) ? 1.0 : (bar.playing ? 1.0 : 0.55)
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
        }

        property color waveColor: bar.waveColor
        property size itemSize: Qt.size(width, height)
        property real pad: bar.pad
        property real cy: bar.cy
        property real endX: Math.max(bar.pad, bar.progressX)
        property real strokeWidth: bar.strokeWidth
        property real amplitude: bar.amplitude * bar.liveAmp
        property real trackAlpha: bar.trackAlpha
        property real startTaper: bar.startTaperMax
        property real phase: bar.phase
        property vector4d shape0: Qt.vector4d(0.65, 0.50, bar.s(130) * bar.scaleFactor, bar.baseLen * 1.75)
        property vector4d shape1: Qt.vector4d(0.71, 0.90, bar.s(105) * bar.scaleFactor, bar.baseLen * 1.05)
        property vector4d motion0: Qt.vector4d(1.0, 0.0, 0.0, 0.0)
        property vector4d motion1: Qt.vector4d(2.2, 1.8, Math.PI, 0.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/seekbar_wave.frag.qsb"
    }

    Rectangle {
        id: handle
        x: Math.max(0, Math.min(bar.width - width, bar.progressX - width / 2))
        y: bar.cy - height / 2
        width: bar.handleSize
        height: bar.handleSize
        radius: width / 2
        color: bar.isDragging ? bar.handleHoverColor : (mouseArea.containsMouse ? bar.handleHoverColor : bar.waveColor)
        opacity: 1.0
        scale: bar.isDragging ? 1.25 : (mouseArea.containsMouse ? 1.15 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: bar.s(1.0)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.45
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        height: bar.mouseAreaHeight
        y: Math.max(0, Math.min(bar.height - height, Math.round(bar.cy - height / 2)))
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updatePos(mx) {
            var avail = bar.width - 2 * bar.pad;
            if (avail <= 0) return;
            var frac = Math.max(0.0, Math.min(1.0, (mx - bar.pad) / avail));
            var newVal = bar.from + frac * (bar.to - bar.from);
            bar.value = newVal;
            bar.moved(newVal);
        }

        onPressed: mouse => updatePos(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) updatePos(mouse.x);
        }
    }
}
