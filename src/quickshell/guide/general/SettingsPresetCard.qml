import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"
import "../display"

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

    readonly property var settings: modelData.settings || {}
    readonly property var snapshot: modelData.snapshot || null
    readonly property var themeSettings: settings.theme || {}
    readonly property var presetPalette: modelData.palette || themeSettings.colors || {}

    function paletteColor(key, fallback) {
        return presetPalette[key] ? presetPalette[key] : fallback;
    }

    readonly property string wallpaperPath: {
        let walls = modelData.wallpapers || {};
        let p = walls[previewScreen] || walls[Object.keys(walls)[0]] || "";
        if (!p || /\.(mp4|mkv|mov|webm)$/i.test(p)) return "";
        return p.indexOf("://") !== -1 ? p : ("file://" + p);
    }

    readonly property var snapshotLayers: snapshot ? [snapshot.dock, snapshot.bar].filter(l => l && l.file) : []
    readonly property var widgetsLayer: (snapshot && snapshot.widgets) ? snapshot.widgets : (tab.capturedWidgets[modelData.id] || null)

    function layerSource(layer) {
        return layer ? ("file://" + tab.presetsDir + "/" + layer.file + "?v=" + (modelData.created || 0)) : "";
    }

    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property string previewScreen: snapshot ? snapshot.screen : (primaryScreen ? primaryScreen.name : "")
    readonly property real previewWidth: snapshot ? snapshot.width : (primaryScreen ? primaryScreen.width : 1920)
    readonly property real previewHeight: snapshot ? snapshot.height : (primaryScreen ? primaryScreen.height : 1080)
    readonly property var previewWidgets: {
        let widgets = modelData.widgets || {};
        let list = widgets[previewScreen.replace(/[^a-zA-Z0-9_-]/g, "_")] || widgets[previewScreen];
        let result = [];
        for (let i = 0; list && i < list.length; i++) result.push(list[i]);
        return result;
    }

    readonly property string createdText: {
        if (!modelData.created) return "";
        return new Date(modelData.created).toLocaleDateString(Qt.locale(I18n.qtLocaleName), Locale.ShortFormat);
    }

    width: presetCard.tileWidth
    height: previewBox.height + rootObj.s(40)
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
        id: previewBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(width * presetCard.previewHeight / presetCard.previewWidth)
        color: presetCard.paletteColor("mantle", Qt.darker(presetCard.accentColor, 1.15))

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

        BoundedImage {
            anchors.fill: parent
            source: presetCard.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Item {
            id: virtualScreen
            width: presetCard.previewWidth
            height: presetCard.previewHeight
            transformOrigin: Item.TopLeft
            scale: previewBox.width / width
            enabled: false

            Repeater {
                model: widgetsImage.status === Image.Ready ? [] : presetCard.previewWidgets
                delegate: WidgetPresetMiniWidget {
                    tab: presetCard.tab
                    monName: presetCard.previewScreen
                    previewWidth: presetCard.previewWidth
                    previewHeight: presetCard.previewHeight
                }
            }

            Image {
                id: widgetsImage
                x: presetCard.widgetsLayer ? presetCard.widgetsLayer.x : 0
                y: presetCard.widgetsLayer ? presetCard.widgetsLayer.y : 0
                width: presetCard.widgetsLayer ? presetCard.widgetsLayer.w : 0
                height: presetCard.widgetsLayer ? presetCard.widgetsLayer.h : 0
                source: presetCard.layerSource(presetCard.widgetsLayer)
                fillMode: Image.Stretch
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Repeater {
                model: presetCard.snapshotLayers
                delegate: Image {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    source: presetCard.layerSource(modelData)
                    fillMode: Image.Stretch
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: previewBox.bottom

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: rootObj.s(10)
            anchors.rightMargin: rootObj.s(8)
            spacing: rootObj.s(6)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: presetCard.modelData.name || presetCard.modelData.id || ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    font.bold: true
                    color: ThemeBackend.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: text !== ""
                    text: presetCard.createdText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(10)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: rootObj.s(-3)

                Repeater {
                    model: ["mauve", "blue", "green", "peach", "red"]
                    delegate: Rectangle {
                        required property string modelData
                        visible: presetCard.presetPalette[modelData] !== undefined
                        width: rootObj.s(12)
                        height: width
                        radius: width / 2
                        color: presetCard.paletteColor(modelData, "transparent")
                        border.width: rootObj.s(1.5)
                        border.color: presetCard.accentColor
                    }
                }
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
