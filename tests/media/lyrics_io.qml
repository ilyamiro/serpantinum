import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../src/quickshell" as Shell

Item {
    id: test
    property int step: 0
    property bool failed: false
    QtObject {
        id: fixturePlayer
        property string dbusName: "org.mpris.MediaPlayer2.fixture"
        property string trackTitle: "Cached A"
        property string trackArtist: "Test"
        property string trackAlbum: ""
        property var metadata: ({})
        property int playbackState: MprisPlaybackState.Paused
        property bool isPlaying: false
        property real position: 0
        property real length: 100
    }
    Shell.LyricsProvider {
        id: lyrics
        player: fixturePlayer
        function fetchLyrics(artist, title, key) {
            test.failed = true;
            console.error("FAIL: unexpected network lookup: " + key);
        }
    }
    function check(text) {
        if (!lyrics.hasLyrics || lyrics.lyrics[0].text !== text) {
            failed = true;
            console.error("FAIL: expected " + text + ", got " + JSON.stringify(lyrics.lyrics));
        }
    }
    Timer {
        interval: 200
        repeat: true
        running: Shell.Config.dataReady
        onTriggered: {
            switch (test.step++) {
            case 0:
                lyrics.subscribe(); // start real disk read A
                fixturePlayer.trackTitle = "Cached B"; // cancel before stdout arrives
                break;
            case 1:
                test.check("Cached B");
                lyrics.loadLocalLyricsFile(Quickshell.env("MEDIA_TEST_LRC"));
                fixturePlayer.trackTitle = "Cached A"; // reject old local file response
                break;
            case 2:
                test.check("Cached A");
                lyrics.loadLocalLyricsFile(Quickshell.env("MEDIA_TEST_LRC"));
                break;
            case 3:
                test.check("Local lyrics");
                lyrics.unsubscribe();
                if (!test.failed) console.log("PASS: Lyrics IO (cache and local-file cancellation)");
                Qt.quit();
            }
        }
    }
}
