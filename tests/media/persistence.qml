import QtQuick
import Quickshell
import "../../src/quickshell" as Shell

Item {
    id: test
    property bool started: false
    function run() {
        if (started || !Shell.Config.dataReady) return;
        started = true;
        if (Quickshell.env("MEDIA_TEST_READ") === "1") {
            if (Shell.MprisController.musicSource === "desktop:spotify"
                && Shell.MprisController.hideWhenIdle && Shell.MprisController.hideUnavailableLyrics
                && Shell.Config.getSetting("_mediaPersistenceProbe", "") === Quickshell.env("MEDIA_TEST_PERSISTENCE_TOKEN"))
                console.log("PASS: Settings restored in a fresh process");
            else
                console.error("FAIL: Settings were not restored");
            Qt.quit();
        } else {
            Shell.Config.updateJsonBulk({"media.musicSource": "desktop:spotify",
                "media.hideWhenIdle": true, "media.hideUnavailableLyrics": true,
                // The preceding cross-process test may have saved identical media
                // values. Config intentionally does not write an unchanged object.
                "_mediaPersistenceProbe": Quickshell.env("MEDIA_TEST_PERSISTENCE_TOKEN")});
        }
    }
    Connections {
        target: Shell.Config
        function onDataReadyChanged() { test.run(); }
        function onSettingsLoaded() {
            if (test.started && Quickshell.env("MEDIA_TEST_READ") !== "1" && !Shell.Config.isWriting) {
                console.log("PASS: Settings saved through Config");
                Qt.quit();
            }
        }
    }
    Component.onCompleted: run()
}
