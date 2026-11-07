import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property string screenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""
    property string wallpaperDir: Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property string path: ""
    property int revision: 0
    readonly property bool isVideo: {
        let lp = path.toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm") || lp.indexOf("000_") !== -1;
    }

    function refresh() {
        wallFetcher.running = false;
        wallFetcher.running = true;
    }

    Timer {
        id: snapshotDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.revision++
    }

    FileView {
        path: root.screenName !== "" ? (Caching.getCacheDir("wallpaper") + "/current_" + root.screenName) : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let res = text().trim();
            if (res !== "" && res !== root.path) {
                root.path = res;
                root.revision++;
            }
        }
    }

    FileView {
        path: Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"
        watchChanges: true
        onFileChanged: snapshotDebounceTimer.restart()
        onLoaded: snapshotDebounceTimer.restart()
    }

    Process {
        id: wallFetcher
        running: false
        command: {
            let current = root.screenName ? (Wallpaper.getWallpaperPath(root.screenName) || Wallpaper.getWallpaper(root.screenName)) : "";
            let curDir = root.wallpaperDir || "";
            let pyScript =
                "import os, sys\n" +
                "home = os.path.expanduser('~')\n" +
                "val = sys.argv[1]\n" +
                "cur_dir = sys.argv[2]\n" +
                "if not val:\n" +
                "    print('')\n" +
                "    sys.exit(0)\n" +
                "if os.path.isabs(val) and os.path.exists(val):\n" +
                "    print(val)\n" +
                "    sys.exit(0)\n" +
                "candidates = []\n" +
                "if cur_dir and os.path.isdir(cur_dir):\n" +
                "    candidates.append(cur_dir)\n" +
                "candidates.extend([\n" +
                "    os.path.join(home, 'Pictures', 'Wallpapers'),\n" +
                "    os.path.join(home, 'Wallpapers'),\n" +
                "    os.path.join(home, 'Pictures'),\n" +
                "    os.path.join(home, 'Videos'),\n" +
                "    os.path.join(home, 'Videos', 'Wallpapers'),\n" +
                "    os.path.join(home, '.local/share/wallpapers'),\n" +
                "    '/usr/share/backgrounds',\n" +
                "    '/usr/share/wallpapers'\n" +
                "])\n" +
                "base_name = os.path.basename(val)\n" +
                "found = ''\n" +
                "for d in candidates:\n" +
                "    target = os.path.join(d, base_name)\n" +
                "    if os.path.isfile(target):\n" +
                "        found = target\n" +
                "        break\n" +
                "if not found:\n" +
                "    for root_dir in [os.path.join(home, 'Pictures'), os.path.join(home, 'Wallpapers'), '/usr/share/backgrounds']:\n" +
                "        if os.path.isdir(root_dir):\n" +
                "            for root, dirs, files in os.walk(root_dir):\n" +
                "                if base_name in files:\n" +
                "                    found = os.path.join(root, base_name)\n" +
                "                    break\n" +
                "            if found:\n" +
                "                break\n" +
                "if not found:\n" +
                "    found = os.path.join(cur_dir, val) if cur_dir else val\n" +
                "print(found)\n";
            return ["python3", "-c", pyScript, current, curDir];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let res = this.text.trim();
                if (res !== "" && res !== root.path) {
                    root.path = res;
                    root.revision++;
                }
            }
        }
    }
}
