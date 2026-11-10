import QtQuick
import QtQuick.Window
import Quickshell
import "../../"
import "../"

Item {
    id: root

    property var rects: []
    property var screenRects: []
    property var edges: []
    property point offset: Qt.point(0, 0)
    property string kind: ""
    property var attachTo: []
    property bool publishShape: false
    property rect band: Qt.rect(0, 0, 0, 0)
    property real filletRadius: 0
    property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
    property bool blur: true
    property string surfaceId: kind + ":" + Math.random().toString(36).slice(2)

    readonly property var hostWindow: QsWindow.window
    readonly property var hostScreen: hostWindow ? hostWindow.screen : null
    readonly property string screenName: hostScreen && hostScreen.name ? hostScreen.name : ""
    readonly property bool live: visible && screenName !== "" && rects.length > 0

    readonly property real originX: {
        const w = hostWindow;
        const scr = hostScreen;
        if (!w || !scr || !w.anchors) return 0;
        const a = w.anchors;
        const m = w.margins;
        if (a.left) return m.left;
        if (a.right) return scr.width - w.width - m.right;
        return (scr.width - w.width) / 2;
    }

    readonly property real originY: {
        const w = hostWindow;
        const scr = hostScreen;
        if (!w || !scr || !w.anchors) return 0;
        const a = w.anchors;
        const m = w.margins;
        if (a.top) return m.top;
        if (a.bottom) return scr.height - w.height - m.bottom;
        return (scr.height - w.height) / 2;
    }

    function toScreen(r) {
        const radii = r.r || [0, 0, 0, 0];
        return { x: r.x + originX + offset.x, y: r.y + originY + offset.y, w: r.w, h: r.h, r: [radii[0], radii[1], radii[2], radii[3]], k: filletRadius };
    }

    readonly property var localShapes: {
        const out = [];
        for (let i = 0; i < rects.length; i++) {
            const r = rects[i];
            if (r && r.w > 0 && r.h > 0) out.push(toScreen(r));
        }
        if (hostScreen) {
            const W = hostScreen.width;
            const H = hostScreen.height;
            for (let i = 0; i < edges.length; i++) {
                const e = edges[i];
                if (e === "top") out.push({ x: -10000, y: -10000, w: W + 20000, h: 10000, r: [0, 0, 0, 0], k: filletRadius });
                else if (e === "bottom") out.push({ x: -10000, y: H, w: W + 20000, h: 10000, r: [0, 0, 0, 0], k: filletRadius });
                else if (e === "left") out.push({ x: -10000, y: -10000, w: 10000, h: H + 20000, r: [0, 0, 0, 0], k: filletRadius });
                else if (e === "right") out.push({ x: W, y: -10000, w: 10000, h: H + 20000, r: [0, 0, 0, 0], k: filletRadius });
            }
        }
        for (let i = 0; i < screenRects.length; i++) {
            const r = screenRects[i];
            if (r && r.w > 0 && r.h > 0) out.push({ x: r.x, y: r.y, w: r.w, h: r.h, r: r.r || [0, 0, 0, 0], k: filletRadius });
        }
        return out;
    }

    readonly property var screenBand: band.width > 0 && band.height > 0
        ? { x: band.x + originX + offset.x, y: band.y + originY + offset.y, w: band.width, h: band.height }
        : null

    readonly property var publishedShape: {
        if (!publishShape || !live || localShapes.length === 0) return null;
        const s = localShapes[0];
        return { kind: kind, attachTo: attachTo, smoothing: filletRadius, x: s.x, y: s.y, w: s.w, h: s.h, r: s.r };
    }

    onPublishedShapeChanged: {
        if (publishedShape) SurfaceField.publish(screenName, surfaceId, publishedShape);
        else SurfaceField.withdraw(screenName, surfaceId);
    }

    onScreenBandChanged: syncBand()
    onLiveChanged: syncBand()

    function syncBand() {
        if (live && screenBand) SurfaceField.claimBand(screenName, surfaceId, screenBand);
        else SurfaceField.releaseBand(screenName, surfaceId);
    }

    property string lastScreen: ""
    onScreenNameChanged: {
        if (lastScreen !== "") {
            SurfaceField.withdraw(lastScreen, surfaceId);
            SurfaceField.releaseBand(lastScreen, surfaceId);
        }
        lastScreen = screenName;
        if (publishedShape) SurfaceField.publish(screenName, surfaceId, publishedShape);
        syncBand();
    }

    Component.onDestruction: {
        SurfaceField.withdraw(screenName, surfaceId);
        SurfaceField.releaseBand(screenName, surfaceId);
    }

    readonly property var neighbours: {
        if (!live || (!publishShape && attachTo.length === 0)) return [];
        const rev = SurfaceField.revision;
        const all = SurfaceField.shapesOn(screenName);
        const out = [];
        for (const id in all) {
            if (id === surfaceId) continue;
            const e = all[id];
            const wanted = attachTo.indexOf(e.kind) !== -1 || (e.attachTo && e.attachTo.indexOf(kind) !== -1);
            if (wanted) out.push(e);
        }
        return out;
    }

    readonly property real k: {
        let v = filletRadius;
        for (let i = 0; i < neighbours.length; i++) v = Math.max(v, neighbours[i].smoothing || 0);
        return v;
    }

    readonly property var quad: {
        if (!live || localShapes.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
        const g = Math.ceil(k) + 1;
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (let i = 0; i < localShapes.length; i++) {
            const s = localShapes[i];
            x0 = Math.min(x0, s.x - g);
            y0 = Math.min(y0, s.y - g);
            x1 = Math.max(x1, s.x + s.w + g);
            y1 = Math.max(y1, s.y + s.h + g);
        }
        if (screenBand) {
            x0 = screenBand.x;
            y0 = screenBand.y;
            x1 = screenBand.x + screenBand.w;
            y1 = screenBand.y + screenBand.h;
        }
        if (hostWindow) {
            x0 = Math.max(x0, originX);
            y0 = Math.max(y0, originY);
            x1 = Math.min(x1, originX + hostWindow.width);
            y1 = Math.min(y1, originY + hostWindow.height);
        }
        x0 = Math.floor(x0);
        y0 = Math.floor(y0);
        x1 = Math.ceil(x1);
        y1 = Math.ceil(y1);
        return { x: x0, y: y0, w: Math.max(0, x1 - x0), h: Math.max(0, y1 - y0) };
    }

    function clipShape(s, x0, y0, x1, y1) {
        const cx0 = Math.max(s.x, x0);
        const cy0 = Math.max(s.y, y0);
        const cx1 = Math.min(s.x + s.w, x1);
        const cy1 = Math.min(s.y + s.h, y1);
        if (cx1 <= cx0 || cy1 <= cy0) return null;
        const l = cx0 > s.x, t = cy0 > s.y, r = cx1 < s.x + s.w, b = cy1 < s.y + s.h;
        return {
            x: cx0, y: cy0, w: cx1 - cx0, h: cy1 - cy0,
            r: [(l || t) ? 0 : s.r[0], (r || t) ? 0 : s.r[1], (r || b) ? 0 : s.r[2], (l || b) ? 0 : s.r[3]],
            k: s.smoothing || 0
        };
    }

    readonly property var slots: {
        const out = localShapes.slice(0, 6);
        let maxR = 0;
        for (let i = 0; i < neighbours.length; i++) maxR = Math.max(maxR, neighbours[i].r[0], neighbours[i].r[1], neighbours[i].r[2], neighbours[i].r[3]);
        const g = 2 * k + maxR;
        const q = quad;
        for (let i = 0; i < neighbours.length && out.length < 6; i++) {
            const c = clipShape(neighbours[i], q.x - g, q.y - g, q.x + q.w + g, q.y + q.h + g);
            if (c) out.push(c);
        }
        return out;
    }

    readonly property var holes: {
        const rev = SurfaceField.bandRevision;
        const out = [];
        if (!live) return out;
        const all = SurfaceField.bandsOn(screenName);
        const q = quad;
        for (const id in all) {
            if (id === surfaceId || out.length >= 2) continue;
            const b = all[id];
            if (b.x < q.x + q.w && b.x + b.w > q.x && b.y < q.y + q.h && b.y + b.h > q.y) out.push(b);
        }
        return out;
    }

    function slotRect(i) {
        const s = slots[i];
        return s ? Qt.vector4d(s.x, s.y, s.w, s.h) : Qt.vector4d(0, 0, 0, 0);
    }

    function slotRadii(i) {
        const s = slots[i];
        return s ? Qt.vector4d(s.r[0], s.r[1], s.r[2], s.r[3]) : Qt.vector4d(0, 0, 0, 0);
    }

    function slotK(i) {
        const s = slots[i];
        return s ? (s.k || 0) : 0;
    }

    function holeRect(i) {
        const h = holes[i];
        return h ? Qt.vector4d(h.x, h.y, h.w, h.h) : Qt.vector4d(0, 0, 0, 0);
    }

    x: quad.x - originX - offset.x
    y: quad.y - originY - offset.y
    width: quad.w
    height: quad.h

    property vector2d itemSize: Qt.vector2d(width, height)
    property vector2d origin: Qt.vector2d(quad.x, quad.y)
    readonly property real smoothing: k
    property real dpr: Screen.devicePixelRatio
    property vector4d hole0: holeRect(0)
    property vector4d hole1: holeRect(1)
    property vector4d s0: slotRect(0)
    property vector4d s1: slotRect(1)
    property vector4d s2: slotRect(2)
    property vector4d s3: slotRect(3)
    property vector4d s4: slotRect(4)
    property vector4d s5: slotRect(5)
    property vector4d r0: slotRadii(0)
    property vector4d r1: slotRadii(1)
    property vector4d r2: slotRadii(2)
    property vector4d r3: slotRadii(3)
    property vector4d r4: slotRadii(4)
    property vector4d r5: slotRadii(5)
    property vector4d k0: Qt.vector4d(slotK(0), slotK(1), slotK(2), slotK(3))
    property vector4d k1: Qt.vector4d(slotK(4), slotK(5), 0, 0)

    readonly property Item backdrop: fieldBlur

    WallpaperBlur {
        id: fieldBlur
        anchors.fill: parent
        standalone: true
        radius: 0
        field: root
        surfaceEnabled: root.blur
    }

    ShaderEffect {
        anchors.fill: parent
        property color color: root.color
        property vector2d itemSize: root.itemSize
        property vector2d origin: root.origin
        property real smoothing: root.smoothing
        property real dpr: root.dpr
        property vector4d hole0: root.hole0
        property vector4d hole1: root.hole1
        property vector4d s0: root.s0
        property vector4d s1: root.s1
        property vector4d s2: root.s2
        property vector4d s3: root.s3
        property vector4d s4: root.s4
        property vector4d s5: root.s5
        property vector4d r0: root.r0
        property vector4d r1: root.r1
        property vector4d r2: root.r2
        property vector4d r3: root.r3
        property vector4d r4: root.r4
        property vector4d r5: root.r5
        property vector4d k0: root.k0
        property vector4d k1: root.k1
        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/surface_field.frag.qsb"
    }
}
