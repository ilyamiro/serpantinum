pragma Singleton
import QtQuick
import Quickshell
import "AppMatcherInternal.js" as Internal

Item {
    id: root

    signal indexChanged()

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

    function resolveIcon(ic) {
        if (!ic) return "";
        let s = String(ic).trim();
        if (s === "") return "";
        if (s.startsWith("file://") || s.startsWith("http://") || s.startsWith("https://")) return s;
        if (s.startsWith("image://") && !s.startsWith("image://icon/")) return s;
        if (s.startsWith("/")) return "file://" + s;

        let name = s.startsWith("image://icon/") ? s.substring(13) : s;
        let baseName = name.replace(/\.(png|svg|xpm|ico)$/i, "");
        let candidates = [baseName];
        if (name !== baseName) candidates.push(name);
        if (baseName.endsWith("-symbolic")) {
            candidates.push(baseName.substring(0, baseName.length - 9));
        }

        if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
            for (let i = 0; i < candidates.length; i++) {
                let resolved = Quickshell.iconPath(candidates[i], true);
                if (resolved && resolved.length > 0) {
                    return resolved.startsWith("/") ? ("file://" + resolved) : resolved;
                }
            }
            return "";
        }
        return "image://icon/" + baseName;
    }

    Component.onCompleted: {
        rebuild();
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined") ? DesktopEntries : null
        function onApplicationsChanged() {
            Internal.markDirty();
            root.indexChanged();
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            Internal.markDirty();
            root.indexChanged();
        }
    }
}
