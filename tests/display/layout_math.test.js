// Run: node --test tests/display/
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const file = path.join(__dirname, "..", "..", "src", "quickshell", "guide", "display", "DisplayLayoutMath.js");
const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
const LM = new Function(source + "\nreturn { logicalSize, overlaps, touches, connected, snap, pushOut, pullToEdge, resolveDrop };")();

// Most tests only care about the position; drop an empty shifts list.
const resolveDrop = LM.resolveDrop;
LM.resolveDrop = (...a) => { const r = resolveDrop(...a); if (r.shifts && r.shifts.length === 0) delete r.shifts; return r; };

const R = (name, x, y, w, h) => ({ name, x, y, w, h });
const left = R("L", 0, 0, 1920, 1080);
const right = R("R", 1920, 0, 1920, 1080);

test("logical size follows scale and rotation", () => {
    assert.deepStrictEqual(LM.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 0 }), { w: 1920, h: 1080 });
    assert.deepStrictEqual(LM.logicalSize({ width: 1920, height: 1080, scale: 1.5, transform: 0 }), { w: 1280, h: 720 });
    assert.deepStrictEqual(LM.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 1 }), { w: 1080, h: 1920 });
    assert.deepStrictEqual(LM.logicalSize({ width: 1920, height: 1080, scale: 2, transform: 3 }), { w: 540, h: 960 });
    assert.deepStrictEqual(LM.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 2 }), { w: 1920, h: 1080 });
});

test("touching needs a shared edge segment, not a corner", () => {
    assert.ok(LM.touches(left, right));
    assert.ok(!LM.touches(left, R("C", 1920, 1080, 100, 100)));       // corner only
    assert.ok(!LM.touches(left, R("G", 1930, 0, 100, 100)));          // gap
    assert.ok(LM.touches(left, R("B", 500, 1080, 100, 100)));         // below
});

test("magnet snaps a nearby drop flush against the neighbour", () => {
    const r = LM.resolveDrop([left, right], "R", 1950, 12, 40);
    assert.deepStrictEqual(r, { ok: true, x: 1920, y: 0 });
});

test("a drop outside the magnet radius keeps its free vertical offset when touching", () => {
    const r = LM.resolveDrop([left, right], "R", 1920, 400, 40);
    assert.deepStrictEqual(r, { ok: true, x: 1920, y: 400 });
});

test("dropping on top of another screen is pushed to the nearest free side", () => {
    const r = LM.resolveDrop([left, right], "R", 1500, 0, 20);
    assert.strictEqual(r.ok, true);
    assert.ok(!LM.overlaps(R("R", r.x, r.y, 1920, 1080), left));
    assert.strictEqual(r.x, 1920);
});

test("a screen dropped in empty space is pulled back to touch", () => {
    const r = LM.resolveDrop([left, right], "R", 6000, 300, 40);
    assert.deepStrictEqual(r, { ok: true, x: 1920, y: 300 });
});

test("a screen can be placed below and above", () => {
    assert.deepStrictEqual(LM.resolveDrop([left, right], "R", 100, 1100, 40), { ok: true, x: 100, y: 1080 });
    assert.deepStrictEqual(LM.resolveDrop([left, right], "R", 100, -1100, 40), { ok: true, x: 100, y: -1080 });
});

test("moving the bridge of a chain keeps the layout connected", () => {
    const a = R("A", 0, 0, 1000, 1000);
    const b = R("B", 1000, 0, 500, 1000);
    const c = R("C", 1500, 0, 1000, 1000);
    // Dropping B far to the right would leave A cut off; it must stay between A and C.
    const r = LM.resolveDrop([a, b, c], "B", 9000, 0, 40);
    assert.deepStrictEqual(r, { ok: true, x: 1000, y: 0 });
    const far = LM.resolveDrop([a, b, c], "B", 1000, 5000, 40);
    assert.strictEqual(far.ok, true);
    assert.ok(LM.connected([a, R("B", far.x, far.y, 500, 1000), c]));
});

test("an end of a chain dropped far away is reattached", () => {
    const a = R("A", 0, 0, 1000, 1000);
    const b = R("B", 1000, 0, 1000, 1000);
    const c = R("C", 2000, 0, 1000, 1000);
    assert.deepStrictEqual(LM.resolveDrop([a, b, c], "C", 8000, 0, 40), { ok: true, x: 2000, y: 0 });
});

test("moving an end of a chain is fine", () => {
    const a = R("A", 0, 0, 1000, 1000);
    const b = R("B", 1000, 0, 1000, 1000);
    const c = R("C", 2000, 0, 1000, 1000);
    assert.strictEqual(LM.resolveDrop([a, b, c], "C", 2000, 1000, 40).ok, true);
});

test("a single screen has no layout to change", () => {
    assert.deepStrictEqual(LM.resolveDrop([left], "L", 500, 500, 40), { ok: true, x: 0, y: 0 });
});

test("unknown monitor is rejected", () => {
    assert.strictEqual(LM.resolveDrop([left], "X", 0, 0, 40).ok, false);
});

test("scaled and rotated screens snap with their logical size", () => {
    const small = R("S", 0, 0, 1280, 720);       // 1920x1080 at 1.5
    const tall = R("T", 1280, 0, 1080, 1920);    // rotated
    const r = LM.resolveDrop([small, tall], "T", 1300, 5, 40);
    assert.deepStrictEqual(r, { ok: true, x: 1280, y: 0 });
});

test("negative coordinates work (screen to the left of the origin)", () => {
    const base = R("R", 0, 0, 1920, 1080);
    const l = R("L", -1920, 0, 1920, 1080);
    assert.deepStrictEqual(LM.resolveDrop([base, l], "L", -1900, 10, 40), { ok: true, x: -1920, y: 0 });
    assert.deepStrictEqual(LM.resolveDrop([base, l], "L", -5000, 300, 40), { ok: true, x: -1920, y: 300 });
});

test("results are always integers and never overlap", () => {
    for (let i = 0; i < 400; i++) {
        const x = Math.round(Math.sin(i * 12.9898) * 6000);
        const y = Math.round(Math.cos(i * 78.233) * 4000);
        const rects = [R("L", 0, 0, 1920, 1080), right, R("T", 0, 1080, 1920, 1080)];
        const r = LM.resolveDrop(rects, "R", x, y, 40);
        if (!r.ok) continue;
        assert.ok(Number.isInteger(r.x) && Number.isInteger(r.y));
        const sh = (n, o) => { const m = (r.shifts || []).find(q => q.name === n); return m ? R(n, m.x, m.y, o.w, o.h) : o; };
        const all = [sh("L", left), sh("T", R("T", 0, 1080, 1920, 1080)), R("R", r.x, r.y, 1920, 1080)];
        assert.ok(!LM.overlaps(all[0], all[2]) && !LM.overlaps(all[1], all[2]), "overlap at " + x + "," + y);
        assert.ok(LM.connected(all), "disconnected at " + x + "," + y);
    }
});

test("dropping the right screen between two others inserts it there and slides the rest", () => {
    const l = R("L", 0, 0, 1920, 1080), c = R("C", 1920, 0, 1920, 1080), r = R("R", 3840, 0, 1920, 1080);
    // Drop R's top-left so it straddles the L|C boundary.
    const d = resolveDrop([l, c, r], "R", 1000, 20, 20);
    assert.strictEqual(d.ok, true);
    assert.deepStrictEqual([d.x, d.y], [1920, 20]);
    assert.deepStrictEqual(d.shifts, [{ name: "C", x: 3840, y: 0 }]);
});

test("insertion keeps the result connected and overlap-free", () => {
    const l = R("L", 0, 0, 1920, 1080), c = R("C", 1920, 0, 1920, 1080), r = R("R", 3840, 0, 1920, 1080);
    const d = resolveDrop([l, c, r], "R", 1000, 0, 20);
    const after = [l, R("C", 1920 + (d.shifts[0] ? 1920 : 0), 0, 1920, 1080), R("R", d.x, d.y, 1920, 1080)];
    assert.ok(LM.connected(after));
    assert.ok(!LM.overlaps(after[0], after[2]) && !LM.overlaps(after[1], after[2]));
});

test("a mostly vertical drop over a monitor still goes above or below", () => {
    const l = R("L", 0, 0, 1920, 1080), c = R("C", 1920, 0, 1920, 1080), r = R("R", 3840, 0, 1920, 1080);
    const d = resolveDrop([l, c, r], "R", 2000, 900, 20);
    assert.strictEqual(d.y, 1080);
    assert.strictEqual((d.shifts || []).length, 0);
});

test("vertical stack: dropping between two stacked screens inserts it and slides the lower one", () => {
    const t = R("T", 0, 0, 1920, 1080), b = R("B", 0, 1080, 1920, 1080), x = R("X", 1920, 0, 1920, 1080);
    const d = resolveDrop([t, b, x], "X", 30, 700, 20);
    assert.strictEqual(d.ok, true);
    assert.deepStrictEqual([d.x, d.y], [30, 1080]);
    assert.deepStrictEqual(d.shifts, [{ name: "B", x: 0, y: 2160 }]);
});

test("free vertical placement does not slide anything", () => {
    const l = R("L", 0, 0, 1920, 1080), c = R("C", 1920, 0, 1920, 1080), r = R("R", 3840, 0, 1920, 1080);
    const d = resolveDrop([l, c, r], "R", 1950, 900, 20);
    assert.strictEqual(d.y, 1080);
    assert.strictEqual((d.shifts || []).length, 0);
});
