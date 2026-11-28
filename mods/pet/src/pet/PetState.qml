pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "PetArt.js" as Art

Item {
    id: root
    visible: false

    readonly property var settings: Config.getSetting("pet", ({}))
    readonly property bool enabled: settings.enabled !== false
    property bool pendingSummon: false

    signal powerRequested(bool on)

    function updateSettings(patch) {
        let cur = Config.getSetting("pet", ({}));
        if (!cur || typeof cur !== "object") cur = {};
        for (let k in patch) cur[k] = patch[k];
        Config.setSetting("pet", cur);
    }

    function setEnabled(on) {
        updateSettings({ enabled: !!on });
    }

    function setSounds(on) {
        updateSettings({ sounds: !!on });
    }

    function num(v, d) {
        let n = Number(v);
        return (v === undefined || v === null || v === "" || isNaN(n)) ? d : n;
    }

    readonly property var defaultCodingApps: [
        "jetbrains-*", "code", "code-oss", "codium", "vscodium", "cursor", "dev.zed.Zed", "zed",
        "neovide", "kitty", "Alacritty", "foot", "org.wezfurlong.wezterm", "com.mitchellh.ghostty",
        "DBeaver", "beekeeper-studio", "Github"
    ]
    readonly property var codingApps: Array.isArray(settings.codingApps) ? settings.codingApps : defaultCodingApps
    readonly property real minutesPerTreat: Math.max(5, num(settings.treatMinutes, 25))

    readonly property string furName: (typeof settings.fur === "string" && settings.fur !== "") ? settings.fur : "mauve"

    function themeColor(name, fallback) {
        if (typeof name === "string" && name.charAt(0) === "#") return name;
        let c = ThemeBackend[name];
        return (c !== undefined && c !== null) ? String(c) : String(fallback);
    }

    readonly property var colors: Art.makePalette({
        fur: themeColor(furName, ThemeBackend.mauve),
        bed: themeColor(typeof settings.bed === "string" && settings.bed !== "" ? settings.bed : "peach", ThemeBackend.peach),
        phones: String(ThemeBackend.peach),
        umbrella: String(ThemeBackend.red),
        text: String(ThemeBackend.text),
        base: String(ThemeBackend.base)
    })

    readonly property bool soundsOn: settings.sounds !== false
    readonly property real sfxVolume: Math.max(0, Math.min(1.5, num(settings.soundVolume, 0.7)))
    readonly property string soundDir: Qt.resolvedUrl("sounds/").toString().replace("file://", "")
    property var lastSfx: ({})

    function sfx(name, vol, minGap) {
        if (!root.soundsOn) return;
        let now = Date.now();
        if (minGap && root.lastSfx[name] && now - root.lastSfx[name] < minGap) return;
        root.lastSfx[name] = now;
        Sounds.play(root.soundDir + name + ".wav", (vol === undefined ? 1.0 : vol) * root.sfxVolume);
    }

    property bool loaded: false

    property bool out: true
    property int treats: 0
    property real happiness: 0.6
    property real fullness: 0.4
    property string creditDate: ""
    property int creditedCoding: 0
    property int creditedPomos: 0
    property int fedTotal: 0
    property int pettedTotal: 0
    property int thrownTotal: 0
    property int caughtTotal: 0
    property real lastFedAt: 0
    property int looseTreats: 0

    property var beds: []

    signal summonRequested(var bed)
    signal dismissRequested()
    signal chaseRequested()
    signal reactRequested(string kind)
    signal treatsEarned(int count, string reason)
    signal treatDrag(string phase, real sx, real sy, var bed)
    signal treatDropRequested(var bed)
    signal bedPetted(var bed)
    signal bedArrived()

    readonly property string stateDir: Caching.getStateDir("pet")

    FileView {
        id: store
        path: root.stateDir + "/state.json"
        printErrors: false
        onLoaded: root.restore(store.text())
        onLoadFailed: root.loaded = true
    }

    function restore(txt) {
        try {
            let d = JSON.parse(txt);
            if (d && typeof d === "object") {
                if (d.out !== undefined) root.out = !!d.out;
                if (d.treats !== undefined) root.treats = Math.max(0, Math.round(Number(d.treats) || 0));
                if (d.happiness !== undefined) root.happiness = Math.max(0, Math.min(1, Number(d.happiness) || 0));
                if (d.fullness !== undefined) root.fullness = Math.max(0, Math.min(1, Number(d.fullness) || 0));
                if (d.lastFedAt !== undefined) root.lastFedAt = Number(d.lastFedAt) || 0;
                if (d.looseTreats !== undefined) root.looseTreats = Math.max(0, Math.min(3, Math.round(Number(d.looseTreats) || 0)));
                if (d.credit && typeof d.credit === "object") {
                    root.creditDate = String(d.credit.date || "");
                    root.creditedCoding = Math.max(0, Math.round(Number(d.credit.coding) || 0));
                    root.creditedPomos = Math.max(0, Math.round(Number(d.credit.pomodoros) || 0));
                }
                if (d.stats && typeof d.stats === "object") {
                    root.fedTotal = Math.round(Number(d.stats.fed) || 0);
                    root.pettedTotal = Math.round(Number(d.stats.petted) || 0);
                    root.thrownTotal = Math.round(Number(d.stats.thrown) || 0);
                    root.caughtTotal = Math.round(Number(d.stats.caught) || 0);
                }
            }
        } catch (e) {}
        root.loaded = true;
    }

    function snapshot() {
        return {
            out: root.out,
            treats: root.treats,
            happiness: Math.round(root.happiness * 1000) / 1000,
            fullness: Math.round(root.fullness * 1000) / 1000,
            lastFedAt: root.lastFedAt,
            looseTreats: root.looseTreats,
            credit: { date: root.creditDate, coding: root.creditedCoding, pomodoros: root.creditedPomos },
            stats: { fed: root.fedTotal, petted: root.pettedTotal, thrown: root.thrownTotal, caught: root.caughtTotal }
        };
    }

    Timer {
        id: saveTimer
        interval: 1200
        onTriggered: store.setText(JSON.stringify(root.snapshot(), null, 2) + "\n")
    }

    function save() {
        if (root.loaded) saveTimer.restart();
    }

    onOutChanged: save()
    onTreatsChanged: save()
    onHappinessChanged: save()
    onFullnessChanged: save()
    onCreditDateChanged: save()
    onCreditedCodingChanged: save()
    onCreditedPomosChanged: save()
    onFedTotalChanged: save()
    onPettedTotalChanged: save()
    onThrownTotalChanged: save()
    onCaughtTotalChanged: save()
    onLastFedAtChanged: save()
    onLooseTreatsChanged: save()

    Component.onDestruction: {
        if (saveTimer.running) {
            saveTimer.stop();
            store.setText(JSON.stringify(root.snapshot(), null, 2) + "\n");
        }
    }

    function toggle() {
        if (root.out) root.dismissRequested();
        else root.summonRequested(null);
    }

    function addTreats(count, reason) {
        let n = Math.round(Number(count) || 0);
        if (n <= 0) return;
        root.treats = Math.min(99, root.treats + n);
        root.treatsEarned(n, reason || "");
    }

    function nudgeHappiness(delta) {
        root.happiness = Math.max(0, Math.min(1, root.happiness + delta));
    }

    // fullness drains ~25% per hour since the last meal
    function currentFullness() {
        if (root.lastFedAt <= 0) return root.fullness;
        let hours = Math.max(0, (Date.now() - root.lastFedAt) / 3600000);
        return Math.max(0, root.fullness - hours * 0.25);
    }

    function feed() {
        root.fullness = Math.min(1, currentFullness() + 0.25);
        root.lastFedAt = Date.now();
        root.fedTotal++;
        nudgeHappiness(0.08);
    }

    function isFull() {
        return currentFullness() >= 0.92;
    }

    // a treat leaving the jar becomes "loose" (in hand or on the floor) until it's eaten
    function takeTreat() {
        if (root.treats <= 0 || root.looseTreats >= 3) return false;
        root.treats--;
        root.looseTreats++;
        return true;
    }

    function treatEaten() {
        root.looseTreats = Math.max(0, root.looseTreats - 1);
        feed();
    }

    function returnLooseTreat() {
        if (root.looseTreats <= 0) return;
        root.looseTreats--;
        root.treats = Math.min(99, root.treats + 1);
    }

    function toggleFromBed(bed) {
        if (root.out) root.dismissRequested();
        else root.summonRequested(bed);
    }

    function requestTreatDrop(bed) {
        if (root.treats > 0) root.treatDropRequested(bed);
    }

    function registerBed(bed) {
        if (!bed || root.beds.indexOf(bed) !== -1) return;
        let next = root.beds.slice();
        next.push(bed);
        root.beds = next;
    }

    function unregisterBed(bed) {
        let i = root.beds.indexOf(bed);
        if (i === -1) return;
        let next = root.beds.slice();
        next.splice(i, 1);
        root.beds = next;
    }

    function bedFor(screenName) {
        let fallback = null;
        for (let i = 0; i < root.beds.length; i++) {
            let b = root.beds[i];
            if (!b || !b.isUsable) continue;
            if (b.screenName === screenName) return b;
            if (!fallback) fallback = b;
        }
        return fallback;
    }
}
