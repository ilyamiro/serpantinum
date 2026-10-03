import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../../"
import "../"

Item {
    id: root
    implicitWidth: size
    implicitHeight: size

    property int size: 44
    property int cornerRadius: 12
    property int imageRadius: -1

    property string source: ""
    property bool isGif: false
    property bool playing: true
    property int fillMode: Image.PreserveAspectCrop

    property bool interactive: false
    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int borderWidth: 0

    property bool action_highlight: false
    property string clickSound: "reusables/imagebox/click.wav"

    signal clicked()
    signal doubleClicked()
    signal pressAndHold()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.interactive
    property bool isPressed: btnMa.pressed && root.interactive

    Rectangle {
        id: container
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.backgroundColor
        border.color: root.borderColor
        border.width: root.borderWidth
        clip: true

        scale: (!root.interactive ? 1.0 : (root.isPressed ? 0.94 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        Item {
            anchors.fill: parent
            anchors.margins: root.borderWidth

            Rectangle {
                id: maskRect
                anchors.fill: parent
                radius: root.imageRadius >= 0 ? root.imageRadius : Math.max(0, root.cornerRadius - root.borderWidth)
                color: "black"
                visible: false
                layer.enabled: true
            }

            Loader {
                id: mediaLoader
                anchors.fill: parent
                sourceComponent: root.isGif ? gifComponent : staticComponent
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: mediaLoader
                maskEnabled: true
                maskSource: maskRect
            }
        }

        Component {
            id: staticComponent
            Image {
                anchors.fill: parent
                source: root.source
                fillMode: root.fillMode
                sourceSize: Qt.size(parent.width, parent.height)
                asynchronous: true
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
            }
        }

        Component {
            id: gifComponent
            AnimatedImage {
                anchors.fill: parent
                source: root.source
                fillMode: root.fillMode
                playing: root.playing && root.visible
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.borderWidth
            radius: root.imageRadius >= 0 ? root.imageRadius : Math.max(0, root.cornerRadius - root.borderWidth)
            color: "#ffffff"
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.08; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (!root.interactive) return;
            btnPopAnim.start();
            root.flashOpacity = 0.3;
            btnFlashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx(root.clickSound);
            }
            root.clicked();
        }

        onDoubleClicked: {
            if (!root.interactive) return;
            root.doubleClicked();
        }

        onPressAndHold: {
            if (!root.interactive) return;
            root.pressAndHold();
        }
    }
}
