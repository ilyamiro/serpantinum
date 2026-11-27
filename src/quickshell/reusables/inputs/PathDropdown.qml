import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"

Dropdown {
    id: pathRoot
    isPathSelector: false
    allowCustomValue: true

    property var _externalCallback: null
    property string _pendingQuery: ""

    function expandPath(raw) {
        let q = String(raw || "").trim();
        if (q.startsWith("~") && Caching.home !== "") {
            q = Caching.home + q.slice(1);
        }
        return q;
    }

    function scanPath(query) {
        _externalCallback = null;
        pathScanProcess.targetQuery = expandPath(query);
        pathScanProcess.running = false;
        pathScanProcess.running = true;
    }

    function scanPathFor(query, callback) {
        _externalCallback = callback;
        pathScanProcess.targetQuery = expandPath(query);
        pathScanProcess.running = false;
        pathScanProcess.running = true;
    }

    function scheduleScanFor(query, callback) {
        _externalCallback = callback;
        _pendingQuery = query;
        pathScanTimer.restart();
    }

    onEditingStarted: {
        if (pathRoot.currentValue) {
            pathRoot.scanPath(pathRoot.currentValue);
        }
    }

    onSearchChanged: function(txt) {
        if (pathRoot.isEditing && txt.length > 0) {
            _externalCallback = null;
            _pendingQuery = txt;
            pathScanTimer.restart();
        }
    }

    onCustomAccepted: function(rawText) {
        let expanded = expandPath(rawText);
        if (expanded !== "") {
            pathRoot.selectOrInsertOption(expanded);
        }
    }

    Timer {
        id: pathScanTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (pathRoot._externalCallback) {
                if (pathRoot._pendingQuery.length > 0) {
                    pathRoot.scanPathFor(pathRoot._pendingQuery, pathRoot._externalCallback);
                }
            } else if (pathRoot.isEditing && pathRoot.searchText.length > 0) {
                pathRoot.scanPath(pathRoot.searchText);
            }
        }
    }

    Process {
        id: pathScanProcess
        property string targetQuery: ""
        running: false
        command: {
            let pyScript =
                "import os, sys\n" +
                "home = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else os.path.expanduser('~')\n" +
                "pics = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else os.path.join(home, 'Pictures')\n" +
                "q = sys.argv[1].strip()\n" +
                "exts = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.mp4', '.mkv', '.mov', '.webm'}\n" +
                "dirs = set()\n" +
                "base = q if os.path.isdir(q) else (os.path.dirname(q) if (os.path.isabs(q) and os.path.exists(os.path.dirname(q))) else '')\n" +
                "search_roots = []\n" +
                "if base and os.path.isdir(base):\n" +
                "    search_roots.append(base)\n" +
                "else:\n" +
                "    search_roots = [home, pics, os.path.join(home, 'Wallpapers'), os.path.join(home, 'Videos'), '/usr/share/backgrounds', '/usr/share/wallpapers']\n" +
                "for r in search_roots:\n" +
                "    if not os.path.isdir(r): continue\n" +
                "    dirs.add(r)\n" +
                "    for root_dir, subdirs, files in os.walk(r, followlinks=True):\n" +
                "        depth = root_dir[len(r):].count(os.sep)\n" +
                "        if depth > 3:\n" +
                "            subdirs[:] = []\n" +
                "            continue\n" +
                "        subdirs[:] = [d for d in subdirs if not d.startswith('.')]\n" +
                "        if any(os.path.splitext(f)[1].lower() in exts for f in files) or (q and q.lower() in root_dir.lower()):\n" +
                "            dirs.add(root_dir)\n" +
                "for d in sorted(list(dirs), key=lambda x: (x.count(os.sep), x.lower()))[:60]:\n" +
                "    print(d)\n";
            return ["python3", "-c", pyScript, targetQuery, Caching.home, Caching.xdgPicturesDir];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
                if (lines.length > 0) {
                    if (pathRoot._externalCallback) {
                        let cb = pathRoot._externalCallback;
                        cb(lines);
                    } else {
                        pathRoot.mergeOptions(lines);
                    }
                }
            }
        }
    }
}
