import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 100
    property real maxWidth: 1200
    property real maxHeight: 500
    property real minAspect: 1.8
    property real maxAspect: 7.0

    readonly property var player: MprisController.activePlayer
    readonly property bool active: player !== null && player.trackTitle !== ""
    property var levels: Cava.barLevels
    readonly property int barCount: Math.min(64, Math.max(16, Math.floor(root.width / 8)))

    Component.onCompleted: Cava.registerConsumer()
    Component.onDestruction: Cava.unregisterConsumer()

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, root.height * 0.12)
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: active ? player.trackTitle : "No music playing"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(12, root.height * 0.14)
                font.weight: Font.Bold
                color: ThemeBackend.text
                elide: Text.ElideRight
            }
            Text {
                text: active ? (player.isPlaying ? "󰐊" : "󰏤") : "󰎈"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(16, root.height * 0.18)
                color: ThemeBackend.mauve
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.max(2, root.width / 180)
            anchors.bottom: parent.bottom

            Repeater {
                model: root.barCount
                delegate: Rectangle {
                    required property int index
                    width: (parent.width - (root.barCount - 1) * parent.spacing) / root.barCount
                    height: Math.max(3, (root.levels.length > 0 ? root.levels[index % root.levels.length] : 0) * parent.height)
                    radius: width / 2
                    color: ThemeBackend.mauve
                    opacity: 0.35 + height / Math.max(1, parent.height) * 0.65
                    anchors.bottom: parent.bottom
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
    }
}
