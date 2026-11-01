import QtQuick

Item {
    id: root

    property url source: ""
    property int fillMode: Image.PreserveAspectFit
    property bool allowAnimation: false
    readonly property bool animatedCandidate: allowAnimation && /\.(gif|webp)$/i.test(String(source))
    property bool playing: true
    property bool asynchronous: true
    property bool cache: true
    property bool smooth: true
    property bool antialiasing: false
    property int horizontalAlignment: Image.AlignHCenter
    property int verticalAlignment: Image.AlignVCenter
    property real devicePixelRatio: (Screen.devicePixelRatio && Screen.devicePixelRatio > 0) ? Screen.devicePixelRatio : 1
    property int decodeStep: 128

    readonly property Item image: loader.item
    readonly property int status: image ? image.status : Image.Null
    readonly property real paintedWidth: image ? image.paintedWidth : 0
    readonly property real paintedHeight: image ? image.paintedHeight : 0
    readonly property bool isAnimated: animatedCandidate && !probedStatic

    property bool probedStatic: false
    property int decodeEdge: 0

    function neededEdge() {
        let edge = Math.max(width, height) * devicePixelRatio;
        if (!(edge > 0)) return 0;
        return Math.ceil(edge / decodeStep) * decodeStep;
    }

    function growDecodeEdge() {
        let need = neededEdge();
        if (need > decodeEdge) decodeEdge = need;
    }

    function scheduleDecodeEdge() {
        if (decodeEdge === 0) growDecodeEdge();
        else resizeDebounce.restart();
    }

    onWidthChanged: scheduleDecodeEdge()
    onHeightChanged: scheduleDecodeEdge()
    onDevicePixelRatioChanged: scheduleDecodeEdge()
    onSourceChanged: {
        probedStatic = false;
        decodeEdge = neededEdge();
    }
    Component.onCompleted: growDecodeEdge()

    Timer {
        id: resizeDebounce
        interval: 250
        onTriggered: root.growDecodeEdge()
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: String(root.source) !== "" && (root.isAnimated || root.decodeEdge > 0)
        sourceComponent: root.isAnimated ? animatedComponent : stillComponent
    }

    Component {
        id: stillComponent
        Image {
            source: root.source
            sourceSize: Qt.size(root.decodeEdge, root.decodeEdge)
            fillMode: root.fillMode
            asynchronous: root.asynchronous
            cache: root.cache
            smooth: root.smooth
            antialiasing: root.antialiasing
            mipmap: false
            horizontalAlignment: root.horizontalAlignment
            verticalAlignment: root.verticalAlignment
        }
    }

    Component {
        id: animatedComponent
        AnimatedImage {
            source: root.source
            fillMode: root.fillMode
            asynchronous: root.asynchronous
            cache: root.cache
            smooth: root.smooth
            antialiasing: root.antialiasing
            mipmap: false
            playing: root.playing
            horizontalAlignment: root.horizontalAlignment
            verticalAlignment: root.verticalAlignment
            onStatusChanged: {
                if (status === AnimatedImage.Ready && frameCount <= 1) {
                    let probed = String(source);
                    Qt.callLater(() => {
                        if (String(root.source) === probed) root.probedStatic = true;
                    });
                }
            }
        }
    }
}
