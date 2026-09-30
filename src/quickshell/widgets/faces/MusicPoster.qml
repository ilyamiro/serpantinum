import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 120
    property real maxWidth: 1000
    property real maxHeight: 500
    property real minAspect: 1.5
    property real maxAspect: 5.0

    readonly property var player: MprisController.activePlayer
    readonly property bool active: player !== null && player.trackTitle !== ""

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, Math.min(root.width, root.height) * 0.1)
        spacing: 14

        Image {
            Layout.preferredWidth: Math.min(root.height - 24, root.width * 0.3)
            Layout.preferredHeight: Layout.preferredWidth
            source: active ? MprisController.currentArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            sourceSize.width: 512
            sourceSize.height: 512
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: active ? player.trackTitle : "Nothing playing"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(14, root.height * 0.16)
                font.weight: Font.Black
                color: ThemeBackend.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: active ? player.trackArtist : "Start a song to see it here"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(10, root.height * 0.09)
                color: ThemeBackend.subtext0
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: active ? (player.isPlaying ? "PLAYING" : "PAUSED") : ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(9, root.height * 0.07)
                font.letterSpacing: 1.5
                color: ThemeBackend.mauve
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
    }
}
