pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"

Singleton {
    id: root

    readonly property var _playerWatch: {
        let players = Mpris.players.values;
        let states = [];
        for (let i = 0; i < players.length; i++) {
            states.push(players[i].isPlaying);
            states.push(players[i].canControl);
            states.push(players[i].dbusName);
        }
        return states;
    }

    property string lastPlayingBus: ""

    readonly property MprisPlayer activePlayer: {
        let _ = _playerWatch;
        try {
            let players = Mpris.players.values.filter(p => p).sort((a, b) => (a.dbusName || "").localeCompare(b.dbusName || ""));
            let playing = players.find(p => p.isPlaying);
            if (playing) return playing;
            let last = root.lastPlayingBus !== "" ? players.find(p => p.dbusName === root.lastPlayingBus) : null;
            if (last) return last;
            let loaded = players.find(p => p.playbackState !== MprisPlaybackState.Stopped && p.trackTitle !== "");
            if (loaded) return loaded;
            let controllable = players.find(p => p.canControl);
            if (controllable) return controllable;
            return players.length > 0 ? players[0] : null;
        } catch (e) {
            return null;
        }
    }

    readonly property var players: {
        let _ = _playerWatch;
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    readonly property var targetPlayer: {
        let list = root.players;
        if (root.manualPlayer) {
            for (let i = 0; i < list.length; i++) {
                if (list[i] === root.manualPlayer) return root.manualPlayer;
            }
        }
        return root.activePlayer || (list.length > 0 ? list[0] : null);
    }

    readonly property var playerOptions: {
        let list = root.players;
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

    readonly property int currentPlayerIndex: {
        if (!root.targetPlayer) return 0;
        let list = root.players;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === root.targetPlayer) return i;
        }
        return 0;
    }

    function selectPlayerByIndex(idx) {
        let list = root.players;
        if (idx >= 0 && idx < list.length) {
            root.manualPlayer = list[idx];
        }
    }

    function formatTime(seconds) {
        let sec = Math.max(0, Math.floor(Number(seconds) || 0));
        let m = Math.floor(sec / 60);
        let s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string activePlayerId: activePlayer ? (activePlayer.dbusName || activePlayer.identity || "") : ""
    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool isPlaying: {
        try {
            return activePlayer ? activePlayer.isPlaying === true : false;
        } catch (e) {
            return false;
        }
    }
    readonly property string trackTitle: {
        try {
            return activePlayer ? String(activePlayer.trackTitle || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string trackArtist: {
        try {
            return activePlayer ? String(activePlayer.trackArtist || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string currentArtUrl: {
        if (!activePlayer) return "";
        if (activePlayer.trackArtUrl && activePlayer.trackArtUrl !== "") return activePlayer.trackArtUrl;
        if (activePlayer.metadata) {
            let m = activePlayer.metadata;
            if (m["mpris:artUrl"]) return m["mpris:artUrl"];
            if (m["artUrl"]) return m["artUrl"];
            if (m["xesam:url"] && typeof m["xesam:url"] === "string" && (m["xesam:url"].startsWith("http") || m["xesam:url"].startsWith("file://"))) {
                if (m["xesam:url"].match(/\.(jpg|jpeg|png|webp)$/i)) return m["xesam:url"];
            }
        }
        return "";
    }
    property real livePosition: activePlayer ? activePlayer.position : 0

    property string artUrl: ""
    property int artWidth: 0
    property string artTrack: ""
    property string artRawUrl: ""
    property string grad: ""
    property string textColor: "#cdd6f4"
    property string deviceIcon: "󰓃"
    property string deviceName: "Speaker"
    property bool fetchPending: false
    property string fetchArtUrl: ""

    onActivePlayerChanged: {
        if (root.activePlayer && root.activePlayer.isPlaying) {
            root.lastPlayingBus = root.activePlayer.dbusName || "";
        }
        if (root.activePlayer) {
            root.livePosition = root.activePlayer.position;
        }
        root.queueFetch();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasActivePlayer && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }

    Timer {
        id: fetchDebounceTimer
        interval: 60
        repeat: false
        onTriggered: root.fetchArt()
    }

    function queueFetch() {
        fetchDebounceTimer.restart();
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
        }
        function onPostTrackChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
            root.queueFetch();
        }
        function onTrackArtUrlChanged() {
            root.queueFetch();
        }
        function onTrackTitleChanged() {
            root.queueFetch();
        }
        function onMetadataChanged() {
            root.queueFetch();
        }
        function onPlaybackStateChanged() {
            root.queueFetch();
        }
    }

    Process {
        id: artFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.activePlayerId,
            root.fetchArtUrl.startsWith("data:") ? "data:stdin" : root.fetchArtUrl,
            root.trackTitle,
            root.trackArtist
        ]
        onStarted: {
            if (stdinEnabled && root.fetchArtUrl.startsWith("data:")) write(root.fetchArtUrl + "\n");
        }
        onExited: {
            if (root.fetchPending) {
                root.fetchPending = false;
                root.startArtFetch();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.deviceIcon = d.deviceIcon || "󰓃";
                        root.deviceName = d.deviceName || "Speaker";

                        if (d.playerId !== root.activePlayerId || d.title !== root.trackTitle || d.artist !== root.trackArtist) {
                            return;
                        }

                        let track = d.playerId + "\n" + d.title + "\n" + d.artist;
                        let sameTrack = !!(d.title || d.artist) && track === root.artTrack;

                        if (d.isPlaceholder === false && d.artUrl) {
                            if (sameTrack && d.artUrl !== root.artUrl && d.artWidth < root.artWidth) return;
                            let carriedOver = track !== root.artTrack && d.rawUrl === root.artRawUrl;
                            root.artTrack = track;
                            root.artRawUrl = d.rawUrl;
                            root.artWidth = carriedOver ? 0 : d.artWidth;
                            root.artUrl = d.artUrl;
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        } else {
                            if (sameTrack && root.artUrl && root.artWidth > 0) return;
                            root.artTrack = "";
                            root.artRawUrl = "";
                            root.artWidth = 0;
                            root.artUrl = "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function fetchArt() {
        if (!root.hasActivePlayer) {
            root.artTrack = "";
            root.artRawUrl = "";
            root.artWidth = 0;
            root.artUrl = "";
            root.grad = "";
            root.textColor = "#cdd6f4";
            return;
        }
        if (artFetchProc.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        root.startArtFetch();
    }

    function startArtFetch() {
        root.fetchArtUrl = root.currentArtUrl;
        artFetchProc.stdinEnabled = root.fetchArtUrl.startsWith("data:");
        artFetchProc.running = true;
    }

    function forceArtRefresh() {
        root.fetchArt();
    }
}
