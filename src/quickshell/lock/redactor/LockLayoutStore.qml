pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../widgets"

QtObject {
    id: root

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
    property string lastWrittenText: ""

    property var historyStack: []
    property int historyIndex: -1
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
        return {
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
    }

    function defaultScreenItems() {
        return [
            root.makeEntry("clock", "lockscreen", root.screenW * 0.5 - 210, root.screenH * 0.36 - 100, 420, 200),
            root.makeEntry("fingerprint", "classic", root.screenW * 0.5, root.screenH * 0.92, 0, 0)
        ];
    }

    function defaultPanelItems() {
        return [
            root.makeEntry("widget:weather", "full", 20, 20, 380, 190),
            root.makeEntry("widget:cpu", "default", 20, 218, 186, 160),
            root.makeEntry("widget:ram", "default", 214, 218, 186, 160),
            root.makeEntry("widget:temp", "default", 20, 386, 186, 160),
            root.makeEntry("widget:disk", "default", 214, 386, 186, 160),
            root.makeEntry("avatar", "round", 540, 20, 200, 200),
            root.makeEntry("user", "filled", 450, 236, 185, 44),
            root.makeEntry("lockstatus", "filled", 645, 236, 185, 44),
            root.makeEntry("password", "filled", 450, 288, 380, 44),
            root.makeEntry("keyboard", "button", 600, 364, 0, 0),
            root.makeEntry("battery", "button", 685, 364, 0, 0),
            root.makeEntry("fingerprint", "classic", 640, 450, 0, 0),
            root.makeEntry("notifications", "card", 860, 20, 400, 422),
            root.makeEntry("widget:music", "full", 860, 450, 400, 96)
        ];
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

    function ensurePassword() {
        for (let i = 0; i < root.panelItems.count; i++) {
            if (root.panelItems.get(i).itype === "password") return;
        }
        root.panelItems.append(root.makeEntry("password", "filled", Math.max(0, (root.panelW - 380) / 2), Math.max(0, root.panelH - 64), 380, 44));
    }

    function fill(model, list) {
        model.clear();
        for (let i = 0; i < list.length; i++) model.append(list[i]);
    }

    function touch() {
        root.revision++;
        if (root.applying) return;
        saveTimer.restart();
        if (root.historyActive) historyTimer.restart();
    }

    function beginHistory() {
        root.historyActive = true;
        root.historyStack = [];
        root.historyIndex = -1;
        historyTimer.stop();
        historyBaseline.restart();
    }

    function endHistory() {
        historyBaseline.stop();
        historyTimer.stop();
        root.historyActive = false;
        root.historyStack = [];
        root.historyIndex = -1;
    }

    function commitHistory() {
        historyTimer.stop();
        if (!root.historyActive || root.historyIndex < 0) return;
        let text = root.serialize();
        if (root.historyStack[root.historyIndex] === text) return;
        let stack = root.historyStack.slice(0, root.historyIndex + 1);
        stack.push(text);
        if (stack.length > 100) stack.shift();
        root.historyStack = stack;
        root.historyIndex = stack.length - 1;
    }

    function stepHistory(delta) {
        root.commitHistory();
        let target = root.historyIndex + delta;
        if (!root.historyActive || target < 0 || target >= root.historyStack.length) return;
        if (!root.applyText(root.historyStack[target])) return;
        let stack = root.historyStack.slice();
        stack[target] = root.serialize();
        root.historyStack = stack;
        root.historyIndex = target;
        root.touch();
    }

    function undo() {
        root.stepHistory(-1);
    }

    function redo() {
        root.stepHistory(1);
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
            if (k.endsWith("Changed") || k.startsWith("on") || typeof row[k] === "function" || row[k] === undefined) continue;
            o[k] = row[k];
        }
        return o;
    }

    function modelToJson(model) {
        let out = [];
        for (let i = 0; i < model.count; i++) out.push(root.rowToJson(model.get(i)));
        return out;
    }

    function serialize() {
        return JSON.stringify({
            version: 3,
            ref: { w: root.refW, h: root.refH },
            panel: { x: root.panelX, y: root.panelY, w: root.panelW, h: root.panelH, opacity: root.panelOpacity },
            screen: root.modelToJson(root.screenItems),
            items: root.modelToJson(root.panelItems)
        }, null, 2);
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
        if (raw.itype === "clock" && e.iw <= 0) {
            let cs = LockElementRegistry.defaultSize("clock");
            e.ix -= cs.w / 2;
            e.iy -= cs.h / 2;
            e.iw = cs.w;
            e.ih = cs.h;
        }
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
        if (raw.itype === "fingerprint") e.showText = raw.ivariant === "icon" ? false : raw.showText !== false;
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

    function applyText(text) {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return false;
        }
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
        root.ensurePassword();
        root.applying = false;
        root.revision++;
        return true;
    }

    function saveNow() {
        saveTimer.stop();
        let text = root.serialize();
        root.lastWrittenText = text;
        Quickshell.execDetached([
            "bash", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/layout.json.tmp\" && mv \"$1/layout.json.tmp\" \"$1/layout.json\"",
            "bash", root.stateDir, text
        ]);
    }

    function flush() {
        if (saveTimer.running) root.saveNow();
    }

    function reloadFromDisk(text) {
        let trimmed = String(text || "").trim();
        if (trimmed === "") {
            if (!root.loaded) root.applyDefaults();
            return;
        }
        if (trimmed === root.lastWrittenText.trim()) return;
        if (!root.applyText(trimmed) && !root.loaded) root.applyDefaults();
    }

    property Timer historyTimer: Timer {
        interval: 600
        repeat: false
        onTriggered: root.commitHistory()
    }

    property Timer historyBaseline: Timer {
        interval: 800
        repeat: false
        onTriggered: {
            root.historyStack = [root.serialize()];
            root.historyIndex = 0;
        }
    }

    property Timer saveTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.saveNow()
    }

    property FileView fileView: FileView {
        path: root.filePath
        watchChanges: true
        onLoaded: {
            root.reloadFromDisk(fileView.text());
            root.loaded = true;
        }
        onFileChanged: fileView.reload()
        onLoadFailed: {
            if (!root.loaded) root.applyDefaults();
            root.loaded = true;
        }
    }

    Component.onCompleted: root.applyDefaults()
}
