import QtQuick
import QtQuick.Layouts
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
        uploadLevels(null);
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    property real barSpacing: Scaler.s(4)
    property real minBarWidth: Scaler.s(6)
    property int activeBars: Math.max(4, Math.min(128, Math.floor((width + barSpacing) / (minBarWidth + barSpacing))))

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

    function uploadLevels(source) {
        let v = new Array(64).fill(0.0);
        if (source) {
            for (let i = 0; i < Math.min(64, source.length); i++) v[i] = source[i];
        }
        levels0 = packLevels(v, 0);
        levels1 = packLevels(v, 16);
        levels2 = packLevels(v, 32);
        levels3 = packLevels(v, 48);
    }

    onIsSubscribedChanged: uploadLevels(isSubscribed ? Cava.barLevels : null)

    Connections {
        target: Cava
        enabled: root.isSubscribed
        function onBarLevelsChanged() {
            root.uploadLevels(Cava.barLevels);
        }
    }

    ShaderEffect {
        anchors.fill: parent

        property matrix4x4 levels0: root.levels0
        property matrix4x4 levels1: root.levels1
        property matrix4x4 levels2: root.levels2
        property matrix4x4 levels3: root.levels3
        property color barColor: ThemeBackend.mauve
        property size itemSize: Qt.size(width, height)
        property real barCount: root.activeBars
        property real sourceCount: Math.max(2, Math.min(64, Cava.barCount))
        property real spacing: root.barSpacing
        property real minBarHeight: Scaler.s(3)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/visualizer_bars.frag.qsb"
    }
}
