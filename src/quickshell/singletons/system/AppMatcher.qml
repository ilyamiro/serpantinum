pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    function iconCandidates(appId) {
        let out = [];
        let push = function(value) {
            let v = String(value === undefined || value === null ? "" : value).trim();
            if (v === "" || out.indexOf(v) !== -1) return;
            out.push(v);
        };

        let key = normalizeKey(appId);
        if (key === "") return out;

        let cid = canonicalId(key);
        push(cid);
        let tail = cid.substring(cid.lastIndexOf(".") + 1);
        push(tail);

        // Window classes are not always icon names: "Minecraft* 1.21.1",
        // "Steam (1)", "org.example.App [2]". Try the cleaned variants too.
        let plain = key.replace(/[()\[\]{}*]/g, " ").replace(/\s+/g, " ").trim();
        push(plain);
        push(plain.split(" ")[0]);
        push(plain.replace(/\s+\d[\d.]*$/, ""));
        return out;
    }

    function iconSource(appId, hint) {
        let direct = String(hint === undefined || hint === null ? "" : hint).trim();
        let cacheKey = normalizeKey(appId) + "|" + direct;
        // Reading _iconCache here also makes bindings re-evaluate when the
        // index or the desktop entries load, so placeholders get replaced.
        let cache = root._iconCache;
        if (root._iconIndexReady && cache[cacheKey] !== undefined) return cache[cacheKey];

        let candidates = [];
        let push = function(value) {
            let v = String(value === undefined || value === null ? "" : value).trim();
            if (v === "" || candidates.indexOf(v) !== -1) return;
            candidates.push(v);
        };

        if (direct !== "") {
            if (direct.startsWith("file://") || direct.startsWith("image://")
                    || direct.startsWith("http://") || direct.startsWith("https://")) {
                return root._iconCache[cacheKey] = direct;
            }
            push(direct);
        }

        let resolvedId = resolve(appId);
        let ent = entry(resolvedId);
        if (ent && ent.icon) push(String(ent.icon));

        // Unknown windows often carry no desktop entry at all, so the window
        // class arrives as the hint. Derive candidates from it as well.
        let names = iconCandidates(appId);
        let hintNames = iconCandidates(direct);
        for (let i = 0; i < hintNames.length; i++) {
            if (names.indexOf(hintNames[i]) === -1) names.push(hintNames[i]);
        }
        for (let i = 0; i < names.length; i++) push(names[i]);

        let out = "";
        for (let i = 0; i < candidates.length; i++) {
            let name = candidates[i];
            if (name.startsWith("/")) {
                out = "file://" + name;
                break;
            }
            name = name.replace(/\.(png|svg|xpm|ico)$/i, "");
            if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
                let path = Quickshell.iconPath(name, true);
                if (path && String(path).length > 0) {
                    out = String(path);
                    if (out.startsWith("/")) out = "file://" + out;
                    break;
                }
            }
            // The icon theme lookup only sees the active theme. Fall back to
            // the index of every installed theme so an icon that exists in
            // another theme (Qogir, Papirus, ...) is still used.
            let indexed = root._iconIndex[name.toLowerCase()];
            if (indexed && indexed.path) {
                out = "file://" + indexed.path;
                break;
            }
        }

        if (out === "" && candidates.length > 0) {
            out = "image://icon/" + candidates[0].replace(/\.(png|svg|xpm|ico)$/i, "");
        }
        return root._iconCache[cacheKey] = out;
    }

    property var _iconCache: ({})
    property var _iconIndex: ({})
    property bool _iconIndexReady: false

    Process {
        id: iconIndexProc
        running: true
        command: [
            "bash", "-c",
            "find \"$HOME/.local/share/icons\" \"$HOME/.icons\" /usr/share/icons /usr/share/pixmaps "
            + "-type f \\( -iname '*.svg' -o -iname '*.png' -o -iname '*.xpm' \\) "
            + "-printf '%p\\n' 2>/dev/null | LC_ALL=C sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text || "";
                let lines = text.split("\n");
                let index = ({});
                for (let i = 0; i < lines.length; i++) {
                    let path = lines[i].trim();
                    if (path === "") continue;
                    // Only application icons are useful here: the index is a
                    // fallback for icons that the active theme does not ship.
                    if (path.indexOf("/apps/") === -1 && path.indexOf("/usr/share/pixmaps/") !== 0) continue;
                    let slash = path.lastIndexOf("/");
                    let file = slash >= 0 ? path.substring(slash + 1) : path;
                    let dot = file.lastIndexOf(".");
                    let name = (dot > 0 ? file.substring(0, dot) : file).toLowerCase();
                    if (name === "") continue;
                    let score = 0;
                    if (path.indexOf("/scalable/") !== -1) score += 2;
                    if (path.indexOf("/hicolor/") !== -1) score += 1;
                    let existing = index[name];
                    if (existing === undefined || score > existing.score) index[name] = { path: path, score: score };
                }
                root._iconIndex = index;
                root._iconIndexReady = true;
                root._iconCache = ({});
            }
        }
    }

    Component.onCompleted: {
        rebuild();
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined") ? DesktopEntries : null
        function onApplicationsChanged() {
            Internal.markDirty();
            root._iconCache = ({});
            root.indexChanged();
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            Internal.markDirty();
            root._iconCache = ({});
            root.indexChanged();
        }
    }
}
