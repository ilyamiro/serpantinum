import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"
import "../reusables"

HostedPanel {
    id: root

    readonly property bool active: root.visible
    readonly property bool spectrumRegistered: spectrumGate.active

    SubscriptionGate {
        id: spectrumGate
        target: Spectrum
        wanted: root.active
    }

    function formatTime(sec) {
        return MprisController.formatTime(sec);
    }

    property int barCount: 60
    property var rawBarLevels: []

    Binding {
        target: root
        property: "rawBarLevels"
        value: Spectrum.barLevels
        when: root.active
    }

    property var beat: {
        let source = rawBarLevels;
        if (!source || source.length === 0) return { bass: 0.0, kick: 0.0 };

        let subBass = (source[0] || 0.0) * 0.50 + (source[1] || 0.0) * 0.35 + (source[2] || 0.0) * 0.15;
        let kickPunch = (source[1] || 0.0) * 0.30 + (source[2] || 0.0) * 0.45 + (source[3] || 0.0) * 0.25;
        let rawKick = Math.max(subBass, kickPunch);

        let kick = rawKick > 0.10 ? Math.min(1.0, Math.pow((rawKick - 0.10) / 0.90, 1.8) * 1.4) : 0.0;
        let bass = Math.max(0.0, Math.min(1.0, subBass * 0.6 + kickPunch * 0.4));

        return { bass: bass, kick: kick };
    }

    property real bassLevel: beat.bass
    property real kickLevel: beat.kick

    readonly property var playerList: MprisController.players
    readonly property var targetPlayer: MprisController.targetPlayer
    readonly property bool hasTargetPlayer: targetPlayer !== null
    readonly property var playerOptions: MprisController.playerOptions
    readonly property int currentPlayerIndex: MprisController.currentPlayerIndex

    function selectPlayerByIndex(idx) {
        MprisController.selectPlayerByIndex(idx);
        triggerLocalArtFetch();
    }

    property real currentLivePosition: targetPlayer ? targetPlayer.position : 0

    Connections {
        target: root.targetPlayer
        function onPositionChanged() {
            if (!root.active) return;
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
        }
        function onPostTrackChanged() {
            if (!root.active) return;
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
            root.triggerLocalArtFetch();
        }
        function onTrackArtUrlChanged() {
            if (!root.active) return;
            root.triggerLocalArtFetch();
        }
        function onTrackTitleChanged() {
            if (!root.active) return;
            root.triggerLocalArtFetch();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.hasTargetPlayer && root.targetPlayer.isPlaying
        onTriggered: {
            if (root.targetPlayer) {
                if (typeof root.targetPlayer.positionChanged === "function") {
                    root.targetPlayer.positionChanged();
                }
                root.currentLivePosition = root.targetPlayer.position;
            }
        }
    }

    property string localArtUrl: ""
    property int localArtWidth: 0
    property string localArtTrack: ""
    property string localArtRawUrl: ""
    property string localGrad: ""
    property string localTextColor: ""
    property string localDeviceIcon: "󰓃"
    property string localDeviceName: "Speaker"
    property string localFetchArtUrl: ""

    Process {
        id: customArtFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.targetPlayer ? (root.targetPlayer.dbusName || root.targetPlayer.identity || "") : "",
            root.localFetchArtUrl.startsWith("data:") ? "data:stdin" : root.localFetchArtUrl,
            root.targetPlayer ? (root.targetPlayer.trackTitle || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackArtist || "") : ""
        ]
        onStarted: {
            if (stdinEnabled && root.localFetchArtUrl.startsWith("data:")) write(root.localFetchArtUrl + "\n");
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        let track = d.playerId + "\n" + d.title + "\n" + d.artist;
                        let sameTrack = !!(d.title || d.artist) && track === root.localArtTrack && root.localArtUrl !== "";
                        let keepCurrent = sameTrack && (d.artUrl ? d.artUrl !== root.localArtUrl && d.artWidth < root.localArtWidth : root.localArtWidth > 0);
                        if (!keepCurrent) {
                            let carriedOver = track !== root.localArtTrack && !!d.artUrl && d.rawUrl === root.localArtRawUrl;
                            root.localArtTrack = track;
                            root.localArtRawUrl = d.rawUrl || "";
                            root.localArtWidth = carriedOver ? 0 : (d.artWidth || 0);
                            root.localArtUrl = d.artUrl || "";
                            root.localGrad = d.grad || "";
                            root.localTextColor = d.textColor || "#cdd6f4";
                        }
                        root.localDeviceIcon = d.deviceIcon || "󰓃";
                        root.localDeviceName = d.deviceName || "Speaker";
                    } catch(e) {}
                }
            }
        }
    }

    function triggerLocalArtFetch() {
        if (root.targetPlayer && root.targetPlayer !== MprisController.activePlayer) {
            customArtFetchProc.running = false;
            root.localFetchArtUrl = root.targetPlayer.trackArtUrl || "";
            customArtFetchProc.stdinEnabled = root.localFetchArtUrl.startsWith("data:");
            customArtFetchProc.running = true;
        } else if (root.targetPlayer && root.targetPlayer === MprisController.activePlayer) {
            if (!MprisController.artUrl) {
                MprisController.queueFetch();
            }
        }
    }

    property string activeArtUrl: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.artUrl : localArtUrl
    property string activeGrad: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.grad : localGrad
    property string activeTextColor: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.textColor : (localTextColor || "#cdd6f4")
    property string activeDeviceIcon: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.deviceIcon : localDeviceIcon
    property string activeDeviceName: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.deviceName : localDeviceName

    property var borderColors: {
        var defaultColors = [ThemeBackend.mauve || "#cba6f7", ThemeBackend.blue || "#89b4fa", ThemeBackend.red || "#f38ba8", ThemeBackend.mauve || "#cba6f7"];
        var gradSource = root.activeGrad || (typeof MprisController !== "undefined" ? MprisController.grad : "");
        if (!gradSource) return defaultColors;
        
        var hexRegex = /#[0-9a-fA-F]{6}/g;
        var matches = gradSource.match(hexRegex);
        
        if (matches && matches.length >= 3) {
            return [matches[0], matches[1], matches[2], matches[0]];
        }
        return defaultColors;
    }

    property color bc1: borderColors[0] || ThemeBackend.mauve || "#cba6f7"
    property color bc2: borderColors[1] || ThemeBackend.blue || "#89b4fa"
    property color bc3: borderColors[2] || ThemeBackend.red || "#f38ba8"
    property color bc4: borderColors[3] || ThemeBackend.mauve || "#cba6f7"

    property color dynamicTextColor: {
        var rawCol = root.activeTextColor || (typeof MprisController !== "undefined" ? MprisController.textColor : "");
        if (rawCol) {
            var c = String(rawCol).trim();
            var match = c.match(/^(#[0-9a-fA-F]{6})/);
            if (match) return match[1];
        }
        return ThemeBackend.text || "#cdd6f4";
    }
}
