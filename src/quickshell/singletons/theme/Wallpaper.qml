pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    signal wallpaperChanged(string screenName, string path, string transition)
    signal playbackChanged(string screenName, string state)
    signal wallpaperCleared(string screenName)

    property var screenWallpapers: ({})
    property var screenWallpaperPaths: ({})
    property var engines: ({})

    readonly property var transitionIds: ["fade", "wipe", "circle", "swipe", "paint"]
    readonly property var transitionModes: ["random", "custom"]
    readonly property var wipeOrientations: ["random", "horizontal", "vertical"]
    readonly property var circleOrigins: ["random", "center"]
    readonly property var swipeDirections: ["left", "right", "top", "bottom", "top_left", "top_right", "bottom_left", "bottom_right"]
    readonly property var defaultTransitionSettings: ({
        "mode": "random",
        "pool": ["fade", "wipe", "circle", "swipe", "paint"],
        "effects": {
            "fade": { "duration": 1000 },
            "wipe": { "duration": 1600, "orientation": "random" },
            "circle": { "duration": 1600, "origin": "random" },
            "swipe": { "duration": 1600, "direction": "random" },
            "paint": { "duration": 2400 }
        }
    })

    function transitionSettings(): var {
        let d = root.defaultTransitionSettings;
        let s = (typeof Config !== "undefined") ? Config.getSetting("wallpaperTransition", {}) : {};
        if (!s || typeof s !== "object") s = {};
        let effects = {};
        for (let i = 0; i < root.transitionIds.length; i++) {
            let id = root.transitionIds[i];
            effects[id] = Object.assign({}, d.effects[id], (s.effects && typeof s.effects[id] === "object") ? s.effects[id] : {});
        }
        let single = s.mode === "single" && root.transitionIds.indexOf(s.type) !== -1;
        let pool = single ? [s.type] : (Array.isArray(s.pool) ? s.pool.filter(id => root.transitionIds.indexOf(id) !== -1) : d.pool.slice());
        if (pool.length === 0) pool = d.pool.slice();
        return {
            "mode": single ? "custom" : (root.transitionModes.indexOf(s.mode) !== -1 ? s.mode : d.mode),
            "pool": pool,
            "effects": effects
        };
    }

    function resolveTransition(typeIndex: int): var {
        let s = root.transitionSettings();
        let id;
        if (typeIndex >= 0 && typeIndex < root.transitionIds.length) {
            id = root.transitionIds[typeIndex];
        } else {
            let candidates = s.mode === "custom" ? s.pool : root.transitionIds;
            id = candidates[Math.floor(Math.random() * candidates.length)];
        }
        let fx = s.effects[id];
        let duration = Number(fx.duration);
        let dirIdx = root.swipeDirections.indexOf(fx.direction);
        return {
            "type": root.transitionIds.indexOf(id),
            "duration": isNaN(duration) ? root.defaultTransitionSettings.effects[id].duration : Math.max(100, Math.min(10000, Math.round(duration))),
            "vertical": fx.orientation === "vertical" || (fx.orientation !== "horizontal" && Math.random() < 0.5),
            "direction": dirIdx >= 0 ? dirIdx : Math.floor(Math.random() * root.swipeDirections.length),
            "centered": fx.origin === "center"
        };
    }

    function registerEngine(screenName: string, engine: var): void {
        if (!screenName) return;
        let map = Object.assign({}, root.engines);
        map[screenName] = engine;
        root.engines = map;
    }

    function unregisterEngine(screenName: string, engine: var): void {
        if (!screenName || root.engines[screenName] !== engine) return;
        let map = Object.assign({}, root.engines);
        delete map[screenName];
        root.engines = map;
    }

    function setWallpaper(screenName: string, path: string, transition: string): void {
        root.wallpaperChanged(screenName, path, transition ? transition : "fade");
    }

    function getWallpaper(screenName: string): string {
        if (!screenName || screenName === "") {
            let keys = Object.keys(root.screenWallpapers);
            return keys.length > 0 ? root.screenWallpapers[keys[0]] : "";
        }
        return root.screenWallpapers[screenName] || "";
    }

    function getWallpaperPath(screenName: string): string {
        if (!screenName || screenName === "") {
            let keys = Object.keys(root.screenWallpaperPaths);
            return keys.length > 0 ? root.screenWallpaperPaths[keys[0]] : "";
        }
        return root.screenWallpaperPaths[screenName] || "";
    }

    function setPlayback(screenName: string, state: string): void {
        root.playbackChanged(screenName, state);
    }

    function clearWallpaper(screenName: string): void {
        root.wallpaperCleared(screenName);
    }

    function shuffle(screenName: string, transition: string): void {
        let scrName = screenName || "all";
        let dir = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers");
        let script =
            "[ -d \"$1\" ] && find -L \"$1\" -maxdepth 1 -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" -o -iname \"*.bmp\" -o -iname \"*.mp4\" -o -iname \"*.mkv\" -o -iname \"*.mov\" -o -iname \"*.webm\" \\) 2>/dev/null | shuf -n 1";
        shuffleProcess.targetScreenName = scrName;
        shuffleProcess.transition = transition || "";
        shuffleProcess.command = ["bash", "-c", script, "shuffle", dir];
        shuffleProcess.running = false;
        shuffleProcess.running = true;
    }

    Process {
        id: shuffleProcess
        running: false
        property string targetScreenName: ""
        property string transition: ""

        stdout: StdioCollector {
            onStreamFinished: {
                let picked = this.text.trim();
                if (picked !== "") root.setWallpaper(shuffleProcess.targetScreenName, picked, shuffleProcess.transition);
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function setWallpaper(screenName: string, path: string, transition: string): void {
            root.setWallpaper(screenName, path, transition);
        }

        function getWallpaper(screenName: string): string {
            return root.getWallpaper(screenName);
        }

        function getWallpaperPath(screenName: string): string {
            return root.getWallpaperPath(screenName);
        }

        function setPlayback(screenName: string, state: string): void {
            root.setPlayback(screenName, state);
        }

        function clearWallpaper(screenName: string): void {
            root.clearWallpaper(screenName);
        }
    }
}
