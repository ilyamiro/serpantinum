import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: root.shape === "rect"

    property bool previewMode: false
    property string shape: "rect"
    property string imagePath: ""

    readonly property bool roundShape: root.shape === "round"
    readonly property bool roundedShape: root.shape === "rounded"

    property real minWidth: root.roundShape ? 40 : 30
    property real minHeight: root.roundShape ? 40 : 30
    property real maxWidth: root.roundShape ? 3000 : 4000
    property real maxHeight: root.roundShape ? 3000 : 4000
    property real minAspect: root.roundShape ? 1.0 : 0.02
    property real maxAspect: root.roundShape ? 1.0 : 50.0
    property bool isRound: root.roundShape

    readonly property string imageSource: root.imagePath !== "" ? (root.imagePath.startsWith("file://") ? root.imagePath : "file://" + root.imagePath) : ""
    readonly property real cornerRadius: root.roundShape ? (width / 2) : (root.roundedShape ? (ThemeBackend.borderRadius !== undefined ? ThemeBackend.borderRadius : 12) : 0)

    Rectangle {
        anchors.fill: parent
        color: (root.imagePath === "" || srcImage.status !== Image.Ready) ? ThemeBackend.surface0 : "transparent"
        radius: root.cornerRadius
        clip: root.shape === "rect"
        antialiasing: root.shape !== "rect"

        BoundedImage {
            id: srcImage
            anchors.fill: parent
            source: root.imageSource
            fillMode: root.roundShape ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            antialiasing: true
            allowAnimation: true
            playing: true
            visible: root.shape === "rect" && status === Image.Ready
        }

        Item {
            id: maskContainer
            anchors.fill: parent
            visible: false
            layer.enabled: root.shape !== "rect"
            layer.smooth: true
            layer.mipmap: root.roundShape
            layer.samples: root.roundShape ? 4 : 0
            layer.textureSize: root.roundShape ? Qt.size(
                Math.max(1, Math.ceil(width * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2)),
                Math.max(1, Math.ceil(height * (Screen.devicePixelRatio ? Screen.devicePixelRatio : 1) * 2))
            ) : Qt.size(0, 0)

            Rectangle {
                x: root.roundedShape ? Math.round((parent.width - (srcImage.paintedWidth > 0 ? srcImage.paintedWidth : parent.width)) / 2) : 0
                y: root.roundedShape ? Math.round((parent.height - (srcImage.paintedHeight > 0 ? srcImage.paintedHeight : parent.height)) / 2) : 0
                width: root.roundedShape ? Math.round(srcImage.paintedWidth > 0 ? srcImage.paintedWidth : parent.width) : parent.width
                height: root.roundedShape ? Math.round(srcImage.paintedHeight > 0 ? srcImage.paintedHeight : parent.height) : parent.height
                radius: root.cornerRadius
                color: "white"
                antialiasing: true
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: srcImage
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: maskContainer
            visible: root.shape !== "rect" && root.imagePath !== "" && srcImage.status === Image.Ready
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
