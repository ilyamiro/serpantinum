import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../src/quickshell" as S
import "../../src/quickshell/bar"
import "../../src/quickshell/widgets/faces/music"

Window {
    id: root
    width: 800; height: 400; visible: true
    BarModule { id: media; moduleId: "media" }
    MusicFaceLyricsSimple { id: lyrics; width: 300; height: 100 }
    Process { id: report }
    Timer {
        interval: 100
        repeat: true
        running: S.Config.dataReady
        onTriggered: {
            if (report.running) return;
            let value = {step: S.Config.getSetting("_mediaTestStep", -1),
                mode: S.MprisController.musicSource, idle: S.MprisController.hideWhenIdle,
                hideLyrics: S.MprisController.hideUnavailableLyrics,
                source: S.MprisController.activePlayer ? S.MprisController.activePlayer.identity : "",
                playing: S.MprisController.isPlaying, mediaVisible: media.effectiveVisible,
                width: media.width, lyricsVisible: lyrics.contentVisible,
                hasLyrics: S.Lyrics.hasLyrics, subscribers: S.Lyrics.subscribers,
                lyricSource: S.Lyrics.player ? S.Lyrics.player.identity : ""};
            report.command = ["python3", "-c", "import os,sys; p=sys.argv[1]; open(p+'.tmp','w').write(sys.argv[2]); os.replace(p+'.tmp',p)",
                Quickshell.env("MEDIA_TEST_RESULT"), JSON.stringify(value)];
            report.running = true;
        }
    }
}
