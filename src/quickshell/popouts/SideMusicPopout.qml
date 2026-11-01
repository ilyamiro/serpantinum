import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../reusables"
import "../"

PanelWindow {
    id: sideMusicPopout

    screen: SideMusicController.screen

    WlrLayershell.namespace: "sidemusic"
    WlrLayershell.layer: WlrLayer.Top
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        item: (sideMusicPopout.isVisible || menuContainer.animProgress > 0.001) ? menuContainer : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: SideMusicController.isVisible
    property real targetX: SideMusicController.targetX
    property real targetY: SideMusicController.targetY
    property bool alignRight: SideMusicController.alignRight
    property bool alignBottom: SideMusicController.alignBottom
    property bool isSideBar: SideMusicController.isSideBar

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            SideMusicController.hide();
            sideMusicPopout.configRevision++;
        }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    onBarStyleChanged: {
        SideMusicController.hide();
    }

    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }
    property real cornerRadius: ThemeBackend.borderRadius || s(12)
    property real menuMargin: isSolid ? 0 : s(8)

    visible: isVisible || menuContainer.animProgress > 0.001

    property real menuWidth: s(220)
    property real menuHeight: s(140)

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

    property var playerOptions: {
        let list = playerList;
        let names = [];
        let counts = {};
        for (let i = 0; i < list.length; i++) {
            let base = list[i].identity || list[i].desktopEntry || ("Player " + (i + 1));
            counts[base] = (counts[base] || 0) + 1;
        }
        for (let i = 0; i < list.length; i++) {
            let p = list[i];
            let base = p.identity || p.desktopEntry || ("Player " + (i + 1));
            if (counts[base] > 1 && p.trackTitle) {
                names.push(base + " (" + p.trackTitle + ")");
            } else {
                names.push(base);
            }
        }
        return names;
    }

    property int currentPlayerIndex: {
        if (!targetPlayer) return 0;
        for (let i = 0; i < playerList.length; i++) {
            if (playerList[i] === targetPlayer) return i;
        }
        return 0;
    }

    function selectPlayerByIndex(idx) {
        if (idx >= 0 && idx < playerList.length) {
            manualPlayer = playerList[idx];
        }
    }

    property bool isMediaActive: targetPlayer !== null && targetPlayer.playbackState !== MprisPlaybackState.Stopped && targetPlayer.trackTitle !== ""
    property bool isPlaying: targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false
    
    property real currentLivePosition: {
        if (!targetPlayer) return 0.0;
        let pos = (targetPlayer === MprisController.activePlayer) ? MprisController.livePosition : targetPlayer.position;
        return (typeof pos === "number" && !isNaN(pos)) ? pos : 0.0;
    }

    Connections {
        target: sideMusicPopout.targetPlayer
        function onPositionChanged() {
            if (sideMusicPopout.targetPlayer && sideMusicPopout.targetPlayer !== MprisController.activePlayer) {
                let pos = sideMusicPopout.targetPlayer.position;
                sideMusicPopout.currentLivePosition = (typeof pos === "number" && !isNaN(pos)) ? pos : 0.0;
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: sideMusicPopout.visible && sideMusicPopout.targetPlayer !== null && sideMusicPopout.isPlaying && sideMusicPopout.targetPlayer !== MprisController.activePlayer
        onTriggered: {
            if (sideMusicPopout.targetPlayer) {
                if (typeof sideMusicPopout.targetPlayer.positionChanged === "function") {
                    sideMusicPopout.targetPlayer.positionChanged();
                }
                let pos = sideMusicPopout.targetPlayer.position;
                sideMusicPopout.currentLivePosition = (typeof pos === "number" && !isNaN(pos)) ? pos : 0.0;
            }
        }
    }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    property real clampedX: {
        let w = menuWidth;
        let x = 0;
        if (isSideBar) {
            if (alignRight) {
                let barEdge = (targetX > sideMusicPopout.width / 2) ? targetX : (sideMusicPopout.width - barHeight);
                x = isSolid ? (sideMusicPopout.width - barHeight - w) : (barEdge - w - menuMargin);
            } else {
                let barEdge = (targetX > 0 && targetX < sideMusicPopout.width / 2) ? targetX : barHeight;
                x = isSolid ? barHeight : (barEdge + menuMargin);
            }
        } else {
            x = targetX - (w / 2);
        }
        let edgeBound = (isSolid && !isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(sideMusicPopout.width - w - edgeBound, x));
    }

    property real clampedY: {
        let h = menuHeight;
        let y = 0;
        if (isSideBar) {
            y = targetY - (h / 2) + s(4);
        } else {
            if (alignBottom) {
                let barEdge = (targetY > sideMusicPopout.height / 2) ? targetY : (sideMusicPopout.height - barHeight);
                y = isSolid ? (sideMusicPopout.height - barHeight - h) : (barEdge - h - menuMargin);
            } else {
                let barEdge = (targetY > 0 && targetY < sideMusicPopout.height / 2) ? targetY : barHeight;
                y = isSolid ? barHeight : (barEdge + menuMargin);
            }
        }
        let edgeBound = (isSolid && isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(sideMusicPopout.height - h - edgeBound, y));
    }

    Item {
        id: menuContainer

        property real dynamicCornerRadius: sideMusicPopout.isSolid ? Math.max(0, Math.min(sideMusicPopout.cornerRadius, (sideMusicPopout.isSideBar ? width : height))) : 0

        property real animProgress: sideMusicPopout.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: sideMusicPopout.isVisible ? 280 : 220
                easing.type: Easing.OutCubic
            }
        }

        x: {
            if (sideMusicPopout.isSolid) {
                if (sideMusicPopout.isSideBar) {
                    if (sideMusicPopout.alignRight) {
                        return sideMusicPopout.clampedX + (sideMusicPopout.menuWidth - width);
                    }
                    return sideMusicPopout.clampedX;
                }
                return sideMusicPopout.clampedX;
            }
            let slideOffset = sideMusicPopout.s(16) * (1.0 - animProgress);
            if (sideMusicPopout.isSideBar) {
                return sideMusicPopout.alignRight ? (sideMusicPopout.clampedX + slideOffset) : (sideMusicPopout.clampedX - slideOffset);
            }
            return sideMusicPopout.clampedX;
        }

        y: {
            if (sideMusicPopout.isSolid) {
                if (!sideMusicPopout.isSideBar) {
                    if (sideMusicPopout.alignBottom) {
                        return sideMusicPopout.clampedY + (sideMusicPopout.menuHeight - height);
                    }
                    return sideMusicPopout.clampedY;
                }
                return sideMusicPopout.clampedY;
            }
            let slideOffset = sideMusicPopout.s(16) * (1.0 - animProgress);
            if (!sideMusicPopout.isSideBar) {
                return sideMusicPopout.alignBottom ? (sideMusicPopout.clampedY + slideOffset) : (sideMusicPopout.clampedY - slideOffset);
            }
            return sideMusicPopout.clampedY;
        }

        width: {
            if (sideMusicPopout.isSolid && sideMusicPopout.isSideBar) {
                return sideMusicPopout.menuWidth * animProgress;
            }
            return sideMusicPopout.menuWidth;
        }

        height: {
            if (sideMusicPopout.isSolid && !sideMusicPopout.isSideBar) {
                return sideMusicPopout.menuHeight * animProgress;
            }
            return sideMusicPopout.menuHeight;
        }

        opacity: animProgress
        scale: !sideMusicPopout.isSolid ? (0.92 + (0.08 * animProgress)) : 1.0

        transformOrigin: {
            if (sideMusicPopout.isSideBar) {
                return sideMusicPopout.alignRight ? Item.Right : Item.Left;
            }
            return sideMusicPopout.alignBottom ? Item.Bottom : Item.Top;
        }

        GlassFillets {
            id: menuFillets
            card: menuBox
            filletRadius: (sideMusicPopout.isSolid && menuContainer.dynamicCornerRadius > 0.5) ? menuContainer.dynamicCornerRadius : 0
            filletDir: sideMusicPopout.isSideBar
                ? (sideMusicPopout.alignRight ? Qt.vector2d(1, 0) : Qt.vector2d(-1, 0))
                : (sideMusicPopout.alignBottom ? Qt.vector2d(0, 1) : Qt.vector2d(0, -1))
        }

        ShaderEffect {
            visible: sideMusicPopout.isSolid && menuContainer.dynamicCornerRadius > 0.5
            x: {
                if (sideMusicPopout.isSideBar) {
                    return sideMusicPopout.alignRight ? (parent.width - menuContainer.dynamicCornerRadius) : 0;
                }
                return -menuContainer.dynamicCornerRadius;
            }
            y: {
                if (sideMusicPopout.isSideBar) {
                    return -menuContainer.dynamicCornerRadius;
                }
                return sideMusicPopout.alignBottom ? (parent.height - menuContainer.dynamicCornerRadius) : 0;
            }
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (sideMusicPopout.isSideBar) {
                    return sideMusicPopout.alignRight ? 3.0 : 2.0;
                }
                return sideMusicPopout.alignBottom ? 3.0 : 1.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: sideMusicPopout.isSolid && menuContainer.dynamicCornerRadius > 0.5
            x: {
                if (sideMusicPopout.isSideBar) {
                    return sideMusicPopout.alignRight ? (parent.width - menuContainer.dynamicCornerRadius) : 0;
                }
                return parent.width;
            }
            y: {
                if (sideMusicPopout.isSideBar) {
                    return parent.height;
                }
                return sideMusicPopout.alignBottom ? (parent.height - menuContainer.dynamicCornerRadius) : 0;
            }
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (sideMusicPopout.isSideBar) {
                    return sideMusicPopout.alignRight ? 1.0 : 0.0;
                }
                return sideMusicPopout.alignBottom ? 2.0 : 0.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        Rectangle {
            id: menuBox
            anchors.fill: parent
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: sideMusicPopout.cornerRadius
            readonly property bool flatCorners: sideMusicPopout.isSolid
            topLeftRadius: (flatCorners && (sideMusicPopout.isSideBar ? !sideMusicPopout.alignRight : !sideMusicPopout.alignBottom)) ? 0 : sideMusicPopout.cornerRadius
            topRightRadius: (flatCorners && (sideMusicPopout.isSideBar ? sideMusicPopout.alignRight : !sideMusicPopout.alignBottom)) ? 0 : sideMusicPopout.cornerRadius
            bottomLeftRadius: (flatCorners && (sideMusicPopout.isSideBar ? !sideMusicPopout.alignRight : sideMusicPopout.alignBottom)) ? 0 : sideMusicPopout.cornerRadius
            bottomRightRadius: (flatCorners && (sideMusicPopout.isSideBar ? sideMusicPopout.alignRight : sideMusicPopout.alignBottom)) ? 0 : sideMusicPopout.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                rim: 0
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
                filletRadius: menuFillets.filletRadius
                filletDir: menuFillets.filletDir
            }

            HoverHandler {
                id: menuHoverHandler
                onHoveredChanged: {
                    SideMusicController.menuHovered = hovered;
                    if (hovered) {
                        SideMusicController.cancelHide();
                    } else {
                        SideMusicController.requestHide();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
            }

            ColumnLayout {
                width: sideMusicPopout.menuWidth - sideMusicPopout.s(24)
                height: sideMusicPopout.menuHeight - sideMusicPopout.s(16)
                anchors.top: (!sideMusicPopout.isSideBar && !sideMusicPopout.alignBottom) ? parent.top : undefined
                anchors.bottom: (!sideMusicPopout.isSideBar && sideMusicPopout.alignBottom) ? parent.bottom : undefined
                anchors.left: (sideMusicPopout.isSideBar && !sideMusicPopout.alignRight) ? parent.left : undefined
                anchors.right: (sideMusicPopout.isSideBar && sideMusicPopout.alignRight) ? parent.right : undefined
                anchors.horizontalCenter: sideMusicPopout.isSideBar ? parent.horizontalCenter : undefined
                anchors.verticalCenter: !sideMusicPopout.isSideBar ? parent.verticalCenter : undefined
                anchors.topMargin: sideMusicPopout.s(8)
                anchors.bottomMargin: sideMusicPopout.s(8)
                anchors.leftMargin: sideMusicPopout.s(12)
                anchors.rightMargin: sideMusicPopout.s(12)
                spacing: sideMusicPopout.s(4)

                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: titleSection.implicitHeight
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Caching.serpantinumDir) {
                            Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"]);
                        }
                    }

                    ColumnLayout {
                        id: titleSection
                        anchors.fill: parent
                        spacing: sideMusicPopout.s(2)

                        MarqueeText {
                            Layout.fillWidth: true
                            Layout.preferredHeight: sideMusicPopout.s(18)
                            text: isMediaActive ? (targetPlayer ? targetPlayer.trackTitle : "") : I18n.t("music.nothing_playing")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: sideMusicPopout.s(13)
                            marqueeSpacing: sideMusicPopout.s(40)
                            pauseDuration: 2500
                            speed: 25
                            active: menuHoverHandler.hovered
                        }

                        Text {
                            Layout.fillWidth: true
                            text: targetPlayer && targetPlayer.trackArtist ? targetPlayer.trackArtist : (targetPlayer ? targetPlayer.identity : "")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: sideMusicPopout.s(11)
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: sideMusicPopout.s(6)

                    Dropdown {
                        id: sourceDropdown
                        visible: sideMusicPopout.playerList.length >= 2
                        Layout.preferredHeight: sideMusicPopout.s(22)
                        implicitHeight: sideMusicPopout.s(22)
                        implicitWidth: sideMusicPopout.s(150)
                        cornerRadius: ThemeBackend.borderRadius
                        options: sideMusicPopout.playerOptions
                        currentIndex: sideMusicPopout.currentPlayerIndex
                        fontPixelSize: sideMusicPopout.s(10)
                        iconSize: sideMusicPopout.s(11)
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.mantle
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        onValueChanged: (index, value) => {
                            sideMusicPopout.selectPlayerByIndex(index);
                        }
                    }

                    ClickButton {
                        id: sourcePill
                        visible: sideMusicPopout.playerList.length < 2
                        Layout.preferredHeight: sideMusicPopout.s(20)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: sideMusicPopout.s(8)
                        buttonText: I18n.t("music.via_source", { "source": sideMusicPopout.targetPlayer ? (sideMusicPopout.targetPlayer.identity || sideMusicPopout.targetPlayer.desktopEntry || "Media") : I18n.t("music.offline") })
                        textFontSize: sideMusicPopout.s(10)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.overlay2
                    }
                }

                WavySeekBar {
                    id: popupProgBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: sideMusicPopout.s(26)
                    Layout.alignment: Qt.AlignVCenter
                    from: 0.0
                    to: (targetPlayer && typeof targetPlayer.length === "number" && !isNaN(targetPlayer.length)) ? targetPlayer.length : 100.0
                    value: sideMusicPopout.currentLivePosition
                    playing: sideMusicPopout.isPlaying
                    waveColor: ThemeBackend.mauve

                    property bool seekPending: false

                    Timer {
                        id: seekDebounceTimer
                        interval: 800
                        onTriggered: popupProgBar.seekPending = false
                    }

                    Connections {
                        target: sideMusicPopout
                        function onCurrentLivePositionChanged() {
                            if (!popupProgBar.isDragging && !popupProgBar.seekPending) {
                                popupProgBar.value = sideMusicPopout.currentLivePosition;
                            }
                        }
                    }

                    onIsDraggingChanged: {
                        if (isDragging) SideMusicController.cancelHide();
                        else SideMusicController.requestHide();
                    }

                    onMoved: val => {
                        if (targetPlayer && targetPlayer.canSeek) {
                            popupProgBar.seekPending = true;
                            seekDebounceTimer.restart();
                            popupProgBar.value = val;
                            targetPlayer.position = val;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: sideMusicPopout.formatTime(sideMusicPopout.currentLivePosition)
                        color: ThemeBackend.subtext1
                        font.family: ThemeBackend.fontFamily
                        font.bold: true
                        font.pixelSize: sideMusicPopout.s(9.5)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: sideMusicPopout.formatTime(targetPlayer ? targetPlayer.length : 0)
                        color: ThemeBackend.subtext1
                        font.family: ThemeBackend.fontFamily
                        font.bold: true
                        font.pixelSize: sideMusicPopout.s(9.5)
                    }
                }
            }
        }
    }
}
