pragma Singleton
import QtQuick
import "../../"

QtObject {
    id: root

    property var windows: ({})
    property int windowsRevision: 0
    signal windowChanged(string screenName, string kind)

    property var shapes: ({})
    property int revision: 0
    signal screenShapesChanged(string screenName, string kind)

    function extractWindow(entry) {
        if (!entry) return null;
        return (entry.window !== undefined && entry.window !== null) ? entry.window : entry;
    }

    function registerWindow(kind, screenName, window) {
        if (!kind || !screenName || !window) return;
        const bucket = root.windows[kind];
        if (bucket && bucket[screenName] === window) return;
        const next = Object.assign({}, root.windows);
        next[kind] = Object.assign({}, bucket || {});
        next[kind][screenName] = window;
        root.windows = next;
        root.windowsRevision++;
        root.windowChanged(screenName, kind);
    }

    function unregisterWindow(kind, screenName, window) {
        if (!kind) return;
        const bucket = root.windows[kind];
        if (!bucket) return;
        let removedScreen = "";
        const nextBucket = Object.assign({}, bucket);
        if (screenName && nextBucket[screenName] !== undefined && (window === undefined || nextBucket[screenName] === window || extractWindow(nextBucket[screenName]) === window)) {
            delete nextBucket[screenName];
            removedScreen = screenName;
        } else if (window !== undefined) {
            for (const key in nextBucket) {
                if (nextBucket[key] === window || extractWindow(nextBucket[key]) === window) {
                    delete nextBucket[key];
                    removedScreen = key;
                    break;
                }
            }
        }
        if (!removedScreen) return;
        const next = Object.assign({}, root.windows);
        next[kind] = nextBucket;
        root.windows = next;
        root.windowsRevision++;
        root.windowChanged(removedScreen, kind);
    }

    function windowOf(kind, screenName) {
        const rev = root.windowsRevision;
        if (!kind || !screenName || rev < 0) return null;
        const bucket = root.windows[kind];
        if (!bucket || bucket[screenName] === undefined) return null;
        return extractWindow(bucket[screenName]);
    }

    function windowsOf(kind) {
        const rev = root.windowsRevision;
        if (!kind || rev < 0) return [];
        const bucket = root.windows[kind];
        if (!bucket) return [];
        const out = [];
        for (const key in bucket) {
            const w = extractWindow(bucket[key]);
            if (w) out.push(w);
        }
        return out;
    }

    function arraysEqual(a, b) {
        if (a === b) return true;
        if (!Array.isArray(a) || !Array.isArray(b)) return false;
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false;
        }
        return true;
    }

    function shapesEqual(a, b) {
        if (a === b) return true;
        if (!a || !b || typeof a !== "object" || typeof b !== "object") return false;
        if (a.kind !== b.kind
                || a.x !== b.x
                || a.y !== b.y
                || a.w !== b.w
                || a.h !== b.h
                || a.width !== b.width
                || a.height !== b.height
                || a.smoothing !== b.smoothing
                || a.radius !== b.radius
                || a.edge !== b.edge
                || a.visible !== b.visible) {
            return false;
        }
        if (!arraysEqual(a.r, b.r)) return false;
        if (!arraysEqual(a.attachTo, b.attachTo)) return false;
        const keysA = Object.keys(a);
        const keysB = Object.keys(b);
        if (keysA.length !== keysB.length) return false;
        for (let i = 0; i < keysA.length; i++) {
            const k = keysA[i];
            if (k === "kind" || k === "x" || k === "y" || k === "w" || k === "h"
                    || k === "width" || k === "height" || k === "smoothing"
                    || k === "radius" || k === "edge" || k === "visible"
                    || k === "r" || k === "attachTo") {
                continue;
            }
            if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
            const va = a[k];
            const vb = b[k];
            if (Array.isArray(va) || Array.isArray(vb)) {
                if (!arraysEqual(va, vb)) return false;
            } else if (va !== vb) {
                return false;
            }
        }
        return true;
    }

    function publishShape(screenName, id, shape) {
        if (!screenName || !id) return;
        const bucket = root.shapes[screenName];
        const cur = bucket ? bucket[id] : undefined;
        if (cur !== undefined && shapesEqual(cur, shape)) return;
        const next = Object.assign({}, root.shapes);
        next[screenName] = Object.assign({}, bucket || {});
        next[screenName][id] = shape;
        root.shapes = next;
        root.revision++;
        root.screenShapesChanged(screenName, shape && shape.kind ? String(shape.kind) : "");
    }

    function withdrawShape(screenName, id) {
        if (!screenName || !id) return;
        const bucket = root.shapes[screenName];
        if (!bucket || bucket[id] === undefined) return;
        const oldKind = (bucket[id] && bucket[id].kind) ? String(bucket[id].kind) : "";
        const next = Object.assign({}, root.shapes);
        next[screenName] = Object.assign({}, bucket);
        delete next[screenName][id];
        root.shapes = next;
        root.revision++;
        root.screenShapesChanged(screenName, oldKind);
    }

    function shapesOn(screenName) {
        if (!screenName) return ({});
        return root.shapes[screenName] || ({});
    }

    readonly property var barSettings: (Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({})

    readonly property string barPosition: (barSettings && barSettings.position !== undefined && barSettings.position !== "") ? String(barSettings.position) : "top"

    readonly property bool isSideBar: barPosition === "left" || barPosition === "right"

    readonly property bool barAutohide: (barSettings && barSettings.autohide !== undefined) ? Boolean(barSettings.autohide) : false

    readonly property string barStyle: {
        if (!barSettings || barSettings.style === undefined) return "modular";
        const st = barSettings.style;
        if (typeof st === "string") return st;
        if (st && typeof st === "object") {
            if (st.fill || st.mode === "fill") return "fill";
            if (st.solid || st.mode === "solid") return "solid";
        }
        return "modular";
    }

    readonly property bool isSolidBar: barStyle === "solid"
    readonly property bool isFillBar: barStyle === "fill"

    readonly property int barRawHeight: {
        let v = (barSettings && barSettings.height !== undefined) ? Number(barSettings.height) : 40;
        if (isNaN(v)) v = 40;
        return Math.round(Math.max(28, Math.min(48, v)));
    }

    readonly property real barThicknessRatio: barRawHeight / 40.0
    readonly property int barThickness: Math.round(48 * barThicknessRatio)
    readonly property int barInset: Math.round(barRawHeight) + (isSolidBar && !barAutohide ? 4 : 0)

    function isBarEnabledOnScreen(screen) {
        return Config.isBarEnabledOnScreen(screen);
    }

    function barSpanOn(screenName) {
        const win = windowOf("bars", screenName);
        if (!win) return { minX: 0, maxX: 0, minY: 0, maxY: 0, valid: false };
        const ox = (win.margins && win.margins.left !== undefined) ? win.margins.left : 0;
        const oy = (win.margins && win.margins.top !== undefined) ? win.margins.top : 0;
        const rawMinX = win.currentBarMinX !== undefined ? win.currentBarMinX : 0;
        const rawMaxX = win.currentBarMaxX !== undefined ? win.currentBarMaxX : 0;
        const rawMinY = win.currentBarMinY !== undefined ? win.currentBarMinY : 0;
        const rawMaxY = win.currentBarMaxY !== undefined ? win.currentBarMaxY : 0;
        const minX = ox + rawMinX;
        const maxX = ox + rawMaxX;
        const minY = oy + rawMinY;
        const maxY = oy + rawMaxY;
        const vertical = win.isVertical !== undefined ? Boolean(win.isVertical) : root.isSideBar;
        const valid = vertical ? (maxY > minY) : (maxX > minX);
        return { minX: minX, maxX: maxX, minY: minY, maxY: maxY, valid: valid };
    }

    function windowOrigin(win, scr) {
        if (!win || !scr || !win.anchors) return Qt.point(0, 0);
        const a = win.anchors;
        const m = win.margins;
        const wx = a.left ? m.left : (a.right ? (scr.width - win.width - m.right) : ((scr.width - win.width) * 0.5));
        const wy = a.top ? m.top : (a.bottom ? (scr.height - win.height - m.bottom) : ((scr.height - win.height) * 0.5));
        return Qt.point(wx, wy);
    }

    function fitToBar(pos, size, spanStart, spanEnd, screenSize, edgeMargin, barEndRadius, cornerRadius, isSolid) {
        const margin = edgeMargin !== undefined ? edgeMargin : 0;
        const lo = margin;
        const hi = Math.max(lo, screenSize - size - margin);
        const solid = isSolid !== undefined ? Boolean(isSolid) : (root.isSolidBar || root.isFillBar);
        const hasSpan = spanEnd > spanStart;
        const endR = barEndRadius !== undefined ? barEndRadius : 0;
        const cornerR = cornerRadius !== undefined ? cornerRadius : 0;
        const inset = endR + cornerR;
        if (solid && hasSpan && cornerR > 0.5 && size <= (spanEnd - spanStart - 2 * inset)) {
            return Math.max(spanStart + inset, Math.min(spanEnd - inset - size, pos));
        }
        if (!solid || !hasSpan) return Math.max(lo, Math.min(hi, pos));
        let p = pos;
        if (p + size > spanEnd - endR && p + size < spanEnd) p = spanEnd - size;
        if (p > spanStart && p < spanStart + endR) p = spanStart;
        return Math.max(lo, Math.min(hi, p));
    }

    function surfaceRect(x, y, w, h, scaleX, scaleY, originX, originY, radii) {
        const sx = scaleX !== undefined ? scaleX : 1;
        const sy = scaleY !== undefined ? scaleY : sx;
        const ox = originX !== undefined ? originX : (w * 0.5);
        const oy = originY !== undefined ? originY : (h * 0.5);
        const rs = (sx + sy) * 0.5;
        const r = Array.isArray(radii) && radii.length === 4
            ? [radii[0] * rs, radii[1] * rs, radii[2] * rs, radii[3] * rs]
            : [0, 0, 0, 0];
        return {
            x: x + ox * (1 - sx),
            y: y + oy * (1 - sy),
            w: w * sx,
            h: h * sy,
            r: r
        };
    }

    function itemSurfaceRect(item, box) {
        if (!item) return { x: 0, y: 0, w: 0, h: 0, r: [0, 0, 0, 0] };
        const sc = item.scale;
        let ox = item.width * 0.5;
        let oy = item.height * 0.5;
        const o = item.transformOrigin;
        if (o === Item.Top || o === Item.TopLeft || o === Item.TopRight) oy = 0;
        else if (o === Item.Bottom || o === Item.BottomLeft || o === Item.BottomRight) oy = item.height;
        if (o === Item.Left || o === Item.TopLeft || o === Item.BottomLeft) ox = 0;
        else if (o === Item.Right || o === Item.TopRight || o === Item.BottomRight) ox = item.width;
        const radii = box
            ? [box.topLeftRadius || 0, box.topRightRadius || 0, box.bottomRightRadius || 0, box.bottomLeftRadius || 0]
            : [0, 0, 0, 0];
        return surfaceRect(item.x, item.y, item.width, item.height, sc, sc, ox, oy, radii);
    }

    function dockAvoidance(screen) {
        const screenName = (typeof screen === "string") ? screen : (screen && screen.name ? screen.name : "");
        const win = screenName ? windowOf("docks", screenName) : null;
        const dockCfg = (Config.rawSettings && Config.rawSettings.dock) ? Config.rawSettings.dock : ({});
        const enabled = win && win.dockEnabled !== undefined ? Boolean(win.dockEnabled) : (dockCfg.enabled !== undefined ? Boolean(dockCfg.enabled) : true);
        const position = win && win.dockPosition ? String(win.dockPosition) : (dockCfg.position ? String(dockCfg.position) : "bottom");
        const autohide = win && win.autohide !== undefined ? Boolean(win.autohide) : (dockCfg.autohide !== undefined ? Boolean(dockCfg.autohide) : false);
        const elementSize = dockCfg.elementSize !== undefined ? Number(dockCfg.elementSize) : 44;
        const vertical = position === "left" || position === "right";
        let thickness = 0;
        if (enabled && !autohide) {
            if (win && win.visible) {
                thickness = vertical ? (win.width || 0) : (win.height || 0);
            }
            if (thickness <= 0) {
                thickness = Math.round((isNaN(elementSize) ? 44 : elementSize) + 20);
            }
        }
        return {
            enabled: enabled,
            position: position,
            autohide: autohide,
            vertical: vertical,
            thickness: thickness
        };
    }

    function dockMarginFor(screen, edge) {
        const info = dockAvoidance(screen);
        if (!info.enabled || info.autohide || info.position !== edge) return 0;
        return info.thickness;
    }
}
