import QtQuick
import "../../"
import ".."

QtObject {
    id: geometry

    property real safeWidth: 0
    property real safeHeight: 0
    property bool gridEnabled: false
    property var repeater: null
    property var guideLines: []
    property var measureLines: []
    readonly property real snapThreshold: s(12)
    readonly property bool showDistances: !(typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.showDistances === false)

    function s(val) { return Scaler.s(val); }

    function getConstraints(loaderItem) {
        if (!loaderItem) return null;
        return {
            minW: loaderItem.minWidth !== undefined ? loaderItem.minWidth : 10,
            minH: loaderItem.minHeight !== undefined ? loaderItem.minHeight : 10,
            maxW: loaderItem.maxWidth !== undefined ? loaderItem.maxWidth : 9999,
            maxH: loaderItem.maxHeight !== undefined ? loaderItem.maxHeight : 9999,
            minA: loaderItem.minAspect !== undefined ? loaderItem.minAspect : 0,
            maxA: loaderItem.maxAspect !== undefined ? loaderItem.maxAspect : 9999
        };
    }

    function clampResize(loaderItem, rawW, rawH, dx, dy, isCorner) {
        let c = getConstraints(loaderItem);
        if (!c) return { w: rawW, h: rawH };

        let w = Math.max(c.minW, Math.min(c.maxW, rawW));
        let h = Math.max(c.minH, Math.min(c.maxH, rawH));

        let hasMinA = c.minA !== undefined && c.minA > 0;
        let hasMaxA = c.maxA !== undefined && c.maxA > 0 && c.maxA < 9999;

        if (!isCorner) {
            if (dx !== 0) {
                let effMinW = Math.max(c.minW, hasMinA ? h * c.minA : c.minW);
                let effMaxW = Math.min(c.maxW, hasMaxA ? h * c.maxA : c.maxW);
                if (effMinW <= effMaxW) {
                    w = Math.max(effMinW, Math.min(effMaxW, w));
                } else {
                    w = Math.max(c.minW, Math.min(c.maxW, w));
                }
            } else {
                let effMinH = Math.max(c.minH, hasMaxA ? w / c.maxA : c.minH);
                let effMaxH = Math.min(c.maxH, hasMinA ? w / c.minA : c.maxH);
                if (effMinH <= effMaxH) {
                    h = Math.max(effMinH, Math.min(effMaxH, h));
                } else {
                    h = Math.max(c.minH, Math.min(c.maxH, h));
                }
            }
            return { w: w, h: h };
        }

        let ratio = w / h;
        if (hasMinA && ratio < c.minA) {
            let mA = c.minA;
            let hProj = (w * mA + h) / (mA * mA + 1);
            let hMin = Math.max(c.minH, c.minW / mA);
            let hMax = Math.min(c.maxH, c.maxW / mA);
            h = Math.max(hMin, Math.min(hMax, hProj));
            w = h * mA;
        } else if (hasMaxA && ratio > c.maxA) {
            let mA = c.maxA;
            let hProj = (w * mA + h) / (mA * mA + 1);
            let hMin = Math.max(c.minH, c.minW / mA);
            let hMax = Math.min(c.maxH, c.maxW / mA);
            h = Math.max(hMin, Math.min(hMax, hProj));
            w = h * mA;
        }

        w = Math.max(c.minW, Math.min(c.maxW, w));
        h = Math.max(c.minH, Math.min(c.maxH, h));

        return { w: w, h: h };
    }

    function axisKeys(axis) {
        return axis === "x"
            ? { horizontal: true, lo: "l", hi: "r", clo: "t", chi: "b", extent: safeWidth, crossExtent: safeHeight }
            : { horizontal: false, lo: "t", hi: "b", clo: "l", chi: "r", extent: safeHeight, crossExtent: safeWidth };
    }

    function boxOf(item) {
        return { l: item.x, t: item.y, r: item.x + item.width, b: item.y + item.height };
    }

    function otherBoxes(excluded) {
        let out = [];
        for (let i = 0; i < repeater.count; i++) {
            let p = repeater.itemAt(i);
            if (p && p !== excluded) out.push(boxOf(p));
        }
        return out;
    }

    function shiftBox(box, k, lo) {
        let out = { l: box.l, t: box.t, r: box.r, b: box.b };
        out[k.hi] = lo + box[k.hi] - box[k.lo];
        out[k.lo] = lo;
        return out;
    }

    function crossOverlap(a, b, k) {
        return a[k.clo] < b[k.chi] - 0.5 && a[k.chi] > b[k.clo] + 0.5;
    }

    function neighbor(box, others, k, side) {
        let best = null;
        for (let i = 0; i < others.length; i++) {
            let o = others[i];
            if (!crossOverlap(box, o, k)) continue;
            let gap = side < 0 ? box[k.lo] - o[k.hi] : o[k.lo] - box[k.hi];
            if (gap > -0.5 && (!best || gap < best.gap)) best = { box: o, gap: Math.max(0, gap) };
        }
        return best;
    }

    function gapSegment(box, others, k, side) {
        let n = neighbor(box, others, k, side);
        if (n) {
            return {
                from: side < 0 ? n.box[k.hi] : box[k.hi],
                to: side < 0 ? box[k.lo] : n.box[k.lo],
                cross: (Math.max(box[k.clo], n.box[k.clo]) + Math.min(box[k.chi], n.box[k.chi])) / 2,
                edge: false
            };
        }
        return {
            from: side < 0 ? 0 : box[k.hi],
            to: side < 0 ? box[k.lo] : k.extent,
            cross: (box[k.clo] + box[k.chi]) / 2,
            edge: true
        };
    }

    function measureShape(k, seg) {
        let length = seg.to - seg.from;
        return {
            horizontal: k.horizontal,
            x: k.horizontal ? seg.from : seg.cross,
            y: k.horizontal ? seg.cross : seg.from,
            length: length,
            value: Math.round(length)
        };
    }

    function alignmentLines(k, others) {
        let lines = [0, k.extent / 3, k.extent / 2, k.extent * 2 / 3, k.extent];
        for (let i = 0; i < others.length; i++) {
            let o = others[i];
            lines.push(o[k.lo], (o[k.lo] + o[k.hi]) / 2, o[k.hi]);
        }
        return lines;
    }

    function snapAxis(box, others, k) {
        let raw = box[k.lo];
        let size = box[k.hi] - raw;
        let best = { lo: raw, diff: snapThreshold, line: -1, refs: [] };

        let lines = alignmentLines(k, others);
        let points = [0, size / 2, size];
        for (let i = 0; i < lines.length; i++) {
            for (let j = 0; j < points.length; j++) {
                let lo = lines[i] - points[j];
                let diff = Math.abs(lo - raw);
                if (diff < best.diff) best = { lo: lo, diff: diff, line: lines[i], refs: [] };
            }
        }

        let offerSpacing = (lo, accept) => {
            let diff = Math.abs(lo - raw);
            if (diff >= best.diff) return;
            let refs = accept(shiftBox(box, k, lo));
            if (refs) best = { lo: lo, diff: diff, line: -1, refs: refs };
        };
        let isGap = (n, o, value) => n !== null && n.box === o && Math.abs(n.gap - value) < 0.5;

        let gaps = [];
        let margins = [];
        for (let i = 0; i < others.length; i++) {
            let o = others[i];
            let next = neighbor(o, others, k, 1);
            if (next && next.gap >= 1) gaps.push(gapSegment(o, others, k, 1));
            if (!next) margins.push(gapSegment(o, others, k, 1));
            if (!neighbor(o, others, k, -1)) margins.push(gapSegment(o, others, k, -1));
        }

        for (let i = 0; i < gaps.length; i++) {
            let g = gaps[i];
            let value = g.to - g.from;
            for (let j = 0; j < others.length; j++) {
                let o = others[j];
                if (!crossOverlap(box, o, k)) continue;
                offerSpacing(o[k.hi] + value, b => isGap(neighbor(b, others, k, -1), o, value) ? [measureShape(k, g)] : null);
                offerSpacing(o[k.lo] - value - size, b => isGap(neighbor(b, others, k, 1), o, value) ? [measureShape(k, g)] : null);
            }
        }

        for (let i = 0; i < margins.length; i++) {
            let m = margins[i];
            let value = m.to - m.from;
            if (value < 1) continue;
            offerSpacing(value, b => neighbor(b, others, k, -1) ? null : [measureShape(k, m), measureShape(k, gapSegment(b, others, k, -1))]);
            offerSpacing(k.extent - value - size, b => neighbor(b, others, k, 1) ? null : [measureShape(k, m), measureShape(k, gapSegment(b, others, k, 1))]);
        }

        let before = neighbor(box, others, k, -1);
        let after = neighbor(box, others, k, 1);
        if (before && after) {
            offerSpacing((before.box[k.hi] + after.box[k.lo] - size) / 2, b => {
                let nb = neighbor(b, others, k, -1);
                let na = neighbor(b, others, k, 1);
                return (nb && na && nb.box === before.box && na.box === after.box) ? [] : null;
            });
        }

        return best;
    }

    function calculateSnap(draggedItem, rawX, rawY, bypass) {
        let w = draggedItem.width;
        let h = draggedItem.height;
        let res = { x: rawX, y: rawY, lines: { x: -1, y: -1 }, refs: [] };

        if (gridEnabled) {
            let gridStep = s(20);
            res.x = Math.round(rawX / gridStep) * gridStep;
            res.y = Math.round(rawY / gridStep) * gridStep;
        } else if (!bypass) {
            let others = otherBoxes(draggedItem);
            let kx = axisKeys("x");
            let ky = axisKeys("y");
            let box = { l: rawX, t: rawY, r: rawX + w, b: rawY + h };
            let sx = snapAxis(box, others, kx);
            box = shiftBox(box, kx, sx.lo);
            let sy = snapAxis(box, others, ky);
            box = shiftBox(box, ky, sy.lo);
            res.x = box.l;
            res.y = box.t;
            res.lines = { x: sx.line, y: sy.line };
            res.refs = sx.refs.concat(sy.refs);
        }

        let mX = Math.max(0, safeWidth - w);
        let mY = Math.max(0, safeHeight - h);
        res.x = Math.max(0, Math.min(mX, res.x));
        res.y = Math.max(0, Math.min(mY, res.y));
        res.box = { l: res.x, t: res.y, r: res.x + w, b: res.y + h };

        return res;
    }

    function snapEdges(item, box, sides) {
        let others = otherBoxes(item);
        let out = { x: null, y: null };
        let axes = ["x", "y"];
        for (let a = 0; a < axes.length; a++) {
            let side = sides[axes[a]];
            if (!side) continue;
            let k = axisKeys(axes[a]);
            let edge = side < 0 ? box[k.lo] : box[k.hi];
            let lines = alignmentLines(k, others);
            let bestDiff = snapThreshold;
            for (let i = 0; i < lines.length; i++) {
                let diff = Math.abs(lines[i] - edge);
                if (diff < bestDiff) {
                    bestDiff = diff;
                    out[axes[a]] = { line: lines[i], diff: diff };
                }
            }
        }
        return out;
    }

    function guideSegment(box, others, k, line) {
        let onLine = b => Math.abs(b[k.lo] - line) < 0.5 || Math.abs((b[k.lo] + b[k.hi]) / 2 - line) < 0.5 || Math.abs(b[k.hi] - line) < 0.5;
        if (!onLine(box)) return null;

        let from = box[k.clo];
        let to = box[k.chi];
        let linked = false;
        for (let i = 0; i < others.length; i++) {
            if (!onLine(others[i])) continue;
            from = Math.min(from, others[i][k.clo]);
            to = Math.max(to, others[i][k.chi]);
            linked = true;
        }
        if (!linked) {
            from = 0;
            to = k.crossExtent;
        }

        let t = s(1);
        return k.horizontal
            ? { x: line - t / 2, y: from, w: t, h: to - from }
            : { x: from, y: line - t / 2, w: to - from, h: t };
    }

    function presentOverlay(item, box, snap) {
        let others = otherBoxes(item);
        let guides = [];
        let measures = snap ? snap.refs.slice() : [];
        let axes = ["x", "y"];
        for (let a = 0; a < axes.length; a++) {
            let k = axisKeys(axes[a]);
            let line = snap ? snap.lines[axes[a]] : -1;
            if (line >= 0) {
                let guide = guideSegment(box, others, k, line);
                if (guide) guides.push(guide);
            }
            for (let side = -1; side <= 1; side += 2) {
                let seg = gapSegment(box, others, k, side);
                if (!seg.edge && seg.to - seg.from >= 1) measures.push(measureShape(k, seg));
            }
        }
        guideLines = guides;
        measureLines = showDistances ? measures : [];
    }

    function clearOverlay() {
        if (guideLines.length > 0) guideLines = [];
        if (measureLines.length > 0) measureLines = [];
    }

    function snapBoxToGrid(loaderItem, x, y, w, h) {
        let gridStep = s(20);
        let L = Math.round(x / gridStep) * gridStep;
        let T = Math.round(y / gridStep) * gridStep;
        let R = Math.round((x + w) / gridStep) * gridStep;
        let B = Math.round((y + h) / gridStep) * gridStep;

        L = Math.max(0, Math.min(safeWidth, L));
        T = Math.max(0, Math.min(safeHeight, T));
        R = Math.max(0, Math.min(safeWidth, R));
        B = Math.max(0, Math.min(safeHeight, B));

        if (R <= L) R = L + gridStep;
        if (B <= T) B = T + gridStep;

        let snappedW = R - L;
        let snappedH = B - T;

        let clamped = clampResize(loaderItem, snappedW, snappedH, 0, 0, true);

        let finalX = L;
        let finalY = T;
        let mX = Math.max(0, safeWidth - clamped.w);
        let mY = Math.max(0, safeHeight - clamped.h);
        finalX = Math.max(0, Math.min(mX, finalX));
        finalY = Math.max(0, Math.min(mY, finalY));

        return { x: finalX, y: finalY, w: clamped.w, h: clamped.h };
    }

    function calculateResize(loaderItem, startX, startY, startW, startH, dx, dy, edges, isCorner, rot) {
        let rawW = startW;
        let rawH = startH;

        if (edges.left) rawW = startW - dx;
        else if (edges.right) rawW = startW + dx;

        if (edges.top) rawH = startH - dy;
        else if (edges.bottom) rawH = startH + dy;

        let gridStep = s(20);
        if (gridEnabled) {
            if (edges.left || edges.right) rawW = Math.round(rawW / gridStep) * gridStep;
            if (edges.top || edges.bottom) rawH = Math.round(rawH / gridStep) * gridStep;
        }

        let normRot = ((Math.round(rot || 0) % 360) + 360) % 360;
        let isRot90 = (normRot % 180 !== 0);
        let maxAllowedW = isRot90 ? safeHeight : safeWidth;
        let maxAllowedH = isRot90 ? safeWidth : safeHeight;

        rawW = Math.max(10, Math.min(maxAllowedW, rawW));
        rawH = Math.max(10, Math.min(maxAllowedH, rawH));

        let clamped = clampResize(loaderItem, rawW, rawH, dx, dy, isCorner);
        let finalW = Math.max(10, Math.min(maxAllowedW, clamped.w));
        let finalH = Math.max(10, Math.min(maxAllowedH, clamped.h));

        return { x: startX, y: startY, w: finalW, h: finalH };
    }
}
