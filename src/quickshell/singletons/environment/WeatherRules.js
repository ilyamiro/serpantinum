.pragma library

var DEFAULTS = {
    enabled: true, dailyForecast: false, governmentWarnings: true, quietHours: true,
    quietStart: 22, quietEnd: 5,
    rain_soon: true, snow_soon: true, heavy_rain: true, heavy_snow: true, thunderstorm: true,
    ice: true, fog: true, temp_rise: true, temp_drop: true, hot: true, cold: true,
    wind: true, uv: true, air_quality: true
};

var HOUR = 3600000;
var DAY = 86400000;
var LOOKAHEAD = 12 * HOUR;
var SOON = 3 * HOUR;
var MAX_AGE = 6 * HOUR;
var HEAT_COLD_SUPPRESS = 3 * DAY;
var DAILY_SPACING = HOUR;

var WET_CODES = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];
var SNOW_CODES = [71, 73, 75, 77, 85, 86];
var STORM_CODES = [95, 96, 99];
var ICE_CODES = [56, 57, 66, 67];
var FOG_CODES = [45, 48];
var RAIN_CODES = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82];

function settingsOf(settings) {
    var out = {};
    var k;
    for (k in DEFAULTS) out[k] = DEFAULTS[k];
    if (settings && typeof settings === "object") {
        for (k in settings) {
            if (settings[k] !== undefined && settings[k] !== null) out[k] = settings[k];
        }
    }
    return out;
}

function isQuietHour(settings, hour) {
    var s = settingsOf(settings);
    if (!s.quietHours) return false;
    var a = Number(s.quietStart);
    var b = Number(s.quietEnd);
    if (isNaN(a) || isNaN(b) || a === b) return false;
    return a < b ? (hour >= a && hour < b) : (hour >= a || hour < b);
}

function num(v) {
    return (v === null || v === undefined || isNaN(Number(v))) ? null : Number(v);
}

function inList(list, v) {
    return v !== null && v !== undefined && list.indexOf(Number(v)) >= 0;
}

function toC(v, unit) {
    if (v === null) return null;
    return unit === "imperial" ? (v - 32) * 5 / 9 : v;
}

function toKmh(v, unit) {
    if (v === null) return null;
    return unit === "imperial" ? v * 1.609344 : v;
}

function fromC(v, unit) {
    if (unit === "imperial") return v * 9 / 5 + 32;
    if (unit === "standard") return v + 273.15;
    return v;
}

function deltaFromC(v, unit) {
    return unit === "imperial" ? v * 9 / 5 : v;
}

function tempSym(unit) {
    return unit === "imperial" ? "°F" : (unit === "standard" ? "K" : "°C");
}

function fmtTemp(c, unit) {
    return Math.round(fromC(c, unit)) + tempSym(unit);
}

function fmtDelta(c, unit) {
    return Math.round(deltaFromC(c, unit)) + "°";
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function parseLocal(s, offMs) {
    var y = Number(s.slice(0, 4));
    var mo = Number(s.slice(5, 7));
    var d = Number(s.slice(8, 10));
    var h = Number(s.slice(11, 13)) || 0;
    var mi = Number(s.slice(14, 16)) || 0;
    return Date.UTC(y, mo - 1, d, h, mi) - offMs;
}

function dateKey(shiftedMs) {
    var d = new Date(shiftedMs);
    return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate());
}

function shiftDate(key, days) {
    var t = Date.UTC(Number(key.slice(0, 4)), Number(key.slice(5, 7)) - 1, Number(key.slice(8, 10))) + days * DAY;
    return dateKey(t);
}

function dayEnd(key, offMs) {
    return parseLocal(key + "T00:00", offMs) + DAY;
}

function buildHours(raw, unit, offMs) {
    var h = raw.hourly;
    var out = [];
    for (var i = 0; i < h.time.length; i++) {
        var ts = parseLocal(h.time[i], offMs);
        var local = ts + offMs;
        out.push({
            ts: ts,
            date: h.time[i].slice(0, 10),
            hour: new Date(local).getUTCHours(),
            temp: toC(num(h.temperature_2m && h.temperature_2m[i]), unit),
            feels: toC(num(h.apparent_temperature && h.apparent_temperature[i]), unit),
            pop: num(h.precipitation_probability && h.precipitation_probability[i]),
            code: num(h.weather_code && h.weather_code[i]),
            precip: num(h.precipitation && h.precipitation[i]),
            snow: num(h.snowfall && h.snowfall[i]),
            vis: num(h.visibility && h.visibility[i]),
            gust: toKmh(num(h.wind_gusts_10m && h.wind_gusts_10m[i]), unit),
            uv: num(h.uv_index && h.uv_index[i])
        });
    }
    return out;
}

function isWet(h) {
    return (h.precip !== null && h.precip >= 0.1) || (h.snow !== null && h.snow > 0) || inList(WET_CODES, h.code);
}

function dayStat(hours, date, field, fn) {
    var vals = [];
    for (var i = 0; i < hours.length; i++) {
        if (hours[i].date === date && hours[i][field] !== null) vals.push(hours[i][field]);
    }
    return vals.length ? fn.apply(null, vals) : null;
}

function runEnd(hours, from, pred) {
    var end = hours[from].ts + HOUR;
    for (var i = from + 1; i < hours.length; i++) {
        if (hours[i].ts === end && pred(hours[i])) end += HOUR;
        else break;
    }
    return end;
}

function firstMatch(hours, pred) {
    for (var i = 0; i < hours.length; i++) {
        if (pred(hours[i])) return i;
    }
    return -1;
}

function dailyCondition(hours, date) {
    var day = hours.filter(function(h) { return h.date === date && h.hour >= 6 && h.hour <= 21; });
    if (!day.length) return null;
    var count = function(list) {
        return day.filter(function(h) { return inList(list, h.code); }).length;
    };
    if (count(STORM_CODES) >= 1) return "daily_storm";
    if (count(SNOW_CODES) >= 2) return "daily_snow";
    if (count(RAIN_CODES) >= 2) return "daily_rain";
    if (count(FOG_CODES) >= 2) return "daily_fog";
    if (day.filter(function(h) { return h.code === 2 || h.code === 3; }).length * 2 >= day.length) return "daily_cloudy";
    return "daily_clear";
}

function aqiNow(aqi, now, offMs) {
    if (!aqi) return null;
    var off = aqi.utc_offset_seconds !== undefined ? Number(aqi.utc_offset_seconds) * 1000 : offMs;
    if (aqi.current && num(aqi.current.us_aqi) !== null) {
        var t = aqi.current.time ? parseLocal(aqi.current.time, off) : now;
        if (now - t <= MAX_AGE) return num(aqi.current.us_aqi);
    }
    if (aqi.hourly && aqi.hourly.time && aqi.hourly.us_aqi) {
        for (var i = 0; i < aqi.hourly.time.length; i++) {
            var ts = parseLocal(aqi.hourly.time[i], off);
            if (ts <= now && now < ts + HOUR) return num(aqi.hourly.us_aqi[i]);
        }
    }
    return null;
}

function evaluate(input) {
    var none = { alerts: [] };
    if (!input || !input.forecast || !input.forecast.hourly || !input.forecast.hourly.time) return none;
    var s = settingsOf(input.settings);
    if (!s.enabled || input.offline) return none;
    var raw = input.forecast;
    var lat = num(raw.latitude);
    var lon = num(raw.longitude);
    if (lat === 0 && lon === 0) return none;
    var unit = input.unit === "imperial" || input.unit === "standard" ? input.unit : "metric";
    var now = Number(input.now);
    if (isNaN(now)) return none;
    var state = input.state || {};
    var delivered = state.delivered || {};
    var last = state.lastDelivered || {};
    var offMs = (num(raw.utc_offset_seconds) || 0) * 1000;
    if (input.fetchedAt && now - Number(input.fetchedAt) * 1000 > MAX_AGE) return none;

    var hours = buildHours(raw, unit, offMs);
    var ci = -1;
    for (var i = 0; i < hours.length; i++) {
        if (hours[i].ts <= now && now < hours[i].ts + HOUR) { ci = i; break; }
    }
    if (ci < 0) return none;
    var cur = hours[ci];
    var today = cur.date;
    var yesterday = shiftDate(today, -1);
    var tomorrow = shiftDate(today, 1);
    var win = hours.filter(function(h) { return h.ts >= cur.ts && h.ts <= now + LOOKAHEAD; });
    var cands = [];

    var band = function(h) { return Math.floor(h.hour / 6); };
    var push = function(kind, id, bypass, expires, args, keys) {
        cands.push({
            id: id, kind: kind,
            titleKey: "weather_alerts." + kind + ".title",
            bodyKey: "weather_alerts." + kind + "." + (keys || "body"),
            args: args || {}, urgency: "normal", bypassQuiet: bypass, expires: expires,
            toggle: kind.indexOf("daily_") === 0 ? "dailyForecast" : kind
        });
    };
    var windowEvent = function(kind, pred, bypass) {
        var idx = firstMatch(win, pred);
        if (idx < 0) return;
        var h = win[idx];
        push(kind, kind + ":" + h.date + ":" + band(h), bypass, runEnd(win, idx, pred),
            { time: pad(h.hour) + ":00" });
    };

    windowEvent("ice", function(h) { return inList(ICE_CODES, h.code); }, true);
    windowEvent("thunderstorm", function(h) { return inList(STORM_CODES, h.code); }, true);
    windowEvent("heavy_rain", function(h) {
        return (h.precip !== null && h.precip >= 7.6) || h.code === 65 || h.code === 82;
    }, false);
    windowEvent("heavy_snow", function(h) {
        return (h.snow !== null && h.snow >= 2.5) || h.code === 75 || h.code === 86;
    }, false);

    var gustIdx = firstMatch(win, function(h) { return h.gust !== null && h.gust >= 62; });
    if (gustIdx >= 0) {
        var gh = win[gustIdx];
        var peak = 0;
        win.forEach(function(h) { if (h.gust !== null && h.gust > peak) peak = h.gust; });
        var speed = unit === "imperial" ? Math.round(peak / 1.609344) + " mph" : Math.round(peak) + " km/h";
        push("wind", "wind:" + gh.date + ":" + band(gh), false, runEnd(win, gustIdx, function(h) { return h.gust !== null && h.gust >= 62; }),
            { time: pad(gh.hour) + ":00", speed: speed });
    }

    var feelsMax = dayStat(hours, today, "feels", Math.max);
    var feelsMin = dayStat(hours, today, "feels", Math.min);
    var dayEndMs = dayEnd(today, offMs);
    if (feelsMax !== null && feelsMax >= 35) {
        push("hot", "hot:" + today, false, dayEndMs, { temp: fmtTemp(feelsMax, unit) });
    }
    if (feelsMin !== null && feelsMin <= -15) {
        push("cold", "cold:" + today, false, dayEndMs, { temp: fmtTemp(feelsMin, unit) });
    }

    windowEvent("fog", function(h) {
        return (h.vis !== null && h.vis < 1000) || inList(FOG_CODES, h.code);
    }, false);

    var wetNow = isWet(cur) || (raw.current && inList(WET_CODES, raw.current.weather_code));
    if (!wetNow) {
        var soon = hours.filter(function(h) { return h.ts > cur.ts && h.ts <= cur.ts + SOON; });
        var si = firstMatch(soon, function(h) { return h.pop !== null && h.pop >= 60; });
        if (si >= 0) {
            var sh = soon[si];
            var snowy = (sh.snow !== null && sh.snow > 0) || inList(SNOW_CODES, sh.code);
            var kind = snowy ? "snow_soon" : "rain_soon";
            push(kind, kind + ":" + sh.date + ":" + band(sh), false, sh.ts + 2 * HOUR,
                { time: pad(sh.hour) + ":00" });
        }
    }

    var maxToday = dayStat(hours, today, "temp", Math.max);
    var maxYesterday = dayStat(hours, yesterday, "temp", Math.max);
    if (maxToday !== null && maxYesterday !== null) {
        var diff = maxToday - maxYesterday;
        if (diff >= 8) {
            push("temp_rise", "temp_rise:" + today, false, dayEndMs,
                { delta: fmtDelta(diff, unit), max: fmtTemp(maxToday, unit) });
        } else if (diff <= -8) {
            push("temp_drop", "temp_drop:" + today, false, dayEndMs,
                { delta: fmtDelta(-diff, unit), max: fmtTemp(maxToday, unit) });
        }
    }

    var uvIdx = firstMatch(hours, function(h) {
        return h.date === today && h.ts + HOUR > now && h.uv !== null && h.uv >= 8;
    });
    if (uvIdx >= 0) {
        var uvPeak = dayStat(hours, today, "uv", Math.max);
        push("uv", "uv:" + today, false, dayEndMs,
            { value: Math.round(uvPeak), time: pad(hours[uvIdx].hour) + ":00" });
    }

    var aqiVal = aqiNow(input.aqi, now, offMs);
    if (aqiVal !== null && aqiVal >= 151) {
        push("air_quality", "air_quality:" + today, false, dayEndMs, { value: Math.round(aqiVal) });
    }

    var localHour = cur.hour;
    var windowName = null;
    var target = null;
    if (localHour >= 5 && localHour < 12) { windowName = "today"; target = today; }
    else if (localHour >= 18 && localHour < 22) { windowName = "tomorrow"; target = tomorrow; }
    if (windowName) {
        var cond = dailyCondition(hours, target);
        var tMax = dayStat(hours, target, "temp", Math.max);
        var tMin = dayStat(hours, target, "temp", Math.min);
        if (cond && tMax !== null && tMin !== null) {
            push(cond, "daily:" + today + ":" + windowName, false,
                windowName === "today" ? dayEndMs : dayEndMs + DAY,
                { max: fmtTemp(tMax, unit), min: fmtTemp(tMin, unit) }, windowName);
        }
    }

    var priority = ["ice", "thunderstorm", "heavy_rain", "heavy_snow", "wind", "hot", "cold", "fog",
        "rain_soon", "snow_soon", "temp_rise", "temp_drop", "uv", "air_quality"];
    var rank = function(c) {
        var p = priority.indexOf(c.kind);
        return p >= 0 ? p : priority.length;
    };
    var quiet = !!input.quiet;
    var picked = null;
    var ordered = cands.slice().sort(function(a, b) { return rank(a) - rank(b); });
    for (var j = 0; j < ordered.length; j++) {
        var c = ordered[j];
        if (!s[c.toggle]) continue;
        if (c.expires && c.expires <= now) continue;
        if (delivered[c.id] && Number(delivered[c.id]) > now) continue;
        if (quiet && !c.bypassQuiet) continue;
        if (c.kind === "hot" && last.hot && now - Number(last.hot) < HEAT_COLD_SUPPRESS) continue;
        if (c.kind === "cold" && last.cold && now - Number(last.cold) < HEAT_COLD_SUPPRESS) continue;
        if (c.kind.indexOf("daily_") === 0 && last.daily && now - Number(last.daily) < DAILY_SPACING) continue;
        picked = c;
        break;
    }
    if (!picked) return none;
    delete picked.toggle;
    return { alerts: [picked] };
}
