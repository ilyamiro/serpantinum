import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"

Rectangle {
    id: presetCard
    required property var tab
    required property real tileWidth
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    property color accentColor: ThemeBackend.surface0
    property real popScale: 1.0
    property real flashOpacity: 0.0

    width: presetCard.tileWidth
    height: presetImageBox.height + rootObj.s(28)
    radius: ThemeBackend.borderRadius
    clip: true

    color: presetGlass.active ? "transparent" : (presetMouse.pressed ? Qt.darker(presetCard.accentColor, 1.28) : (presetHover.hovered ? Qt.darker(presetCard.accentColor, 1.14) : presetCard.accentColor))
    Behavior on color { ColorAnimation { duration: 150 } }

    GlassFill {
        id: presetGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: presetCard.accentColor
        tintAmount: presetMouse.pressed ? 0.55 : (presetHover.hovered ? 0.42 : 0.3)
        press: presetMouse.pressed ? 1 : (presetHover.hovered ? 0.25 : 0)
        pulse: Math.min(1, presetCard.flashOpacity * 2.5)
        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on tintAmount { NumberAnimation { duration: 150 } }
    }

    scale: (presetMouse.pressed ? 0.985 : (presetHover.hovered ? 1.015 : 1.0)) * presetCard.popScale
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

    HoverHandler {
        id: presetHover
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: "#ffffff"
        opacity: presetCard.flashOpacity
        visible: !presetGlass.active
        PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: presetCard; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: presetCard; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: presetMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            popAnim.start();
            presetCard.flashOpacity = 0.15;
            flashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx("reusables/clickbutton/click.wav");
            }
            presetCard.tab.requestApply(presetCard.modelData);
        }
    }

    Rectangle {
        id: presetImageBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(width * 10 / 16)
        color: Qt.darker(presetCard.accentColor, 1.15)

        layer.enabled: presetImage.status === Image.Ready
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: imageMask
        }

        Item {
            id: imageMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                width: parent.width
                height: parent.height + ThemeBackend.borderRadius * 2
                radius: ThemeBackend.borderRadius
                color: "white"
            }
        }

        BoundedImage {
            id: presetImage
            anchors.fill: parent
            source: presetCard.tab.imageSource(presetCard.modelData.image)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        Text {
            anchors.centerIn: parent
            visible: presetImage.status !== Image.Ready
            text: "󰆓"
            font.family: ThemeBackend.iconFont
            font.pixelSize: Math.round(parent.height * 0.32)
            color: Qt.alpha(ThemeBackend.subtext0, 0.5)
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: presetImageBox.bottom

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: rootObj.s(8)
            anchors.rightMargin: rootObj.s(8)
            spacing: rootObj.s(4)

            Text {
                text: presetCard.modelData.name || presetCard.modelData.id || ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                font.bold: true
                color: ThemeBackend.text
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            IconButton {
                size: rootObj.s(22)
                Layout.preferredWidth: rootObj.s(22)
                Layout.preferredHeight: rootObj.s(22)
                cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                buttonIcon: "󰋩"
                iconFontSize: rootObj.s(12)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                Layout.alignment: Qt.AlignVCenter
                onClicked: presetCard.tab.pickImage(presetCard.modelData, presetCard.modelData.image)
            }

            DeleteButton {
                size: rootObj.s(22)
                cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                iconFontSize: rootObj.s(11)
                Layout.alignment: Qt.AlignVCenter
                onClicked: presetCard.tab.deletePreset(presetCard.modelData)
            }
        }
    }
}
