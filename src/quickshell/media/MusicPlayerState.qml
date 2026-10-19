import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

Item {
    id: root

    readonly property bool active: root.visible

    property bool cavaRegistered: false

    function registerCava() {
        if (!cavaRegistered) {
            cavaRegistered = true;
            Cava.registerConsumer();
        }
    }

    function unregisterCava() {
        if (cavaRegistered) {
            cavaRegistered = false;
            Cava.unregisterConsumer();
        }
    }

    function s(val) { 
        return Scaler.s(val); 
    }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    property int barCount: 60
    property var rawBarLevels: []

    Binding {
        target: root
        property: "rawBarLevels"
        value: Cava.barLevels
        when: root.active
    }

    // Sub-bass and kick strength for the glow and the disc bounce
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
            triggerLocalArtFetch();
        }
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
    property string localBlur: ""
    property string localGrad: ""
    property string localTextColor: ""
    property string localDeviceIcon: "󰓃"
    property string localDeviceName: "Speaker"

    Process {
        id: customArtFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.targetPlayer ? (root.targetPlayer.dbusName || root.targetPlayer.identity || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackArtUrl || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackTitle || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackArtist || "") : ""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.localArtUrl = d.artUrl || "";
                        root.localBlur = d.blur || "";
                        root.localGrad = d.grad || "";
                        root.localTextColor = d.textColor || "#cdd6f4";
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
            customArtFetchProc.running = true;
        } else if (root.targetPlayer && root.targetPlayer === MprisController.activePlayer) {
            if (!MprisController.artUrl) {
                MprisController.queueFetch();
            }
        }
    }

    property string activeArtUrl: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.artUrl : localArtUrl
    property string activeBlur: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.blur : localBlur
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
