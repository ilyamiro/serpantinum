pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables/canvas"

QtObject {
    id: root

    signal redactorOpenRequested(string monitor)

    function openRedactor(monitor) {
        root.redactorOpenRequested(monitor || "");
    }

    readonly property real screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
    readonly property real screenH: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080

    readonly property real defaultPanelW: 1280
    readonly property real defaultPanelH: 566
    readonly property var legacyPanelSize: ({ w: 1280, h: 580 })
    readonly property var legacyPanelItems: [
        ["widget:weather", "full", 20, 20, 380, 182],
        ["widget:cpu", "default", 20, 210, 186, 170],
        ["widget:ram", "default", 214, 210, 186, 170],
        ["widget:temp", "default", 20, 388, 186, 170],
        ["widget:disk", "default", 214, 388, 186, 170],
        ["avatar", "round", 540, 20, 200, 200],
        ["user", "filled", 450, 236, 185, 44],
        ["lockstatus", "filled", 645, 236, 185, 44],
        ["password", "filled", 450, 288, 380, 44],
        ["keyboard", "filled", 450, 340, 185, 44],
        ["battery", "filled", 645, 340, 185, 44],
        ["fingerprint", "labeled", 640, 450, 0, 0],
        ["notifications", "card", 860, 20, 400, 440],
        ["widget:music", "full", 860, 468, 400, 92]
    ]

    readonly property real noFingerprintShift: 69
    property bool fingerprintSupported: true

    property real panelW: root.defaultPanelW
    property real panelH: root.defaultPanelH
    property real panelX: -1
    property real panelOpacity: 1.0
    property real refW: 1920
    property real refH: 1080
    property real panelY: -1
    property ListModel screenItems: ListModel { dynamicRoles: true }
    property ListModel panelItems: ListModel { dynamicRoles: true }

    property int revision: 0
    property bool applying: false
    property bool loaded: false
    property bool historyActive: false

    readonly property string stateDir: Caching.getStateDir("lockscreen")
    readonly property string filePath: root.stateDir + "/layout.json"

    readonly property var standardKeys: ["iid", "itype", "ivariant", "ix", "iy", "iw", "ih", "iopacity", "irotation", "iimage"]

    function modelFor(scope) {
        return scope === "panel" ? root.panelItems : root.screenItems;
    }

    function newId() {
        return "i_" + Date.now() + "_" + Math.floor(Math.random() * 100000);
    }

    function makeEntry(type, variant, x, y, w, h) {
        let entry = {
            iid: root.newId(),
            itype: type,
            ivariant: variant || LockElementRegistry.defaultVariant(type),
            ix: x,
            iy: y,
            iw: w,
            ih: h,
            iopacity: 1.0,
            irotation: 0,
            iimage: ""
        };
        let t = LockElementRegistry.types[type];
        if (t && t.defaults) {
            for (let k in t.defaults) entry[k] = t.defaults[k];
        }
        return entry;
    }

    function defaultScreenItems() {
        return [
            root.makeEntry("clock", "lockscreen", root.screenW * 0.5 - 210, root.screenH * 0.36 - 100, 420, 200),
            root.makeEntry("fingerprint", "classic", root.screenW * 0.5, root.screenH * 0.92, 0, 0)
        ];
    }

    function defaultPanelItems(supported) {
        let hasFingerprint = supported === undefined ? root.fingerprintSupported : supported;
        let dy = hasFingerprint ? 0 : root.noFingerprintShift;
        return [
            root.makeEntry("widget:weather", "full", 20, 20, 380, 190),
            root.makeEntry("widget:cpu", "default", 20, 218, 186, 160),
            root.makeEntry("widget:ram", "default", 214, 218, 186, 160),
            root.makeEntry("widget:temp", "default", 20, 386, 186, 160),
            root.makeEntry("widget:disk", "default", 214, 386, 186, 160),
            root.makeEntry("avatar", "round", 540, 20 + dy, 200, 200),
            root.makeEntry("user", "filled", 450, 236 + dy, 185, 44),
            root.makeEntry("lockstatus", "filled", 645, 236 + dy, 185, 44),
            root.makeEntry("password", "filled", 450, 288 + dy, 380, 44),
            root.makeEntry("keyboard", "button", 600, 364 + dy, 0, 0),
            root.makeEntry("battery", "button", 685, 364 + dy, 0, 0),
            root.makeEntry("fingerprint", "classic", 640, 450, 0, 0),
            root.makeEntry("notifications", "card", 860, 20, 400, 422),
            root.makeEntry("widget:music", "full", 860, 450, 400, 96)
        ];
    }

    function panelMatchesDefaults(supported) {
        let defaults = root.defaultPanelItems(supported);
        if (root.panelItems.count !== defaults.length) return false;
        for (let i = 0; i < defaults.length; i++) {
            let e = root.panelItems.get(i);
            let d = defaults[i];
            if (e.itype !== d.itype || e.ivariant !== d.ivariant || Math.round(e.ix) !== d.ix || Math.round(e.iy) !== d.iy) return false;
        }
        return true;
    }

    function setFingerprintSupported(supported) {
        if (supported === root.fingerprintSupported) return;
        let followsDefaults = root.panelMatchesDefaults(root.fingerprintSupported) && root.panelW === root.defaultPanelW && root.panelH === root.defaultPanelH;
        root.fingerprintSupported = supported;
        if (!followsDefaults) return;
        root.applying = true;
        root.fill(root.panelItems, root.defaultPanelItems());
        root.applying = false;
        root.revision++;
    }

    function setPanelOpacity(value) {
        root.panelOpacity = Math.max(0, Math.min(1, value));
        root.touch();
    }

    function setReference(w, h) {
        if (w <= 0 || h <= 0 || (w === root.refW && h === root.refH)) return;
        let fx = w / root.refW;
        let fy = h / root.refH;
        let f = Math.min(fx, fy);
        let m = root.screenItems;
        for (let i = 0; i < m.count; i++) {
            let e = m.get(i);
            m.setProperty(i, "ix", e.ix * fx);
            m.setProperty(i, "iy", e.iy * fy);
            if (e.iw > 0 && e.ih > 0) {
                m.setProperty(i, "iw", e.iw * f);
                m.setProperty(i, "ih", e.ih * f);
            }
        }
        root.refW = w;
        root.refH = h;
        root.touch();
    }

    function ensureRequired(scope) {
        let reqTypes = LockElementRegistry.requiredTypes(scope);
        let m = root.modelFor(scope);
        let containerW = scope === "panel" ? root.panelW : root.refW;
        let containerH = scope === "panel" ? root.panelH : root.refH;
        for (let r = 0; r < reqTypes.length; r++) {
            let typeId = reqTypes[r];
            let present = false;
            for (let i = 0; i < m.count; i++) {
                if (m.get(i).itype === typeId) {
                    present = true;
                    break;
                }
            }
            if (!present) {
                let def = LockElementRegistry.defaultSize(typeId);
                let w = def.w;
                let h = def.h;
                let x = Math.max(0, (containerW - w) / 2);
                let y = Math.max(0, containerH - h - 20);
                m.append(root.makeEntry(typeId, LockElementRegistry.defaultVariant(typeId), x, y, w, h));
            }
        }
    }

    function fill(model, list) {
        model.clear();
        for (let i = 0; i < list.length; i++) model.append(list[i]);
    }

    function touch() {
        root.revision++;
        if (root.applying) return;
        saveTimer.restart();
        if (root.historyActive) historyStore.scheduleCommit();
    }

    function beginHistory() {
        root.historyActive = true;
        historyStore.clear();
        historyBaseline.restart();
    }

    function endHistory() {
        historyBaseline.stop();
        root.historyActive = false;
        historyStore.clear();
    }

    function commitHistory() {
        historyStore.commit();
    }

    function undo() {
        historyStore.undo();
    }

    function redo() {
        historyStore.redo();
    }

    function findItem(id) {
        let scopes = ["screen", "panel"];
        for (let s = 0; s < scopes.length; s++) {
            let m = root.modelFor(scopes[s]);
            for (let i = 0; i < m.count; i++) {
                if (m.get(i).iid === id) return { scope: scopes[s], index: i };
            }
        }
        return null;
    }

    function addItem(scope, entry) {
        root.modelFor(scope).append(entry);
        root.touch();
        return entry.iid;
    }

    function removeItem(id) {
        let f = root.findItem(id);
        if (!f) return;
        root.modelFor(f.scope).remove(f.index, 1);
        root.touch();
    }

    function setItemProperty(id, prop, value) {
        let f = root.findItem(id);
        if (!f) return;
        root.modelFor(f.scope).setProperty(f.index, prop, value);
        root.touch();
    }

    function clearScope(scope) {
        let m = root.modelFor(scope);
        for (let i = m.count - 1; i >= 0; i--) {
            if (LockElementRegistry.isDeletable(m.get(i).itype)) m.remove(i, 1);
        }
        root.touch();
    }

    function resetScope(scope) {
        root.applying = true;
        if (scope === "panel") {
            root.panelW = root.defaultPanelW;
            root.panelH = root.defaultPanelH;
            root.panelX = -1;
            root.panelY = -1;
            root.panelOpacity = 1.0;
            root.fill(root.panelItems, root.defaultPanelItems());
        } else {
            root.fill(root.screenItems, root.defaultScreenItems());
        }
        root.applying = false;
        root.touch();
    }

    function setPanelRect(x, y, w, h) {
        root.panelX = x;
        root.panelY = y;
        root.panelW = w;
        root.panelH = h;
        root.touch();
    }

    function applyDefaults() {
        root.applying = true;
        root.panelW = root.defaultPanelW;
        root.panelH = root.defaultPanelH;
        root.panelX = -1;
        root.panelY = -1;
        root.panelOpacity = 1.0;
        root.refW = root.screenW;
        root.refH = root.screenH;
        root.fill(root.screenItems, root.defaultScreenItems());
        root.fill(root.panelItems, root.defaultPanelItems());
        root.applying = false;
        root.revision++;
    }

    function rowToJson(row) {
        let o = {};
        for (let k in row) {
            if (!k || typeof k !== "string") continue;
            if (k === "objectName" || k.endsWith("Changed") || k.startsWith("on") || typeof row[k] === "function" || row[k] === undefined) continue;
            o[k] = row[k];
        }
        return o;
    }

    function modelToJson(model) {
        let out = [];
        for (let i = 0; i < model.count; i++) out.push(root.rowToJson(model.get(i)));
        return out;
    }

    function toData() {
        return {
            version: 3,
            ref: { w: root.refW, h: root.refH },
            panel: { x: root.panelX, y: root.panelY, w: root.panelW, h: root.panelH, opacity: root.panelOpacity },
            screen: root.modelToJson(root.screenItems),
            items: root.modelToJson(root.panelItems)
        };
    }

    function serialize() {
        return JSON.stringify(root.toData(), null, 2);
    }

    function sanitize(raw, scope) {
        if (!raw || !LockElementRegistry.hasType(raw.itype) || !LockElementRegistry.allowedIn(raw.itype, scope)) return null;
        let n = function(v, d) { let x = Number(v); return isNaN(x) ? d : x; };
        let e = {};
        for (let k in raw) e[k] = raw[k];
        e.iid = raw.iid ? String(raw.iid) : root.newId();
        let variant = LockElementRegistry.normalizeVariant(raw.itype, raw.ivariant);
        e.ivariant = LockElementRegistry.hasVariant(raw.itype, variant) ? variant : LockElementRegistry.defaultVariant(raw.itype);
        e.ix = n(raw.ix, 0);
        e.iy = n(raw.iy, 0);
        e.iw = Math.max(0, n(raw.iw, 0));
        e.ih = Math.max(0, n(raw.ih, 0));
        LockElementRegistry.migrateEntry(raw, e);
        if (variant !== raw.ivariant && LockElementRegistry.isScaled(raw.itype) && e.iw > 0 && e.ih > 0) {
            e.ix += e.iw / 2;
            e.iy += e.ih / 2;
            e.iw = 0;
            e.ih = 0;
        }
        if (scope === "panel") {
            e.iw = Math.min(e.iw, root.panelW);
            e.ih = Math.min(e.ih, root.panelH);
            e.ix = Math.max(0, Math.min(e.ix, Math.max(0, root.panelW - e.iw)));
            e.iy = Math.max(0, Math.min(e.iy, Math.max(0, root.panelH - e.ih)));
        }
        e.iopacity = Math.max(0, Math.min(1, n(raw.iopacity, 1)));
        e.irotation = ((Math.round(n(raw.irotation, 0)) % 360) + 360) % 360;
        e.iimage = raw.iimage ? String(raw.iimage) : "";
        return e;
    }

    function loadList(scope, list) {
        let m = root.modelFor(scope);
        m.clear();
        let seen = {};
        for (let i = 0; i < list.length; i++) {
            let e = root.sanitize(list[i], scope);
            if (!e || seen[e.iid]) continue;
            seen[e.iid] = true;
            m.append(e);
        }
    }

    function isLegacyPanel(data) {
        let p = data.panel || {};
        let list = Array.isArray(data.items) ? data.items : [];
        let legacy = root.legacyPanelItems;
        if (Number(p.w) !== root.legacyPanelSize.w || Number(p.h) !== root.legacyPanelSize.h) return false;
        if (list.length !== legacy.length) return false;
        for (let i = 0; i < legacy.length; i++) {
            let e = list[i] || {};
            let l = legacy[i];
            if (e.itype !== l[0] || e.ivariant !== l[1]) return false;
            if (Math.round(Number(e.ix)) !== l[2] || Math.round(Number(e.iy)) !== l[3]) return false;
            if (Math.round(Number(e.iw)) !== l[4] || Math.round(Number(e.ih)) !== l[5]) return false;
        }
        return true;
    }

    function applyData(data) {
        if (!data || typeof data !== "object" || data.version !== 3) return false;

        root.applying = true;
        let p = data.panel || {};
        let legacy = root.isLegacyPanel(data);
        root.panelW = legacy ? root.defaultPanelW : Math.max(240, Number(p.w) || root.defaultPanelW);
        root.panelH = legacy ? root.defaultPanelH : Math.max(160, Number(p.h) || root.defaultPanelH);
        root.panelOpacity = p.opacity !== undefined ? Math.max(0, Math.min(1, Number(p.opacity))) : 1.0;
        let r = data.ref || {};
        root.refW = Number(r.w) > 0 ? Number(r.w) : root.screenW;
        root.refH = Number(r.h) > 0 ? Number(r.h) : root.screenH;
        root.panelX = p.x !== undefined && Number(p.x) >= 0 ? Number(p.x) : -1;
        root.panelY = p.y !== undefined && Number(p.y) >= 0 ? Number(p.y) : -1;
        root.loadList("screen", Array.isArray(data.screen) ? data.screen : []);
        if (legacy) root.fill(root.panelItems, root.defaultPanelItems());
        else root.loadList("panel", Array.isArray(data.items) ? data.items : []);
        root.ensureRequired("screen");
        root.ensureRequired("panel");
        root.applying = false;
        root.revision++;
        return true;
    }

    function applyText(text) {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return false;
        }
        return root.applyData(data);
    }

    function saveNow() {
        saveTimer.stop();
        stateFile.save(root.toData());
    }

    function flush() {
        if (saveTimer.running) root.saveNow();
    }

    property HistoryStack historyStore: HistoryStack {
        maxEntries: 100
        debounceMs: 600
        enabled: root.historyActive
        snapshotFn: () => root.serialize()
        restoreFn: (text) => {
            if (!root.applyText(text)) return false;
            let normalized = root.serialize();
            root.touch();
            return normalized;
        }
    }

    property Timer historyBaseline: Timer {
        interval: 800
        repeat: false
        onTriggered: historyStore.reset()
    }

    property Process fingerprintProbe: Process {
        command: ["serpantinum-core", "system", "fingerprint"]
        running: true
        onExited: (exitCode) => root.setFingerprintSupported(exitCode === 0)
    }

    property Timer saveTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.saveNow()
    }

    property JsonStateFile stateFile: JsonStateFile {
        path: root.filePath
        watchChanges: true
        printErrors: false
        onLoaded: (data) => {
            if (data === null) {
                if (!root.loaded) root.applyDefaults();
            } else if (!root.applyData(data) && !root.loaded) {
                root.applyDefaults();
            }
            root.loaded = true;
        }
        onLoadFailed: {
            if (!root.loaded) root.applyDefaults();
            root.loaded = true;
        }
    }

    Component.onCompleted: root.applyDefaults()
}
