.pragma library

var SEVERITIES = ["moderate", "severe", "extreme"];
var HAZARDS = ["generic", "rain", "flood", "snow", "ice", "storm", "wind", "fog", "heat", "cold", "fire", "dust", "marine"];

var FORECAST = {
    rain_soon: { sky: "overcast", cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "mid" }, rain: { top: 0.62, n: 8 } },
    heavy_rain: { sky: "storm", cloud: { x: 0.5, y: 0.42, s: 0.86, tone: "dark" }, rain: { top: 0.62, n: 14, heavy: true } },
    thunderstorm: { sky: "storm", cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, rain: { top: 0.65, n: 9 }, bolt: { x: 0.52, y: 0.78, s: 0.34 } },
    snow_soon: { sky: "snow", cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "light" }, snow: { top: 0.62, n: 8 } },
    heavy_snow: { sky: "overcast", cloud: { x: 0.5, y: 0.42, s: 0.86, tone: "mid" }, snow: { top: 0.62, n: 14, heavy: true } },
    ice: { sky: "ice", ground: "ice", crystal: { x: 0.5, y: 0.46, s: 0.6 }, crystals: [{ x: 0.2, y: 0.26, s: 0.2 }, { x: 0.8, y: 0.66, s: 0.2 }] },
    fog: { sky: "fog", cloud: { x: 0.5, y: 0.34, s: 0.76, tone: "light" }, fog: true },
    temp_rise: { sky: "warm", sun: { x: 0.32, y: 0.34, s: 0.5 }, thermo: { x: 0.68, y: 0.52, s: 0.6, dir: 1 } },
    temp_drop: { sky: "cold", crystal: { x: 0.32, y: 0.34, s: 0.4 }, thermo: { x: 0.68, y: 0.52, s: 0.6, dir: -1 } },
    hot: { sky: "heat", sun: { x: 0.5, y: 0.5, s: 0.74, tone: "hot", rays: 12 } },
    cold: { sky: "cold", crystal: { x: 0.5, y: 0.5, s: 0.62 }, snow: { top: 0, n: 7, light: true } },
    wind: { sky: "breeze", cloud: { x: 0.3, y: 0.28, s: 0.5, tone: "light" }, wind: { x: 0.52, y: 0.56, s: 0.8 } },
    uv: { sky: "uv", sun: { x: 0.5, y: 0.5, s: 0.74, tone: "uv", rays: 12 } },
    air_quality: { sky: "haze", sun: { x: 0.5, y: 0.46, s: 0.6, tone: "dim" }, particles: { n: 16 } },
    daily_clear: { sky: "clear", sun: { x: 0.5, y: 0.5, s: 0.7 } },
    daily_cloudy: { sky: "clear", sun: { x: 0.34, y: 0.34, s: 0.5 }, cloud: { x: 0.58, y: 0.58, s: 0.76, tone: "light" } },
    daily_rain: { sky: "overcast", sun: { x: 0.26, y: 0.26, s: 0.4, tone: "dim" }, cloud: { x: 0.5, y: 0.46, s: 0.8, tone: "mid" }, rain: { top: 0.62, n: 8 } },
    daily_snow: { sky: "snow", sun: { x: 0.26, y: 0.26, s: 0.4, tone: "dim" }, cloud: { x: 0.5, y: 0.46, s: 0.8, tone: "light" }, snow: { top: 0.62, n: 8 } },
    daily_storm: { sky: "storm", cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, rain: { top: 0.65, n: 9 }, bolt: { x: 0.52, y: 0.78, s: 0.34 } },
    daily_fog: { sky: "fog", cloud: { x: 0.5, y: 0.34, s: 0.76, tone: "light" }, fog: true }
};

var HAZARD = {
    generic: {},
    rain: { cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "dark" }, rain: { top: 0.62, n: 8 } },
    flood: { cloud: { x: 0.5, y: 0.28, s: 0.72, tone: "dark" }, rain: { top: 0.4, n: 7 }, waves: { x: 0.5, y: 0.6, s: 1.0 } },
    snow: { cloud: { x: 0.5, y: 0.44, s: 0.8, tone: "mid" }, snow: { top: 0.62, n: 8 } },
    ice: { crystal: { x: 0.5, y: 0.5, s: 0.62 } },
    storm: { cloud: { x: 0.5, y: 0.4, s: 0.86, tone: "dark" }, bolt: { x: 0.52, y: 0.78, s: 0.34 } },
    wind: { wind: { x: 0.5, y: 0.5, s: 0.84 } },
    fog: { cloud: { x: 0.5, y: 0.34, s: 0.76, tone: "mid" }, fog: true },
    heat: { sun: { x: 0.5, y: 0.5, s: 0.76, tone: "hot", rays: 12 } },
    cold: { crystal: { x: 0.5, y: 0.5, s: 0.62 } },
    fire: { flame: { x: 0.5, y: 0.5, s: 0.7 } },
    dust: { sun: { x: 0.5, y: 0.42, s: 0.6, tone: "dim" }, particles: { n: 16, dust: true } },
    marine: { waves: { x: 0.5, y: 0.56, s: 1.0 }, wind: { x: 0.5, y: 0.32, s: 0.5 } }
};

var OFFSET = {
    forecast: { rain_soon: [0, -0.035], snow_soon: [0, -0.04], heavy_rain: [0, -0.025], heavy_snow: [0, -0.025], thunderstorm: [0, -0.01], ice: [0, 0.04], temp_rise: [-0.025, 0.05], temp_drop: [-0.055, 0.02], hot: [0, 0], cold: [0, 0], wind: [0.015, -0.03], uv: [0, 0], daily_clear: [0, 0], daily_cloudy: [-0.03, 0.015], daily_rain: [0.025, -0.025], daily_snow: [0.025, -0.025], daily_storm: [0, -0.01] },
    hazard: { moderate_rain: [-0.03, -0.015], moderate_flood: [0, -0.02], moderate_snow: [-0.03, -0.015], moderate_ice: [-0.085, -0.09], moderate_storm: [-0.02, 0.01], moderate_wind: [-0.035, -0.05], moderate_heat: [-0.045, -0.045], moderate_cold: [-0.085, -0.09], moderate_fire: [-0.085, -0.065], moderate_marine: [0, -0.03], severe_rain: [-0.05, -0.02], severe_flood: [0, -0.02], severe_snow: [-0.05, -0.02], severe_ice: [-0.105, -0.095], severe_storm: [-0.04, 0.005], severe_wind: [-0.055, -0.055], severe_heat: [-0.065, -0.05], severe_cold: [-0.105, -0.095], severe_fire: [-0.11, -0.07], severe_marine: [0, -0.03], extreme_rain: [-0.055, -0.03], extreme_flood: [0, -0.02], extreme_snow: [-0.055, -0.03], extreme_ice: [-0.11, -0.105], extreme_storm: [-0.045, -0.005], extreme_wind: [-0.06, -0.065], extreme_heat: [-0.065, -0.065], extreme_cold: [-0.11, -0.105], extreme_fire: [-0.11, -0.08], extreme_marine: [0, -0.03], moderate_dust: [-0.045, -0.045], severe_dust: [-0.065, -0.05], extreme_dust: [-0.065, -0.065] }
};

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
        out.off = OFFSET.hazard[g.sev + "_" + g.hazard] || [0, 0];
        out.shield = empty ? { x: 0.5, y: 0.5, s: 0.72 } : { x: 0.72, y: 0.7, s: 0.52 };
        return out;
    }
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
    fog: { a: "#8a959f", b: "#cdd3d7", glow: "#e1e6e9", mood: "soft" },
    heat: { a: "#e8662f", b: "#ffd078", glow: "#ffb347", mood: "glow" },
    warm: { a: "#f0905a", b: "#ffdfa6", glow: "#ffc27a", mood: "glow" },
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
