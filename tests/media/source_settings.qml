import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../src/quickshell" as S
import "../../src/quickshell/guide/bar/modules"

Window {
    id: test
    width: 1000
    height: 900
    visible: true
    property string role: Quickshell.env("MEDIA_TEST_ROLE")
    property int step: 0
    property int localeStep: 0
    QtObject {
        id: context
        property bool visible: true
        property int currentTab: 0
        property int currentSubTab: 0
        property string highlightedSettingId: ""
        property int highlightToken: 0
        function s(v) { return v; }
    }
    BarModulesSettings {
        id: settings
        rootObj: context
        tabIndex: 0
        isDesktop: false
        function inView(item) { return true; }
        BarMediaCard { id: card; width: parent.width; tab: settings }
    }
    function find(item) {
        if (item.options !== undefined && typeof item.selected === "function") return item;
        for (let child of item.children || []) {
            let result = find(child);
            if (result) return result;
        }
        return null;
    }
    function verify(value, message) {
        if (!value) throw new Error(message);
    }
    function findRow(item, id) {
        if (item.settingId === id) return item;
        for (let child of item.children || []) {
            let row = findRow(child, id);
            if (row) return row;
        }
        return null;
    }
    function checkTranslations() {
        if (!S.I18n.isReady) return false;
        verify(S.I18n.i18nDir === Quickshell.env("SERPANTINUM_DIR") + "/assets/languages",
            "Settings uses the shell asset directory");
        if (localeStep === 0) {
            S.I18n.currentLang = "ru";
            localeStep = 1;
            return false;
        }
        if (localeStep === 1 && !S.I18n.resolveKey("ru", "guide.bar.media.source.title")) return false;
        for (let pair of [["source", "media_music_source"], ["hide_idle", "media_hide_when_idle"],
                          ["hide_lyrics", "media_hide_unavailable_lyrics"]]) {
            let row = findRow(card, pair[1]);
            verify(row !== null, "native settings row exists");
            for (let field of ["title", "desc"]) {
                let key = "guide.bar.media." + pair[0] + "." + field;
                let text = S.I18n.resolveKey(localeStep === 1 ? "ru" : "en", key);
                verify(!!text && text !== key, "translated " + key);
                verify(row[field === "title" ? "title" : "description"] === text,
                    "native control displays " + key);
            }
        }
        if (localeStep === 1) {
            S.I18n.currentLang = "en";
            localeStep = 2;
            return false;
        }
        return true;
    }
    Process {
        id: closePlayer
        command: ["dbus-send", "--session", "--print-reply", "--dest=org.serpantinum.MediaTest",
            "/test", "org.serpantinum.MediaTest.Change", "string:browser", "string:close"]
    }
    Timer {
        interval: 100
        repeat: true
        running: S.Config.dataReady
        onTriggered: {
            try {
                if (!test.checkTranslations()) return;
                let dropdown = test.find(card);
                test.verify(dropdown !== null, "native source dropdown exists");
                let index = card.musicSources.indexOf("desktop:brave");
                if (test.role === "writer") {
                    if (test.step === 0) {
                        if (index < 0) return;
                        dropdown.selected(index, dropdown.options[index]);
                        test.step++;
                        return;
                    }
                    if (S.Config.isWriting) return;
                    test.verify(S.Config.getSetting("media.musicSource") === "desktop:brave", "saved stable key");
                    test.verify(S.Config.getSetting("media.musicSourceName") === "Brave", "saved display name");
                    console.log("PASS: native source setting saved");
                    Qt.quit();
                    return;
                }
                if (S.MprisController.musicSource !== "desktop:brave") return;
                test.verify(index >= 0 && dropdown.currentIndex === index, "selected source remains in Settings");
                if (test.role === "reader" && test.step === 0) {
                    if (!S.MprisController.activePlayer) return;
                    test.verify(S.MprisController.activePlayer.identity === "Brave", "separate process reacts");
                    closePlayer.running = true;
                    test.step++;
                    return;
                }
                if (closePlayer.running || S.MprisController.activePlayer) return;
                test.verify(S.Config.getSetting("media.musicSourceName") === "Brave", "display name survives disconnect/restart");
                test.verify(dropdown.options[index].includes("Brave") && dropdown.options[index].includes("Unavailable"), "unavailable source label");
                console.log("PASS: source settings " + test.role);
                Qt.quit();
            } catch (error) {
                console.error("FAIL: source settings: " + error);
                Qt.quit();
            }
        }
    }
}
