import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import "../"
import "../reusables"

ColumnLayout {
    required property var screenRoot
    anchors.fill: parent
    anchors.margins: screenRoot.s(14)
    spacing: screenRoot.s(10)

    NotificationBox {
        id: notificationsMainBox
        Layout.fillWidth: true
        Layout.fillHeight: true
        hasShadow: true
        shadowColor: Qt.rgba(0, 0, 0, 0.14)
        baseColor: ThemeBackend.faded(Qt.lighter(ThemeBackend.surface0, 1.28))
        standaloneBlur: true
        blurScreen: screenRoot.surface.screen
        borderWidth: 1
        borderColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)
        cornerRadius: screenRoot.s(16)
        cardRadius: screenRoot.s(14)
        emptyGraphicSize: screenRoot.s(110)
        rootContext: screenRoot
    }

    Item {
        id: mediaBoxContainer
        Layout.fillWidth: true
        Layout.preferredHeight: screenRoot.s(96)

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: screenRoot.s(1.5)
            anchors.bottomMargin: -screenRoot.s(1.5)
            radius: screenRoot.s(16)
            color: Qt.rgba(0, 0, 0, 0.14)
        }

        Rectangle {
            id: mediaBoxBg
            anchors.fill: parent
            radius: screenRoot.s(16)
            color: ThemeBackend.faded(Qt.lighter(ThemeBackend.surface0, 1.28))
            border.width: ThemeBackend.liquidGlass ? 0 : 1
            border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                screenOverride: screenRoot.surface.screen
                useSnapshot: true
                standalone: true
            }

            Rectangle {
                id: mediaBgMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
                layer.enabled: true
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mediaBgMask
                }

                Visualizer {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(30, parent.height * 0.85)
                    active: screenRoot.isCavaSubscribed
                    count: Math.min(32, Math.max(4, Math.floor(width / (5 + spacing))))
                    spacing: Math.max(2, Math.floor(width * 0.008))
                    rise: 0.5
                    fall: 0.5
                    maxLength: height * 0.9
                    opacityBase: 0.22
                    opacityRange: 0.18
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: screenRoot.s(10)
                spacing: screenRoot.s(10)

                Rectangle {
                    id: lockArtRect
                    Layout.preferredWidth: screenRoot.s(60)
                    Layout.preferredHeight: screenRoot.s(60)
                    Layout.alignment: Qt.AlignVCenter
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface1
                    border.width: 1
                    border.color: (screenRoot.isMediaActive && MprisController.isPlaying) ? ThemeBackend.mauve : ThemeBackend.surface1
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: screenRoot.s(22)
                        color: ThemeBackend.subtext0
                        visible: !screenRoot.isMediaActive || !MprisController.artUrl
                    }

                    Image {
                        id: lockArtImg
                        anchors.fill: parent
                        source: (screenRoot.isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(screenRoot.s(60), screenRoot.s(60))
                        visible: false
                    }

                    Rectangle {
                        id: lockArtMask
                        anchors.fill: parent
                        radius: lockArtRect.radius
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: lockArtImg
                        maskEnabled: true
                        maskSource: lockArtMask
                        visible: screenRoot.isMediaActive && MprisController.artUrl !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    MarqueeText {
                        Layout.fillWidth: true
                        text: screenRoot.isMediaActive ? (MprisController.trackTitle || "Unknown Track") : I18n.t("music.nothing_playing")
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: screenRoot.s(13)
                        marqueeSpacing: screenRoot.s(30)
                        active: screenRoot.wingsReveal > 0.98 && screenRoot.isMediaActive && MprisController.isPlaying
                    }

                    Text {
                        text: screenRoot.isMediaActive ? (MprisController.trackArtist || "Unknown Artist") : ""
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: screenRoot.s(10)
                        color: ThemeBackend.subtext1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: screenRoot.isMediaActive && text !== ""
                    }

                    Text {
                        text: screenRoot.isMediaActive && screenRoot.player ? (screenRoot.formatMusicTime(MprisController.livePosition) + " / " + screenRoot.formatMusicTime(screenRoot.player.length)) : "--:-- / --:--"
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: screenRoot.s(10)
                        color: ThemeBackend.subtext0
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: screenRoot.isMediaActive
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: screenRoot.s(4)

                    IconButton {
                        Layout.preferredWidth: screenRoot.s(28)
                        Layout.preferredHeight: screenRoot.s(28)
                        cornerRadius: screenRoot.s(8)
                        buttonIcon: "󰒮"
                        iconFontSize: screenRoot.s(14)
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                        onClicked: if (screenRoot.player && screenRoot.player.canGoPrevious) screenRoot.player.previous()
                    }

                    IconButton {
                        Layout.preferredWidth: screenRoot.s(32)
                        Layout.preferredHeight: screenRoot.s(32)
                        cornerRadius: screenRoot.s(10)
                        buttonIcon: (screenRoot.isMediaActive && MprisController.isPlaying) ? "󰏤" : "󰐊"
                        iconFontSize: screenRoot.s(16)
                        accentColor: ThemeBackend.surface1
                        textColor: (screenRoot.isMediaActive && MprisController.isPlaying) ? ThemeBackend.green : ThemeBackend.text
                        onClicked: if (screenRoot.player && screenRoot.player.canTogglePlaying) screenRoot.player.togglePlaying()
                    }

                    IconButton {
                        Layout.preferredWidth: screenRoot.s(28)
                        Layout.preferredHeight: screenRoot.s(28)
                        cornerRadius: screenRoot.s(8)
                        buttonIcon: "󰒭"
                        iconFontSize: screenRoot.s(14)
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                        onClicked: if (screenRoot.player && screenRoot.player.canGoNext) screenRoot.player.next()
                    }
                }
            }
        }
    }
}
