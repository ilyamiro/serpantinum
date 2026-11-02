import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../src/quickshell" as S
import "../../src/quickshell/guide/bar/modules"

Window {
    id: root
    width: 1000; height: 900; visible: true
    property int handled: -1
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
    // Exercise the real controls' signals and their real SettingsRow handlers,
    // rather than writing the media values directly from the test driver.
    function find(item, predicate) {
        if (predicate(item)) return item;
        for (let child of item.children || []) {
            let match = find(child, predicate);
            if (match) return match;
        }
        return null;
    }
    function control(id, predicate) {
        let row = find(card, item => item.settingId === id);
        let value = row ? find(row, predicate) : null;
        if (!value) throw new Error("Native control not found: " + id);
        return value;
    }
    function applyRequest() {
        if (!S.Config.dataReady || !request.loaded) return;
        try {
            let data = JSON.parse(request.text());
            if (data.step === handled) return;
            let dropdown = control("media_music_source", item => item.options !== undefined && typeof item.selected === "function");
            let index = card.musicSources.indexOf(data.mode);
            if (index < 0) return;
            handled = data.step;
            dropdown.selected(index, dropdown.options[index]);
            control("media_hide_when_idle", item => item.checked !== undefined && typeof item.toggled === "function").toggled(data.idle);
            control("media_hide_unavailable_lyrics", item => item.checked !== undefined && typeof item.toggled === "function").toggled(data.lyrics);
            S.Config.setSetting("_mediaTestStep", data.step);
        } catch (error) { console.error("FAIL: native settings request: " + error); }
    }
    FileView {
        id: request
        path: Quickshell.env("MEDIA_TEST_REQUEST")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyRequest()
    }
    Connections { target: S.Config; function onDataReadyChanged() { root.applyRequest(); } }
    Connections { target: S.MprisController; function onMusicSourcesChanged() { root.applyRequest(); } }
}
