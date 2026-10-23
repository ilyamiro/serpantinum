import QtQuick
import QtMultimedia

Item {
    id: videoRoot
    property var picker

    MediaPlayer {
        id: previewPlayer
        source: videoRoot.picker && videoRoot.picker.selectedIsVideo ? "file://" + videoRoot.picker.selectedFilePath : ""
        videoOutput: previewVideoOutput
        loops: MediaPlayer.Infinite
        audioOutput: null
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                play();
        }
    }

    VideoOutput {
        id: previewVideoOutput
        anchors.fill: parent
        fillMode: videoRoot.picker && videoRoot.picker.showCircleMask ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
    }
}
