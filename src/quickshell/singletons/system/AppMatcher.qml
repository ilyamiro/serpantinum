pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "AppMatcherInternal.js" as Internal

Item {
    id: root

    signal indexChanged()

    property var iconCache: ({})
    property int cacheVersion: 0

    readonly property string cacheFilePath: {
        let dir = (typeof Caching !== "undefined" && Caching.cacheDir) ? Caching.cacheDir : (Quickshell.env("HOME") + "/.cache/serpantinum");
        return dir + "/icons.json";
    }

    FileView {
        id: iconCacheView
        path: root.cacheFilePath
        watchChanges: true
        onLoaded: {
            try {
                let txt = text();
                if (txt && txt.length > 2) {
                    root.iconCache = JSON.parse(txt);
                    root.cacheVersion++;
                    root.indexChanged();
                }
            } catch (e) {
                // Ignore parse errors on incomplete file writes
            }
        }
    }

    Process {
        id: indexerProc
        command: [
            "sh", "-c",
            'for p in "$1" "$2" "$3"; do if [ -n "$p" ] && [ -f "$p" ]; then exec python3 "$p" "$4"; fi; done',
            "_",
            (typeof Caching !== "undefined" && Caching.serpantinumDir ? Caching.serpantinumDir + "/scripts/icon_indexer.py" : ""),
            (Quickshell.shellDir + "/../scripts/icon_indexer.py"),
            "/usr/share/serpantinum/scripts/icon_indexer.py",
            root.cacheFilePath
        ]
        running: false
    }

    Timer {
        id: indexerDebounce
        interval: 1000
        repeat: false
        onTriggered: {
            if (!indexerProc.running) {
                indexerProc.running = true;
            }
        }
    }

    function triggerIconIndex() {
        indexerDebounce.restart();
    }

    readonly property var wrapperExecs: ["env", "sh", "bash", "zsh", "fish", "flatpak", "snap", "gtk-launch", "xdg-open", "gio", "systemd-run", "uwsm", "uwsm-app", "nix", "nix-shell", "java", "python", "python3", "wine", "electron", "dex", "sudo", "pkexec"]

    function canonicalId(id) {
        if (!id) return "";
        let s = String(id).toLowerCase().trim();
        while (s.endsWith(".desktop")) {
            s = s.slice(0, -8);
        }
        return s;
    }

    function normalizeKey(value) {
        return value ? String(value).toLowerCase().trim() : "";
    }

    function _put(map, key, id) {
        if (key && map[key] === undefined) map[key] = id;
    }

    function rebuild() {
        let entries = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values)
            ? DesktopEntries.applications.values : [];
        let byId = {};
        let idKeys = {};
        let classKeys = {};
        let execKeys = {};
        let tailKeys = {};
        let nameKeys = {};

        for (let i = 0; i < entries.length; i++) {
            let e = entries[i];
            if (!e || !e.id || e.noDisplay) continue;
            let cid = canonicalId(e.id);
            if (byId[cid] === undefined) byId[cid] = e;
            _put(idKeys, cid, cid);
            _put(classKeys, normalizeKey(e.startupClass), cid);
            let cmd = (e.command && e.command.length > 0) ? String(e.command[0]) : "";
            let base = normalizeKey(cmd.substring(cmd.lastIndexOf("/") + 1));
            if (base !== "" && wrapperExecs.indexOf(base) === -1) _put(execKeys, base, cid);
            let tail = cid.substring(cid.lastIndexOf(".") + 1);
            if (tail !== cid) _put(tailKeys, tail, cid);
            _put(nameKeys, normalizeKey(e.name), cid);
        }

        Internal.setTables(byId, Object.assign({}, nameKeys, tailKeys, execKeys, classKeys, idKeys));
    }

    function resolve(appId) {
        let key = normalizeKey(appId);
        if (key === "") return "";
        if (Internal.isDirty()) rebuild();
        let cached = Internal.getCached(key);
        if (cached !== undefined) return cached;

        let cidKey = canonicalId(key);
        let tail = cidKey.substring(cidKey.lastIndexOf(".") + 1);
        let id = Internal.lookupKey(key, cidKey, tail);
        if (id === undefined && typeof DesktopEntries !== "undefined" && typeof DesktopEntries.heuristicLookup === "function") {
            let found = DesktopEntries.heuristicLookup(String(appId));
            if (found && found.id) id = canonicalId(found.id);
        }
        if (id === undefined) {
            id = cidKey;
        }
        let out = id !== undefined ? id : "";
        return Internal.setCached(key, out);
    }

    function entry(id) {
        if (Internal.isDirty()) rebuild();
        let cid = canonicalId(id);
        return cid !== "" ? Internal.getEntry(cid) : null;
    }

    function resolveIcon(ic, _depth) {
        if (!ic) return "";
        let _ = root.cacheVersion;
        let s = String(ic).trim();
        if (s === "") return "";
        if (s.startsWith("file://") || s.startsWith("http://") || s.startsWith("https://")) return s;
        if (s.startsWith("image://") && !s.startsWith("image://icon/")) return s;
        if (s.startsWith("/")) return "file://" + s;

        let name = s.startsWith("image://icon/") ? s.substring(13) : s;
        let baseName = name.replace(/\.(png|svg|xpm|ico)$/i, "");
        let candidates = [baseName.toLowerCase()];
        if (name.toLowerCase() !== baseName.toLowerCase()) {
            candidates.push(name.toLowerCase());
        }
        if (baseName.endsWith("-symbolic")) {
            candidates.push(baseName.substring(0, baseName.length - 9).toLowerCase());
        }

        // 1. Check active Qt theme (preserves user-selected icon theme, e.g. Papirus, Adwaita)
        if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
            for (let i = 0; i < candidates.length; i++) {
                let resolved = Quickshell.iconPath(candidates[i], true);
                if (resolved && resolved.length > 0) {
                    return resolved.startsWith("/") ? ("file://" + resolved) : resolved;
                }
            }
        }

        // 2. Check cached fallback icons from standard directories (hicolor, pixmaps, etc.)
        for (let i = 0; i < candidates.length; i++) {
            let p = root.iconCache[candidates[i]];
            if (p) return "file://" + p;
        }

        // 3. If an appId was passed instead of an icon name, check matching desktop entry icon
        let depth = _depth || 0;
        if (depth < 2) {
            let ent = entry(baseName);
            if (ent && ent.icon && ent.icon !== ic && ent.icon !== baseName) {
                let fallbackRes = resolveIcon(ent.icon, depth + 1);
                if (fallbackRes && fallbackRes.length > 0) return fallbackRes;
            }
        }

        return "";
    }

    Component.onCompleted: {
        rebuild();
        triggerIconIndex();
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined") ? DesktopEntries : null
        function onApplicationsChanged() {
            Internal.markDirty();
            root.indexChanged();
            root.triggerIconIndex();
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            Internal.markDirty();
            root.indexChanged();
            root.triggerIconIndex();
        }
    }
}
