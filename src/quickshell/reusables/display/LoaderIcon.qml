import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Item {
    id: root
    implicitWidth: 64
    implicitHeight: 64

    property color accentColor: "#89b4fa"
    property bool running: true
    property real morphSpeed: 1.0

    opacity: running ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

    property var shapeConfigs: [
        {p: 7, d: 0.08, ax: 1.0, ay: 1.0},
        {p: 9, d: 0.12, ax: 1.0, ay: 1.0},
        {p: 5, d: 0.15, ax: 1.0, ay: 1.0},
        {p: 2, d: 0.10, ax: 1.3, ay: 0.7},
        {p: 8, d: 0.18, ax: 1.0, ay: 1.0},
        {p: 4, d: 0.15, ax: 1.0, ay: 1.0},
        {p: 0, d: 0.00, ax: 1.2, ay: 0.8}
    ]

    property int currentIndex: 0
    property int nextIndex: 1
    property real morphProgress: 0.0
    property real kickRotation: 0.0
    property real baseRotation: 0.0

    NumberAnimation on baseRotation {
        from: 0
        to: 360
        duration: 9100 / root.morphSpeed
        loops: Animation.Infinite
        running: root.running
    }

    Behavior on morphProgress {
        id: morphBehavior
        SpringAnimation {
            spring: 6.0
            damping: 0.5
            mass: 1.0
            epsilon: 0.001
        }
    }

    Behavior on kickRotation {
        SpringAnimation {
            spring: 6.0
            damping: 0.5
            mass: 1.0
            epsilon: 0.001
        }
    }

    Component.onCompleted: {
        root.morphProgress = 1.0;
        root.kickRotation = 45.0;
    }

    Timer {
        id: cycleTimer
        interval: 650 / root.morphSpeed
        running: root.running
        repeat: true
        onTriggered: {
            morphBehavior.enabled = false;
            root.morphProgress = 0.0;
            root.currentIndex = root.nextIndex;
            root.nextIndex = (root.nextIndex + 1) % 7;
            
            morphBehavior.enabled = true;
            root.morphProgress = 1.0;
            root.kickRotation += 45.0;
        }
    }

    ShaderEffect {
        id: blobShader
        anchors.fill: parent
        rotation: root.baseRotation + root.kickRotation

        property vector2d itemSize: Qt.vector2d(width, height)
        property color accentColor: root.accentColor
        property vector4d cfg1: {
            let c = root.shapeConfigs[root.currentIndex];
            return Qt.vector4d(c.p, c.d, c.ax, c.ay);
        }
        property vector4d cfg2: {
            let c = root.shapeConfigs[root.nextIndex];
            return Qt.vector4d(c.p, c.d, c.ax, c.ay);
        }
        property vector4d params: Qt.vector4d(root.morphProgress, 0.0, 0.0, 0.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/loader_blob.frag.qsb"
    }
}
