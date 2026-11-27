.pragma library

var DEFAULT_IGNORED_PROPS = [
    "objectName", "destroyed", "deleteLater", "parent", "data",
    "resources", "children", "visible", "enabled", "x", "y", "z",
    "width", "height", "opacity", "rotation", "scale"
];

function extractConstraints(item, explicitLimits) {
    if (explicitLimits) {
        return {
            minW: explicitLimits.minW !== undefined ? explicitLimits.minW : 10,
            minH: explicitLimits.minH !== undefined ? explicitLimits.minH : 10,
            maxW: explicitLimits.maxW !== undefined ? explicitLimits.maxW : 9999,
            maxH: explicitLimits.maxH !== undefined ? explicitLimits.maxH : 9999,
            minA: explicitLimits.minA !== undefined ? explicitLimits.minA : (explicitLimits.aspect > 0 ? explicitLimits.aspect : 0),
            maxA: explicitLimits.maxA !== undefined ? explicitLimits.maxA : (explicitLimits.aspect > 0 ? explicitLimits.aspect : 9999)
        };
    }
    if (!item) return null;
    if (item.minW !== undefined || item.minH !== undefined || item.minA !== undefined || item.maxA !== undefined) {
        return {
            minW: item.minW !== undefined ? item.minW : 10,
            minH: item.minH !== undefined ? item.minH : 10,
            maxW: item.maxW !== undefined ? item.maxW : 9999,
            maxH: item.maxH !== undefined ? item.maxH : 9999,
            minA: item.minA !== undefined ? item.minA : 0,
            maxA: item.maxA !== undefined ? item.maxA : 9999
        };
    }
    return {
        minW: item.minWidth !== undefined ? item.minWidth : 10,
        minH: item.minHeight !== undefined ? item.minHeight : 10,
        maxW: item.maxWidth !== undefined ? item.maxWidth : 9999,
        maxH: item.maxHeight !== undefined ? item.maxHeight : 9999,
        minA: item.minAspect !== undefined ? item.minAspect : 0,
        maxA: item.maxAspect !== undefined ? item.maxAspect : 9999
    };
}

function clampResize(constraintsOrItem, rawW, rawH, dx, dy, isCorner) {
    var c = extractConstraints(constraintsOrItem);
    if (!c) return { w: rawW, h: rawH };

    var w = Math.max(c.minW, Math.min(c.maxW, rawW));
    var h = Math.max(c.minH, Math.min(c.maxH, rawH));

    var hasMinA = c.minA !== undefined && c.minA > 0;
    var hasMaxA = c.maxA !== undefined && c.maxA > 0 && c.maxA < 9999;

    if (!isCorner) {
        if (dx !== 0) {
            var effMinW = Math.max(c.minW, hasMinA ? h * c.minA : c.minW);
            var effMaxW = Math.min(c.maxW, hasMaxA ? h * c.maxA : c.maxW);
            w = effMinW <= effMaxW ? Math.max(effMinW, Math.min(effMaxW, w)) : Math.max(c.minW, Math.min(c.maxW, w));
        } else {
            var effMinH = Math.max(c.minH, hasMaxA ? w / c.maxA : c.minH);
            var effMaxH = Math.min(c.maxH, hasMinA ? w / c.minA : c.maxH);
            h = effMinH <= effMaxH ? Math.max(effMinH, Math.min(effMaxH, h)) : Math.max(c.minH, Math.min(c.maxH, h));
        }
        return { w: w, h: h };
    }

    var ratio = w / h;
    var mA = 0;
    if (hasMinA && ratio < c.minA) mA = c.minA;
    else if (hasMaxA && ratio > c.maxA) mA = c.maxA;
    if (mA > 0) {
        var hProj = (w * mA + h) / (mA * mA + 1);
        var hMin = Math.max(c.minH, c.minW / mA);
        var hMax = Math.min(c.maxH, c.maxW / mA);
        h = Math.max(hMin, Math.min(hMax, hProj));
        w = h * mA;
    }

    return {
        w: Math.max(c.minW, Math.min(c.maxW, w)),
        h: Math.max(c.minH, Math.min(c.maxH, h))
    };
}

function calculateResize(constraintsOrItem, startX, startY, startW, startH, dx, dy, edges, isCorner, rot, opts) {
    var safeWidth = (opts && opts.safeWidth > 0) ? opts.safeWidth : 1920;
    var safeHeight = (opts && opts.safeHeight > 0) ? opts.safeHeight : 1080;
    var gridEnabled = !!(opts && opts.gridEnabled);
    var gridStep = (opts && opts.gridStep > 0) ? opts.gridStep : 20;

    var rawW = startW;
    var rawH = startH;

    if (edges.left) rawW = startW - dx;
    else if (edges.right) rawW = startW + dx;

    if (edges.top) rawH = startH - dy;
    else if (edges.bottom) rawH = startH + dy;

    if (gridEnabled) {
        if (edges.left || edges.right) rawW = Math.round(rawW / gridStep) * gridStep;
        if (edges.top || edges.bottom) rawH = Math.round(rawH / gridStep) * gridStep;
    }

    var normRot = ((Math.round(rot || 0) % 360) + 360) % 360;
    var isRot90 = (normRot % 180 !== 0);
    var maxAllowedW = isRot90 ? safeHeight : safeWidth;
    var maxAllowedH = isRot90 ? safeWidth : safeHeight;

    rawW = Math.max(10, Math.min(maxAllowedW, rawW));
    rawH = Math.max(10, Math.min(maxAllowedH, rawH));

    var clamped = clampResize(constraintsOrItem, rawW, rawH, dx, dy, isCorner);
    return {
        x: startX,
        y: startY,
        w: Math.max(10, Math.min(maxAllowedW, clamped.w)),
        h: Math.max(10, Math.min(maxAllowedH, clamped.h))
    };
}

function axisKeys(axis, safeWidth, safeHeight) {
    return axis === "x"
        ? { horizontal: true, lo: "l", hi: "r", clo: "t", chi: "b", extent: safeWidth, crossExtent: safeHeight }
        : { horizontal: false, lo: "t", hi: "b", clo: "l", chi: "r", extent: safeHeight, crossExtent: safeWidth };
}

function boxOf(item) {
    return { l: item.x, t: item.y, r: item.x + item.width, b: item.y + item.height };
}

function otherBoxesFromRepeater(repeater, excluded) {
    var out = [];
    if (!repeater) return out;
    for (var i = 0; i < repeater.count; i++) {
        var p = repeater.itemAt(i);
        if (p && p !== excluded) out.push(boxOf(p));
    }
    return out;
}

function shiftBox(box, k, lo) {
    var out = { l: box.l, t: box.t, r: box.r, b: box.b };
    out[k.hi] = lo + box[k.hi] - box[k.lo];
    out[k.lo] = lo;
    return out;
}

function crossOverlap(a, b, k) {
    return a[k.clo] < b[k.chi] - 0.5 && a[k.chi] > b[k.clo] + 0.5;
}

function neighbor(box, others, k, side) {
    var best = null;
    for (var i = 0; i < others.length; i++) {
        var o = others[i];
        if (!crossOverlap(box, o, k)) continue;
        var gap = side < 0 ? box[k.lo] - o[k.hi] : o[k.lo] - box[k.hi];
        if (gap > -0.5 && (!best || gap < best.gap)) best = { box: o, gap: Math.max(0, gap) };
    }
    return best;
}

function gapSegment(box, others, k, side) {
    var n = neighbor(box, others, k, side);
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
    var length = seg.to - seg.from;
    return {
        horizontal: k.horizontal,
        x: k.horizontal ? seg.from : seg.cross,
        y: k.horizontal ? seg.cross : seg.from,
        length: length,
        value: Math.round(length)
    };
}

function alignmentLines(k, others) {
    var lines = [0, k.extent / 3, k.extent / 2, k.extent * 2 / 3, k.extent];
    for (var i = 0; i < others.length; i++) {
        var o = others[i];
        lines.push(o[k.lo], (o[k.lo] + o[k.hi]) / 2, o[k.hi]);
    }
    return lines;
}

function snapAxis(box, others, k, snapThreshold) {
    var raw = box[k.lo];
    var size = box[k.hi] - raw;
    var best = { lo: raw, diff: snapThreshold, line: -1, refs: [] };

    var lines = alignmentLines(k, others);
    var points = [0, size / 2, size];
    for (var i = 0; i < lines.length; i++) {
        for (var j = 0; j < points.length; j++) {
            var lo = lines[i] - points[j];
            var diff = Math.abs(lo - raw);
            if (diff < best.diff) best = { lo: lo, diff: diff, line: lines[i], refs: [] };
        }
    }

    var offerSpacing = function(lo, accept) {
        var d = Math.abs(lo - raw);
        if (d >= best.diff) return;
        var refs = accept(shiftBox(box, k, lo));
        if (refs) best = { lo: lo, diff: d, line: -1, refs: refs };
    };
    var isGap = function(n, o, value) {
        return n !== null && n.box === o && Math.abs(n.gap - value) < 0.5;
    };

    var gaps = [];
    var margins = [];
    for (var mIdx = 0; mIdx < others.length; mIdx++) {
        var o = others[mIdx];
        var next = neighbor(o, others, k, 1);
        if (next && next.gap >= 1) gaps.push(gapSegment(o, others, k, 1));
        if (!next) margins.push(gapSegment(o, others, k, 1));
        if (!neighbor(o, others, k, -1)) margins.push(gapSegment(o, others, k, -1));
    }

    for (var gIdx = 0; gIdx < gaps.length; gIdx++) {
        var g = gaps[gIdx];
        var gVal = g.to - g.from;
        for (var oIdx = 0; oIdx < others.length; oIdx++) {
            var other = others[oIdx];
            if (!crossOverlap(box, other, k)) continue;
            offerSpacing(other[k.hi] + gVal, function(b) { return isGap(neighbor(b, others, k, -1), other, gVal) ? [measureShape(k, g)] : null; });
            offerSpacing(other[k.lo] - gVal - size, function(b) { return isGap(neighbor(b, others, k, 1), other, gVal) ? [measureShape(k, g)] : null; });
        }
    }

    for (var marIdx = 0; marIdx < margins.length; marIdx++) {
        var mar = margins[marIdx];
        var marVal = mar.to - mar.from;
        if (marVal < 1) continue;
        offerSpacing(marVal, function(b) { return neighbor(b, others, k, -1) ? null : [measureShape(k, mar), measureShape(k, gapSegment(b, others, k, -1))]; });
        offerSpacing(k.extent - marVal - size, function(b) { return neighbor(b, others, k, 1) ? null : [measureShape(k, mar), measureShape(k, gapSegment(b, others, k, 1))]; });
    }

    var before = neighbor(box, others, k, -1);
    var after = neighbor(box, others, k, 1);
    if (before && after) {
        offerSpacing((before.box[k.hi] + after.box[k.lo] - size) / 2, function(b) {
            var nb = neighbor(b, others, k, -1);
            var na = neighbor(b, others, k, 1);
            return (nb && na && nb.box === before.box && na.box === after.box) ? [] : null;
        });
    }

    return best;
}

function calculateSnap(w, h, rawX, rawY, others, safeWidth, safeHeight, opts) {
    var gridEnabled = !!(opts && opts.gridEnabled);
    var gridStep = (opts && opts.gridStep > 0) ? opts.gridStep : 20;
    var snapThreshold = (opts && opts.snapThreshold > 0) ? opts.snapThreshold : 12;
    var bypass = !!(opts && opts.bypass);

    var res = { x: rawX, y: rawY, lines: { x: -1, y: -1 }, refs: [] };

    if (gridEnabled) {
        res.x = Math.round(rawX / gridStep) * gridStep;
        res.y = Math.round(rawY / gridStep) * gridStep;
    } else if (!bypass) {
        var kx = axisKeys("x", safeWidth, safeHeight);
        var ky = axisKeys("y", safeWidth, safeHeight);
        var box = { l: rawX, t: rawY, r: rawX + w, b: rawY + h };
        var sx = snapAxis(box, others, kx, snapThreshold);
        box = shiftBox(box, kx, sx.lo);
        var sy = snapAxis(box, others, ky, snapThreshold);
        box = shiftBox(box, ky, sy.lo);
        res.x = box.l;
        res.y = box.t;
        res.lines = { x: sx.line, y: sy.line };
        res.refs = sx.refs.concat(sy.refs);
    }

    var mX = Math.max(0, safeWidth - w);
    var mY = Math.max(0, safeHeight - h);
    res.x = Math.max(0, Math.min(mX, res.x));
    res.y = Math.max(0, Math.min(mY, res.y));
    res.box = { l: res.x, t: res.y, r: res.x + w, b: res.y + h };

    return res;
}

function snapEdges(box, others, sides, safeWidth, safeHeight, snapThreshold) {
    var out = { x: null, y: null };
    var axes = ["x", "y"];
    for (var a = 0; a < axes.length; a++) {
        var side = sides[axes[a]];
        if (!side) continue;
        var k = axisKeys(axes[a], safeWidth, safeHeight);
        var edge = side < 0 ? box[k.lo] : box[k.hi];
        var lines = alignmentLines(k, others);
        var bestDiff = snapThreshold;
        for (var i = 0; i < lines.length; i++) {
            var diff = Math.abs(lines[i] - edge);
            if (diff < bestDiff) {
                bestDiff = diff;
                out[axes[a]] = { line: lines[i], diff: diff };
            }
        }
    }
    return out;
}

function guideSegment(box, others, k, line, lineThickness) {
    var onLine = function(b) {
        return Math.abs(b[k.lo] - line) < 0.5 || Math.abs((b[k.lo] + b[k.hi]) / 2 - line) < 0.5 || Math.abs(b[k.hi] - line) < 0.5;
    };
    if (!onLine(box)) return null;

    var from = box[k.clo];
    var to = box[k.chi];
    var linked = false;
    for (var i = 0; i < others.length; i++) {
        if (!onLine(others[i])) continue;
        from = Math.min(from, others[i][k.clo]);
        to = Math.max(to, others[i][k.chi]);
        linked = true;
    }
    if (!linked) {
        from = 0;
        to = k.crossExtent;
    }

    var t = lineThickness > 0 ? lineThickness : 1;
    return k.horizontal
        ? { x: line - t / 2, y: from, w: t, h: to - from }
        : { x: from, y: line - t / 2, w: to - from, h: t };
}

function buildOverlay(box, others, snap, safeWidth, safeHeight, lineThickness, showDistances) {
    var guides = [];
    var measures = (snap && snap.refs) ? snap.refs.slice() : [];
    var axes = ["x", "y"];
    for (var a = 0; a < axes.length; a++) {
        var k = axisKeys(axes[a], safeWidth, safeHeight);
        var line = (snap && snap.lines) ? snap.lines[axes[a]] : -1;
        if (line >= 0) {
            var guide = guideSegment(box, others, k, line, lineThickness);
            if (guide) guides.push(guide);
        }
        if (showDistances) {
            for (var side = -1; side <= 1; side += 2) {
                var seg = gapSegment(box, others, k, side);
                if (!seg.edge && seg.to - seg.from >= 1) measures.push(measureShape(k, seg));
            }
        }
    }
    return {
        guideLines: guides,
        measureLines: showDistances ? measures : []
    };
}

function snapBoxToGrid(constraintsOrItem, x, y, w, h, safeWidth, safeHeight, gridStep) {
    var step = gridStep > 0 ? gridStep : 20;
    var L = Math.round(x / step) * step;
    var T = Math.round(y / step) * step;
    var R = Math.round((x + w) / step) * step;
    var B = Math.round((y + h) / step) * step;

    L = Math.max(0, Math.min(safeWidth, L));
    T = Math.max(0, Math.min(safeHeight, T));
    R = Math.max(0, Math.min(safeWidth, R));
    B = Math.max(0, Math.min(safeHeight, B));

    if (R <= L) R = L + step;
    if (B <= T) B = T + step;

    var clamped = clampResize(constraintsOrItem, R - L, B - T, 0, 0, true);
    var mX = Math.max(0, safeWidth - clamped.w);
    var mY = Math.max(0, safeHeight - clamped.h);
    return {
        x: Math.max(0, Math.min(mX, L)),
        y: Math.max(0, Math.min(mY, T)),
        w: clamped.w,
        h: clamped.h
    };
}

function calculateRotatedResize(params) {
    var constraints = params.constraints;
    var startX = params.startX;
    var startY = params.startY;
    var startW = params.startW;
    var startH = params.startH;
    var dx = params.dx;
    var dy = params.dy;
    var edges = params.edges;
    var isCorner = !!params.isCorner;
    var rot = params.rot || 0;
    var safeWidth = params.safeWidth;
    var safeHeight = params.safeHeight;
    var gridEnabled = !!params.gridEnabled;
    var gridStep = params.gridStep > 0 ? params.gridStep : 20;
    var freeSnap = !!params.freeSnap;
    var otherBoxes = params.otherBoxes || [];
    var snapThreshold = params.snapThreshold > 0 ? params.snapThreshold : 12;
    var lockedAspect = params.lockedAspect > 0 ? params.lockedAspect : 0;

    var rad = rot * Math.PI / 180.0;
    var cos = Math.cos(rad);
    var sin = Math.sin(rad);

    var ldx = dx * cos + dy * sin;
    var ldy = -dx * sin + dy * cos;

    var passLdx = isCorner ? ldx : (edges.left || edges.right ? ldx : 0);
    var passLdy = isCorner ? ldy : (edges.top || edges.bottom ? ldy : 0);

    var rot90 = Math.abs(Math.round(rot)) % 180 !== 0;
    var startCX = startX + (rot90 ? startH : startW) / 2.0;
    var startCY = startY + (rot90 ? startW : startH) / 2.0;

    var pxFixed = edges.left ? startW / 2.0 : (edges.right ? -startW / 2.0 : 0);
    var pyFixed = edges.top ? startH / 2.0 : (edges.bottom ? -startH / 2.0 : 0);
    var fixedX = startCX + pxFixed * cos - pyFixed * sin;
    var fixedY = startCY + pxFixed * sin + pyFixed * cos;

    var place = function(w, h) {
        var pxNew = edges.left ? w / 2.0 : (edges.right ? -w / 2.0 : 0);
        var pyNew = edges.top ? h / 2.0 : (edges.bottom ? -h / 2.0 : 0);
        var bw = rot90 ? h : w;
        var bh = rot90 ? w : h;
        var x = fixedX - (pxNew * cos - pyNew * sin) - bw / 2.0;
        var y = fixedY - (pxNew * sin + pyNew * cos) - bh / 2.0;
        x = Math.max(0, Math.min(Math.max(0, safeWidth - bw), x));
        y = Math.max(0, Math.min(Math.max(0, safeHeight - bh), y));
        return { l: x, t: y, r: x + bw, b: y + bh };
    };

    var resizeOpts = { safeWidth: safeWidth, safeHeight: safeHeight, gridEnabled: gridEnabled, gridStep: gridStep };
    var res = calculateResize(constraints, startX, startY, startW, startH, passLdx, passLdy, edges, isCorner, rot, resizeOpts);
    var box = place(res.w, res.h);
    var lines = { x: -1, y: -1 };

    if (freeSnap) {
        var sides = { x: 0, y: 0 };
        var addSide = function(nx, ny) {
            sides.x += Math.round(nx * cos - ny * sin);
            sides.y += Math.round(nx * sin + ny * cos);
        };
        if (edges.left) addSide(-1, 0);
        if (edges.right) addSide(1, 0);
        if (edges.top) addSide(0, -1);
        if (edges.bottom) addSide(0, 1);

        var hit = snapEdges(box, otherBoxes, sides, safeWidth, safeHeight, snapThreshold);
        if (lockedAspect > 0 && hit.x && hit.y) {
            if (hit.x.diff <= hit.y.diff) hit.y = null;
            else hit.x = null;
        }

        if (hit.x || hit.y) {
            var w = res.w;
            var h = res.h;
            if (hit.x) {
                var bw = sides.x < 0 ? box.r - hit.x.line : hit.x.line - box.l;
                if (rot90) h = bw;
                else w = bw;
            }
            if (hit.y) {
                var bh = sides.y < 0 ? box.b - hit.y.line : hit.y.line - box.t;
                if (rot90) w = bh;
                else h = bh;
            }
            if (lockedAspect > 0) {
                if ((hit.x !== null) !== rot90) h = w / lockedAspect;
                else w = h * lockedAspect;
            }

            var sdx = edges.left ? startW - w : (edges.right ? w - startW : 0);
            var sdy = edges.top ? startH - h : (edges.bottom ? h - startH : 0);
            var snappedRes = calculateResize(constraints, startX, startY, startW, startH, sdx, sdy, edges, isCorner, rot, resizeOpts);
            var snappedBox = place(snappedRes.w, snappedRes.h);

            var landsX = !hit.x || Math.abs((sides.x < 0 ? snappedBox.l : snappedBox.r) - hit.x.line) < 0.5;
            var landsY = !hit.y || Math.abs((sides.y < 0 ? snappedBox.t : snappedBox.b) - hit.y.line) < 0.5;
            if (landsX && landsY) {
                res = snappedRes;
                box = snappedBox;
                lines = { x: hit.x ? hit.x.line : -1, y: hit.y ? hit.y.line : -1 };
            }
        }
    }

    var boxW = box.r - box.l;
    var boxH = box.b - box.t;
    var newX = box.l;
    var newY = box.t;

    if (gridEnabled) {
        var mX = Math.max(0, safeWidth - boxW);
        var mY = Math.max(0, safeHeight - boxH);
        newX = Math.max(0, Math.min(mX, Math.round(newX / gridStep) * gridStep));
        newY = Math.max(0, Math.min(mY, Math.round(newY / gridStep) * gridStep));
    }

    return {
        x: newX,
        y: newY,
        w: res.w,
        h: res.h,
        box: { l: newX, t: newY, r: newX + boxW, b: newY + boxH },
        lines: lines
    };
}

function rotateBounds(curX, curY, curW, curH, curRot, constraintsOrItem, safeWidth, safeHeight, opts) {
    var normCur = Math.abs(Math.round(curRot || 0)) % 360;
    var nextRot = normCur + 90;

    var curBW = (normCur % 180 === 0) ? curW : curH;
    var curBH = (normCur % 180 === 0) ? curH : curW;
    var centerX = curX + curBW / 2.0;
    var centerY = curY + curBH / 2.0;

    var unscaledBW = (nextRot % 180 === 0) ? curW : curH;
    var unscaledBH = (nextRot % 180 === 0) ? curH : curW;

    var limitY = (opts && opts.limitY > 0) ? opts.limitY : safeHeight;
    var maxBW = Math.max(20, 2.0 * Math.min(centerX, safeWidth - centerX));
    var maxBH = Math.max(20, 2.0 * Math.min(centerY, limitY - centerY));

    var scaleX = (maxBW > 0 && unscaledBW > maxBW) ? (maxBW / unscaledBW) : 1.0;
    var scaleY = (maxBH > 0 && unscaledBH > maxBH) ? (maxBH / unscaledBH) : 1.0;
    var factor = Math.min(1.0, scaleX, scaleY);

    var clamped = clampResize(constraintsOrItem, curW * factor, curH * factor, 0, 0, true);
    var nextBW = (nextRot % 180 === 0) ? clamped.w : clamped.h;
    var nextBH = (nextRot % 180 === 0) ? clamped.h : clamped.w;

    var mX = Math.max(0, safeWidth - nextBW);
    var mY = Math.max(0, safeHeight - nextBH);
    var newX = Math.max(0, Math.min(mX, centerX - nextBW / 2.0));
    var newY = Math.max(0, Math.min(mY, centerY - nextBH / 2.0));

    if (opts && opts.gridEnabled) {
        var gridStep = opts.gridStep > 0 ? opts.gridStep : 20;
        newX = Math.max(0, Math.min(mX, Math.round(newX / gridStep) * gridStep));
        newY = Math.max(0, Math.min(mY, Math.round(newY / gridStep) * gridStep));
    }

    return {
        x: newX,
        y: newY,
        w: clamped.w,
        h: clamped.h,
        rotation: nextRot
    };
}

function resetBounds(curX, curY, curW, curH, curRot, defW, defH, constraintsOrItem, safeWidth, safeHeight, opts) {
    var normCur = Math.abs(Math.round(curRot || 0)) % 360;
    var curBW = (normCur % 180 === 0) ? curW : curH;
    var curBH = (normCur % 180 === 0) ? curH : curW;
    var cx = curX + curBW / 2.0;
    var cy = curY + curBH / 2.0;

    var clamped = clampResize(constraintsOrItem, defW, defH, 0, 0, true);
    var finalW = clamped.w;
    var finalH = clamped.h;

    var mX = Math.max(0, safeWidth - finalW);
    var mY = Math.max(0, safeHeight - finalH);
    var newX = Math.max(0, Math.min(mX, cx - finalW / 2.0));
    var newY = Math.max(0, Math.min(mY, cy - finalH / 2.0));

    if (opts && opts.gridEnabled) {
        var snapped = snapBoxToGrid(constraintsOrItem, newX, newY, finalW, finalH, safeWidth, safeHeight, opts.gridStep);
        newX = snapped.x;
        newY = snapped.y;
        finalW = snapped.w;
        finalH = snapped.h;
    }

    return {
        x: newX,
        y: newY,
        w: finalW,
        h: finalH,
        rotation: 0,
        opacity: 1.0
    };
}

function applyVariantAspect(curW, curH, curVariant, nextVariant, savedAspects) {
    if (curVariant === nextVariant) return null;
    if (curH > 0 && savedAspects) {
        savedAspects[curVariant] = curW / curH;
    }
    var targetAspect = savedAspects ? savedAspects[nextVariant] : 0;
    if (targetAspect > 0) {
        var area = curW * curH;
        var newH = Math.max(10, Math.sqrt(area / targetAspect));
        return { w: Math.max(10, newH * targetAspect), h: newH };
    }
    return null;
}

function applyCustomProps(target, props, extraIgnored) {
    if (!target || !props) return;
    for (var k in props) {
        if (!k || typeof k !== "string") continue;
        if (k.endsWith("Changed") || k.startsWith("on") || typeof props[k] === "function" || props[k] === undefined) continue;
        if (DEFAULT_IGNORED_PROPS.indexOf(k) !== -1) continue;
        if (extraIgnored && extraIgnored.indexOf(k) !== -1) continue;
        try {
            if (target[k] !== undefined && target[k] !== props[k]) {
                target[k] = props[k];
            }
        } catch (e) {}
    }
}

function resolveThemeColor(colorName, theme) {
    if (!theme) return "#cdd6f4";
    if (colorName === "mauve") return theme.mauve;
    if (colorName === "surface0") return theme.surface0;
    if (colorName === "surface1") return theme.surface1;
    if (colorName === "crust") return theme.crust;
    if (colorName === "base") return theme.base;
    if (colorName === "red") return theme.red;
    return theme.text;
}

function handleGeometryAction(action, adapter) {
    if (!adapter) return false;
    if (action === "pickImage") {
        if (typeof adapter.pickImage === "function") adapter.pickImage();
        return true;
    }
    if (action === "stretchWidth") {
        if (adapter.isRotated90) {
            adapter.setGeometry({ y: 0, w: adapter.safeHeight });
        } else {
            adapter.setGeometry({ x: 0, w: adapter.safeWidth });
        }
        return true;
    }
    if (action === "fillScreen") {
        var gap = adapter.gap !== undefined ? adapter.gap : 50;
        var w = (adapter.isRotated90 ? adapter.safeHeight : adapter.safeWidth) - gap * 2;
        var h = (adapter.isRotated90 ? adapter.safeWidth : adapter.safeHeight) - gap * 2;
        adapter.setGeometry({ x: gap, y: gap, w: w, h: h });
        return true;
    }
    if (adapter.extraArg !== undefined && typeof adapter.setProperty === "function") {
        adapter.setProperty(action, adapter.extraArg);
        return true;
    }
    return false;
}
