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

    property bool ready: false
    property bool inRebuild: false
    property string lastScreen: ""

    function schedule() {
        if (ready) Qt.callLater(rebuild);
    }

    onRectsChanged: schedule()
    onScreenRectsChanged: schedule()
    onEdgesChanged: schedule()
    onOffsetChanged: schedule()
    onFilletRadiusChanged: schedule()
    onAttachToChanged: schedule()
    onPublishShapeChanged: schedule()
    onKindChanged: schedule()
    onVisibleChanged: schedule()
    onLiveChanged: schedule()
    onOriginXChanged: schedule()
    onOriginYChanged: schedule()

    onScreenNameChanged: {
        if (lastScreen !== "") SurfaceField.withdraw(lastScreen, surfaceId);
        lastScreen = screenName;
        schedule();
    }

    Connections {
        target: SurfaceField
        function onRevisionChanged() { if (!root.inRebuild) root.schedule(); }
    }

    Connections {
        target: root.hostWindow
        ignoreUnknownSignals: true
        function onWidthChanged() { root.schedule(); }
        function onHeightChanged() { root.schedule(); }
    }

    Connections {
        target: root.hostScreen
        ignoreUnknownSignals: true
        function onWidthChanged() { root.schedule(); }
        function onHeightChanged() { root.schedule(); }
    }

    Component.onCompleted: {
        ready = true;
        lastScreen = screenName;
        rebuild();
    }

    Component.onDestruction: {
        ready = false;
        SurfaceField.withdraw(screenName, surfaceId);
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

    function buildShapes(ox, oy) {
        const out = [];
        for (let i = 0; i < rects.length; i++) {
            const r = rects[i];
            if (!r || !(r.w > 0 && r.h > 0)) continue;
            const radii = r.r || [0, 0, 0, 0];
            out.push({ x: r.x + ox + offset.x, y: r.y + oy + offset.y, w: r.w, h: r.h, r: [radii[0], radii[1], radii[2], radii[3]], k: filletRadius });
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

    function buildQuad(shapes, ox, oy, k) {
        if (!live || shapes.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
        const g = Math.ceil(k) + 1;
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (let i = 0; i < shapes.length; i++) {
            const s = shapes[i];
            x0 = Math.min(x0, s.x - g);
            y0 = Math.min(y0, s.y - g);
            x1 = Math.max(x1, s.x + s.w + g);
            y1 = Math.max(y1, s.y + s.h + g);
        }
        if (hostWindow) {
            x0 = Math.max(x0, ox);
            y0 = Math.max(y0, oy);
            x1 = Math.min(x1, ox + hostWindow.width);
            y1 = Math.min(y1, oy + hostWindow.height);
        }
        x0 = Math.floor(x0);
        y0 = Math.floor(y0);
        x1 = Math.ceil(x1);
        y1 = Math.ceil(y1);
        return { x: x0, y: y0, w: Math.max(0, x1 - x0), h: Math.max(0, y1 - y0) };
    }

    function shapeNear(s, k, others) {
        let maxR = 0;
        for (let i = 0; i < 4; i++) maxR = Math.max(maxR, s.r[i]);
        const g = 2 * k + maxR;
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        let any = false;
        for (let i = 0; i < others.length; i++) {
            const o = others[i];
            const c = clipShape(s, o.x - g, o.y - g, o.x + o.w + g, o.y + o.h + g);
            if (!c) continue;
            any = true;
            x0 = Math.min(x0, c.x);
            y0 = Math.min(y0, c.y);
            x1 = Math.max(x1, c.x + c.w);
            y1 = Math.max(y1, c.y + c.h);
        }
        if (!any) return s;
        return clipShape(s, x0, y0, x1, y1) || s;
    }

    function flattenTouching(s, others) {
        const px = [s.x, s.x + s.w, s.x + s.w, s.x];
        const py = [s.y, s.y, s.y + s.h, s.y + s.h];
        for (let c = 0; c < 4; c++) {
            if (!(s.r[c] > 0)) continue;
            for (let i = 0; i < others.length; i++) {
                const o = others[i];
                if (px[c] >= o.x - 0.5 && px[c] <= o.x + o.w + 0.5 && py[c] >= o.y - 0.5 && py[c] <= o.y + o.h + 0.5) {
                    s.r[c] = 0;
                    break;
                }
            }
        }
    }

    function putV4(name, a, b, c, d) {
        const v = root[name];
        if (v.x !== a || v.y !== b || v.z !== c || v.w !== d) root[name] = Qt.vector4d(a, b, c, d);
    }

    function rebuild() {
        if (!ready) return;
        inRebuild = true;

        const ox = originX;
        const oy = originY;
        const shapes = buildShapes(ox, oy);
        const isLive = live;

        const owners = [];
        const dependents = [];
        if (isLive) {
            const all = SurfaceField.shapesOn(screenName);
            for (const id in all) {
                if (id === surfaceId) continue;
                const e = all[id];
                if (attachTo.indexOf(e.kind) !== -1) owners.push(e);
                else if (e.attachTo && e.attachTo.indexOf(kind) !== -1) dependents.push(e);
            }
        }

        let k = filletRadius;
        for (let i = 0; i < owners.length; i++) k = Math.max(k, owners[i].smoothing || 0);

        const neighbours = owners.concat(dependents);
        for (let i = 0; i < shapes.length; i++) flattenTouching(shapes[i], neighbours);

        const q = buildQuad(shapes, ox, oy, k);

        const slots = shapes.slice(0, 6);
        const roles = slots.map(() => 0);
        let maxR = 0;
        for (let i = 0; i < neighbours.length; i++) maxR = Math.max(maxR, neighbours[i].r[0], neighbours[i].r[1], neighbours[i].r[2], neighbours[i].r[3]);
        let kAll = k;
        for (let i = 0; i < dependents.length; i++) kAll = Math.max(kAll, dependents[i].smoothing || 0);
        const g = 2 * kAll + maxR;
        for (let i = 0; i < neighbours.length && slots.length < 6; i++) {
            const c = clipShape(neighbours[i], q.x - g, q.y - g, q.x + q.w + g, q.y + q.h + g);
            if (!c) continue;
            slots.push(c);
            roles.push(i < owners.length ? 1 : 2);
        }

        const nx = q.x - ox - offset.x;
        const ny = q.y - oy - offset.y;
        if (x !== nx) x = nx;
        if (y !== ny) y = ny;
        if (width !== q.w) width = q.w;
        if (height !== q.h) height = q.h;
        if (itemSize.x !== q.w || itemSize.y !== q.h) itemSize = Qt.vector2d(q.w, q.h);
        if (origin.x !== q.x || origin.y !== q.y) origin = Qt.vector2d(q.x, q.y);
        if (smoothing !== k) smoothing = k;

        const ks = [0, 0, 0, 0, 0, 0];
        const os = [0, 0, 0, 0, 0, 0];
        for (let i = 0; i < 6; i++) {
            const s = slots[i];
            if (s) {
                putV4("s" + i, s.x, s.y, s.w, s.h);
                putV4("r" + i, s.r[0], s.r[1], s.r[2], s.r[3]);
                ks[i] = s.k || 0;
                os[i] = roles[i];
            } else {
                putV4("s" + i, 0, 0, 0, 0);
                putV4("r" + i, 0, 0, 0, 0);
            }
        }
        putV4("k0", ks[0], ks[1], ks[2], ks[3]);
        putV4("k1", ks[4], ks[5], 0, 0);
        putV4("o0", os[0], os[1], os[2], os[3]);
        putV4("o1", os[4], os[5], 0, 0);

        if (publishShape && isLive && shapes.length > 0) {
            const v = shapeNear(shapes[0], k, owners);
            SurfaceField.publish(screenName, surfaceId, { kind: kind, attachTo: attachTo, smoothing: filletRadius, x: v.x, y: v.y, w: v.w, h: v.h, r: v.r });
        } else {
            SurfaceField.withdraw(screenName, surfaceId);
        }

        inRebuild = false;
    }

    property vector2d itemSize: Qt.vector2d(0, 0)
    property vector2d origin: Qt.vector2d(0, 0)
    property real smoothing: 0
    property real dpr: Screen.devicePixelRatio
    property vector4d s0: Qt.vector4d(0, 0, 0, 0)
    property vector4d s1: Qt.vector4d(0, 0, 0, 0)
    property vector4d s2: Qt.vector4d(0, 0, 0, 0)
    property vector4d s3: Qt.vector4d(0, 0, 0, 0)
    property vector4d s4: Qt.vector4d(0, 0, 0, 0)
    property vector4d s5: Qt.vector4d(0, 0, 0, 0)
    property vector4d r0: Qt.vector4d(0, 0, 0, 0)
    property vector4d r1: Qt.vector4d(0, 0, 0, 0)
    property vector4d r2: Qt.vector4d(0, 0, 0, 0)
    property vector4d r3: Qt.vector4d(0, 0, 0, 0)
    property vector4d r4: Qt.vector4d(0, 0, 0, 0)
    property vector4d r5: Qt.vector4d(0, 0, 0, 0)
    property vector4d k0: Qt.vector4d(0, 0, 0, 0)
    property vector4d k1: Qt.vector4d(0, 0, 0, 0)
    property vector4d o0: Qt.vector4d(0, 0, 0, 0)
    property vector4d o1: Qt.vector4d(0, 0, 0, 0)

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
        property vector4d o0: root.o0
        property vector4d o1: root.o1
        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/surface_field.frag.qsb"
    }
}
