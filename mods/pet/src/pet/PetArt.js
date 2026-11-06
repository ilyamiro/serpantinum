.pragma library

// Pixel art for the pet. Every sprite faces right; scene() mirrors when facing left.
// Palette keys: K outline, F fur, D fur shade, L fur light, P pink, W white, E eye,
// T tongue, G glasses, H/h headphones, U/u umbrella, S stick, C/c laptop, R heart,
// Y star, Z text, A water, X/x fish, N note, B/b/O bed, M sparkle

var CW = 48;
var CH = 40;

var HEAD_BASE = [
    ".KK.......KK.",
    "KFFK.....KFFK",
    "KFPFK...KFPFK",
    "KFFFFKKKFFFFK",
    "KFFFFFFFFFFFK",
    "KFFWEFFFWEFFK",
    "KFFEEFFFEEFFK",
    "KLFFFFPFFFFLK",
    "KLLFFKFKFFLLK",
    ".KLLLLLLLLLK.",
    "..KKKKYKKKK.."
];

var EYES = {
    normal: { 5: "KFFWEFFFWEFFK", 6: "KFFEEFFFEEFFK" },
    blink:  { 5: "KFFFFFFFFFFFK", 6: "KFFEEFFFEEFFK" },
    happy:  { 5: "KFFFEFFFFEFFK", 6: "KFFEFEFFEFEFK" },
    up:     { 4: "KFFWEFFFWEFFK", 5: "KFFEEFFFEEFFK", 6: "KFFFFFFFFFFFK" },
    side:   { 5: "KFFFWEFFFWEFK", 6: "KFFFEEFFFEEFK" },
    wide:   { 4: "KFFWEFFFWEFFK", 5: "KFFEEFFFEEFFK", 6: "KFFEEFFFEEFFK" },
    dizzy:  { 4: "KFEFEFFFEFEFK", 5: "KFFEFFFFFEFFK", 6: "KFEFEFFFEFEFK" },
    tired:  { 5: "KFFKKFFFKKFFK", 6: "KFFEEFFFEEFFK" },
    sleep:  { 5: "KFFFFFFFFFFFK", 6: "KFFKKFFFKKFFK" }
};

var MOUTHS = {
    normal: {},
    open:   { 8: "KLLFFKKKFFLLK", 9: ".KLLLKTKLLLK." },
    pant:   { 8: "KLLFFKKKFFLLK", 9: ".KLLLKTKLLLK." },
    chew:   { 8: "KLLFFFKFFFLLK" },
    smile:  { 8: "KLLFKFFFKFLLK", 9: ".KLLLKKKLLLK." }
};

// face name -> [eyes, mouth, blush]
var FACES = {
    normal: ["normal", "normal", false],
    blink:  ["blink", "normal", false],
    happy:  ["happy", "smile", true],
    love:   ["happy", "normal", true],
    meow:   ["normal", "open", false],
    yawn:   ["sleep", "open", false],
    pant:   ["tired", "pant", false],
    up:     ["up", "normal", false],
    side:   ["side", "normal", false],
    alert:  ["wide", "normal", false],
    dizzy:  ["dizzy", "open", false],
    tired:  ["tired", "normal", false],
    sleep:  ["sleep", "normal", false],
    chew:   ["happy", "chew", true],
    chew2:  ["happy", "open", true]
};

var SPR = {
    torso: [
        "..KKKKKKKKKK....",
        ".KFFFFFFFFFFKK..",
        "KFFFFFFFFFFFFFK.",
        "KDFFFFFFFFFFFFK.",
        "KDFFFFFFFFFFFFK.",
        "KDDFFFFFFFFLLK..",
        ".KKKKKKKKKKKK..."
    ],
    legN:  ["KFFK", "KFFK", "KFFK", "KKKK"],
    legNu: ["KFFK", "KFFK", "KKKK"],
    legNs: ["KFFK", "KKKK"],
    legF:  ["KDDK", "KDDK", "KDDK", "KKKK"],
    legFu: ["KDDK", "KDDK", "KKKK"],
    legFs: ["KDDK", "KKKK"],
    tailA: [
        "..KK.",
        ".KFFK",
        ".KFK.",
        "KFK..",
        "KFK..",
        "KFK..",
        ".KFK.",
        "..KFK"
    ],
    tailB: [
        ".KK..",
        "KFFK.",
        ".KFK.",
        "..KFK",
        "..KFK",
        ".KFK.",
        ".KFK.",
        "..KFK"
    ],
    tailRun: [
        "KK.....",
        "KFKK...",
        ".KFFKKK",
        "..KKFFK",
        "....KKK"
    ],
    sit: [
        "....KKKKKK.....",
        "...KFFFFFFK....",
        "..KFFFFFFFFK...",
        "..KFFFFFFFFFK..",
        ".KDFFFFFFFLLK..",
        ".KDFFFFFFFLLK..",
        "KDDFFFFFKFLLK..",
        "KDDFFFFFKFLLK..",
        "KDDFFFFFKFLLK..",
        "KDDDFFFKKLLLK..",
        "KKKKKKKKKKKKK.."
    ],
    tailFloor: [
        "KK.....",
        "KFK....",
        ".KFKKKK",
        "..KFFFF",
        "...KKKK"
    ],
    tailFloorB: [
        ".......",
        "KKK....",
        "KFFKKKK",
        ".KKFFFF",
        "...KKKK"
    ],
    loafA: [
        "....KKKKKKKKKK....",
        "..KKFFFFFFFFFFKK..",
        ".KFFFFFFFFFFFFFFK.",
        "KFFFFFFFFFFFFFFFFK",
        "KDFFFFFFFFFFFFFFFK",
        "KDDFFFFFFFFFFFFFDK",
        ".KKKKKKKKKKKKKKKK."
    ],
    loafB: [
        "..................",
        "....KKKKKKKKKK....",
        "..KKFFFFFFFFFFKK..",
        ".KFFFFFFFFFFFFFFK.",
        "KDFFFFFFFFFFFFFFFK",
        "KDDFFFFFFFFFFFFFDK",
        ".KKKKKKKKKKKKKKKK."
    ],
    tailLoaf: [
        "KKKKKKKK..",
        "KFFFFFFFKK",
        ".KKKKKKKK."
    ],
    flop: [
        "...KKKKKKKKKKKK.....",
        "..KFFFFFFFFFFFFKK...",
        ".KFFFFFFFFFFFFFFFK..",
        "KFFFFFFFFFFFFFFFFFK.",
        "KDDFFFFFFFFFFFFFLLK.",
        ".KKKKKKKKKKKKKKKKK.."
    ],
    flopLegs: [
        "KKKKK.",
        "KFFFFK",
        "KKKKK."
    ],
    dangle: [
        "...KKKKK...",
        "..KFFFFFK..",
        ".KFFFFFFFK.",
        ".KDFFFFFLK.",
        ".KDFFFFFLK.",
        ".KDFFFFFLK.",
        ".KDFFFFFLK.",
        "..KDFFFLK..",
        "..KKFKFKK..",
        "..KFK.KFK..",
        "..KFK.KFK..",
        "..KKK.KKK.."
    ],
    tailHang: [
        ".KK",
        "KFK",
        "KFK",
        "KFK",
        "KFK",
        ".KK"
    ],
    leap: [
        "......KKKKKKKKK.......",
        "KKK.KKFFFFFFFFFKK.....",
        "KFFKFFFFFFFFFFFFFK....",
        ".KKFFFFFFFFFFFFFFFKKKK",
        "...KDFFFFFFFFFFFLLFFFK",
        "..KDDKKKKKKKKKKKKKKKK.",
        ".KKKK................."
    ],
    stretch: [
        "KK..................",
        "KFK.................",
        ".KFKKKK.............",
        "..KFFFFKKK..........",
        "..KFFFFFFFKKK.......",
        "..KDFFFFFFFFFKK.....",
        "...KDDFFFFFFFFFKKK..",
        "...KFFKKKKKKKKFFFFFK",
        "...KKKK.......KKKKKK"
    ],
    paw:   ["KLK", "KKK"],
    pawUp: ["KLK", "KLK", "KKK"],
    groomPaw: ["KLLK", "KLPK", "KKKK"],
    groomPawUp: ["KLLK", "KLLK", "KLPK", "KKKK"],
    tongue: ["T", "T"],
    glasses: [
        ".GGGG.GGGG.",
        "GGggGGGggGG",
        ".GggG.GggG.",
        ".GGGG.GGGG."
    ],
    lid: [
        "KKKKKKKKKKKKKKK",
        "KCCCCCCCCCCCCCK",
        "KCCCCCCCCCCCCCK",
        "KCCCCCCMCCCCCCK",
        "KCCCCCCCCCCRRCK",
        "KCCCCCCCCCCRRCK",
        "KKKKKKKKKKKKKKK",
        ".KKKKKKKKKKKKK."
    ],
    phones: [
        "...HHHHHHHHH...",
        "..H.........H..",
        ".H...........H.",
        ".H...........H.",
        "HHH.........HHH",
        "HhH.........HhH",
        "HhH.........HhH",
        "HHH.........HHH"
    ],
    umbrella: [
        ".....UUUUU.....",
        "...UUUUUUUUU...",
        ".UUUUUUUUUUUUU.",
        "UuUuUuUuUuUuUuU",
        ".......S.......",
        ".......S.......",
        ".......S.......",
        ".......S.......",
        ".......S.......",
        ".......S......."
    ],
    laptop: [
        ".......KK",
        ".......Kc",
        "......Kc.",
        "......Kc.",
        ".....Kc..",
        ".....Kc..",
        "KKKKKKKKK",
        "KCCCCCCCK",
        "KKKKKKKKK"
    ],
    sweat: [".A", "AA", "AA"],
    z1: ["ZZZ", "..Z", ".Z.", "ZZZ"],
    bit0: ["ZZZ", "Z.Z", "Z.Z", "ZZZ"],
    bit1: [".Z.", "ZZ.", ".Z.", "ZZZ"],
    z2: ["ZZZZ", "..Z.", ".Z..", "ZZZZ"],
    heart: [".R.R.", "RWRRR", ".RRR.", "..R.."],
    star: [".Y.", "YYY", ".Y."],
    sparkle: [".M.", "MYM", ".M."],
    note: ["..N.", "..NN", "..N.", "NNN.", "NN.."],
    bang: ["YY", "YY", "YY", "YY", "..", "YY"],
    crumb: ["x"],
    drop: ["A", "A"],
    fish: [
        "K...KKKK.",
        "KK.KXXXXK",
        "KXKXXXXKX",
        "KK.KxxxxK",
        "K...KKKK."
    ]
};

var _parsed = {};

function buildHead(face) {
    var f = FACES[face] || FACES.normal;
    var out = HEAD_BASE.slice();
    var e = EYES[f[0]] || EYES.normal;
    var m = MOUTHS[f[1]] || MOUTHS.normal;
    for (var k in e) out[parseInt(k)] = e[k];
    for (var j in m) out[parseInt(j)] = m[j];
    if (f[2]) out[7] = "KP" + out[7].substring(2, 11) + "PK";
    return out;
}

function sprite(name) {
    var c = _parsed[name];
    if (c) return c;
    var rows = name.indexOf("head:") === 0 ? buildHead(name.substring(5)) : SPR[name];
    if (!rows) return null;
    var runs = [];
    var w = 0;
    for (var y = 0; y < rows.length; y++) {
        var r = rows[y];
        if (r.length > w) w = r.length;
        var x = 0;
        while (x < r.length) {
            var key = r[x];
            if (key === "." || key === " ") { x++; continue; }
            var s = x;
            while (x < r.length && r[x] === key) x++;
            runs.push([y, s, x - s, key]);
        }
    }
    c = { w: w, h: rows.length, runs: runs };
    _parsed[name] = c;
    return c;
}

// walk leg layout per frame: [farBack, farFront, nearBack, nearFront] as [x, lifted]
var WALK = [
    [[3, 0], [11, 0], [0, 0], [8, 0]],
    [[2, 1], [10, 0], [1, 0], [9, 1]],
    [[1, 0], [9, 0], [2, 0], [10, 0]],
    [[2, 0], [10, 1], [1, 1], [9, 0]]
];
var RUN = [
    [[0, 0], [12, 0], [2, 1], [10, 1]],
    [[3, 1], [8, 1], [4, 0], [9, 0]]
];

// st: { pose, frame, face, facing, glasses, phones, umbrella, sweat, tongue, bob, fx: [{g, dx, dy}] }
function scene(st) {
    var d = [];
    var pose = st.pose || "sit";
    var frame = st.frame || 0;
    var face = st.face || "normal";
    var hx = 0, hy = 0;
    var headOn = true;
    var accOk = true;
    var tongue = !!st.tongue || face === "pant";

    function add(name, x, y) {
        var sp = sprite(name);
        if (sp) d.push([sp, x, y, false, name]);
    }

    function legs(tx, ty, layout, shortLegs) {
        var fb = layout[0], ff = layout[1], nb = layout[2], nf = layout[3];
        var farName = function(l) { return shortLegs ? "legFs" : (l[1] ? "legFu" : "legF"); };
        var nearName = function(l) { return shortLegs ? "legNs" : (l[1] ? "legNu" : "legN"); };
        return {
            far: [[farName(fb), tx + fb[0], ty + 6], [farName(ff), tx + ff[0], ty + 6]],
            near: [[nearName(nb), tx + nb[0], ty + 6], [nearName(nf), tx + nf[0], ty + 6]]
        };
    }

    if (pose === "walk" || pose === "run" || pose === "stand" || pose === "stumble" || pose === "crouch" || pose === "eat") {
        var tx = 16, ty = 30;
        var layout = WALK[0];
        var shortLegs = false;
        var tail = (frame % 2 === 0) ? "tailA" : "tailB";
        if (pose === "walk") {
            layout = WALK[frame % 4];
            tail = (Math.floor(frame / 2) % 2 === 0) ? "tailA" : "tailB";
        } else if (pose === "run") {
            layout = RUN[frame % 2];
            ty = (frame % 2 === 0) ? 29 : 30;
            tail = "tailRun";
        } else if (pose === "stumble") {
            layout = [[-1, 0], [13, 0], [0, 0], [12, 0]];
            ty = 31;
        } else if (pose === "crouch" || pose === "eat") {
            ty = 32;
            shortLegs = true;
        }
        var lg = legs(tx, ty, layout, shortLegs);
        if (tail === "tailRun") add(tail, tx - 6, ty - 1);
        else add(tail, tx - 3, ty - 7);
        add(lg.far[0][0], lg.far[0][1], lg.far[0][2]);
        add(lg.far[1][0], lg.far[1][1], lg.far[1][2]);
        add("torso", tx, ty);
        add(lg.near[0][0], lg.near[0][1], lg.near[0][2]);
        add(lg.near[1][0], lg.near[1][1], lg.near[1][2]);
        hx = tx + 7;
        hy = ty - 7;
        if (pose === "stumble") hx -= 1;
        if (pose === "crouch") { hx = tx + 8; hy = ty - 6; }
        if (pose === "eat") { hx = tx + 9; hy = ty - 3; accOk = false; }
    } else if (pose === "sit" || pose === "type" || pose === "groom" || pose === "dance") {
        var sx = 17, sy = 29;
        add((frame % 2 === 0) ? "tailFloor" : "tailFloorB", sx - 5, sy + 6);
        add("sit", sx, sy);
        hx = sx + 1;
        hy = sy - 7 + (st.bob || 0);
    } else if (pose === "loaf" || pose === "sleep") {
        var lx = 15, ly = 33;
        add(frame % 2 === 0 ? "loafA" : "loafB", lx, ly);
        add("tailLoaf", lx - 1, ly + 4);
        hx = lx + 7;
        hy = ly - 5 + (frame % 2 === 0 ? 0 : 1);
        accOk = false;
    } else if (pose === "flop") {
        var fx0 = 14, fy0 = 34;
        add("flop", fx0, fy0);
        add("flopLegs", fx0 + 16, fy0 + 2);
        hx = fx0 + 11;
        hy = fy0 - 5;
        accOk = false;
    } else if (pose === "dangle") {
        var dx0 = 19, dy0 = 27;
        add("tailHang", dx0 - 2, dy0 + 6 + (frame % 2));
        add("dangle", dx0, dy0);
        hx = dx0 - 1;
        hy = dy0 - 9;
        accOk = false;
    } else if (pose === "leap") {
        var lpx = 13, lpy = 32;
        add("leap", lpx, lpy);
        hx = lpx + 11;
        hy = lpy - 6;
        accOk = false;
    } else if (pose === "stretch") {
        var stx = 14, sty = 31;
        add("stretch", stx, sty);
        hx = stx + 9;
        hy = sty - 2;
        accOk = false;
    } else {
        headOn = true;
        hx = 18;
        hy = 22;
    }

    if (accOk && st.umbrella) {
        var um = sprite("umbrella");
        d.splice(0, 0, [um, hx - 1, hy - 9, false, "umbrella"]);
    }
    if (headOn) add("head:" + face, hx, hy);
    if (tongue || (pose === "groom" && frame % 2 === 0)) add("tongue", hx + 6, hy + 9);
    if (pose === "groom") add(frame % 2 === 0 ? "groomPawUp" : "groomPaw", hx + 8, hy + 7 + (frame % 2 === 0 ? 0 : 1));
    if (accOk && st.glasses) add("glasses", hx + 1, hy + 4);
    if (st.phones && pose !== "sleep" && pose !== "loaf" && pose !== "eat") add("phones", hx - 1, hy - 1);
    if (st.sweat) add("sweat", hx + 11, hy + 1);
    if (pose === "type") {
        add("lid", hx - 1, hy + 10);
        var up = frame % 2 === 0;
        add("paw", hx - 1, hy + 9 + (up ? -1 : 0));
        add("paw", hx + 11, hy + 9 + (up ? 0 : -1));
    }

    var facing = (st.facing === undefined || st.facing >= 0) ? 1 : -1;
    var minX = 999, minY = 999, maxX = -999, maxY = -999;
    for (var i = 0; i < d.length; i++) {
        var it = d[i];
        if (facing < 0) {
            it[1] = CW - it[1] - it[0].w;
            it[3] = true;
        }
        if (it[4] !== "umbrella" && it[4] !== "laptop") {
            minX = Math.min(minX, it[1]);
            minY = Math.min(minY, it[2]);
            maxX = Math.max(maxX, it[1] + it[0].w);
            maxY = Math.max(maxY, it[2] + it[0].h);
        }
    }

    var headCX = facing > 0 ? hx + 6.5 : CW - hx - 6.5;
    var fx = st.fx || [];
    for (var f = 0; f < fx.length; f++) {
        var g = sprite(fx[f].g);
        if (!g) continue;
        var gx = Math.round(headCX + facing * (fx[f].dx || 0) - g.w / 2);
        var gy = Math.round(hy + (fx[f].dy || 0));
        d.push([g, gx, gy, false, "fx"]);
    }

    return {
        draws: d,
        hit: { x: minX, y: minY, w: maxX - minX, h: maxY - minY },
        head: { x: headCX, y: hy },
        cw: CW,
        ch: CH
    };
}

// Small scene for the bar bed: cushion with (optionally) the sleeping cat, plus treat fish.
var BED = {
    back: [
        "....KKKKKKKKKKKKKKKK....",
        "..KKBBBBBBBBBBBBBBBBKK..",
        ".KBBbbbbbbbbbbbbbbbbBBK.",
        "KBBb................bBBK"
    ],
    front: [
        "KBBb................bBBK",
        "KBBBbbbbbbbbbbbbbbbbBBBK",
        "KBOBBBOBBBOBBBOBBBOBBOBK",
        ".KBBBBBBBBBBBBBBBBBBBBK.",
        "..KKKKKKKKKKKKKKKKKKKK.."
    ]
};

SPR.bedBack = BED.back;
SPR.bedFront = BED.front;

var BED_W = 32;
var BED_H = 16;
// where the cat's body sits in the bed scene (sprite px), used to aim the jump into bed
var BED_SEAT = { x: 16, y: 8 };

function bedScene(st) {
    var d = [];
    var bx = 3, by = 8;
    var frame = st.frame || 0;
    var hx = bx + 10;
    var hy = by - 7 + (frame % 2 === 0 ? 0 : 1);
    d.push([sprite("bedBack"), bx, by, false, "bed"]);
    if (st.home) {
        d.push([sprite(frame % 2 === 0 ? "loafA" : "loafB"), bx + 3, by - 2, false, "cat"]);
        d.push([sprite("head:" + (st.face || "sleep")), hx, hy, false, "cat"]);
    }
    d.push([sprite("bedFront"), bx, by + 3, false, "bed"]);
    var fx = st.fx || [];
    for (var f = 0; f < fx.length; f++) {
        var g = sprite(fx[f].g);
        if (g) d.push([g, Math.round(hx + 6.5 + (fx[f].dx || 0) - g.w / 2), Math.round(hy + (fx[f].dy || 0)), false, "fx"]);
    }
    return { draws: d, hit: { x: 0, y: 0, w: BED_W, h: BED_H }, head: { x: hx + 6.5, y: hy }, cw: BED_W, ch: BED_H };
}

function fishScene() {
    var f = sprite("fish");
    return { draws: [[f, 0, 0, false, "fish"]], hit: { x: 0, y: 0, w: f.w, h: f.h }, head: { x: 0, y: 0 }, cw: f.w, ch: f.h };
}

function paint(ctx, sc, pal, px) {
    var draws = sc.draws;
    for (var i = 0; i < draws.length; i++) {
        var dr = draws[i];
        var sp = dr[0], ox = dr[1], oy = dr[2], flip = dr[3];
        var runs = sp.runs;
        for (var j = 0; j < runs.length; j++) {
            var r = runs[j];
            var col = pal[r[3]];
            if (!col) continue;
            var x = flip ? (sp.w - r[1] - r[2]) : r[1];
            ctx.fillStyle = col;
            ctx.fillRect((ox + x) * px, (oy + r[0]) * px, r[2] * px, px);
        }
    }
}

function _rgb(c) {
    var h = String(c || "#000000");
    if (h.charAt(0) === "#") h = h.substring(1);
    if (h.length === 8) h = h.substring(2);
    if (h.length !== 6) return [0, 0, 0];
    return [parseInt(h.substring(0, 2), 16), parseInt(h.substring(2, 4), 16), parseInt(h.substring(4, 6), 16)];
}

function _hex(v) {
    var s = "#";
    for (var i = 0; i < 3; i++) {
        var n = Math.round(Math.max(0, Math.min(255, v[i])));
        s += (n < 16 ? "0" : "") + n.toString(16);
    }
    return s;
}

function mix(a, b, t) {
    var x = _rgb(a), y = _rgb(b);
    return _hex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t]);
}

function luminance(c) {
    var v = _rgb(c);
    return (0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]) / 255;
}

// t: { fur, bed, phones, umbrella, text, base }
function makePalette(t) {
    var fur = t.fur || "#adc6ff";
    var outline = mix(fur, "#000000", 0.72);
    var phones = t.phones || "#debcdf";
    var umbrella = t.umbrella || "#ffb4ab";
    var bed = t.bed || "#debcdf";
    var text = t.text || "#e2e2e9";
    var base = t.base || "#0c0e13";
    return {
        K: outline,
        F: fur,
        D: mix(fur, "#000000", 0.22),
        L: mix(fur, "#ffffff", 0.5),
        P: mix("#ff9fb2", fur, 0.2),
        W: "#ffffff",
        E: mix(fur, "#000000", 0.86),
        T: "#ff7b93",
        G: mix(fur, "#000000", 0.8),
        g: "rgba(255,255,255,0.3)",
        H: mix(phones, "#000000", 0.15),
        h: mix(phones, "#ffffff", 0.45),
        U: umbrella,
        u: mix(umbrella, "#000000", 0.25),
        S: outline,
        C: mix(base, text, 0.55),
        c: mix(text, "#9fe8ff", 0.5),
        R: "#ff5f7e",
        Y: "#ffd166",
        Z: text,
        A: "#7cc7ff",
        X: "#ff9f5a",
        x: "#d9733a",
        N: text,
        B: bed,
        b: mix(bed, "#000000", 0.22),
        O: mix(bed, "#ffffff", 0.55),
        M: "#ffffff"
    };
}
