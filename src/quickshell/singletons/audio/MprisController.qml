pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "PlayerSelection.js" as PlayerSelection

Singleton {
    id: root

    readonly property string musicSource: PlayerSelection.sourceKey(Config.getSetting("media.musicSource", "automatic"))
    readonly property var musicSources: {
        let _ = _playerWatch;
        return PlayerSelection.sources(Mpris.players.values, musicSource,
            Config.getSetting("media.musicSourceName", ""));
    }
    readonly property bool hideWhenIdle: Config.getSetting("media.hideWhenIdle", false)
    readonly property bool hideUnavailableLyrics: Config.getSetting("media.hideUnavailableLyrics", false)

    readonly property var _playerWatch: {
        let players = Mpris.players.values;
        let states = [];
        for (let i = 0; i < players.length; i++) {
            states.push(players[i].isPlaying);
            states.push(players[i].canControl);
            states.push(PlayerSelection.busName(players[i]));
            states.push(players[i].identity);
            states.push(players[i].desktopEntry);
            states.push(players[i].playbackState);
            states.push(players[i].trackTitle);
        }
        return states;
    }

    property string lastPlayingBus: ""
    property string selectedBus: ""

    readonly property MprisPlayer activePlayer: {
        let _ = _playerWatch;
        try {
            return PlayerSelection.select(Mpris.players.values, root.musicSource,
                root.lastPlayingBus, MprisPlaybackState.Stopped, root.selectedBus);
        } catch (e) {
            return null;
        }
    }

    readonly property string activePlayerId: activePlayer ? (PlayerSelection.busName(activePlayer) || activePlayer.identity || "") : ""
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
    property string blur: ""
    property string grad: ""
    property string textColor: "#cdd6f4"
    property string deviceIcon: "󰓃"
    property string deviceName: "Speaker"
    property bool fetchPending: false

    function rememberPlayingPlayer() {
        root.selectedBus = root.activePlayer ? PlayerSelection.busName(root.activePlayer) : "";
        if (root.activePlayer && root.activePlayer.isPlaying)
            root.lastPlayingBus = PlayerSelection.busName(root.activePlayer);
    }

    onIsPlayingChanged: Qt.callLater(root.rememberPlayingPlayer)

    onActivePlayerChanged: {
        // Never show artwork from the previous source while its replacement loads.
        root.artUrl = "";
        root.blur = "";
        root.grad = "";
        // Updating an input of activePlayer inside its change handler causes a
        // binding loop. Coalesce history updates after selection has settled.
        Qt.callLater(root.rememberPlayingPlayer);
        if (root.activePlayer) {
            root.livePosition = root.activePlayer.position;
        } else {
            root.livePosition = 0;
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
            root.currentArtUrl,
            root.trackTitle,
            root.trackArtist
        ]
        onExited: {
            if (root.fetchPending) {
                root.fetchPending = false;
                artFetchProc.running = true;
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

                        if (d.isPlaceholder === false && d.artUrl) {
                            root.artUrl = d.artUrl;
                            root.blur = d.blur || "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        } else {
                            root.artUrl = "";
                            root.blur = "";
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
            root.artUrl = "";
            root.blur = "";
            root.grad = "";
            root.textColor = "#cdd6f4";
            return;
        }
        if (artFetchProc.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        artFetchProc.running = true;
    }

    function forceArtRefresh() {
        root.fetchArt();
    }
}
