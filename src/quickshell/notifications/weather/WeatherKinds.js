.pragma library

var SEVERITIES = ["moderate", "severe", "extreme"];
var HAZARDS = ["generic", "rain", "flood", "snow", "ice", "storm", "wind", "fog", "heat", "cold", "fire", "dust", "marine"];

var FORECAST = {
    rain_soon: { sky: "overcast", cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "mid" }, rain: { top: 0.62, n: 12 } },
    heavy_rain: { sky: "storm", cloud: { x: 0.5, y: 0.42, s: 0.86, tone: "dark" }, rain: { top: 0.62, n: 16, heavy: true } },
    thunderstorm: { sky: "storm", cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, rain: { top: 0.65, n: 12 }, bolt: { x: 0.5, y: 0.782, s: 0.2 } },
    snow_soon: { sky: "snow", cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "light" }, snow: { top: 0.62, n: 8 } },
    heavy_snow: { sky: "overcast", cloud: { x: 0.5, y: 0.42, s: 0.86, tone: "mid" }, snow: { top: 0.62, n: 14, heavy: true } },
    ice: { sky: "ice", ground: "ice", crystal: { x: 0.5, y: 0.46, s: 0.6 }, crystals: [{ x: 0.2, y: 0.26, s: 0.2 }, { x: 0.8, y: 0.66, s: 0.2 }] },
    fog: { sky: "fog", cloud: { x: 0.5, y: 0.3, s: 0.72, tone: "light" }, fog: true },
    temp_rise: { sky: "warm", sun: { x: 0.2, y: 0.5, s: 0.36, tone: "hot" }, thermo: { x: 0.5, y: 0.53, s: 0.8, dir: 1 } },
    temp_drop: { sky: "cold", crystal: { x: 0.2, y: 0.5, s: 0.3 }, thermo: { x: 0.5, y: 0.53, s: 0.8, dir: -1 } },
    hot: { sky: "heat", sun: { x: 0.5, y: 0.5, s: 0.74, tone: "hot" } },
    cold: { sky: "cold", crystal: { x: 0.5, y: 0.5, s: 0.62 }, snow: { top: 0, n: 7, light: true } },
    wind: { sky: "breeze", cloud: { x: 0.3, y: 0.28, s: 0.5, tone: "light" }, wind: { x: 0.5, y: 0.62, s: 0.86 } },
    uv: { sky: "uv", sun: { x: 0.5, y: 0.5, s: 0.74, tone: "uv" } },
    air_quality: { sky: "haze", sun: { x: 0.5, y: 0.46, s: 0.6, tone: "dim" }, particles: { n: 16 } },
    daily_clear: { sky: "clear", sun: { x: 0.5, y: 0.5, s: 0.7 } },
    daily_cloudy: { sky: "clear", sun: { x: 0.34, y: 0.34, s: 0.5 }, cloud: { x: 0.58, y: 0.58, s: 0.76, tone: "light" } },
    daily_rain: { sky: "overcast", sun: { x: 0.26, y: 0.26, s: 0.4, tone: "dim" }, cloud: { x: 0.5, y: 0.46, s: 0.8, tone: "mid" }, rain: { top: 0.62, n: 12 } },
    daily_snow: { sky: "snow", sun: { x: 0.26, y: 0.26, s: 0.4, tone: "dim" }, cloud: { x: 0.5, y: 0.46, s: 0.8, tone: "light" }, snow: { top: 0.62, n: 8 } },
    daily_storm: { sky: "storm", cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, rain: { top: 0.65, n: 12 }, bolt: { x: 0.5, y: 0.782, s: 0.2 } },
    daily_fog: { sky: "fog", cloud: { x: 0.5, y: 0.3, s: 0.72, tone: "light" }, fog: true }
};

var HAZARD = {
    generic: {},
    rain: { cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "dark" }, rain: { top: 0.62, n: 12 } },
    flood: { cloud: { x: 0.5, y: 0.28, s: 0.72, tone: "dark" }, rain: { top: 0.4, n: 10 }, waves: { x: 0.5, y: 0.6, s: 1.0 } },
    snow: { cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "mid" }, snow: { top: 0.62, n: 8 } },
    ice: { crystal: { x: 0.5, y: 0.5, s: 0.62 } },
    storm: { cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, bolt: { x: 0.5, y: 0.782, s: 0.2 } },
    wind: { wind: { x: 0.5, y: 0.5, s: 0.84 } },
    fog: { cloud: { x: 0.5, y: 0.3, s: 0.72, tone: "mid" }, fog: true },
    heat: { sun: { x: 0.5, y: 0.5, s: 0.76, tone: "hot" } },
    cold: { crystal: { x: 0.5, y: 0.5, s: 0.62 } },
    fire: { flame: { x: 0.5, y: 0.5, s: 0.7 } },
    dust: { sun: { x: 0.5, y: 0.42, s: 0.6, tone: "dim" }, particles: { n: 16, dust: true } },
    marine: { waves: { x: 0.5, y: 0.56, s: 1.0 }, wind: { x: 0.44, y: 0.3, s: 0.7 } }
};

var OFFSET = {
    forecast: { rain_soon: [0, -0.035], snow_soon: [0, -0.04], heavy_rain: [0, -0.025], heavy_snow: [0, -0.025], thunderstorm: [0, -0.01], ice: [0, 0.04], hot: [0, 0], cold: [0, 0], wind: [0.015, -0.03], uv: [0, 0], daily_clear: [0, 0], daily_cloudy: [-0.03, 0.015], daily_rain: [0.025, -0.025], daily_snow: [0.025, -0.025], daily_storm: [0, -0.01] },
    hazard: [0.02, 0.02]
};

var SUN = { x: 0.34, y: 0.34, s: 0.5 };
var SUN_DIM = { x: 0.28, y: 0.28, s: 0.4, tone: "dim" };
var MOON = { x: 0.34, y: 0.34, s: 0.5 };
var MOON_DIM = { x: 0.28, y: 0.28, s: 0.4 };

function wmoScene(code, night) {
    var body = function (sun, moon) { return night ? { moon: moon } : { sun: sun }; };
    var cloud = function (y, tone) { return { x: 0.5, y: y, s: 0.8, tone: tone }; };
    var corner = { x: 0.58, y: 0.58, s: 0.76, tone: "light" };
    var scene;
    switch (code) {
    case 0: scene = night ? { moon: { x: 0.5, y: 0.5, s: 0.7 } } : { sun: { x: 0.5, y: 0.5, s: 0.74 } }; break;
    case 1: scene = body({ x: 0.4, y: 0.4, s: 0.62 }, { x: 0.4, y: 0.4, s: 0.62 }); scene.cloud = { x: 0.66, y: 0.66, s: 0.5, tone: "light" }; break;
    case 2: scene = body(SUN, MOON); scene.cloud = corner; break;
    case 3: scene = { cloud: { x: 0.5, y: 0.5, s: 0.86, tone: "mid" } }; break;
    case 45: case 48: scene = { cloud: { x: 0.5, y: 0.3, s: 0.72, tone: "light" }, fog: true }; break;
    case 51: case 53: case 55: scene = { cloud: cloud(0.44, "light"), rain: { top: 0.62, n: code === 55 ? 8 : 5 } }; break;
    case 56: case 57: scene = { cloud: cloud(0.4, "mid"), rain: { top: 0.6, n: 6 }, crystals: [{ x: 0.2, y: 0.8, s: 0.2 }, { x: 0.8, y: 0.8, s: 0.2 }] }; break;
    case 61: scene = { cloud: cloud(0.44, "mid"), rain: { top: 0.62, n: 6 } }; break;
    case 63: scene = { cloud: cloud(0.44, "mid"), rain: { top: 0.62, n: 10 } }; break;
    case 65: scene = { cloud: cloud(0.42, "dark"), rain: { top: 0.62, n: 16, heavy: true } }; break;
    case 66: case 67: scene = { cloud: cloud(0.4, "dark"), rain: { top: 0.6, n: 8 }, crystals: [{ x: 0.2, y: 0.8, s: 0.2 }, { x: 0.8, y: 0.8, s: 0.2 }] }; break;
    case 71: scene = { cloud: cloud(0.44, "light"), snow: { top: 0.62, n: 5 } }; break;
    case 73: scene = { cloud: cloud(0.44, "light"), snow: { top: 0.62, n: 8 } }; break;
    case 75: scene = { cloud: cloud(0.42, "mid"), snow: { top: 0.62, n: 14, heavy: true } }; break;
    case 77: scene = { cloud: cloud(0.44, "light"), snow: { top: 0.62, n: 10, light: true } }; break;
    case 80: case 81: scene = body(SUN_DIM, MOON_DIM); scene.cloud = { x: 0.5, y: 0.46, s: 0.8, tone: "mid" }; scene.rain = { top: 0.62, n: code === 80 ? 6 : 10 }; break;
    case 82: scene = { cloud: cloud(0.42, "dark"), rain: { top: 0.62, n: 16, heavy: true } }; break;
    case 85: scene = body(SUN_DIM, MOON_DIM); scene.cloud = { x: 0.5, y: 0.46, s: 0.8, tone: "light" }; scene.snow = { top: 0.62, n: 6 }; break;
    case 86: scene = { cloud: cloud(0.42, "mid"), snow: { top: 0.62, n: 14, heavy: true } }; break;
    case 95: case 96: case 99: scene = { cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, rain: { top: 0.65, n: code === 95 ? 10 : 14 }, bolt: { x: 0.5, y: 0.782, s: 0.2 } }; break;
    default: return null;
    }
    return scene;
}

function parseWmo(kind) {
    var m = /^wmo_(\d+)(_n)?$/.exec(kind);
    if (!m) return null;
    var scene = wmoScene(parseInt(m[1], 10), !!m[2]);
    if (!scene) return null;
    scene.gov = false;
    scene.sev = "";
    scene.sky = "clear";
    scene.off = [0, 0];
    return scene;
}

var FALLBACK = FORECAST.daily_cloudy;

function parseGov(kind) {
    var rest = kind.substring(4);
    var parts = rest.split("_");
    var sev = "moderate";
    var hazard = "generic";
    if (parts.length > 0 && SEVERITIES.indexOf(parts[0]) !== -1) {
        sev = parts.shift();
    }
    var h = parts.join("_");
    if (h !== "" && HAZARDS.indexOf(h) !== -1) {
        hazard = h;
    }
    return { sev: sev, hazard: hazard };
}

function resolve(kind) {
    kind = (kind || "").toString();
    if (kind.indexOf("gov") === 0 && (kind === "gov" || kind.indexOf("gov_") === 0)) {
        var g = parseGov(kind);
        var scene = HAZARD[g.hazard];
        var empty = Object.keys(scene).length === 0;
        var out = { gov: true, sev: g.sev, hazard: g.hazard, sky: "gov" };
        for (var k in scene) out[k] = scene[k];
        out.off = OFFSET.hazard;
        out.shield = empty ? { x: 0.5, y: 0.5, s: 0.72 } : { x: 0.74, y: 0.70, s: 0.44 };
        return out;
    }
    var wmo = parseWmo(kind);
    if (wmo) return wmo;
    var f = FORECAST[kind];
    var spec = {};
    var src = f || FALLBACK;
    for (var key in src) spec[key] = src[key];
    spec.gov = false;
    spec.off = OFFSET.forecast[kind] || [0, 0];
    spec.sev = "";
    if (!spec.sky) spec.sky = "clear";
    return spec;
}

var PALETTE = {
    clear: { a: "#3f95ec", b: "#bfe4ff", glow: "#ffe07a", mood: "glow" },
    overcast: { a: "#667589", b: "#aebbc8", glow: "#c5d0dc", mood: "soft" },
    storm: { a: "#2b3345", b: "#5b667c", glow: "#7c88a6", mood: "moody" },
    fog: { a: "#76828e", b: "#a7b0b9", glow: "#e1e6e9", mood: "soft" },
    heat: { a: "#e8662f", b: "#ffd078", glow: "#ffb347", mood: "glow" },
    warm: { a: "#c9482a", b: "#ee8a4f", glow: "#ffc27a", mood: "glow" },
    cold: { a: "#4f93d2", b: "#dff2ff", glow: "#bfe6ff", mood: "cool" },
    ice: { a: "#5fb8dc", b: "#eaf9ff", glow: "#dff6ff", mood: "cool" },
    snow: { a: "#8aa0ba", b: "#e9f0f8", glow: "#e9f0f8", mood: "cool" },
    breeze: { a: "#5d9bc9", b: "#c6e3f2", glow: "#b9dff0", mood: "cool" },
    uv: { a: "#5a73dc", b: "#f7c47e", glow: "#f7c47e", mood: "glow" },
    haze: { a: "#9a8660", b: "#dccaa2", glow: "#d6bd86", mood: "soft" },
    gov_moderate: { a: "#2a2530", b: "#745214", glow: "#ffc22e", mood: "alert" },
    gov_severe: { a: "#2a2230", b: "#8a4015", glow: "#ff8226", mood: "alert" },
    gov_extreme: { a: "#2a1f2b", b: "#8a1f26", glow: "#ff3d3d", mood: "alert" }
};

var CARD_STRENGTH = {
    scene: 0.2,
    moderate: 0.24,
    severe: 0.28,
    extreme: 0.34
};

function palette(sky, sev) {
    if (sky === "gov") {
        return PALETTE["gov_" + (sev === "extreme" || sev === "severe" ? sev : "moderate")];
    }
    return PALETTE[sky] || PALETTE.clear;
}

function skyColors(sky, sev) {
    var p = palette(sky, sev);
    return [p.a, p.b];
}

function severityColor(sev) {
    return PALETTE["gov_" + (sev === "extreme" || sev === "severe" ? sev : "moderate")].glow;
}

function card(kind) {
    var spec = resolve(kind);
    var p = palette(spec.sky, spec.sev);
    var gov = spec.gov === true;
    return {
        left: gov ? p.b : p.a,
        right: gov ? p.glow : p.b,
        glow: p.glow,
        dark: p.a,
        mood: p.mood,
        strength: gov ? CARD_STRENGTH[spec.sev] : CARD_STRENGTH.scene,
        gov: gov
    };
}
