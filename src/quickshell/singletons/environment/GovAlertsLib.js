.pragma library

var LEAD_MS = 3 * 3600 * 1000;
var DEFAULT_DURATION_MS = 12 * 3600 * 1000;
var MAX_KDE_CAPS = 40;
var MAX_FEEDS = 4;
var MAX_CAPS_PER_FEED = 20;
var MAX_FEED_AGE_MS = 4 * 86400 * 1000;
var SEV_RANK = { moderate: 1, severe: 2, extreme: 3 };

var NWS_COUNTRIES = ["US", "PR", "GU", "VI", "AS", "MP", "UM"];

var METEOALARM_SLUGS = {
    AT: "austria", BE: "belgium", BA: "bosnia-herzegovina", BG: "bulgaria", HR: "croatia",
    CY: "cyprus", CZ: "czechia", DK: "denmark", EE: "estonia", FI: "finland", FR: "france",
    DE: "germany", GR: "greece", HU: "hungary", IS: "iceland", IE: "ireland", IL: "israel",
    IT: "italy", LV: "latvia", LT: "lithuania", LU: "luxembourg", MT: "malta", MD: "moldova",
    ME: "montenegro", NL: "netherlands", MK: "north-macedonia", NO: "norway", PL: "poland",
    PT: "portugal", RO: "romania", RS: "serbia", SK: "slovakia", SI: "slovenia", ES: "spain",
    SE: "sweden", CH: "switzerland", UA: "ukraine", GB: "united-kingdom"
};

var HAZARD_TABLE = [
    ["fire", /wild ?fire|forest[ -]?fire|bush ?fire|\bfire\b|red flag|waldbrand|brandgefahr|feux? de for|incendie|incendio|inc[eê]ndio|natuurbrand|bosbrand|skogbrann|skogsbrand|mets[aä]palo|po[zż]ar|po[zž][aá]r|t[uű]z|incendiu|пожар|пожеж|yang[ıi]n|שריפ|حريق/],
    ["flood", /flood|[uü]berschwemm|hochwasser|inondation|\bcrue\b|inondazione|alluvion|inundaci|inunda[cç][aã]o|\bcheia|overstrom|hoogwater|[oö]versv[aä]mning|oversv[oø]mmelse|\bflom|tulva|powód[zź]|z[aá]plav|[aá]rv[ií]z|inunda[tț]ii|наводн|повін|повен|ta[sş]k[ıi]n|שיטפון|فيضان|dam break|idrogeologic|idraulic/],
    ["marine", /storm surge|coastal|costero|costier|marine|tsunami|rip current|\bsurf\b|swell|high seas|\bwaves?\b|sturmflut|k[uü]sten|mar[eé]e|submersion|marejada|mareggiata|kuststorm|stormflod|stormflo|b[oø]lge|aallokko|\bfala\b|sea state|\bsea\b|\bseas\b|wasserstand|vågor|bølger|морск|прибереж|kıyı|ים|بحر/],
    ["ice", /\bice\b|\bicy\b|freezing rain|\bglaze|black ice|glatteis|eisregen|verglas|hielo|ghiaccio|gelicidio|ijzel|isslag|underkj[oø]lt|j[aä][aä]t[aä]v|поледиц|ожеледиц|buzlanma|קרח|جليد|ice storm/],
    ["snow", /snow|blizzard|avalanche|sleet|winter (weather|storm)|wintry|schnee|neige|nieve|nevada|\bneve\b|sneeuw|sn[oö]fall|\bsn[oö]\b|\blumi|[sś]nie[gz]|sn[ií]h|havaz|z[aă]pad|ninsoare|снег|сніг|sneg|kar ya[gğ]|שלג|ثلج|lawine|lavina|valanga|aludes|lumes/],
    ["dust", /dust|\bsand|smoke|\bhaze\b|\bash\b|staub|poussi[eè]re|polvo|calima|sabbia|\bstof\b|\bdamm|\bp[oö]ly|\bkurz|пыл|пил|\btoz\b|אבק|غبار|khamsin|sharav|polvo en susp/],
    ["storm", /thunder|tornado|hurricane|typhoon|cyclone|tropical (storm|depression)|severe storm|squall|\bhail|gewitter|unwetter|orage|tormenta|temporal|trovoada|onweer|[aå]ska|tordenv[aæ]r|torden|ukkos|burz|bou[rř]|zivatar|furtun|гроз|шторм|f[ıi]rt[ıi]na|g[oö]k g[uü]r|סופת רעמים|رعد|lightning|waterspout|\bstorm\b/],
    ["rain", /rain|precipitation|shower|downpour|deluge|regen|niederschlag|pluie|lluvia|precipitaci|pioggia|chuva|precipita|neerslag|\bregn|nedb[oø]r|\bsade\b|deszcz|opady|d[eé]š[tť]|sr[aá]žk|eső|csapad[eé]k|ploaie|дожд|дощ|ya[gğ]mur|ya[gğ][ıi][sş]|גשם|أمطار/],
    ["cold", /wind ?chill|extreme cold|hard freeze|grand froid|windchill/],
    ["wind", /wind|gale|gust|\bsturm|b[oö]e\b|b[oö]en|\bvent\b|viento|vento|burrasca|raffica|stormachtig|\bvind|bl[aå]st|kuling|tuuli|myrsky|wiatr|wichur|v[ií]tr|vich[rř]ice|sz[eé]l|vihar|v[aâ]nt|vijelie|ветер|ветр|вітер|вітр|r[uü]zg|רוח|رياح|mistral|f[oö]hn|\bbora\b|tempête|rafale/],
    ["fog", /\bfog|\bmist\b|visibility|nebel|sichtweite|brouillard|niebla|nebbia|nevoeiro|dimma|t[aå]ke|\bsumu|mg[lł]a|mlha|k[oö]d\b|ce[aă][tț][aă]|туман|\bsis\b|ערפל|ضباب/],
    ["heat", /heat|\bhot\b|high temp|extreme(ly)? high|hitze|canicule|chaleur|\bcalor|ola de calor|caldo|ondata di calore|\bhitte|v[aä]rme|\bvarme|helle\b|lämpö|upa[lł]|vedro|horko|h[oő]s[eé]g|canicul[aă]|жара|спека|s[ıi]cak|חום|حر\b|حرارة مرتفعة|temperaturas m[aá]xim/],
    ["cold", /cold|freez|frost|chill|low temp|extreme(ly)? low|k[aä]lte|\bgel\b|froid|fr[ií]o|helada|freddo|\bkou\b|kyla|kulde|pakkanen|mr[oó]z|mr[aá]z|fagy|холод|мороз|заморозк|so[gğ]uk|קור|صقيع|برد|temperaturas m[ií]nim/]
];

var AWARENESS_HAZARD = { 1: "wind", 2: "snow", 3: "storm", 4: "fog", 5: "heat", 6: "cold", 7: "marine", 8: "fire", 9: "snow", 10: "rain", 11: "flood", 12: "flood" };

var MET_SENDER = /meteo|weather|hydro|water|flood|forest|fire|met office|\bmet\b|wetter|bureau|environment|climat|geosphere|dmi|smhi|knmi|imgw|ims|ipma|aemet|dwd|noaa|nws|nve|vedur|ilmatieteen|zamg|shmu|chmi|hmu|arso|rhmz|nimh|meteoswiss|meteofrance|met\.no/i;

function toArray(v) {
    if (v === undefined || v === null) return [];
    return Array.isArray(v) ? v : [v];
}

function str(v) {
    return (v === undefined || v === null) ? "" : String(v);
}

function parseTime(s) {
    if (s === undefined || s === null || s === "") return NaN;
    if (typeof s === "number") return s;
    return Date.parse(String(s).trim());
}

function decodeEntities(s) {
    if (s.indexOf("&") < 0) return s;
    return s.replace(/&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);/g, function (m, e) {
        if (e === "amp") return "&";
        if (e === "lt") return "<";
        if (e === "gt") return ">";
        if (e === "quot") return "\"";
        if (e === "apos") return "'";
        if (e === "nbsp") return " ";
        var code = e.charAt(1) === "x" ? parseInt(e.substring(2), 16) : parseInt(e.substring(1), 10);
        if (!isFinite(code) || code <= 0 || code > 0x10FFFF) return "";
        try { return String.fromCodePoint(code); } catch (err) { return ""; }
    });
}

function localName(name) {
    var i = name.indexOf(":");
    return (i >= 0 ? name.substring(i + 1) : name).toLowerCase();
}

function parseAttrs(s) {
    var out = {};
    if (!s) return out;
    var re = /([^\s=\/]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/g;
    var m;
    while ((m = re.exec(s)) !== null) {
        var v = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : m[4]);
        out[localName(m[1])] = decodeEntities(v);
    }
    return out;
}

function parseXml(src) {
    var root = { n: "#root", attrs: {}, kids: [], text: "" };
    var stack = [root];
    var top = root;
    var re = /<!--[\s\S]*?-->|<!\[CDATA\[([\s\S]*?)\]\]>|<\?[\s\S]*?\?>|<![^>]*>|<\/([^\s>]+)\s*>|<([^\s\/>!?]+)([^>]*?)(\/?)>/g;
    var last = 0;
    var m;
    src = str(src);
    while ((m = re.exec(src)) !== null) {
        if (m.index > last) top.text += decodeEntities(src.substring(last, m.index));
        last = re.lastIndex;
        if (m[1] !== undefined) {
            top.text += m[1];
        } else if (m[2] !== undefined) {
            var closing = localName(m[2]);
            for (var i = stack.length - 1; i > 0; i--) {
                if (stack[i].n === closing) {
                    stack.length = i;
                    top = stack[i - 1];
                    break;
                }
            }
        } else if (m[3] !== undefined) {
            var node = { n: localName(m[3]), attrs: parseAttrs(m[4]), kids: [], text: "" };
            top.kids.push(node);
            if (!m[5]) {
                stack.push(node);
                top = node;
            }
        }
    }
    return root;
}

function kids(node, name) {
    var out = [];
    if (!node) return out;
    for (var i = 0; i < node.kids.length; i++) if (node.kids[i].n === name) out.push(node.kids[i]);
    return out;
}

function kid(node, name) {
    var k = kids(node, name);
    return k.length ? k[0] : null;
}

function txt(node, name) {
    var k = kid(node, name);
    return k ? k.text.trim() : "";
}

function descend(node, name, out) {
    out = out || [];
    for (var i = 0; i < node.kids.length; i++) {
        var k = node.kids[i];
        if (k.n === name) out.push(k);
        else descend(k, name, out);
    }
    return out;
}

function num(v) {
    var n = parseFloat(v);
    return isFinite(n) ? n : NaN;
}

function parsePolygon(s) {
    s = str(s).trim();
    if (!s) return null;
    var pts = [];
    if (s.indexOf(",") >= 0) {
        var toks = s.split(/\s+/);
        for (var i = 0; i < toks.length; i++) {
            var p = toks[i].split(",");
            if (p.length < 2) continue;
            var la = num(p[0]), lo = num(p[1]);
            if (!isNaN(la) && !isNaN(lo)) pts.push([la, lo]);
        }
    } else {
        var n = s.split(/\s+/).map(num);
        for (var j = 0; j + 1 < n.length; j += 2) {
            if (!isNaN(n[j]) && !isNaN(n[j + 1])) pts.push([n[j], n[j + 1]]);
        }
    }
    if (pts.length < 3) return null;
    return { ring: pts, holes: [] };
}

function parseCircle(s, meters) {
    s = str(s).trim();
    if (!s) return null;
    var m = /^\s*(-?[\d.]+)[,\s]+(-?[\d.]+)\s+([\d.]+)/.exec(s);
    if (!m) return null;
    var r = num(m[3]);
    if (isNaN(r)) return null;
    return { lat: num(m[1]), lon: num(m[2]), r: meters ? r / 1000 : r };
}

function geoJsonShapes(geom) {
    var out = { polygons: [], circles: [] };
    if (!geom || !geom.coordinates) return out;
    var polys = geom.type === "Polygon" ? [geom.coordinates] : (geom.type === "MultiPolygon" ? geom.coordinates : []);
    for (var i = 0; i < polys.length; i++) {
        var rings = polys[i].map(function (ring) {
            return ring.map(function (c) { return [c[1], c[0]]; });
        });
        if (rings.length && rings[0].length >= 3) out.polygons.push({ ring: rings[0], holes: rings.slice(1) });
    }
    return out;
}

function inRing(ring, lat, lon) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        var yi = ring[i][0], xi = ring[i][1], yj = ring[j][0], xj = ring[j][1];
        if (((yi > lat) !== (yj > lat)) && (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) inside = !inside;
    }
    return inside;
}

function pointInPolygon(poly, lat, lon) {
    if (!inRing(poly.ring, lat, lon)) return false;
    for (var i = 0; i < poly.holes.length; i++) if (inRing(poly.holes[i], lat, lon)) return false;
    return true;
}

function distanceKm(lat1, lon1, lat2, lon2) {
    var rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad, dLon = (lon2 - lon1) * rad;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function shapesContain(shapes, lat, lon) {
    var i;
    for (i = 0; i < shapes.polygons.length; i++) if (pointInPolygon(shapes.polygons[i], lat, lon)) return true;
    for (i = 0; i < shapes.circles.length; i++) {
        var c = shapes.circles[i];
        if (distanceKm(lat, lon, c.lat, c.lon) <= c.r) return true;
    }
    return false;
}

function hasShapes(shapes) {
    return shapes.polygons.length > 0 || shapes.circles.length > 0;
}

function parseRefs(v) {
    var out = [];
    var toks = Array.isArray(v) ? v : str(v).trim().split(/\s+/);
    for (var i = 0; i < toks.length; i++) {
        var t = str(toks[i]).trim();
        if (!t) continue;
        var p = t.split(",");
        var id = p.length >= 2 ? p[1] : p[0];
        if (id) out.push(id);
    }
    return out;
}

function areaFromNode(a) {
    var area = { desc: txt(a, "areadesc"), polygons: [], circles: [] };
    kids(a, "polygon").forEach(function (p) {
        var poly = parsePolygon(p.text);
        if (poly) area.polygons.push(poly);
    });
    kids(a, "circle").forEach(function (c) {
        var circ = parseCircle(c.text, false);
        if (circ) area.circles.push(circ);
    });
    return area;
}

function nameValueMap(list) {
    var out = {};
    list.forEach(function (p) {
        var k = str(p.name).toLowerCase();
        (out[k] = out[k] || []).push(str(p.value));
    });
    return out;
}

function infoFromNode(n) {
    var codes = kids(n, "eventcode").map(function (c) { return { name: txt(c, "valuename"), value: txt(c, "value") }; });
    var params = kids(n, "parameter").map(function (c) { return { name: txt(c, "valuename"), value: txt(c, "value") }; });
    return {
        language: txt(n, "language"),
        categories: kids(n, "category").map(function (c) { return c.text.trim(); }),
        event: txt(n, "event"),
        urgency: txt(n, "urgency"),
        severity: txt(n, "severity"),
        certainty: txt(n, "certainty"),
        effective: txt(n, "effective"),
        onset: txt(n, "onset"),
        expires: txt(n, "expires"),
        senderName: txt(n, "sendername"),
        headline: txt(n, "headline"),
        description: txt(n, "description"),
        instruction: txt(n, "instruction"),
        web: txt(n, "web"),
        eventCodes: codes,
        params: nameValueMap(params),
        areas: kids(n, "area").map(areaFromNode)
    };
}

function capFromNode(a) {
    return {
        identifier: txt(a, "identifier"),
        sender: txt(a, "sender"),
        sent: txt(a, "sent"),
        status: txt(a, "status"),
        msgType: txt(a, "msgtype"),
        scope: txt(a, "scope"),
        refs: parseRefs(txt(a, "references")),
        infos: kids(a, "info").map(infoFromNode)
    };
}

function parseCap(xml) {
    var doc = parseXml(xml);
    var nodes = descend(doc, "alert");
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
        if (nodes[i].kids.some(function (k) { return k.n === "identifier"; })) out.push(capFromNode(nodes[i]));
    }
    return out;
}

function capFromJson(a) {
    var infos = toArray(a.info).map(function (i) {
        var codes = toArray(i.eventCode).map(function (c) { return { name: str(c.valueName), value: str(c.value) }; });
        var params = toArray(i.parameter).map(function (c) { return { name: str(c.valueName), value: str(c.value) }; });
        return {
            language: str(i.language),
            categories: toArray(i.category).map(str),
            event: str(i.event),
            urgency: str(i.urgency),
            severity: str(i.severity),
            certainty: str(i.certainty),
            effective: str(i.effective),
            onset: str(i.onset),
            expires: str(i.expires),
            senderName: str(i.senderName),
            headline: str(i.headline),
            description: str(i.description),
            instruction: str(i.instruction),
            web: str(i.web),
            eventCodes: codes,
            params: nameValueMap(params),
            areas: toArray(i.area).map(function (ar) {
                var area = { desc: str(ar.areaDesc), polygons: [], circles: [] };
                toArray(ar.polygon).forEach(function (p) {
                    var poly = parsePolygon(p);
                    if (poly) area.polygons.push(poly);
                });
                toArray(ar.circle).forEach(function (c) {
                    var circ = parseCircle(c, false);
                    if (circ) area.circles.push(circ);
                });
                return area;
            })
        };
    });
    return {
        identifier: str(a.identifier),
        sender: str(a.sender),
        sent: str(a.sent),
        status: str(a.status),
        msgType: str(a.msgType),
        scope: str(a.scope),
        refs: parseRefs(a.references === undefined ? "" : a.references),
        infos: infos
    };
}

function matchHazard(text) {
    for (var i = 0; i < HAZARD_TABLE.length; i++) {
        if (HAZARD_TABLE[i][1].test(text)) return HAZARD_TABLE[i][0];
    }
    return "generic";
}

var NON_MET = /landslide|mudslide|rockslide|debris flow|skred|erdrutsch|glissement|frana\b|deslizamiento/i;

function classify(event, headline, awareness) {
    if (NON_MET.test(str(event))) return "generic";
    var aw = /^\s*(\d+)/.exec(str(awareness));
    var text = (str(event) + " " + str(headline).substring(0, 160)).toLowerCase();
    if (aw && AWARENESS_HAZARD[aw[1]]) {
        var h = AWARENESS_HAZARD[aw[1]];
        if (h === "snow" && /ice|glatteis|verglas|hielo|ghiaccio|ijzel|glaze/.test(text)) return "ice";
        return h;
    }
    var found = matchHazard(str(event).toLowerCase());
    return found !== "generic" ? found : matchHazard(str(headline).substring(0, 160).toLowerCase());
}

function normSeverity(s) {
    var v = str(s).toLowerCase();
    return SEV_RANK[v] ? v : "";
}

function langPrefix(l) {
    var p = str(l).toLowerCase().split(/[-_]/)[0];
    if (p === "ua") return "uk";
    if (p === "iw") return "he";
    if (p === "nb" || p === "nn") return "no";
    return p;
}

function pickInfo(group, lang) {
    var want = langPrefix(lang);
    var i;
    for (i = 0; i < group.length; i++) if (langPrefix(group[i].language) === want) return group[i];
    for (i = 0; i < group.length; i++) if (langPrefix(group[i].language) === "en") return group[i];
    return group[0];
}

function groupInfos(infos) {
    var groups = [];
    infos.forEach(function (info) {
        var codes = info.eventCodes.map(function (c) { return c.name + "=" + c.value; }).sort().join(",");
        var aw = (info.params.awareness_type || []).join(",");
        var key = [info.categories.slice().sort().join(","), info.severity, info.onset, info.expires, codes, aw].join("|");
        for (var i = 0; i < groups.length; i++) {
            var g = groups[i];
            if (g.key !== key) continue;
            var dup = false;
            for (var j = 0; j < g.infos.length; j++) if (langPrefix(g.infos[j].language) === langPrefix(info.language)) dup = true;
            if (!dup) {
                g.infos.push(info);
                return;
            }
        }
        groups.push({ key: key, infos: [info] });
    });
    return groups;
}

function categoryOk(info, hazard, senderName) {
    var cats = info.categories.map(function (c) { return c.toLowerCase(); });
    if (cats.length === 0) return hazard !== "generic";
    if (cats.indexOf("met") >= 0) return true;
    var extra = ["flood", "fire", "marine", "storm", "snow", "ice", "wind", "heat", "cold", "rain"];
    if (extra.indexOf(hazard) >= 0 && cats.some(function (c) { return c === "env" || c === "geo" || c === "fire" || c === "safety" || c === "rescue"; })) {
        return MET_SENDER.test(senderName);
    }
    return false;
}

function infoWindow(info) {
    var onset = parseTime(info.onset);
    var effective = parseTime(info.effective);
    var start = !isNaN(onset) ? onset : effective;
    var expires = parseTime(info.expires);
    var ending = parseTime((info.params.eventendingtime || [])[0]);
    if (!isNaN(ending) && (isNaN(expires) || ending > expires)) expires = ending;
    return { start: start, effective: effective, expires: expires };
}

function evalCap(cap, opts) {
    var res = { alerts: [], cancels: [] };
    var now = opts.now;
    if (!cap || !cap.identifier) return res;
    var msgType = cap.msgType.toLowerCase();
    if (msgType === "cancel") {
        res.cancels = cap.refs.slice();
        res.cancels.push(cap.identifier);
        return res;
    }
    if (msgType !== "alert" && msgType !== "update") return res;
    if (cap.status.toLowerCase() !== "actual") return res;
    var scope = cap.scope.toLowerCase();
    if (scope && scope !== "public") return res;
    var groups = groupInfos(cap.infos);
    var sent = parseTime(cap.sent);
    groups.forEach(function (g, gi) {
        var info = pickInfo(g.infos, opts.lang);
        var severity = normSeverity(info.severity);
        if (!severity) return;
        var win = infoWindow(info);
        var start = !isNaN(win.start) ? win.start : (!isNaN(sent) ? sent : now);
        var end = !isNaN(win.expires) ? win.expires : start + DEFAULT_DURATION_MS;
        if (end <= now || now < start - LEAD_MS) return;
        var shapes = { polygons: [], circles: [] };
        g.infos.forEach(function (inf) {
            inf.areas.forEach(function (a) {
                shapes.polygons = shapes.polygons.concat(a.polygons);
                shapes.circles = shapes.circles.concat(a.circles);
            });
        });
        if (opts.shapes) {
            shapes.polygons = shapes.polygons.concat(opts.shapes.polygons);
            shapes.circles = shapes.circles.concat(opts.shapes.circles);
        }
        if (hasShapes(shapes)) {
            if (!shapesContain(shapes, opts.lat, opts.lon)) return;
        } else if (!opts.trustGeo) {
            return;
        }
        var aw = (info.params.awareness_type || [])[0];
        var hazard = classify(info.event, info.headline, aw);
        if (!categoryOk(info, hazard, info.senderName)) return;
        res.alerts.push({
            identifier: cap.identifier + (groups.length > 1 ? "#" + gi : ""),
            refs: cap.refs.slice(),
            sent: !isNaN(sent) ? sent : start,
            start: start,
            end: end,
            severity: severity,
            hazard: hazard,
            event: info.event,
            headline: info.headline,
            description: info.description,
            instruction: info.instruction,
            senderName: info.senderName || cap.sender,
            web: info.web,
            lang: info.language,
            src: opts.src,
            rank: opts.rank
        });
    });
    return res;
}

function emptyInfo() {
    return {
        language: "", categories: ["Met"], event: "", urgency: "", severity: "", certainty: "", effective: "", onset: "",
        expires: "", senderName: "", headline: "", description: "", instruction: "", web: "", eventCodes: [], params: {}, areas: []
    };
}

function nwsToCap(f) {
    var p = f.properties || {};
    var info = emptyInfo();
    info.language = "en";
    info.categories = [str(p.category)];
    info.event = str(p.event);
    info.severity = str(p.severity);
    info.effective = str(p.effective);
    info.onset = str(p.onset);
    var exp = parseTime(p.expires), ends = parseTime(p.ends);
    info.expires = !isNaN(ends) && (isNaN(exp) || ends > exp) ? str(p.ends) : str(p.expires);
    info.senderName = str(p.senderName);
    info.headline = str(p.headline);
    info.description = str(p.description);
    info.instruction = str(p.instruction);
    return {
        identifier: str(p.id || f.id), sender: str(p.sender), sent: str(p.sent), status: str(p.status),
        msgType: str(p.messageType), scope: str(p.scope || "Public"),
        refs: toArray(p.references).map(function (r) { return str(r.identifier); }).filter(Boolean),
        infos: [info]
    };
}

function canadaSeverity(p) {
    var type = str(p.alert_type).toLowerCase();
    var colour = str(p.risk_colour_en).toLowerCase();
    if (type !== "warning" && type !== "watch") return "";
    if (colour === "red") return "Extreme";
    if (colour === "orange") return "Severe";
    if (colour === "yellow") return "Moderate";
    return type === "warning" ? "Severe" : "Moderate";
}

function canadaToCap(f, lang) {
    var p = f.properties || {};
    var fr = langPrefix(lang) === "fr";
    var status = str(p.status_en).toLowerCase();
    var info = emptyInfo();
    info.language = fr ? "fr" : "en";
    info.event = str(fr ? p.alert_name_fr : p.alert_name_en) || str(p.alert_name_en);
    var feature = str(fr ? p.feature_name_fr : p.feature_name_en) || str(p.feature_name_en);
    info.headline = feature ? info.event + " - " + feature : info.event;
    info.severity = canadaSeverity(p);
    info.effective = str(p.publication_datetime);
    info.onset = str(p.validity_datetime || p.publication_datetime);
    info.expires = str(p.event_end_datetime || p.expiration_datetime);
    var exp = parseTime(p.expiration_datetime), end = parseTime(info.expires);
    if (!isNaN(exp) && (isNaN(end) || exp > end)) info.expires = str(p.expiration_datetime);
    info.senderName = "Environment Canada";
    info.description = str(fr ? p.alert_text_fr : p.alert_text_en) || str(p.alert_text_en);
    var ended = /ended|cancel|terminé|annul/.test(status);
    return {
        identifier: "ca:" + str(p.alert_code) + ":" + str(p.feature_id || f.id),
        sender: "ec.gc.ca", sent: str(p.publication_datetime), status: "Actual",
        msgType: ended ? "Cancel" : "Alert", scope: "Public", refs: [], infos: [info]
    };
}

function brightskyToCap(a, lang) {
    var de = langPrefix(lang) === "de";
    var info = emptyInfo();
    info.language = de ? "de" : "en";
    info.categories = toArray(a.category).map(function (c) {
        var s = str(c);
        return s.charAt(0).toUpperCase() + s.substring(1);
    });
    info.event = str(de ? a.event_de : a.event_en) || str(a.event_en);
    info.headline = str(de ? a.headline_de : a.headline_en) || str(a.headline_en);
    info.description = str(de ? a.description_de : a.description_en) || str(a.description_en);
    info.instruction = str(de ? a.instruction_de : a.instruction_en) || str(a.instruction_en);
    var sev = str(a.severity);
    info.severity = sev.charAt(0).toUpperCase() + sev.substring(1);
    info.effective = str(a.effective);
    info.onset = str(a.onset);
    info.expires = str(a.expires);
    info.senderName = "Deutscher Wetterdienst";
    var st = str(a.status);
    return {
        identifier: str(a.alert_id || a.id), sender: "dwd.de", sent: str(a.effective),
        status: st.charAt(0).toUpperCase() + st.substring(1), msgType: "Alert", scope: "Public", refs: [], infos: [info]
    };
}

function metnoToCap(f) {
    var p = f.properties || {};
    var info = emptyInfo();
    info.language = str(p.lang || "");
    info.event = str(p.eventAwarenessName || p.event);
    info.headline = str(p.area) ? info.event + ", " + str(p.area) : info.event;
    info.severity = str(p.severity);
    var times = /(\d{4}-\d\d-\d\dT[\d:.]+(?:Z|[+-]\d\d:\d\d)?)\s*,\s*(\d{4}-\d\d-\d\dT[\d:.]+(?:Z|[+-]\d\d:\d\d)?)\s*$/.exec(str(p.title));
    info.onset = times ? times[1] : "";
    info.effective = info.onset;
    info.expires = str(p.eventEndingTime || (times ? times[2] : ""));
    info.senderName = "MET Norway";
    info.description = str(p.description);
    info.instruction = str(p.instruction);
    info.web = str(p.web);
    info.params = { awareness_type: [str(p.awareness_type)] };
    var type = str(p.type);
    return {
        identifier: "no:" + str(p.id), sender: "met.no", sent: info.effective || info.onset, status: str(p.status),
        msgType: type || "Alert", scope: "Public", refs: [], infos: [info]
    };
}

function fmtCoord(v) {
    return Number(v).toFixed(4);
}

function planNational(ctx) {
    var cc = ctx.country;
    var lat = ctx.lat, lon = ctx.lon;
    if (NWS_COUNTRIES.indexOf(cc) >= 0) {
        return { id: "nws", label: "NWS", tier: 1, rank: 0, jobs: [{ kind: "nws", url: "https://api.weather.gov/alerts/active?point=" + fmtCoord(lat) + "," + fmtCoord(lon), headers: ["Accept: application/geo+json"], timeout: 25, maxSize: 8000000 }] };
    }
    if (cc === "CA") {
        var d = 0.02;
        var bbox = [lon - d, lat - d, lon + d, lat + d].map(fmtCoord).join(",");
        return { id: "eccc", label: "Environment Canada", tier: 1, rank: 0, jobs: [{ kind: "ca", url: "https://api.weather.gc.ca/collections/weather-alerts/items?f=json&limit=100&bbox=" + bbox, headers: [], timeout: 25, maxSize: 8000000 }] };
    }
    if (cc === "DE") {
        return { id: "dwd", label: "DWD", tier: 1, rank: 0, jobs: [{ kind: "de", url: "https://api.brightsky.dev/alerts?lat=" + fmtCoord(lat) + "&lon=" + fmtCoord(lon), headers: [], timeout: 25, maxSize: 4000000 }] };
    }
    if (cc === "NO" || cc === "SJ") {
        var l = langPrefix(ctx.lang) === "no" ? "no" : "en";
        return { id: "metno", label: "MET Norway", tier: 1, rank: 0, jobs: [{ kind: "no", url: "https://api.met.no/weatherapi/metalerts/2.0/current.json?lat=" + fmtCoord(lat) + "&lon=" + fmtCoord(lon) + "&lang=" + l, headers: [], timeout: 25, maxSize: 4000000 }] };
    }
    return null;
}

function planSources(ctx) {
    var list = [];
    var national = planNational(ctx);
    if (national) list.push(national);
    var d = 0.03;
    list.push({
        id: "kde", label: "KDE alert server", tier: 2, rank: 2,
        jobs: [{ kind: "kdeArea", url: "https://alerts.kde.org/alert/area?min_lat=" + fmtCoord(ctx.lat - d) + "&max_lat=" + fmtCoord(ctx.lat + d) + "&min_lon=" + fmtCoord(ctx.lon - d) + "&max_lon=" + fmtCoord(ctx.lon + d), headers: [], timeout: 20, maxSize: 1000000 }]
    });
    var slug = METEOALARM_SLUGS[ctx.country];
    if (slug) {
        list.push({
            id: "meteoalarm", label: "MeteoAlarm", tier: 3, rank: 1,
            jobs: [{ kind: "ma", url: "https://feeds.meteoalarm.org/api/v1/warnings/feeds-" + slug, headers: [], timeout: 60, maxSize: 20000000 }]
        });
    }
    if (ctx.country) {
        list.push({ id: "feeds", label: "Official CAP feeds", tier: 3, rank: 1, jobs: [{ kind: "registry", url: "https://alert-hub-sources.s3.amazonaws.com/json", headers: [], timeout: 40, maxSize: 4000000 }] });
    }
    return list;
}

function isHttp(url) {
    return /^https?:\/\//i.test(str(url));
}

function reduceRegistry(json) {
    var out = [];
    toArray(json && json.sources).forEach(function (s) {
        var x = s && s.source;
        if (!x || !isHttp(x.capAlertFeed)) return;
        out.push({ id: str(x.sourceId), country: str(x.authorityCountry).toUpperCase(), official: x.sourceIsOfficial === true, status: str(x.capAlertFeedStatus), feed: str(x.capAlertFeed) });
    });
    return out;
}

function feedJobs(registry, ctx, srcId) {
    var cc = ctx.country;
    var seenUrls = {};
    var picked = registry.filter(function (e) {
        if (e.country !== cc || !e.official || e.status !== "operating") return false;
        if (/api\.weather\.gov/i.test(e.feed) && NWS_COUNTRIES.indexOf(cc) >= 0) return false;
        if (seenUrls[e.feed]) return false;
        seenUrls[e.feed] = true;
        return true;
    });
    picked.sort(function (a, b) {
        var am = /meteoalarm/i.test(a.feed) ? 1 : 0, bm = /meteoalarm/i.test(b.feed) ? 1 : 0;
        return am - bm;
    });
    return picked.slice(0, MAX_FEEDS).map(function (e) {
        return { kind: "feed", url: e.feed, headers: [], timeout: 30, maxSize: 6000000, label: e.id };
    });
}

function feedEntries(xml) {
    var doc = parseXml(xml);
    var nodes = descend(doc, "entry");
    if (!nodes.length) nodes = descend(doc, "item");
    return nodes.map(function (e) {
        var link = "";
        var links = kids(e, "link");
        var i;
        for (i = 0; i < links.length && !link; i++) {
            var t = str(links[i].attrs.type).toLowerCase();
            if (t.indexOf("cap") >= 0 && isHttp(links[i].attrs.href)) link = links[i].attrs.href;
        }
        for (i = 0; i < links.length && !link; i++) {
            var rel = str(links[i].attrs.rel).toLowerCase();
            if ((rel === "" || rel === "alternate") && isHttp(links[i].attrs.href)) link = links[i].attrs.href;
        }
        if (!link) {
            var lt = txt(e, "link");
            if (isHttp(lt)) link = lt;
        }
        if (!link) {
            var g = txt(e, "guid") || txt(e, "id");
            if (isHttp(g)) link = g;
        }
        var shapes = { polygons: [], circles: [] };
        kids(e, "polygon").forEach(function (p) {
            var poly = parsePolygon(p.text);
            if (poly) shapes.polygons.push(poly);
        });
        kids(e, "circle").forEach(function (c) {
            var circ = parseCircle(c.text, c.text.indexOf(",") < 0);
            if (circ) shapes.circles.push(circ);
        });
        var updated = parseTime(txt(e, "updated") || txt(e, "published") || txt(e, "pubdate") || txt(e, "sent"));
        return {
            link: link,
            id: txt(e, "identifier") || txt(e, "guid") || txt(e, "id"),
            shapes: shapes,
            updated: updated,
            severity: txt(e, "severity"),
            expires: parseTime(txt(e, "expires")),
            status: txt(e, "status")
        };
    });
}

function selectFeedLinks(entries, ctx) {
    var now = ctx.now;
    var byLink = {};
    var order = [];
    entries.forEach(function (e) {
        if (!e.link) return;
        if (e.status && e.status.toLowerCase() !== "actual") return;
        if (e.severity && !normSeverity(e.severity)) return;
        if (!isNaN(e.expires) && e.expires <= now) return;
        if (isNaN(e.expires) && !isNaN(e.updated) && now - e.updated > MAX_FEED_AGE_MS) return;
        if (hasShapes(e.shapes) && !shapesContain(e.shapes, ctx.lat, ctx.lon)) return;
        if (!byLink[e.link]) {
            byLink[e.link] = e;
            order.push(e);
        }
    });
    order.sort(function (a, b) {
        return (isNaN(b.updated) ? 0 : b.updated) - (isNaN(a.updated) ? 0 : a.updated);
    });
    return order.slice(0, MAX_CAPS_PER_FEED).map(function (e) { return e.link; });
}

function mergeRes(a, b) {
    a.alerts = a.alerts.concat(b.alerts);
    a.cancels = a.cancels.concat(b.cancels);
}

function evalCapList(caps, opts) {
    var res = { alerts: [], cancels: [] };
    caps.forEach(function (c) { mergeRes(res, evalCap(c, opts)); });
    return res;
}

function jobOpts(job, ctx, trustGeo) {
    return { lat: ctx.lat, lon: ctx.lon, lang: ctx.lang, now: ctx.now, trustGeo: trustGeo, src: job.src, rank: job.rank };
}

function handleCap(job, caps, ctx) {
    var res = evalCapList(caps, jobOpts(job, ctx, job.kind === "kdeCap"));
    return { ok: true, alerts: res.alerts, cancels: res.cancels, jobs: [] };
}

function fail(msg) {
    return { ok: false, error: msg, alerts: [], cancels: [], jobs: [] };
}

function handleResult(job, text, ctx) {
    var res = { ok: true, alerts: [], cancels: [], jobs: [] };
    var json, caps, i;
    try {
        switch (job.kind) {
        case "nws":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.features)) return fail("bad payload");
            res = evalCapList(json.features.map(nwsToCap), jobOpts(job, ctx, true));
            break;
        case "ca":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.features)) return fail("bad payload");
            res = { alerts: [], cancels: [] };
            json.features.forEach(function (f) {
                var o = jobOpts(job, ctx, false);
                o.shapes = geoJsonShapes(f.geometry);
                mergeRes(res, evalCap(canadaToCap(f, ctx.lang), o));
            });
            break;
        case "de":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.alerts)) return fail("bad payload");
            res = evalCapList(json.alerts.map(function (a) { return brightskyToCap(a, ctx.lang); }), jobOpts(job, ctx, true));
            break;
        case "no":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.features)) return fail("bad payload");
            res = evalCapList(json.features.map(metnoToCap), jobOpts(job, ctx, true));
            break;
        case "ma":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.warnings)) return fail("bad payload");
            res = evalCapList(json.warnings.filter(function (w) { return w && w.alert; }).map(function (w) { return capFromJson(w.alert); }), jobOpts(job, ctx, false));
            break;
        case "kdeArea":
            json = JSON.parse(text);
            if (!Array.isArray(json)) return fail("bad payload");
            res = { alerts: [], cancels: [], jobs: [] };
            json.filter(function (id) { return /^[0-9a-fA-F-]{20,40}$/.test(str(id)); }).slice(0, MAX_KDE_CAPS).forEach(function (id) {
                res.jobs.push({ kind: "kdeCap", url: "https://alerts.kde.org/alert/" + id, headers: [], timeout: 20, maxSize: 2000000, key: "kde:" + id });
            });
            break;
        case "kdeCap":
        case "cap":
            caps = parseCap(text);
            if (!caps.length) return fail("no cap");
            res = evalCapList(caps, jobOpts(job, ctx, job.kind === "kdeCap"));
            res.jobs = [];
            res.caps = caps;
            break;
        case "registry":
            json = JSON.parse(text);
            if (!json || !Array.isArray(json.sources)) return fail("bad payload");
            res = { alerts: [], cancels: [], jobs: [], registry: reduceRegistry(json) };
            res.jobs = feedJobs(res.registry, ctx);
            break;
        case "feed":
            var entries = feedEntries(text);
            res = { alerts: [], cancels: [], jobs: [] };
            selectFeedLinks(entries, ctx).forEach(function (link) {
                res.jobs.push({ kind: "cap", url: link, headers: [], timeout: 20, maxSize: 3000000, key: "cap:" + link });
            });
            break;
        default:
            return fail("unknown job");
        }
    } catch (e) {
        return fail("parse error");
    }
    res.ok = true;
    res.jobs = res.jobs || [];
    return res;
}

function normalizeText(s) {
    return str(s).toLowerCase().replace(/[^a-z0-9\u00c0-\uffff]+/g, " ").trim();
}

function similar(a, b) {
    if (a.hazard !== b.hazard) return false;
    if (a.hazard === "generic" && normalizeText(a.event) !== normalizeText(b.event)) return false;
    var inter = Math.min(a.end, b.end) - Math.max(a.start, b.start);
    if (inter <= 0) return false;
    var minLen = Math.min(a.end - a.start, b.end - b.start);
    if (minLen <= 0) return true;
    return inter / minLen >= 0.5 || Math.abs(a.start - b.start) <= LEAD_MS;
}

function truncate(s, max) {
    s = str(s).replace(/\s+/g, " ").trim();
    if (s.length <= max) return s;
    var cut = s.substring(0, max);
    var sentence = Math.max(cut.lastIndexOf(". "), cut.lastIndexOf("! "), cut.lastIndexOf("? "));
    if (sentence > max * 0.5) return cut.substring(0, sentence + 1);
    var space = cut.lastIndexOf(" ");
    return (space > max * 0.5 ? cut.substring(0, space) : cut).replace(/[,;:\s]+$/, "") + "\u2026";
}

function buildDelivery(a, rootId) {
    var title = str(a.headline).trim();
    if (!title || title.length > 70) title = str(a.event).trim() || title;
    title = truncate(title, 90);
    title = title.charAt(0).toUpperCase() + title.substring(1);
    var body = truncate(a.description || a.instruction || a.event, 240);
    var agency = str(a.senderName).trim();
    if (agency) body = body ? body + "\n" + agency : agency;
    return {
        id: "gov:" + rootId + ":" + a.severity,
        kind: "gov_" + a.severity + "_" + a.hazard,
        title: title,
        body: body,
        urgency: a.severity === "extreme" ? "critical" : "normal",
        bypassQuiet: a.severity !== "moderate",
        expires: a.end
    };
}

function rankOf(a, b) {
    var sd = SEV_RANK[b.severity] - SEV_RANK[a.severity];
    if (sd !== 0) return sd;
    if (a.rank !== b.rank) return a.rank - b.rank;
    return b.sent - a.sent;
}

function mergeAlerts(inputs, cancels, state, now) {
    var threads = (state && state.threads ? state.threads : []).filter(function (t) { return t.end + 86400000 > now; });
    var cancelled = {};
    cancels.forEach(function (id) { cancelled[id] = true; });
    var superseded = {};
    var cands = inputs.filter(function (a) { return a.end > now && now >= a.start - LEAD_MS; });
    cands.forEach(function (a) { a.refs.forEach(function (r) { superseded[r] = true; }); });
    cands = cands.filter(function (a) { return !cancelled[a.identifier] && !superseded[a.identifier]; });
    var parent = cands.map(function (_, i) { return i; });
    function find(i) {
        while (parent[i] !== i) {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    }
    for (var i = 0; i < cands.length; i++) {
        for (var j = i + 1; j < cands.length; j++) {
            if (cands[i].identifier === cands[j].identifier || similar(cands[i], cands[j])) parent[find(j)] = find(i);
        }
    }
    var clusters = {};
    cands.forEach(function (a, idx) {
        var r = find(idx);
        (clusters[r] = clusters[r] || []).push(a);
    });
    var active = [];
    var used = {};
    Object.keys(clusters).forEach(function (k) {
        var members = clusters[k].slice().sort(rankOf);
        var rep = members[0];
        var thread = null;
        for (var t = 0; t < threads.length && !thread; t++) {
            if (used[t]) continue;
            var th = threads[t];
            var hit = members.some(function (m) {
                return th.ids.indexOf(m.identifier) >= 0 || m.refs.some(function (r) { return th.ids.indexOf(r) >= 0; }) || similar(th, m);
            });
            if (hit && !cancelled[th.root]) {
                thread = th;
                used[t] = true;
            }
        }
        if (!thread) {
            thread = { root: rep.refs.length ? rep.refs[0] : rep.identifier, ids: [], hazard: rep.hazard, event: rep.event, start: rep.start, end: rep.end };
            threads.push(thread);
            used[threads.length - 1] = true;
        }
        members.forEach(function (m) {
            if (thread.ids.indexOf(m.identifier) < 0) thread.ids.push(m.identifier);
        });
        thread.ids = thread.ids.slice(-30);
        thread.hazard = rep.hazard;
        thread.event = rep.event;
        thread.start = Math.min(thread.start, rep.start);
        thread.end = Math.max(thread.end, rep.end);
        var d = buildDelivery(rep, thread.root);
        active.push({
            id: d.id, root: thread.root, identifier: rep.identifier, kind: d.kind, severity: rep.severity, hazard: rep.hazard,
            title: d.title, body: d.body, urgency: d.urgency, bypassQuiet: d.bypassQuiet, expires: d.expires,
            start: rep.start, event: rep.event, headline: rep.headline, description: rep.description,
            instruction: rep.instruction, senderName: rep.senderName, web: rep.web, lang: rep.lang, source: rep.src,
            sources: members.map(function (m) { return m.src; }).filter(function (s, i2, arr) { return arr.indexOf(s) === i2; })
        });
    });
    active.sort(function (a, b) {
        var sd = SEV_RANK[b.severity] - SEV_RANK[a.severity];
        return sd !== 0 ? sd : a.start - b.start;
    });
    return { active: active, threads: threads };
}

function computeStatus(health) {
    var total = health.length;
    var ok = health.filter(function (h) { return h.ok; }).length;
    var official = health.filter(function (h) { return h.ok && h.id !== "kde"; }).length;
    var status = "unknown";
    if (total > 0) status = ok === total ? "ok" : (ok === 0 ? "unavailable" : "partial");
    var coverage = official > 0 ? "official" : (ok > 0 ? "worldwide" : "none");
    return { status: status, sourcesOk: ok, sourcesTotal: total, coverage: coverage };
}

var exportsObj = {
    parseXml: parseXml, parseCap: parseCap, capFromJson: capFromJson, parsePolygon: parsePolygon, parseCircle: parseCircle,
    pointInPolygon: pointInPolygon, shapesContain: shapesContain, geoJsonShapes: geoJsonShapes, classify: classify,
    evalCap: evalCap, planSources: planSources, handleResult: handleResult, handleCap: handleCap, feedEntries: feedEntries,
    selectFeedLinks: selectFeedLinks, mergeAlerts: mergeAlerts, buildDelivery: buildDelivery, computeStatus: computeStatus,
    nwsToCap: nwsToCap, canadaToCap: canadaToCap, brightskyToCap: brightskyToCap, metnoToCap: metnoToCap,
    similar: similar, feedJobs: feedJobs, truncate: truncate, pickInfo: pickInfo, parseTime: parseTime, LEAD_MS: LEAD_MS
};

if (typeof module !== "undefined" && module.exports) module.exports = exportsObj;
