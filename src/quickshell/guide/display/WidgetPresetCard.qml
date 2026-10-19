import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"

Rectangle {
    id: presetCard
    required property var tab
    required property string monName
    required property real tileWidth
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    property color accentColor: ThemeBackend.surface0
    property real popScale: 1.0
    property real flashOpacity: 0.0

    width: presetCard.tileWidth
    height: presetPreviewBox.height + rootObj.s(28)
    radius: ThemeBackend.borderRadius
    clip: true

    color: presetGlass.active ? "transparent" : (presetMouse.pressed ? Qt.darker(presetCard.accentColor, 1.28) : (presetHover.hovered ? Qt.darker(presetCard.accentColor, 1.14) : presetCard.accentColor))
    Behavior on color { ColorAnimation { duration: 180 } }

    GlassFill {
        id: presetGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: presetCard.accentColor
        tintAmount: presetMouse.pressed ? 0.55 : (presetHover.hovered ? 0.42 : 0.3)
        press: presetMouse.pressed ? 1 : (presetHover.hovered ? 0.25 : 0)
        pulse: Math.min(1, presetCard.flashOpacity * 2.5)
        Behavior on press { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on tintAmount { NumberAnimation { duration: 180 } }
    }
    Behavior on opacity { NumberAnimation { duration: 180 } }

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
        PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: presetCard; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: presetCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
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
            presetCard.tab.applyWidgetPreset(presetCard.monName, presetCard.modelData);
        }
    }

    Rectangle {
        id: presetPreviewBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        property var screenDims: presetCard.tab.getScreenDimensions(presetCard.monName)
        property real sWidth: screenDims.w > 0 ? screenDims.w : 1920
        property real sHeight: screenDims.h > 0 ? screenDims.h : 1080
        property real sAspect: (sWidth > 0 && sHeight > 0) ? (sWidth / sHeight) : (16 / 9)

        height: Math.round(width / sAspect)
        color: Qt.darker(presetCard.accentColor, 1.15)
        clip: true

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
        }

        Item {
            id: previewMask
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

        Item {
            id: virtualScreenWrapper
            anchors.fill: parent
            clip: true

            Item {
                id: virtualScreen
                width: presetPreviewBox.sWidth
                height: presetPreviewBox.sHeight
                transformOrigin: Item.TopLeft
                scale: presetPreviewBox.width / presetPreviewBox.sWidth
                enabled: false

                Image {
                    id: presetWpImg
                    anchors.fill: parent
                    source: presetCard.tab.getWallpaperSource(presetCard.monName)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: true
                    asynchronous: false
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.25
                }

                Item {
                    id: presetWidgetsLayer
                    anchors.fill: parent

                    Repeater {
                        model: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets : []
                        delegate: WidgetPresetMiniWidget {
                            tab: presetCard.tab
                            monName: presetCard.monName
                            previewWidth: presetPreviewBox.sWidth
                            previewHeight: presetPreviewBox.sHeight
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.surface2, 0.3)
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: presetPreviewBox.bottom

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: rootObj.s(8)
            anchors.rightMargin: rootObj.s(8)
            spacing: rootObj.s(4)

            Text {
                property int widgetCount: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets.length : 0
                property string rawName: (presetCard.modelData && presetCard.modelData.name) ? presetCard.modelData.name : ((presetCard.modelData && presetCard.modelData.id) ? presetCard.modelData.id : "")
                text: (rawName ? I18n.t(rawName, rawName) : "") + " (" + widgetCount + ")"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                font.bold: true
                color: ThemeBackend.text
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            DeleteButton {
                visible: presetCard.modelData.isCustom === true || presetCard.modelData.category === "user"
                size: rootObj.s(22)
                cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                iconFontSize: rootObj.s(11)
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    presetCard.tab.deleteCustomPreset(presetCard.modelData.name || presetCard.modelData.id);
                }
            }
        }
    }
}
