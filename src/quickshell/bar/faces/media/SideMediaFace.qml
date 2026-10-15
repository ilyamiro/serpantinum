import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
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
    readonly property bool isRightBar: module ? module.isRightBar : (barWindow ? (barWindow.barPosition === "right") : false)
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

    readonly property bool showControls: readBool("mediaShowControls", "mediaShowControls")
    readonly property bool showIcon: readBool("mediaShowIcon", "mediaShowIcon") || !showControls

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
    property bool isMediaActive: targetPlayer !== null && targetPlayer.playbackState !== MprisPlaybackState.Stopped && targetPlayer.trackTitle !== ""
    property bool isPlaying: targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false

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

    function sc(v) { return barWindow ? barWindow.s(v) : v; }

    property real baseHeight: {
        let h = sc(isCompact ? 8 : 9);
        if (showIcon) h += sc(isCompact ? 26 : 28);
        if (showIcon && showControls) h += sc(isCompact ? 4 : 5);
        if (showControls) h += sc(isCompact ? 74 : 80) + sc(isCompact ? 6 : 8);
        return h;
    }
    property real targetHeight: (module && !module.moduleActive) ? 0 : baseHeight

    implicitHeight: targetHeight
    implicitWidth: isPreview ? (barWindow ? barWindow.s(56) : 56) : (parent ? parent.width : 0)

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
        spacing: barWindow ? barWindow.s(root.isCompact ? 4 : 5) : (root.isCompact ? 4 : 5)

        Rectangle {
            id: thumbBox
            visible: root.showIcon
            anchors.horizontalCenter: parent.horizontalCenter
            width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
            height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
            radius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
            color: root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1
            border.width: 1
            border.color: (isMediaActive && isPlaying) ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
            clip: true

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 12 : 13) : (root.isCompact ? 12 : 13)
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
            spacing: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                height: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                buttonIcon: "󰒮"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                bgOpacity: root.barOpacity
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
            }

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 8 : 9) : (root.isCompact ? 8 : 9)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                bgOpacity: root.barOpacity
                textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canTogglePlaying) targetPlayer.togglePlaying()
            }

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                height: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                buttonIcon: "󰒭"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                bgOpacity: root.barOpacity
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoNext) targetPlayer.next()
            }
        }
    }
}
