.pragma library

var CATEGORIES = ["currency", "length", "mass", "temperature", "volume", "area", "speed", "time", "data"];

var UNITS = {
    length: [
        ["mm", 0.001], ["cm", 0.01], ["m", 1], ["km", 1000],
        ["in", 0.0254], ["ft", 0.3048], ["yd", 0.9144], ["mi", 1609.344], ["nmi", 1852]
    ],
    mass: [
        ["mg", 0.000001], ["g", 0.001], ["kg", 1], ["t", 1000],
        ["oz", 0.028349523125], ["lb", 0.45359237], ["st", 6.35029318]
    ],
    temperature: [["°C", 0], ["°F", 0], ["K", 0]],
    volume: [
        ["mL", 0.001], ["L", 1], ["m³", 1000],
        ["tsp", 0.00492892159375], ["tbsp", 0.01478676478125], ["fl oz", 0.0295735295625],
        ["cup", 0.2365882365], ["pt", 0.473176473], ["qt", 0.946352946], ["gal", 3.785411784]
    ],
    area: [
        ["mm²", 0.000001], ["cm²", 0.0001], ["m²", 1], ["ha", 10000], ["km²", 1000000],
        ["in²", 0.00064516], ["ft²", 0.09290304], ["ac", 4046.8564224], ["mi²", 2589988.110336]
    ],
    speed: [
        ["m/s", 1], ["km/h", 1 / 3.6], ["mph", 0.44704], ["kn", 1852 / 3600], ["ft/s", 0.3048]
    ],
    time: [
        ["ms", 0.001], ["s", 1], ["min", 60], ["h", 3600], ["d", 86400],
        ["wk", 604800], ["mo", 2629746], ["yr", 31556952]
    ],
    data: [
        ["bit", 0.125], ["B", 1], ["KB", 1000], ["MB", 1000000], ["GB", 1000000000], ["TB", 1000000000000],
        ["KiB", 1024], ["MiB", 1048576], ["GiB", 1073741824], ["TiB", 1099511627776]
    ]
};

var DEFAULT_PAIR = {
    currency: ["USD", "EUR"],
    length: ["km", "mi"],
    mass: ["kg", "lb"],
    temperature: ["°C", "°F"],
    volume: ["L", "gal"],
    area: ["m²", "ft²"],
    speed: ["km/h", "mph"],
    time: ["h", "min"],
    data: ["GB", "MB"]
};

function parseRates(payload) {
    var rates = {};
    var names = {};
    var src = payload && payload.rates ? (payload.rates.usd || {}) : {};
    var labels = payload && payload.names ? payload.names : {};
    Object.keys(src).forEach(function (k) {
        var v = Number(src[k]);
        var code = k.toUpperCase();
        if (isFinite(v) && v > 0 && /^[A-Z0-9]{2,12}$/.test(code)) {
            rates[code] = v;
            names[code] = labels[k] || "";
        }
    });
    return { rates: rates, names: names };
}

function currencyCodes(rates) {
    return Object.keys(rates || {}).sort();
}

function currencyLabel(code, names) {
    var n = names ? names[code] : "";
    return n ? code + " — " + n : code;
}

function unitIds(category, rates) {
    if (category === "currency") return currencyCodes(rates);
    return (UNITS[category] || []).map(function (u) { return u[0]; });
}

function defaultPair(category) {
    return DEFAULT_PAIR[category] || ["", ""];
}

function factor(category, id) {
    var list = UNITS[category] || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i][0] === id) return list[i][1];
    }
    return NaN;
}

function toKelvin(id, v) {
    if (id === "°C") return v + 273.15;
    if (id === "°F") return (v - 32) * 5 / 9 + 273.15;
    return v;
}

function fromKelvin(id, k) {
    if (id === "°C") return k - 273.15;
    if (id === "°F") return (k - 273.15) * 9 / 5 + 32;
    return k;
}

function convert(category, from, to, value, rates) {
    if (isNaN(value)) return NaN;
    if (category === "currency") {
        var rf = rates ? rates[from] : undefined;
        var rt = rates ? rates[to] : undefined;
        if (!rf || !rt) return NaN;
        return value / rf * rt;
    }
    if (category === "temperature") return fromKelvin(to, toKelvin(from, value));
    return value * factor(category, from) / factor(category, to);
}

function formatValue(x, category) {
    if (typeof x !== "number" || !isFinite(x)) return "";
    if (x === 0) return "0";
    var s;
    if (category === "currency") {
        s = Math.abs(x) >= 1 ? x.toFixed(2) : String(Number(x.toPrecision(4)));
    } else {
        s = String(Number(x.toPrecision(10)));
    }
    return s.replace("e+", "E").replace("e", "E").replace(/^-/, "−");
}

function unitLabels(category, rates, names) {
    var ids = unitIds(category, rates);
    if (category !== "currency") return ids;
    return ids.map(function (c) { return currencyLabel(c, names); });
}
