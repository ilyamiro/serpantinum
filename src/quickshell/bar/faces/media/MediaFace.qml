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

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property real barOpacity: (activeTarget && activeTarget.barOpacity !== undefined) ? activeTarget.barOpacity : (barWindow && barWindow.barOpacity !== undefined ? barWindow.barOpacity : (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined ? (Config.rawSettings.bar.opacity / 100.0) : 1.0))

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    function readBool(widgetKey, configKey) {
        if (widget && widget !== root && widget[widgetKey] !== undefined) return Boolean(widget[widgetKey]);
        if (module && module[widgetKey] !== undefined) return Boolean(module[widgetKey]);
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs[configKey] !== undefined) return Boolean(bs[configKey]);
        }
        return true;
    }

    function readValue(widgetKey, configKey, fallback) {
        if (widget && widget !== root && widget[widgetKey] !== undefined) return widget[widgetKey];
        if (module && module[widgetKey] !== undefined) return module[widgetKey];
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs[configKey] !== undefined) return bs[configKey];
        }
        return fallback;
    }

    readonly property string infoMode: readValue("mediaInfoMode", "mediaInfoMode", "duration")
    readonly property real configuredWidth: Number(readValue("mediaWidth", "mediaWidth", 120))
    readonly property bool showIcon: readBool("mediaShowIcon", "mediaShowIcon")
    readonly property bool showControls: readBool("mediaShowControls", "mediaShowControls")

    property var player: MprisController.activePlayer
    readonly property bool hasArt: !isPreview && isMediaActive && !!MprisController.artUrl
    property bool isMediaActive: isPreview || (player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== "")
    readonly property bool isPlaying: isPreview || (isMediaActive && (player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : MprisController.isPlaying))

    property real colWidth: barWindow ? barWindow.s(configuredWidth - (isCompact ? 4 : 0)) : (configuredWidth - (isCompact ? 4 : 0))
    property real innerSpacing: barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8)
    property real btnSpacing: barWindow ? barWindow.s(isCompact ? 3 : 4) : (isCompact ? 3 : 4)
    property real sidePadding: barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8)

    property real targetWidth: {
        if (module && !module.moduleActive) return 0;
        let iconW = 0;
        if (showIcon) {
            let thumbW = barWindow ? barWindow.s(isCompact ? 26 : 28) : (isCompact ? 26 : 28);
            let gapInfo = barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10);
            iconW = thumbW + gapInfo;
        }
        let btnW = 0;
        if (showControls) {
            btnW = (barWindow ? barWindow.s(isCompact ? 28 : 30) : (isCompact ? 28 : 30)) * 3 + btnSpacing * 2 + innerSpacing;
        }
        let margins = sidePadding * 2;
        return iconW + colWidth + btnW + margins;
    }

    implicitWidth: targetWidth
    implicitHeight: barWindow ? barWindow.s(isCompact ? 40 : 44) : (isCompact ? 40 : 44)

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

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
                onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"])

                Row {
                    id: infoLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow ? barWindow.s(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                    transformOrigin: Item.Left

                    scale: mediaInfoMouse.containsMouse ? 1.01 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    Rectangle {
                        id: mediaThumbBox
                        visible: root.showIcon
                        width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        radius: 0
                        color: root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1
                        border.width: 1
                        border.color: root.isPlaying ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: "Monocraft"
                            font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14)
                            color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                            visible: !root.hasArt
                        }

                        Image {
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
                            font.family: "Monocraft"
                            font.weight: Font.Black
                            font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                            marqueeSpacing: barWindow ? barWindow.s(40) : 40
                            speed: 30
                            active: Boolean(root.visible && (!barWindow || barWindow.visible) && (!module || module.moduleActive) && root.isPlaying)
                        }

                        Text {
                            text: root.infoMode === "author"
                                ? (root.isPreview ? I18n.t("guide.bar.media.preview.author", "Song author") : (isMediaActive && player ? (player.trackArtist || "") : ""))
                                : (root.isPreview ? "01:24 / 03:42" : (isMediaActive && player ? (root.formatTime(MprisController.livePosition) + " / " + root.formatTime(player.length)) : ""))
                            font.family: "Monocraft"
                            font.weight: Font.Black
                            font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
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
                    mcStyle: true
                    id: prevMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: "󰒮"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    bgOpacity: root.barOpacity
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoPrevious) player.previous()
                }

                IconButton {
                    mcStyle: true
                    id: playMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: root.isPlaying ? "󰏤" : "󰐊"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    bgOpacity: root.barOpacity
                    textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                }

                IconButton {
                    mcStyle: true
                    id: nextMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: "󰒭"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    bgOpacity: root.barOpacity
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoNext) player.next()
                }
            }
        }
    }
}
