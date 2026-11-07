import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"

Rectangle {
    id: tile
    required property var tab
    required property string transitionId
    property bool selected: false
    property bool interactive: true

    signal picked()

    readonly property var rootObj: tab.rootObj
    readonly property var fx: tab.effect(transitionId)
    readonly property int typeIndex: Wallpaper.transitionIds.indexOf(transitionId)
    readonly property bool hovered: hover.hovered
    property real popScale: 1.0
    property real flashOpacity: 0.0

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: innerCol.implicitHeight + rootObj.s(16)
    radius: ThemeBackend.borderRadius
    clip: true

    color: ThemeBackend.liquidGlass ? "transparent" : (mouse.pressed && tile.interactive
        ? Qt.darker(ThemeBackend.surface0, 1.15)
        : (selected
            ? (hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
            : (hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0)))
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: ((mouse.pressed && tile.interactive) ? 0.985 : (hovered ? 1.015 : 1.0)) * tile.popScale
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

    GlassFill {
        id: glass
        anchors.fill: parent
        radius: parent.radius
        tintColor: ThemeBackend.surface0
        tintAmount: tile.selected ? 0.45 : 0.25
        press: (mouse.pressed && tile.interactive) ? 0.8 : (tile.hovered ? 0.25 : 0)
        pulse: Math.min(1, tile.flashOpacity * 2.5)
        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#ffffff"
        opacity: tile.flashOpacity
        visible: !glass.active
        PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: tile; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: tile; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
    }

    property real progress: 0.55
    property bool flipped: false
    property bool vertical: false
    property int direction: 0
    property real originX: 0.5
    property real originY: 0.5

    readonly property string orientationSetting: fx.orientation || ""
    readonly property string directionSetting: fx.direction || ""
    readonly property string originSetting: fx.origin || ""

    function applyOrientation() {
        tile.vertical = tile.orientationSetting === "vertical" || (tile.orientationSetting !== "horizontal" && Math.random() < 0.5);
    }

    function applyDirection() {
        let dirIdx = Wallpaper.swipeDirections.indexOf(tile.directionSetting);
        tile.direction = dirIdx >= 0 ? dirIdx : Math.floor(Math.random() * Wallpaper.swipeDirections.length);
    }

    function applyOrigin() {
        let centered = tile.originSetting === "center";
        tile.originX = centered ? 0.5 : 0.2 + Math.random() * 0.6;
        tile.originY = centered ? 0.5 : 0.2 + Math.random() * 0.6;
    }

    function randomize() {
        applyOrientation();
        applyDirection();
        applyOrigin();
    }

    Component.onCompleted: randomize()
    onOrientationSettingChanged: applyOrientation()
    onDirectionSettingChanged: applyDirection()
    onOriginSettingChanged: applyOrigin()

    onHoveredChanged: {
        if (hovered) {
            restAnim.stop();
            loopAnim.restart();
        } else {
            loopAnim.stop();
            restAnim.restart();
        }
    }

    SequentialAnimation {
        id: loopAnim
        loops: Animation.Infinite
        ScriptAction { script: tile.randomize() }
        NumberAnimation {
            target: tile
            property: "progress"
            from: 0.0
            to: 1.0
            duration: Math.max(100, Number(tile.fx.duration) || 1000)
            easing.type: Easing.InOutCubic
        }
        PauseAnimation { duration: 450 }
        ScriptAction { script: { tile.flipped = !tile.flipped; tile.progress = 0.0; } }
    }

    NumberAnimation {
        id: restAnim
        target: tile
        property: "progress"
        to: 0.55
        duration: 250
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        id: innerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: tile.rootObj.s(8)
        spacing: tile.rootObj.s(8)
        opacity: (tile.interactive && !tile.selected) ? (tile.hovered ? 0.7 : 0.4) : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Item {
            id: previewBox
            Layout.fillWidth: true
            Layout.preferredHeight: tile.rootObj.s(96)

            Rectangle {
                id: tileMask
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "black"
                visible: false
                layer.enabled: true
            }

            Item {
                id: tileContent
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: tileMask
                }

                Item {
                    id: wallpaperLayer
                    anchors.fill: parent
                    readonly property bool isIncoming: !tile.flipped
                    z: isIncoming ? 2 : 1
                    opacity: (tile.typeIndex === 0 && isIncoming) ? tile.progress : 1.0
                    layer.enabled: tile.typeIndex !== 0 && isIncoming
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: shaderMask
                        maskThresholdMin: 0.0
                        maskSpreadAtMin: 0.0
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ThemeBackend.mauve }
                            GradientStop { position: 1.0; color: ThemeBackend.blue }
                        }
                    }

                    BoundedImage {
                        anchors.fill: parent
                        source: tile.tab.isWallpaperVideo ? ("file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + tile.tab.wallpaperRevision) : (tile.tab.currentWallpaperPath ? "file://" + tile.tab.currentWallpaperPath : "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: source !== ""
                    }
                }

                Item {
                    id: plainLayer
                    anchors.fill: parent
                    readonly property bool isIncoming: tile.flipped
                    z: isIncoming ? 2 : 1
                    opacity: (tile.typeIndex === 0 && isIncoming) ? tile.progress : 1.0
                    layer.enabled: tile.typeIndex !== 0 && isIncoming
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: shaderMask
                        maskThresholdMin: 0.0
                        maskSpreadAtMin: 0.0
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ThemeBackend.surface1 }
                            GradientStop { position: 1.0; color: ThemeBackend.crust }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰸉"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: tile.rootObj.s(26)
                        color: Qt.alpha(ThemeBackend.text, 0.25)
                    }
                }

                ShaderEffect {
                    id: shaderMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: tile.typeIndex !== 0

                    property vector2d itemSize: Qt.vector2d(width, height)
                    property real progress: tile.progress
                    property real transitionType: tile.typeIndex
                    property vector2d origin: Qt.vector2d(tile.originX, tile.originY)
                    property vector4d params: Qt.vector4d(tile.vertical ? 1.0 : 0.0, tile.direction, 0.0, 0.0)

                    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/transitions/wallpaper_transition.frag.qsb"
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: tile.rootObj.s(2)
            Layout.rightMargin: tile.rootObj.s(2)
            Layout.bottomMargin: tile.rootObj.s(2)
            text: tile.tab.transitionName(tile.transitionId)
            font.family: ThemeBackend.fontFamily
            font.pixelSize: tile.rootObj.s(13)
            font.weight: Font.Bold
            color: ThemeBackend.text
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!tile.interactive) return;
            popAnim.start();
            tile.flashOpacity = 0.15;
            flashAnim.start();
            Sounds.playSfx("reusables/clickbutton/click.wav");
            tile.picked();
        }
    }
}
