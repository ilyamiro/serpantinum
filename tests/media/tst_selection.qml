import QtQuick
import QtTest
import "../../src/quickshell/singletons/audio/PlayerSelection.js" as Selection

TestCase {
    name: "MediaSourceSelection"

    function player(bus, playing, identity) {
        return {dbusName: "org.mpris.MediaPlayer2." + bus, identity: identity || bus,
            isPlaying: playing, playbackState: playing ? 1 : 2, trackTitle: "Track", canControl: true};
    }

    function test_selection_data() {
        let rows = [];
        for (let mode of ["automatic", "desktop:custom-player"]) {
            for (let app of ["playing", "paused", "stopped", "closed"]) {
                for (let browser of ["playing", "paused", "stopped", "closed"]) {
                    rows.push({tag: mode + "/" + app + "/" + browser, mode: mode, app: app, browser: browser});
                }
            }
        }
        return rows;
    }

    function test_selection(data) {
        let s = player("custom-player.instance123", data.app === "playing", "Custom Player");
        s.desktopEntry = "custom-player";
        if (data.app === "stopped") s.playbackState = 0;
        let b = player("chromium.instance42", data.browser === "playing", "Brave");
        if (data.browser === "stopped") b.playbackState = 0;
        let players = [];
        if (data.app !== "closed") players.push(s);
        if (data.browser !== "closed") players.push(b);
        let selected = Selection.select(players, data.mode, "", 0);
        if (data.mode !== "automatic") compare(selected, data.app === "closed" ? null : s);
        else if (data.browser === "playing") compare(selected, b);
        else if (data.app === "playing") compare(selected, s);
        else if (data.browser === "paused") compare(selected, b);
        else if (data.app === "paused") compare(selected, s);
        else compare(selected, data.browser !== "closed" ? b : data.app !== "closed" ? s : null);
    }

    function test_stableKeys() {
        for (let name of ["custom.instance42", "custom.instance_abc", "custom.pid99", "custom-123", "custom.123.456"]) {
            compare(Selection.applicationKeys(player(name, true))[0], "mpris:custom");
        }
        let p = player("arbitrary.instance7", true, "Any Application");
        p.desktopEntry = "org.example.Player.desktop";
        compare(Selection.applicationKeys(p)[0], "desktop:org.example.Player");
        compare(Selection.applicationKeys({identity: "Unknown Player"})[0], "identity:Unknown Player");
        compare(Selection.applicationKeys({dbusName: ":1.123", identity: "Unknown Player"})[0], "identity:Unknown Player");
        compare(Selection.applicationKeys({}).length, 0);
        compare(Selection.applicationKeys(player("org.example.pidgin", true))[0], "mpris:org.example.pidgin");
        compare(Selection.applicationKeys(player("org.example.instanceplayer", true))[0], "mpris:org.example.instanceplayer");
        compare(Selection.select([p], "desktop:missing", "", 0), null);
        compare(Selection.select([], "desktop:missing", "", 0), null);
    }

    function test_instancesAndReconnect() {
        let a = player("custom.instance2", false, "Custom");
        let b = player("custom.instance3", true, "Custom");
        compare(Selection.select([a, b], "mpris:custom", "", 0), b);
        compare(Selection.select([a, b], "mpris:custom", "", 0, a.dbusName), a);
        compare(Selection.select([b, a], "mpris:custom", "", 0, a.dbusName), a);
        compare(Selection.select([b], "mpris:custom", "", 0, a.dbusName), b);
        compare(Selection.select([], "mpris:custom", "", 0, a.dbusName), null);
        compare(Selection.select([b], "mpris:custom", "", 0), b);
    }

    function test_discovery() {
        let a = player("custom.instance2", true, "Custom");
        let b = player("custom.instance3", true, "Custom");
        let entries = Selection.sources([b, null, a], "mpris:custom", "Custom");
        compare(entries.length, 1);
        compare(entries[0].key, "mpris:custom");
        compare(entries[0].available, true);
        a.desktopEntry = "org.example.Custom";
        entries = Selection.sources([a, b], "automatic", "");
        compare(entries.length, 1);
        compare(entries[0].key, "desktop:org.example.Custom");
        compare(Selection.select([a, b], "desktop:org.example.Custom", "", 0, b.dbusName), b);
        entries = Selection.sources([a], "mpris:custom", "Custom");
        compare(entries[0].key, "mpris:custom");
        compare(Selection.select([a], "mpris:custom", "", 0), a);
        entries = Selection.sources([], "mpris:custom", "Saved Custom");
        compare(entries.length, 1);
        compare(entries[0].name, "Saved Custom");
        compare(entries[0].available, false);
        compare(Selection.sources([], "automatic", "").length, 0);
        compare(Selection.sources([{}], "automatic", "").length, 0);
        a.identity = "   ";
        compare(Selection.sources([a], "automatic", "")[0].name, "org.example.Custom");
        b.desktopEntry = "org.example.Other";
        compare(Selection.sources([a, b], "automatic", "").length, 2);
    }

    function test_automaticHistoryAndMetadata() {
        let a = player("firefox.instance2", false);
        let b = player("chromium.instance3", true);
        compare(Selection.select([a, b], "automatic", a.dbusName, 0), b);
        b.isPlaying = false;
        compare(Selection.select([a, b], "automatic", a.dbusName, 0), a);
        a.trackTitle = "Changed title";
        a.position = 300;
        compare(Selection.select([b, a], "automatic", a.dbusName, 0), a);
        a.canControl = false;
        b.canControl = false;
        a.playbackState = 0;
        b.playbackState = 0;
        compare(Selection.select([a, b], "automatic", "", 0), b);
    }

    function test_legacyPolicies() {
        for (let key of ["prefer-spotify", "spotify-only", "browser-only", ""])
            compare(Selection.sourceKey(key), "automatic");
    }
}
