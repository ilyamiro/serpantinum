import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"

Rectangle {
    id: delegateContainer
    required property var tab
    required property var modelData
    required property int itemIndex
    readonly property var rootObj: tab.rootObj

    radius: ThemeBackend.borderRadius
    color: delegateContainer.baseC

    opacity: 0.0
    scale: (presetMouse.pressed ? 0.96 : (delegateContainer.isHovered ? 1.03 : 1.0)) * popScale

    property bool isSelected: delegateContainer.tab.currentPreset === modelData.name
    property real flashOpacity: 0.0
    property real popScale: 1.0

    property color baseC: delegateContainer.tab.getCardBase(modelData)
    property color textC: delegateContainer.tab.getCardText(modelData)

    HoverHandler {
        id: delegateHover
    }

    property bool isHovered: delegateHover.hovered

    Component.onCompleted: opacity = 1.0

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

    Loader {
        anchors.fill: parent
        active: modelData.isMatugen === true && delegateContainer.tab.currentWallpaperPath !== ""
        sourceComponent: Item {
            anchors.fill: parent

            Rectangle {
                id: matugenMask
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "black"
                visible: false
                layer.enabled: true
            }

            Item {
                id: matugenContent
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Image {
                    id: matugenWall
                    anchors.fill: parent
                    source: delegateContainer.tab.isWallpaperVideo ? ("file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + delegateContainer.tab.wallpaperRevision) : ("file://" + delegateContainer.tab.currentWallpaperPath + (delegateContainer.tab.wallpaperRevision > 0 ? ("?rev=" + delegateContainer.tab.wallpaperRevision) : ""))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    cache: true
                    sourceSize: Qt.size(Math.round(rootObj.s(360)), Math.round(rootObj.s(120)))
                    onStatusChanged: {
                        if (status === Image.Error) {
                            let snap = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + delegateContainer.tab.wallpaperRevision;
                            if (source.toString() !== snap) {
                                source = snap;
                            }
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: matugenWall
                    blurEnabled: true
                    blurMax: 4
                    blur: 0.4
                    colorizationColor: delegateContainer.baseC
                    colorization: 0.35
                    opacity: 0.85
                }

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.35; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(delegateContainer.baseC, 0.55) }
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: matugenContent
                maskEnabled: true
                maskSource: matugenMask
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: delegateContainer.textC
        opacity: delegateContainer.isSelected ? 0.15 : (delegateContainer.isHovered ? 0.08 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: "#ffffff"
        opacity: delegateContainer.flashOpacity
        PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: "transparent"
        border.color: delegateContainer.isSelected ? delegateContainer.textC : "transparent"
        border.width: delegateContainer.isSelected ? 2 : 0
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: presetMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            btnPopAnim.start();
            delegateContainer.flashOpacity = 0.15;
            btnFlashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx("reusables/clickbutton/click.wav");
            }
            delegateContainer.tab.applyPreset(delegateContainer.modelData);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: rootObj.s(10)
        anchors.rightMargin: rootObj.s(modelData.isCustom === true ? 6 : 10)
        spacing: rootObj.s(6)

        Text {
            text: modelData.name
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            font.weight: delegateContainer.isSelected ? Font.Bold : Font.Medium
            color: delegateContainer.textC
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: rootObj.s(4)

            Repeater {
                model: delegateContainer.tab.getCardDots(delegateContainer.modelData)
                Rectangle {
                    width: rootObj.s(8)
                    height: rootObj.s(8)
                    radius: rootObj.s(4)
                    color: modelData
                }
            }
        }

        Loader {
            active: modelData.isCustom === true
            visible: active
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: DeleteButton {
                size: rootObj.s(24)
                cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                iconFontSize: rootObj.s(12)
                onClicked: {
                    delegateContainer.tab.deleteCustomTheme(delegateContainer.modelData.name);
                }
            }
        }
    }
}
