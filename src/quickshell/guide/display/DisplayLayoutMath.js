.pragma library

// Pure geometry for the display arrangement map. Everything is in LOGICAL pixels
// (physical size / scale, swapped when rotated 90/270 degrees), the unit in which
// Hyprland positions monitors. A rect is { name, x, y, w, h } with integer values.

function logicalSize(m) {
    var w = m.width / m.scale;
    var h = m.height / m.scale;
    if ((m.transform | 0) % 2 === 1) {
        var t = w;
        w = h;
        h = t;
    }
    return { w: Math.round(w), h: Math.round(h) };
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

// Two monitors touch when they share an edge segment of positive length.
function touches(a, b) {
    var vOverlap = a.y < b.y + b.h && b.y < a.y + a.h;
    var hOverlap = a.x < b.x + b.w && b.x < a.x + a.w;
    return (vOverlap && (a.x + a.w === b.x || b.x + b.w === a.x))
        || (hOverlap && (a.y + a.h === b.y || b.y + b.h === a.y));
}

function connected(rects) {
    if (rects.length <= 1) return true;
    var reached = { 0: true };
    var frontier = [0];
    var count = 1;
    while (frontier.length > 0) {
        var i = frontier.pop();
        for (var j = 0; j < rects.length; j++) {
            if (!reached[j] && touches(rects[i], rects[j])) {
                reached[j] = true;
                count++;
                frontier.push(j);
            }
        }
    }
    return count === rects.length;
}

function overlapsAny(rect, others) {
    for (var i = 0; i < others.length; i++)
        if (overlaps(rect, others[i])) return true;
    return false;
}

function touchesAny(rect, others) {
    for (var i = 0; i < others.length; i++)
        if (touches(rect, others[i])) return true;
    return false;
}

function nearest(value, targets, threshold) {
    var best = value;
    var bestDist = threshold + 1;
    for (var i = 0; i < targets.length; i++) {
        var d = Math.abs(targets[i] - value);
        if (d < bestDist) {
            bestDist = d;
            best = targets[i];
        }
    }
    return bestDist <= threshold ? best : value;
}

// Magnet: pull each axis to the closest edge of another monitor within `threshold`.
function snap(rect, others, threshold) {
    var xs = [];
    var ys = [];
    for (var i = 0; i < others.length; i++) {
        var o = others[i];
        xs.push(o.x - rect.w, o.x + o.w, o.x, o.x + o.w - rect.w);
        ys.push(o.y - rect.h, o.y + o.h, o.y, o.y + o.h - rect.h);
    }
    return {
        name: rect.name, w: rect.w, h: rect.h,
        x: nearest(rect.x, xs, threshold),
        y: nearest(rect.y, ys, threshold)
    };
}

function distance(a, b) {
    return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

function best(rect, candidates, others, accept) {
    var out = null;
    var outDist = Infinity;
    for (var i = 0; i < candidates.length; i++) {
        var c = candidates[i];
        if (overlapsAny(c, others)) continue;
        if (accept && !accept(c)) continue;
        var d = distance(c, rect);
        if (d < outDist) {
            outDist = d;
            out = c;
        }
    }
    return out;
}

function at(rect, x, y) {
    return { name: rect.name, w: rect.w, h: rect.h, x: Math.round(x), y: Math.round(y) };
}

// Smallest move that frees `rect` from every monitor it overlaps; null when impossible.
function pushOut(rect, others) {
    var candidates = [];
    for (var i = 0; i < others.length; i++) {
        var o = others[i];
        candidates.push(at(rect, o.x - rect.w, rect.y), at(rect, o.x + o.w, rect.y),
                        at(rect, rect.x, o.y - rect.h), at(rect, rect.x, o.y + o.h));
    }
    return best(rect, candidates, others);
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Closest position that touches some monitor without overlapping any (and that
// satisfies `accept`, when given); null if none.
function pullToEdge(rect, others, accept) {
    var candidates = [];
    for (var i = 0; i < others.length; i++) {
        var o = others[i];
        var cy = clamp(rect.y, o.y - rect.h + 1, o.y + o.h - 1);
        var cx = clamp(rect.x, o.x - rect.w + 1, o.x + o.w - 1);
        candidates.push(at(rect, o.x + o.w, cy), at(rect, o.x - rect.w, cy),
                        at(rect, cx, o.y + o.h), at(rect, cx, o.y - rect.h));
    }
    return best(rect, candidates, others, accept);
}

// Where does monitor `name` end up when dropped with its top-left at (x, y)?
// Returns { ok, x, y, reason } with reason "overlap" | "disconnected" when ok is false.
function resolveDrop(rects, name, x, y, threshold) {
    var me = null;
    var others = [];
    for (var i = 0; i < rects.length; i++) {
        if (rects[i].name === name) me = rects[i];
        else others.push(rects[i]);
    }
    if (!me) return { ok: false, reason: "unknown", x: 0, y: 0 };
    if (others.length === 0) return { ok: true, x: me.x, y: me.y };

    var cand = snap(at(me, x, y), others, threshold);
    if (overlapsAny(cand, others)) {
        cand = pushOut(cand, others);
        if (!cand) return { ok: false, reason: "overlap", x: me.x, y: me.y };
    }
    // The layout must stay one connected block. If the drop floats free, or would
    // cut another screen off (the moved one was a bridge), take the closest spot
    // that touches a neighbour AND keeps everything connected.
    if (!touchesAny(cand, others) || !connected(others.concat([cand]))) {
        cand = pullToEdge(cand, others, function (c) { return connected(others.concat([c])); });
        if (!cand) return { ok: false, reason: "disconnected", x: me.x, y: me.y };
    }
    return { ok: true, x: cand.x, y: cand.y };
}
