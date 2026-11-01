import QtQuick
import QtMultimedia

Item {
    id: videoRoot
    anchors.fill: parent
    property string wallpaperPath: ""
    property bool isReady: false
    property bool paused: false

    onPausedChanged: {
        if (paused) lockVideoPlayer.pause();
        else if (lockVideoPlayer.source !== "") lockVideoPlayer.play();
    }

    MediaPlayer {
        id: lockVideoPlayer
        source: videoRoot.wallpaperPath ? (videoRoot.wallpaperPath.startsWith("file://") ? videoRoot.wallpaperPath : "file://" + videoRoot.wallpaperPath) : ""
        videoOutput: lockVideoOutput
        loops: MediaPlayer.Infinite

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                if (!videoRoot.paused) lockVideoPlayer.play();
            } else if (mediaStatus === MediaPlayer.InvalidMedia || mediaStatus === MediaPlayer.NoMedia) {
                videoRoot.isReady = false;
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                videoRoot.isReady = true;
            }
        }

        onSourceChanged: {
            if (source !== "" && !videoRoot.paused) {
                play();
            }
        }

        Component.onCompleted: {
            if (source !== "" && !videoRoot.paused) {
                play();
            }
        }
    }

    VideoOutput {
        id: lockVideoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: videoRoot.isReady ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }
    }
}
