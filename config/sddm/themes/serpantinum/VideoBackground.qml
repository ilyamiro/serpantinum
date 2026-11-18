import QtQuick
import QtMultimedia

Item {
    id: root
    required property url media
    signal firstFrame()
    property bool hasFrame: false

    MediaPlayer {
        source: root.media
        videoOutput: playback
        loops: MediaPlayer.Infinite
        autoPlay: true
    }

    VideoOutput {
        id: playback
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: root.hasFrame ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
    }

    Connections {
        target: playback.videoSink
        enabled: !root.hasFrame
        function onVideoFrameChanged() {
            root.hasFrame = true
            root.firstFrame()
        }
    }
}
