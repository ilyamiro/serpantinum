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

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property bool isRightBar: module ? module.isRightBar : (barWindow ? (barWindow.barPosition === "right") : false)
    readonly property real barOpacity: ThemeBackend.elementOpacity

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
    readonly property bool showControls: readBool("mediaShowControls", "mediaShowControls")
    readonly property bool showIcon: isVertical ? (readBool("mediaShowIcon", "mediaShowIcon") || !showControls) : readBool("mediaShowIcon", "mediaShowIcon")

    property var player: MprisController.activePlayer
    readonly property bool hasArt: !isPreview && isMediaActive && !!MprisController.artUrl

    property var playerList: {
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    property var targetPlayer: {
        if (manualPlayer) {
            for (let i = 0; i < playerList.length; i++) {
                if (playerList[i] === manualPlayer) return manualPlayer;
            }
        }
        return MprisController.activePlayer;
    }

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

    function sc(v) { return barWindow ? barWindow.cs(v) : v; }

    property real colWidth: barWindow ? barWindow.cs(configuredWidth - (isCompact ? 4 : 0)) : (configuredWidth - (isCompact ? 4 : 0))
    property real innerSpacing: barWindow ? barWindow.cs(isCompact ? 6 : 8) : (isCompact ? 6 : 8)
    property real btnSpacing: barWindow ? barWindow.cs(isCompact ? 3 : 4) : (isCompact ? 3 : 4)
    property real sidePadding: barWindow ? barWindow.cs(isCompact ? 6 : 8) : (isCompact ? 6 : 8)

    property real baseHeight: {
        let h = sc(isCompact ? 8 : 9);
        if (showIcon) h += sc(isCompact ? 26 : 28);
        if (showIcon && showControls) h += sc(isCompact ? 4 : 5);
        if (showControls) h += sc(isCompact ? 74 : 80) + sc(isCompact ? 6 : 8);
        return h;
    }

    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (isVertical) return baseHeight;
        let iconW = 0;
        if (showIcon) {
            let thumbW = barWindow ? barWindow.cs(isCompact ? 26 : 28) : (isCompact ? 26 : 28);
            let gapInfo = barWindow ? barWindow.cs(isCompact ? 8 : 10) : (isCompact ? 8 : 10);
            iconW = thumbW + gapInfo;
        }
        let btnW = 0;
        if (showControls) {
            btnW = (barWindow ? barWindow.cs(isCompact ? 28 : 30) : (isCompact ? 28 : 30)) * 3 + btnSpacing * 2 + innerSpacing;
        }
        let margins = sidePadding * 2;
        return iconW + colWidth + btnW + margins;
    }

    implicitWidth: isVertical ? (isPreview ? (barWindow ? barWindow.cs(56) : 56) : (activeTarget ? activeTarget.width : 0)) : targetLength
    implicitHeight: isVertical ? targetLength : (barWindow ? barWindow.cs(isCompact ? 40 : 44) : (isCompact ? 40 : 44))

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
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
                        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"])

                        Row {
                            id: infoLayout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow ? barWindow.cs(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                            transformOrigin: Item.Left

                            scale: mediaInfoMouse.containsMouse ? 1.01 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                            Rectangle {
                                id: mediaThumbBox
                                visible: root.showIcon
                                width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                                height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                                radius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                                color: mediaThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)
                                border.width: mediaThumbGlass.active && !root.isPlaying ? 0 : 1
                                border.color: root.isPlaying ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
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
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14)
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
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                                    marqueeSpacing: barWindow ? barWindow.cs(40) : 40
                                    speed: 30
                                    active: Boolean(root.visible && (!barWindow || barWindow.visible) && (!module || module.moduleActive) && root.isPlaying)
                                }

                                Text {
                                    text: root.infoMode === "author"
                                        ? (root.isPreview ? I18n.t("guide.bar.media.preview.author", "Song author") : (isMediaActive && player ? (player.trackArtist || "") : ""))
                                        : (root.isPreview ? "01:24 / 03:42" : (isMediaActive && player ? (root.formatTime(MprisController.livePosition) + " / " + root.formatTime(player.length)) : ""))
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
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
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: "󰒮"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canGoPrevious) player.previous()
                        }

                        IconButton {
                            id: playMediaButton
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: root.isPlaying ? "󰏤" : "󰐊"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                            textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                        }

                        IconButton {
                            id: nextMediaButton
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: "󰒭"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    let targetItem = module ? module : root;
                    let pt = targetItem.mapToItem(null, 0, 0);
                    let globX = root.isRightBar ? pt.x : (pt.x + targetItem.width);
                    let globY = pt.y + (targetItem.height / 2);
                    SideMusicController.itemEntered(barWindow ? barWindow.screen : null, globX, globY, root.isRightBar, false, true);
                }
                onExited: {
                    SideMusicController.itemExited();
                }
                onClicked: {
                    let targetItem = module ? module : root;
                    let pt = targetItem.mapToItem(null, 0, 0);
                    let globX = root.isRightBar ? pt.x : (pt.x + targetItem.width);
                    let globY = pt.y + (targetItem.height / 2);
                    SideMusicController.toggle(barWindow ? barWindow.screen : null, globX, globY, root.isRightBar, false, true);
                }
            }

            Column {
                id: baseCol
                anchors.centerIn: parent
                spacing: barWindow ? barWindow.cs(root.isCompact ? 4 : 5) : (root.isCompact ? 4 : 5)

                Rectangle {
                    id: thumbBox
                    visible: root.showIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                    height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                    radius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    color: sideThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)
                    border.width: sideThumbGlass.active && !(isMediaActive && isPlaying) ? 0 : 1
                    border.color: (isMediaActive && isPlaying) ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
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
                        font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 12 : 13) : (root.isCompact ? 12 : 13)
                        color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                        visible: !isMediaActive || root.activeArtUrl === ""
                    }

                    Image {
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
                        onClicked: {
                            if (Caching.serpantinumDir) {
                                Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"]);
                            }
                        }
                    }
                }

                Column {
                    visible: root.showControls
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: barWindow ? barWindow.cs(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        height: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: "󰒮"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
                    }

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 8 : 9) : (root.isCompact ? 8 : 9)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity
                        textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canTogglePlaying) targetPlayer.togglePlaying()
                    }

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        height: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: "󰒭"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
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
