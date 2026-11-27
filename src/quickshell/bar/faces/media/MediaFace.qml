import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    readonly property string infoMode: String(readSetting("mediaInfoMode", "", "duration"))
    readonly property real configuredWidth: Number(readSetting("mediaWidth", "", 120))
    readonly property bool showControls: Boolean(readSetting("mediaShowControls", "", true))
    readonly property bool hideWhenIdle: Boolean(readSetting("mediaHideWhenIdle", "", false))
    readonly property bool idleHidden: hideWhenIdle && !isPreview && !isMediaActive
    readonly property bool isFaceVisible: !idleHidden
    readonly property bool showIcon: isVertical ? (Boolean(readSetting("mediaShowIcon", "", true)) || !showControls) : Boolean(readSetting("mediaShowIcon", "", true))
    readonly property string mediaStyle: String(readSetting("mediaStyle", "", "classic"))
    readonly property bool isAmbient: mediaStyle === "ambient"
    readonly property bool showArtBackground: isAmbient

    property var player: MprisController.activePlayer
    readonly property bool hasArt: !isPreview && isMediaActive && !!MprisController.artUrl

    readonly property var targetPlayer: MprisController.targetPlayer
    property bool hasTargetPlayer: targetPlayer !== null
    property bool isMediaActive: isVertical
        ? (targetPlayer !== null && targetPlayer.playbackState !== MprisPlaybackState.Stopped && targetPlayer.trackTitle !== "")
        : (isPreview || (player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""))
    readonly property bool isPlaying: isVertical
        ? (targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false)
        : (isPreview || (isMediaActive && (player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : MprisController.isPlaying)))

    property string rawArtUrl: {
        if (!targetPlayer) return "";
        if (targetPlayer === MprisController.activePlayer) {
            return MprisController.artUrl;
        }
        return targetPlayer.trackArtUrl || "";
    }

    property string activeArtUrl: {
        if (isPreview || !rawArtUrl) return "";
        if (rawArtUrl.startsWith("file://") || rawArtUrl.startsWith("http")) return rawArtUrl;
        return "file://" + rawArtUrl;
    }

    readonly property string ambientArtUrl: {
        if (isVertical) return isMediaActive ? activeArtUrl : "";
        if (!hasArt) return "";
        let url = MprisController.artUrl;
        return (url.startsWith("file://") || url.startsWith("http")) ? url : "file://" + url;
    }

    property real colWidth: s(configuredWidth - (isCompact ? 4 : 0))
    property real innerSpacing: s(isCompact ? 6 : 8)
    property real btnSpacing: s(isCompact ? 3 : 4)
    property real sidePadding: s(isCompact ? 6 : 8)

    property real baseHeight: {
        let h = s(isCompact ? 8 : 9);
        if (showIcon) h += s(isCompact ? 26 : 28);
        if (showIcon && showControls) h += s(isCompact ? 4 : 5);
        if (showControls) h += s(isCompact ? 74 : 80) + s(isCompact ? 6 : 8);
        return h;
    }

    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (idleHidden) return 0;
        if (isVertical) return baseHeight;
        let iconW = 0;
        if (showIcon) {
            let thumbW = s(isCompact ? 26 : 28);
            let gapInfo = s(isCompact ? 8 : 10);
            iconW = thumbW + gapInfo;
        }
        let btnW = 0;
        if (showControls) {
            btnW = s(isCompact ? 28 : 30) * 3 + btnSpacing * 2 + innerSpacing;
        }
        let margins = sidePadding * 2;
        return iconW + colWidth + btnW + margins;
    }

    implicitWidth: isVertical ? (isPreview ? s(56) : (activeTarget ? activeTarget.width : 0)) : targetLength
    implicitHeight: isVertical ? targetLength : s(isCompact ? 40 : 44)

    Item {
        id: ambientBackground
        anchors.fill: parent
        readonly property bool artReady: root.ambientArtUrl !== "" && ambientArt.status === Image.Ready
        readonly property bool shown: root.showArtBackground && (root.isPreview || artReady)
        opacity: shown ? 1.0 : 0.0
        visible: opacity > 0 && width > 0 && height > 0

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        layer.enabled: visible
        layer.effect: ShaderEffect {
            property vector2d itemSize: Qt.vector2d(width, height)
            property vector2d feather: root.isVertical
                ? Qt.vector2d(0, Math.min(height * 0.5, width))
                : Qt.vector2d(Math.min(width * 0.5, height), 0)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/soft_edge_mask.frag.qsb"
        }

        Item {
            id: ambientSource
            anchors.fill: parent
            anchors.margins: -root.s(16)

            layer.enabled: ambientBackground.visible
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 16
            }

            Rectangle {
                anchors.fill: parent
                visible: root.isPreview
                gradient: Gradient {
                    orientation: root.isVertical ? Gradient.Vertical : Gradient.Horizontal
                    GradientStop { position: 0.0; color: ThemeBackend.mauve }
                    GradientStop { position: 1.0; color: ThemeBackend.blue }
                }
            }

            BoundedImage {
                id: ambientArt
                anchors.centerIn: parent
                width: root.isVertical ? parent.width : parent.width * 0.8
                height: root.isVertical ? parent.height * 0.8 : parent.height
                source: root.ambientArtUrl
                fillMode: Image.PreserveAspectCrop
            }

            ShaderEffectSource {
                anchors.left: parent.left
                anchors.top: parent.top
                width: root.isVertical ? parent.width : ambientArt.x + 1
                height: root.isVertical ? ambientArt.y + 1 : parent.height
                sourceItem: ambientArt
                sourceRect: root.isVertical ? Qt.rect(0, 0, ambientArt.width, 1) : Qt.rect(0, 0, 1, ambientArt.height)
            }

            ShaderEffectSource {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: root.isVertical ? parent.width : ambientArt.x + 1
                height: root.isVertical ? ambientArt.y + 1 : parent.height
                sourceItem: ambientArt
                sourceRect: root.isVertical ? Qt.rect(0, ambientArt.height - 1, ambientArt.width, 1) : Qt.rect(ambientArt.width - 1, 0, 1, ambientArt.height)
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ThemeBackend.base
            opacity: 0.52
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.isVertical ? verticalBody : horizontalBody
    }

    Component {
        id: horizontalBody

        Item {
            Item {
                id: mediaLayoutContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.sidePadding
                anchors.right: parent.right
                anchors.rightMargin: root.sidePadding
                height: parent.height
                clip: true

                Row {
                    id: innerMediaLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.innerSpacing

                    MouseArea {
                        id: mediaInfoMouse
                        width: infoLayout.implicitWidth
                        height: mediaLayoutContainer.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePanel("music")

                        Row {
                            id: infoLayout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.s(root.isCompact ? 8 : 10)
                            transformOrigin: Item.Left

                            scale: mediaInfoMouse.containsMouse ? 1.01 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                            Rectangle {
                                id: mediaThumbBox
                                visible: root.showIcon
                                width: root.s(root.isCompact ? 26 : 28)
                                height: root.s(root.isCompact ? 26 : 28)
                                radius: root.s(root.isCompact ? 9 : 10)
                                color: mediaThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)
                                clip: !mediaThumbGlass.active
                                anchors.verticalCenter: parent.verticalCenter

                                GlassFill {
                                    id: mediaThumbGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: ThemeBackend.surface1
                                    tintAmount: 0.3
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎈"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(root.isCompact ? 13 : 14)
                                    color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                                    visible: !root.hasArt
                                }

                                BoundedImage {
                                    id: mediaArtImg
                                    anchors.fill: parent
                                    source: root.hasArt ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: mediaArtImg
                                    source: mediaArtImg
                                    maskEnabled: true
                                    maskSource: mediaArtMask
                                    visible: root.hasArt && mediaArtImg.status === Image.Ready
                                }

                                Item {
                                    id: mediaArtMask
                                    anchors.fill: parent
                                    layer.enabled: true
                                    visible: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: mediaThumbBox.radius
                                        color: "black"
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: ThemeBackend.surface0
                                    opacity: 0.15
                                    visible: root.hasArt && mediaArtImg.status === Image.Ready
                                }
                            }

                            Column {
                                spacing: -2
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.colWidth

                                MarqueeText {
                                    width: parent.width
                                    text: root.isPreview ? I18n.t("guide.bar.media.preview.title", "Song title") : (isMediaActive ? (player ? player.trackTitle : "") : I18n.t("music.nothing_playing"))
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: root.s(root.isCompact ? 11 : 12)
                                    marqueeSpacing: root.s(40)
                                    speed: 30
                                    active: Boolean(root.visible && (!barWindow || barWindow.visible) && (!module || module.moduleActive) && root.isPlaying)
                                }

                                Text {
                                    text: root.infoMode === "author"
                                        ? (root.isPreview ? I18n.t("guide.bar.media.preview.author", "Song author") : (isMediaActive && player ? (player.trackArtist || "") : ""))
                                        : (root.isPreview ? "01:24 / 03:42" : (isMediaActive && player ? (MprisController.formatTime(MprisController.livePosition) + " / " + MprisController.formatTime(player.length)) : ""))
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: root.s(root.isCompact ? 9 : 10)
                                    color: root.isCompact ? ThemeBackend.overlay2 : ThemeBackend.subtext0
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: isMediaActive
                                }
                            }
                        }
                    }

                    Row {
                        id: buttonRow
                        visible: root.showControls
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.btnSpacing

                        IconButton {
                            id: prevMediaButton
                            height: root.s(root.isCompact ? 28 : 30)
                            width: root.s(root.isCompact ? 28 : 30)
                            cornerRadius: root.s(root.isCompact ? 9 : 10)
                            buttonIcon: "󰒮"
                            iconFontSize: root.s(root.isCompact ? 7 : 8)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canGoPrevious) player.previous()
                        }

                        IconButton {
                            id: playMediaButton
                            height: root.s(root.isCompact ? 28 : 30)
                            width: root.s(root.isCompact ? 28 : 30)
                            cornerRadius: root.s(root.isCompact ? 9 : 10)
                            buttonIcon: root.isPlaying ? "󰏤" : "󰐊"
                            iconFontSize: root.s(root.isCompact ? 9 : 10)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                            textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                        }

                        IconButton {
                            id: nextMediaButton
                            height: root.s(root.isCompact ? 28 : 30)
                            width: root.s(root.isCompact ? 28 : 30)
                            cornerRadius: root.s(root.isCompact ? 9 : 10)
                            buttonIcon: "󰒭"
                            iconFontSize: root.s(root.isCompact ? 7 : 8)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canGoNext) player.next()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: verticalBody

        Item {
            MouseArea {
                id: widgetMouse
                anchors.fill: parent
                enabled: !root.isPreview
                hoverEnabled: !root.isPreview
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    let pt = root.anchorPointFor(module ? module : root);
                    SideMusicController.itemEntered(barWindow ? barWindow.screen : null, pt.x, pt.y, root.isRightBar, false, true);
                }
                onExited: {
                    SideMusicController.itemExited();
                }
                onClicked: {
                    let pt = root.anchorPointFor(module ? module : root);
                    SideMusicController.toggle(barWindow ? barWindow.screen : null, pt.x, pt.y, root.isRightBar, false, true);
                }
            }

            Column {
                id: baseCol
                anchors.centerIn: parent
                spacing: root.s(root.isCompact ? 4 : 5)

                Rectangle {
                    id: thumbBox
                    visible: root.showIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.s(root.isCompact ? 26 : 28)
                    height: root.s(root.isCompact ? 26 : 28)
                    radius: root.s(root.isCompact ? 7 : 8)
                    color: sideThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)
                    clip: !sideThumbGlass.active

                    GlassFill {
                        id: sideThumbGlass
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.3
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(root.isCompact ? 12 : 13)
                        color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                        visible: !isMediaActive || root.activeArtUrl === ""
                    }

                    BoundedImage {
                        id: sideArtImg
                        anchors.fill: parent
                        source: isMediaActive ? root.activeArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: sideArtImg
                        source: sideArtImg
                        maskEnabled: true
                        maskSource: sideArtMask
                        visible: isMediaActive && root.activeArtUrl !== "" && sideArtImg.status === Image.Ready
                    }

                    Item {
                        id: sideArtMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: thumbBox.radius
                            color: "black"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: ThemeBackend.surface0
                        opacity: 0.15
                        visible: isMediaActive && root.activeArtUrl !== "" && sideArtImg.status === Image.Ready
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePanel("music")
                    }
                }

                Column {
                    visible: root.showControls
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.s(root.isCompact ? 3 : 4)

                    IconButton {
                        width: root.s(root.isCompact ? 24 : 26)
                        height: root.s(root.isCompact ? 24 : 26)
                        cornerRadius: root.s(root.isCompact ? 7 : 8)
                        buttonIcon: "󰒮"
                        iconFontSize: root.s(root.isCompact ? 6 : 7)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
                    }

                    IconButton {
                        width: root.s(root.isCompact ? 26 : 28)
                        height: root.s(root.isCompact ? 26 : 28)
                        cornerRadius: root.s(root.isCompact ? 7 : 8)
                        buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                        iconFontSize: root.s(root.isCompact ? 8 : 9)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                        textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canTogglePlaying) targetPlayer.togglePlaying()
                    }

                    IconButton {
                        width: root.s(root.isCompact ? 24 : 26)
                        height: root.s(root.isCompact ? 24 : 26)
                        cornerRadius: root.s(root.isCompact ? 7 : 8)
                        buttonIcon: "󰒭"
                        iconFontSize: root.s(root.isCompact ? 6 : 7)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canGoNext) targetPlayer.next()
                    }
                }
            }
        }
    }
}
