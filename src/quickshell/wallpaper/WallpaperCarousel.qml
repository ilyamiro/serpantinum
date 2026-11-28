import QtQuick
import Quickshell.Io
import "../"

Item {
    id: root
    visible: false

    readonly property bool ready: Config.dataReady && root.stateLoaded
    readonly property bool carouselEnabled: Config.getSetting("wallpaperCarousel.enabled", false) === true
    readonly property int interval: Wallpaper.clampCarouselInterval(Config.getSetting("wallpaperCarousel.interval", Wallpaper.carouselDefaultInterval))

    property bool stateLoaded: false
    property bool active: false
    property real lastChange: 0
    property var shown: []

    onReadyChanged: root.sync()
    onCarouselEnabledChanged: root.sync()
    onIntervalChanged: root.schedule()

    function save() {
        stateFile.save({ "active": root.active, "lastChange": root.lastChange, "shown": root.shown });
    }

    function sync() {
        if (!root.ready) return;
        if (root.carouselEnabled && !root.active) {
            let current = Wallpaper.getWallpaperPath("");
            root.active = true;
            root.lastChange = Date.now();
            root.shown = current ? [current] : [];
            root.save();
        } else if (!root.carouselEnabled && root.active) {
            root.active = false;
            root.lastChange = 0;
            root.shown = [];
            root.save();
        }
        root.schedule();
    }

    function schedule() {
        tick.stop();
        if (!root.ready || !root.carouselEnabled || !root.active) return;
        let remaining = root.lastChange + root.interval * 1000 - Date.now();
        if (remaining <= 0) {
            root.advance();
            return;
        }
        tick.interval = Math.max(250, Math.min(remaining, 60000));
        tick.start();
    }

    function advance() {
        if (lister.running) return;
        lister.command = ["bash", "-c", Wallpaper.listScript, "carousel", Wallpaper.wallpaperDir];
        lister.running = true;
    }

    function pick(files) {
        let pool = files.filter(f => root.shown.indexOf(f) === -1);
        let seen = root.shown;
        if (pool.length === 0) {
            let last = seen.length > 0 ? seen[seen.length - 1] : "";
            pool = files.length > 1 ? files.filter(f => f !== last) : files;
            seen = [];
        }
        root.lastChange = Date.now();
        if (pool.length > 0) {
            let picked = pool[Math.floor(Math.random() * pool.length)];
            root.shown = seen.concat([picked]);
            Wallpaper.setWallpaper("all", picked, "");
        }
        root.save();
        root.schedule();
    }

    Timer {
        id: tick
        repeat: false
        onTriggered: root.schedule()
    }

    Process {
        id: lister
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.carouselEnabled || !root.active) return;
                root.pick(this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0));
            }
        }
    }

    JsonStateFile {
        id: stateFile
        path: Caching.getStateDir("wallpaper") + "/carousel.json"
        onLoaded: function(data) {
            if (!root.stateLoaded && data && typeof data === "object") {
                root.active = data.active === true;
                root.lastChange = Number(data.lastChange) || 0;
                root.shown = Array.isArray(data.shown) ? data.shown.filter(s => typeof s === "string") : [];
            }
            root.stateLoaded = true;
        }
        onLoadFailed: root.stateLoaded = true
    }
}
