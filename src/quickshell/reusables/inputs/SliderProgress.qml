import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 24

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0

    property color backgroundColor: "#1e1e2e"
    property color gradColor1: "#89b4fa"
    property color gradColor2: Qt.lighter(gradColor1, 1.05)
    property color gradColor3: Qt.lighter(gradColor1, 1.10)

    property color glowColor: gradColor1
    property real glowRadius: 0.6
    property real glowOpacity: 0.5

    property real cornerRadius: height / 2
    property bool enabled: true

    property bool isDragging: false

    signal moved(real val)
    signal dragStarted()
    signal dragFinished()

    property real visualPosition: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))
    property real animPosition: visualPosition

    property real flow: 0
    property real lastPosition: 0

    Component.onCompleted: lastPosition = animPosition

    onAnimPositionChanged: {
        const d = Math.abs(animPosition - lastPosition) * root.width;
        lastPosition = animPosition;
        if (!thumbGlass.active || d < 0.05) return;
        flow = Math.min(1, flow + d / 28);
        if (!flowDecay.running) flowDecay.start();
    }

    FrameAnimation {
        id: flowDecay
        onTriggered: {
            root.flow *= Math.pow(0.88, frameTime / 0.016);
            if (root.flow < 0.01) {
                root.flow = 0;
                stop();
            }
        }
    }

    Behavior on animPosition {
        enabled: !root.isDragging
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
    }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        radius: root.cornerRadius
        color: glass.active ? "transparent" : root.backgroundColor
        opacity: root.enabled ? 1.0 : 0.5
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180 } }

        GlassFill {
            id: glass
            anchors.fill: parent
            radius: parent.radius
            tintColor: root.backgroundColor
            tintAmount: 0.22
            press: root.isDragging ? 0.35 : 0
            Behavior on tintAmount { NumberAnimation { duration: 180 } }
            Behavior on press { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Item {
            id: fillContainer
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width, parent.width * root.animPosition))
            opacity: root.animPosition > 0.001 ? (glass.active ? 0.6 : 1.0) : 0.0
            clip: true

            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
                width: root.width
                height: parent.height
                radius: root.cornerRadius

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.gradColor1; Behavior on color { ColorAnimation { duration: 500 } } }
                    GradientStop { position: 0.5; color: root.gradColor2; Behavior on color { ColorAnimation { duration: 500 } } }
                    GradientStop { position: 1.0; color: root.gradColor3; Behavior on color { ColorAnimation { duration: 500 } } }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: root.glowColor
                opacity: root.glowOpacity * 0.2
                visible: root.glowOpacity > 0
            }
        }
    }

    GlassFill {
        id: thumbGlass
        readonly property real thumb: root.height + 8
        width: thumb
        height: thumb
        x: Math.max(-4, Math.min(root.width - thumb + 4, root.width * root.animPosition - thumb / 2))
        anchors.verticalCenter: parent.verticalCenter
        radius: thumb / 2
        tintColor: root.gradColor1
        tintAmount: 0.3
        shadow: 1
        press: root.isDragging ? 1 : 0
        scale: root.isDragging ? 1.2 : 1.0
        Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        transform: Scale {
            origin.x: thumbGlass.width / 2
            origin.y: thumbGlass.height / 2
            xScale: 1 + 0.45 * root.flow
            yScale: 1 - 0.12 * root.flow
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    MouseArea {
        id: sliderMa
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => {
            if (!root.enabled) return;
            root.isDragging = true;
            root.dragStarted();
            updateVal(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressed && root.enabled) {
                updateVal(mouse.x);
            }
        }
        onReleased: {
            if (!root.enabled) return;
            root.isDragging = false;
            root.dragFinished();
        }

        function updateVal(mx) {
            let pct = Math.max(0.0, Math.min(1.0, mx / width));
            root.value = root.from + pct * (root.to - root.from);
            root.moved(root.value);
        }
    }
}
