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

    Process {
        id: remoteSync
        command: ["bash", "-c",
            'main="$1"; shift; for s in "$@"; do p="$(quickshell -p "$main" ipc call wallpaper getWallpaperPath "$s" 2>/dev/null)"; [[ "$p" == /* ]] && printf "%s\t%s\n" "$s" "$p"; done',
            "bash", Caching.mainQml].concat(Quickshell.screens.map(s => s.name))
        stdout: StdioCollector {
            onStreamFinished: {
                let map = {};
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[1] !== "") map[parts[0]] = parts[1];
                }
                if (JSON.stringify(map) !== JSON.stringify(root.screenWallpaperPaths)) {
                    root.screenWallpaperPaths = map;
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: Caching.isStandalone && Caching.mainQml !== ""
        triggeredOnStart: true
        onTriggered: if (!remoteSync.running) remoteSync.running = true
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
