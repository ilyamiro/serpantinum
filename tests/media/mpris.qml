import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../src/quickshell" as Shell

Item {
    id: test
    property int step: 0
    property bool failed: false
    // Keep the service instantiated before the first asynchronous discovery.
    readonly property var controller: Shell.MprisController
    readonly property var discoveredPlayers: Mpris.players.values
    function check(app, playing) {
        let player = Shell.MprisController.activePlayer;
        let actual = player ? player.identity : "";
        if (actual !== app || Shell.MprisController.isPlaying !== playing) {
            failed = true;
            console.error("FAIL: MPRIS step " + step + ": expected " + app + "/" + playing
                + ", got " + actual + "/" + Shell.MprisController.isPlaying);
            console.error("MPRIS diagnostic: mode=" + Shell.MprisController.musicSource
                + ", last=" + Shell.MprisController.lastPlayingBus + ", players="
                + JSON.stringify(Mpris.players.values.map(p => ({bus: p.dbusName, identity: p.identity,
                    playing: p.isPlaying, state: p.playbackState, title: p.trackTitle}))));
        }
    }
    function mode(value) { Shell.Config.setSetting("media.musicSource", value); }
    function verify(condition, message) {
        if (!condition) { failed = true; console.error("FAIL: " + message); }
    }
    function available(key) {
        return controller.musicSources.some(source => source.key === key && source.available);
    }
    function change(name, action) {
        command.command = ["dbus-send", "--session", "--print-reply", "--dest=org.serpantinum.MediaTest",
            "/test", "org.serpantinum.MediaTest.Change", "string:" + name, "string:" + action];
        command.running = true;
    }
    Process {
        id: command
        onExited: function(code) {
            if (code !== 0) { test.failed = true; console.error("FAIL: fixture command exited " + code); }
        }
    }
    Timer {
        interval: 180
        repeat: true
        running: Shell.Config.dataReady
        onTriggered: {
            if (command.running) return;
            if (test.step === 0 && test.discoveredPlayers.length !== 2) return;
            switch (test.step++) {
            case 0: test.mode("automatic"); break;
            case 1:
                test.check("Brave", true);
                test.verify(test.available("desktop:brave"), "browser discovered");
                test.mode("desktop:spotify"); break;
            case 2: test.check("Spotify", true); test.change("spotify", "Paused"); break;
            case 3:
                test.check("Spotify", false);
                test.verify(controller.trackTitle === "Track", "paused metadata retained");
                test.mode("automatic"); break;
            case 4: test.check("Brave", true); test.change("custom", "custom"); break;
            case 5:
                test.verify(test.available("desktop:org.example.Custom"), "arbitrary application discovered");
                test.mode("desktop:org.example.Custom"); break;
            case 6: test.check("Custom Player", true); controller.activePlayer.togglePlaying(); break;
            case 7: test.check("Custom Player", false); test.change("duplicate", "second-instance"); break;
            case 8:
                test.check("Custom Player", false);
                test.verify(controller.activePlayer.dbusName.endsWith("instance42"), "paused instance remains selected");
                test.verify(controller.musicSources.filter(source => source.key === "desktop:org.example.Custom").length === 1, "instances grouped");
                test.change("custom", "close"); break;
            case 9: test.check("Custom Player", true); test.change("duplicate", "close"); break;
            case 10:
                test.check("", false);
                test.verify(controller.musicSource === "desktop:org.example.Custom", "preference retained");
                test.verify(controller.musicSources.some(source => source.key === controller.musicSource && !source.available), "unavailable entry retained");
                test.change("custom", "reconnect"); break;
            case 11: test.check("Custom Player", true); test.change("custom", "metadata"); break;
            case 12:
                test.check("Custom Player", true);
                test.verify(controller.trackTitle === "Changed title", "metadata update");
                test.mode("desktop:brave"); break;
            case 13: test.check("Brave", true); test.change("browser", "close"); break;
            case 14: test.check("", false); test.change("second", "open"); break;
            case 15:
                test.check("", false);
                test.verify(test.available("desktop:firefox"), "new browser discovered without fallback");
                test.mode("desktop:firefox"); break;
            case 16: test.check("Firefox", true); test.change("second", "Stopped"); break;
            case 17: test.check("Firefox", false); test.change("second", "close"); break;
            case 18:
                test.check("", false);
                if (!test.failed) console.log("PASS: MPRIS integration (discovery, manual selection, pause, instances and reconnect)");
                Qt.quit();
            }
        }
    }
}
