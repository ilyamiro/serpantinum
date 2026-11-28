import QtQuick
import QtMultimedia

Item {
    id: root

    property string videoPath: ""
    property bool shouldAutoPlay: false

    function play() {
        player.play();
    }

    function stop() {
        player.stop();
    }

    MediaPlayer {
        id: player
        source: root.videoPath !== "" ? ("file://" + root.videoPath) : ""
        videoOutput: videoOutput
        loops: MediaPlayer.Infinite
        onMediaStatusChanged: {
            if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && root.shouldAutoPlay) {
                player.play();
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
