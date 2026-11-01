import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 40
    property real minHeight: 40
    property real maxWidth: 3000
    property real maxHeight: 3000
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property string imagePath: (typeof model !== "undefined" && model && model.wImagePath) ? model.wImagePath : (parent && parent.wImagePath ? parent.wImagePath : "")

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: (root.imagePath === "" || srcImage.status !== Image.Ready) ? ThemeBackend.surface0 : "transparent"
        radius: width / 2
        antialiasing: true

        Item {
            id: maskContainer
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.samples: 4
            layer.textureSize: Qt.size(
                Math.max(1, Math.ceil(width * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2)),
                Math.max(1, Math.ceil(height * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2))
            )

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "white"
                antialiasing: true
            }
        }

        Item {
            id: imageContainer
            anchors.fill: parent
            visible: root.imagePath !== "" && srcImage.status === Image.Ready
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.samples: 4
            layer.textureSize: Qt.size(
                Math.max(1, Math.ceil(width * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2)),
                Math.max(1, Math.ceil(height * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2))
            )
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskContainer
                autoPaddingEnabled: false
            }

            BoundedImage {
                id: srcImage
                anchors.fill: parent
                source: root.imagePath !== "" ? (root.imagePath.startsWith("file://") ? root.imagePath : "file://" + root.imagePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                antialiasing: true
                allowAnimation: true
                playing: true
            }
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || srcImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: ThemeBackend.iconFont
                font.pixelSize: Math.max(16, Math.min(root.width, root.height) * 0.35)
                color: ThemeBackend.subtext0
            }
        }
    }
}
