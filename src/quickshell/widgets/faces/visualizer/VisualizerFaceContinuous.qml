import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 50
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible

    property bool isSubscribed: false

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Component.onCompleted: {
        uploadLevels(new Array(64).fill(0.0));
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    property int sampleCount: 64
    property var currentLevels: []
    property bool settling: false

    property matrix4x4 levels0
    property matrix4x4 levels1
    property matrix4x4 levels2
    property matrix4x4 levels3

    function packLevels(v, o) {
        return Qt.matrix4x4(v[o], v[o + 1], v[o + 2], v[o + 3],
                            v[o + 4], v[o + 5], v[o + 6], v[o + 7],
                            v[o + 8], v[o + 9], v[o + 10], v[o + 11],
                            v[o + 12], v[o + 13], v[o + 14], v[o + 15]);
    }

    function uploadLevels(v) {
        levels0 = packLevels(v, 0);
        levels1 = packLevels(v, 16);
        levels2 = packLevels(v, 32);
        levels3 = packLevels(v, 48);
    }

    onIsSubscribedChanged: if (isSubscribed) settling = true

    Connections {
        target: Cava
        enabled: root.isSubscribed
        function onBarLevelsChanged() {
            root.settling = true;
        }
    }

    FrameAnimation {
        running: root.isVisVisible && root.settling
        onTriggered: {
            let target = Cava.barLevels || [];
            let cur = root.currentLevels;
            let rise = 1 - Math.pow(0.75, frameTime / 0.016);
            let fall = 1 - Math.pow(0.88, frameTime / 0.016);
            let next = new Array(64).fill(0.0);
            let moving = false;

            for (let i = 0; i < Math.min(64, target.length); i++) {
                let t = target[i] || 0.0;
                let c = cur[i] || 0.0;
                if (Math.abs(t - c) > 0.001) {
                    c += (t - c) * (t > c ? rise : fall);
                    moving = true;
                } else {
                    c = t;
                }
                next[i] = c;
            }

            root.currentLevels = next;
            root.uploadLevels(next);
            if (!moving) root.settling = false;
        }
    }

    ShaderEffect {
        anchors.fill: parent

        property matrix4x4 levels0: root.levels0
        property matrix4x4 levels1: root.levels1
        property matrix4x4 levels2: root.levels2
        property matrix4x4 levels3: root.levels3
        property color waveColor: ThemeBackend.mauve
        property size itemSize: Qt.size(width, height)
        property real pointCount: Math.max(2, Math.min(64, root.sampleCount))
        property real sourceCount: Math.max(2, Math.min(64, Cava.barCount))

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/visualizer_wave.frag.qsb"
    }
}
