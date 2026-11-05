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
        let cacheDir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? Caching.getCacheDir("wallpaper") : "";
        let stateFile = cacheDir ? (cacheDir + "/current_" + scrName) : "";
        let customDir = "";
        if (typeof Config !== "undefined") {
            if (Config.wallpaperDir) customDir = Config.wallpaperDir;
            else if (Config.wallpapersDir) customDir = Config.wallpapersDir;
        }
        let script =
            "STATE_FILE=\"$1\"; CUSTOM_DIR=\"$2\"; DIR=''; " +
            "if [ -n \"$CUSTOM_DIR\" ] && [ -d \"$CUSTOM_DIR\" ]; then " +
            "    DIR=\"$CUSTOM_DIR\"; " +
            "elif [ -n \"$STATE_FILE\" ] && [ -f \"$STATE_FILE\" ]; then " +
            "    CUR=$(cat \"$STATE_FILE\" 2>/dev/null); " +
            "    if [ -n \"$CUR\" ]; then " +
            "        CANDIDATE=$(dirname \"$CUR\"); " +
            "        if [ -d \"$CANDIDATE\" ]; then DIR=\"$CANDIDATE\"; fi; " +
            "    fi; " +
            "fi; " +
            "if [ -z \"$DIR\" ] || [ ! -d \"$DIR\" ]; then " +
            "    for d in \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"$HOME/Pictures\" \"${XDG_CONFIG_HOME:-$HOME/.config}/serpantinum/wallpapers\" \"/usr/share/backgrounds\"; do " +
            "        if [ -d \"$d\" ]; then DIR=\"$d\"; break; fi; " +
            "    done; " +
            "fi; " +
            "if [ -n \"$DIR\" ] && [ -d \"$DIR\" ]; then " +
            "    find -L \"$DIR\" -maxdepth 2 -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" -o -iname \"*.bmp\" -o -iname \"*.avif\" \\) 2>/dev/null | shuf -n 1; " +
            "fi";
        shuffleProcess.targetScreenName = scrName;
        shuffleProcess.transition = transition || "";
        shuffleProcess.command = ["bash", "-c", script, "shuffle", stateFile, customDir];
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
