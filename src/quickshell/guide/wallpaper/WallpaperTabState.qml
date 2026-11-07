import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"

GuideTab {
    id: wallpaperTabRoot
    subTabIndex: 1

    property alias wallpaperDirScanner: wallpaperDirScanner

    property string currentWallpaperDir: Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property var availableWallpaperDirs: []

    property alias currentWallpaperPath: currentWallpaper.path
    property alias wallpaperRevision: currentWallpaper.revision
    property alias isWallpaperVideo: currentWallpaper.isVideo

    property var transition: Wallpaper.transitionSettings()

    CurrentWallpaper {
        id: currentWallpaper
        wallpaperDir: wallpaperTabRoot.currentWallpaperDir
    }

    function effect(id) {
        return wallpaperTabRoot.transition.effects[id] || ({});
    }

    function transitionName(id) {
        return I18n.t("guide.theme.wallpaper.transition." + id + ".name");
    }

    function isInRotation(id) {
        let t = wallpaperTabRoot.transition;
        return t.mode !== "custom" || t.pool.indexOf(id) !== -1;
    }

    function saveTransition(next) {
        wallpaperTabRoot.transition = next;
        Config.setSetting("wallpaperTransition", next);
    }

    function updateTransition(key, value) {
        if (JSON.stringify(wallpaperTabRoot.transition[key]) === JSON.stringify(value)) return;
        let next = JSON.parse(JSON.stringify(wallpaperTabRoot.transition));
        next[key] = value;
        saveTransition(next);
    }

    function updateEffect(id, key, value) {
        if (wallpaperTabRoot.effect(id)[key] === value) return;
        let next = JSON.parse(JSON.stringify(wallpaperTabRoot.transition));
        next.effects[id][key] = value;
        saveTransition(next);
    }

    function pickTransition(id) {
        let t = wallpaperTabRoot.transition;
        if (t.mode !== "custom") return;
        let pool = t.pool.slice();
        let idx = pool.indexOf(id);
        if (idx === -1) {
            pool.push(id);
        } else if (pool.length > 1) {
            pool.splice(idx, 1);
        } else {
            return;
        }
        updateTransition("pool", Wallpaper.transitionIds.filter(x => pool.indexOf(x) !== -1));
    }

    function updateWallpaperDirSetting() {
        Config.setSetting("wallpaperDir", wallpaperTabRoot.currentWallpaperDir);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            wallpaperTabRoot.transition = Wallpaper.transitionSettings();
            let wpDir = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "");
            if (wpDir && wpDir !== "") {
                wallpaperTabRoot.currentWallpaperDir = wpDir;
            }
        }
    }

    Process {
        id: wallpaperDirScanner
        running: false
        command: [
            "bash", "-c",
            "python3 -c '\n" +
            "import os\n" +
            "home = os.path.expanduser(\"~\")\n" +
            "exts = {\".jpg\", \".jpeg\", \".png\", \".webp\", \".bmp\", \".mp4\", \".mkv\", \".mov\", \".webm\"}\n" +
            "dirs = set()\n" +
            "candidates = [\n" +
            "    os.path.join(home, \"Pictures\"),\n" +
            "    os.path.join(home, \"Pictures\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Videos\"),\n" +
            "    os.path.join(home, \"Videos\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \".local/share/wallpapers\"),\n" +
            "    \"/usr/share/backgrounds\",\n" +
            "    \"/usr/share/wallpapers\"\n" +
            "]\n" +
            "for c in candidates:\n" +
            "    if not os.path.isdir(c):\n" +
            "        continue\n" +
            "    dirs.add(c)\n" +
            "    for root, subdirs, files in os.walk(c, followlinks=True):\n" +
            "        depth = root[len(c):].count(os.sep)\n" +
            "        if depth > 3:\n" +
            "            subdirs[:] = []\n" +
            "            continue\n" +
            "        subdirs[:] = [d for d in subdirs if not d.startswith(\".\")]\n" +
            "        if any(os.path.splitext(f)[1].lower() in exts for f in files):\n" +
            "            dirs.add(root)\n" +
            "sorted_dirs = sorted(list(dirs), key=lambda x: (x.count(os.sep), x.lower()))\n" +
            "print(\"\\n\".join(sorted_dirs))\n" +
            "'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                if (wallpaperTabRoot.currentWallpaperDir && lines.indexOf(wallpaperTabRoot.currentWallpaperDir) === -1) {
                    lines.unshift(wallpaperTabRoot.currentWallpaperDir);
                }
                wallpaperTabRoot.availableWallpaperDirs = lines;
            }
        }
    }

    Timer {
        id: activateDebounceTimer
        interval: 220
        repeat: false
        onTriggered: {
            wallpaperDirScanner.running = false;
            wallpaperDirScanner.running = true;
            currentWallpaper.refresh();
        }
    }

    onVisibleChanged: {
        if (visible) activateDebounceTimer.restart();
        else activateDebounceTimer.stop();
    }

    Component.onCompleted: {
        if (visible) activateDebounceTimer.restart();
    }
}
