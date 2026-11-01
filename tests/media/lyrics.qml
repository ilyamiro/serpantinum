import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../src/quickshell" as Shell

Item {
    id: test

    function verify(value) { if (!value) throw new Error("Assertion failed"); }
    function compare(actual, expected) {
        if (actual !== expected) throw new Error("Expected " + expected + ", got " + actual);
    }

    Component.onCompleted: Qt.callLater(function() {
        let cases = [test_contextIsolation, test_staleResponseAndABA, test_sourceChangeSameSong,
            test_visibilityAndSubscription, test_negativeResultDoesNotRefetch,
            test_metadataClearsImmediately, test_noSubscriberRejectsLateResponse];
        try {
            for (let run of cases) {
                init();
                run();
                cleanup();
            }
            console.log("PASS: LyricsContexts (" + cases.length + " cases)");
        } catch (error) {
            console.error("FAIL: LyricsContexts: " + error + "\n" + error.stack);
        }
        Qt.callLater(function() { Qt.quit(); });
    })

    QtObject {
        id: spotify
        property string busName: "org.mpris.MediaPlayer2.spotify"
        property string trackTitle: "Song A"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property var metadata: ({"mpris:trackid": "/track/a"})
        property int playbackState: MprisPlaybackState.Playing
        property bool isPlaying: playbackState === MprisPlaybackState.Playing
        property real position: 12
        property real length: 200
    }
    QtObject {
        id: browser
        property string busName: "org.mpris.MediaPlayer2.chromium.instance7"
        property string trackTitle: "Video B"
        property string trackArtist: "Channel"
        property string trackAlbum: ""
        property var metadata: ({"mpris:trackid": "/video/b"})
        property int playbackState: MprisPlaybackState.Playing
        property bool isPlaying: true
        property real position: 70
        property real length: 400
    }

    Component {
        id: providerComponent
        Shell.LyricsProvider {
            property int searches: 0
            // Exercise real lifecycle/response handling with a controlled backend.
            function checkCacheAndFetch(key) { searches++; loading = true; }
        }
    }
    property var globalContext
    property var popupContext

    function init() {
        spotify.trackTitle = "Song A";
        spotify.metadata = {"mpris:trackid": "/track/a"};
        spotify.playbackState = MprisPlaybackState.Playing;
        globalContext = providerComponent.createObject(test, {player: spotify});
        popupContext = providerComponent.createObject(test, {player: browser});
        globalContext.subscribe();
        popupContext.subscribe();
        Shell.Config.rawSettings = {media: {hideUnavailableLyrics: true, hideWhenIdle: true}};
    }

    function cleanup() {
        globalContext.unsubscribe();
        popupContext.unsubscribe();
        globalContext.destroy();
        popupContext.destroy();
    }

    function session(provider) {
        let s = {key: provider.currentTrackKey, generation: provider.requestGeneration, done: false,
            netEaseDone: false, lrclibDone: false, lineCandidate: null};
        provider.activeSession = s;
        return s;
    }

    function deliver(provider, s, text) {
        return provider.applyLrclibRecord({syncedLyrics: "[00:01.00]" + text}, s);
    }

    function test_contextIsolation() {
        verify(deliver(globalContext, session(globalContext), "Spotify lyrics"));
        verify(deliver(popupContext, session(popupContext), "Browser lyrics"));
        compare(globalContext.lyrics[0].text, "Spotify lyrics");
        compare(popupContext.lyrics[0].text, "Browser lyrics");
        compare(globalContext.player, spotify);
        compare(popupContext.player, browser);
        popupContext.player = spotify;
        compare(popupContext.hasLyrics, false);
        compare(globalContext.hasLyrics, true);
    }

    function test_staleResponseAndABA() {
        let old = session(globalContext);
        spotify.trackTitle = "Song B";
        compare(globalContext.hasLyrics, false);
        verify(!deliver(globalContext, old, "stale A"));
        spotify.trackTitle = "Song A";
        globalContext.triggerSearch();
        let current = session(globalContext);
        verify(!deliver(globalContext, old, "stale A after ABA"));
        verify(deliver(globalContext, current, "fresh A"));
        compare(globalContext.lyrics[0].text, "fresh A");
    }

    function test_sourceChangeSameSong() {
        let old = session(globalContext);
        let clone = Qt.createQmlObject('import QtQuick; QtObject { property string busName: "other"; property string trackTitle: "Song A"; property string trackArtist: "Artist"; property string trackAlbum: "Album"; property var metadata: ({}); property int playbackState: 1; property bool isPlaying: true; property real position: 0; property real length: 200 }', test);
        clone.playbackState = MprisPlaybackState.Playing;
        globalContext.player = clone;
        globalContext.triggerSearch();
        verify(!deliver(globalContext, old, "old source"));
        compare(globalContext.hasLyrics, false);
        globalContext.player = spotify;
        clone.destroy();
    }

    function test_visibilityAndSubscription() {
        compare(globalContext.showContent, false); // loading
        compare(globalContext.subscribers, 1);
        verify(deliver(globalContext, session(globalContext), "found"));
        compare(globalContext.showContent, true);
        let searches = globalContext.searches;
        let generation = globalContext.requestGeneration;
        spotify.playbackState = MprisPlaybackState.Paused;
        compare(globalContext.showContent, true);
        compare(globalContext.hasLyrics, true);
        compare(globalContext.lyrics[0].text, "found");
        compare(globalContext.subscribers, 1);
        Shell.Config.rawSettings = {media: {hideUnavailableLyrics: true, hideWhenIdle: false}};
        compare(globalContext.showContent, true);
        spotify.playbackState = MprisPlaybackState.Playing;
        compare(globalContext.showContent, true);
        compare(globalContext.searches, searches);
        compare(globalContext.requestGeneration, generation);
        spotify.playbackState = MprisPlaybackState.Stopped;
        compare(globalContext.showContent, false);
        compare(globalContext.hasLyrics, false);
        Shell.Config.rawSettings = {};
        compare(globalContext.showContent, true); // backward-compatible empty states
    }

    function test_negativeResultDoesNotRefetch() {
        let s = session(globalContext);
        s.netEaseDone = true;
        s.lrclibDone = true;
        globalContext.checkCompletion(s);
        let searches = globalContext.searches;
        globalContext.subscribe();
        spotify.playbackState = MprisPlaybackState.Paused;
        globalContext.triggerSearch();
        compare(globalContext.searches, searches);
        compare(globalContext.hasLyrics, false);
        compare(globalContext.showContent, false);
        globalContext.unsubscribe();
    }

    function test_metadataClearsImmediately() {
        verify(deliver(globalContext, session(globalContext), "old"));
        spotify.metadata = {"mpris:trackid": "/track/another"};
        compare(globalContext.hasLyrics, false);
        compare(globalContext.showContent, false);
        compare(globalContext.subscribers, 1);
    }

    function test_noSubscriberRejectsLateResponse() {
        let old = session(globalContext);
        globalContext.loading = false; // search timeout allows late results while subscribed
        globalContext.unsubscribe();
        verify(!deliver(globalContext, old, "late"));
        globalContext.subscribe();
        verify(!deliver(globalContext, old, "late after subscribe"));
        verify(deliver(globalContext, session(globalContext), "current"));
    }
}
