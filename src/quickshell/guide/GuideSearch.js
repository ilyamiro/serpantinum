.pragma library

function normalize(text) {
    if (!text) return "";
    let str = String(text);
    str = str.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    if (typeof str.normalize === "function") {
        str = str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }
    str = str.toLowerCase();
    str = str.replace(/[-_/.:›()[\],;+|\\]+/g, " ");
    return str.replace(/\s+/g, " ").trim();
}

function compact(normText) {
    return normText ? normText.replace(/\s+/g, "") : "";
}

function splitWords(normText) {
    return normText ? normText.split(" ").filter(w => w.length > 0) : [];
}

function tokenize(query) {
    let norm = normalize(query);
    if (!norm) return [];
    let raw = norm.split(" ");
    let out = [];
    for (let i = 0; i < raw.length; i++) {
        if (raw[i] && out.indexOf(raw[i]) === -1) out.push(raw[i]);
    }
    return out;
}

function acronym(words) {
    if (!words || words.length < 2) return "";
    let out = "";
    for (let i = 0; i < words.length; i++) {
        if (words[i].length > 0) out += words[i][0];
    }
    return out;
}

function prepareEntry(title, desc, section, tabTitle, subtabTitle, keywords, tabKey, subtabKey, id) {
    let titleNorm = normalize(title);
    let sectionNorm = normalize([section, tabTitle, subtabTitle].join(" "));
    let keywordsNorm = normalize([keywords, tabKey, subtabKey, id].join(" "));
    let descNorm = normalize(desc);

    let titleWords = splitWords(titleNorm);
    let sectionWords = splitWords(sectionNorm);
    let keywordWords = splitWords(keywordsNorm);
    let descWords = splitWords(descNorm);

    return {
        title: titleNorm,
        titleCompact: compact(titleNorm),
        titleWords: titleWords,
        titleAcronym: acronym(titleWords),
        section: sectionNorm,
        sectionCompact: compact(sectionNorm),
        sectionWords: sectionWords,
        keywords: keywordsNorm,
        keywordsCompact: compact(keywordsNorm),
        keywordWords: keywordWords,
        desc: descNorm,
        descWords: descWords,
        allCompact: compact(titleNorm + " " + sectionNorm + " " + keywordsNorm)
    };
}

function damerauDistance(a, b, maxDist) {
    let la = a.length;
    let lb = b.length;
    if (Math.abs(la - lb) > maxDist) return maxDist + 1;
    if (la === 0) return lb;
    if (lb === 0) return la;

    let prev2 = null;
    let prev = new Array(lb + 1);
    for (let j = 0; j <= lb; j++) prev[j] = j;

    for (let i = 1; i <= la; i++) {
        let curr = new Array(lb + 1);
        curr[0] = i;
        let rowMin = curr[0];
        let ca = a.charCodeAt(i - 1);

        for (let j = 1; j <= lb; j++) {
            let cost = ca === b.charCodeAt(j - 1) ? 0 : 1;
            let val = Math.min(
                prev[j] + 1,
                curr[j - 1] + 1,
                prev[j - 1] + cost
            );
            if (i > 1 && j > 1 && prev2 !== null && ca === b.charCodeAt(j - 2) && a.charCodeAt(i - 2) === b.charCodeAt(j - 1)) {
                val = Math.min(val, prev2[j - 2] + 1);
            }
            curr[j] = val;
            if (val < rowMin) rowMin = val;
        }
        if (rowMin > maxDist) return maxDist + 1;
        prev2 = prev;
        prev = curr;
    }
    return prev[lb];
}

function isAdjacentTransposition(a, b) {
    if (a.length !== b.length || a.length < 3) return false;
    let diff = -1;
    for (let i = 0; i < a.length; i++) {
        if (a.charCodeAt(i) !== b.charCodeAt(i)) {
            if (diff !== -1) return false;
            if (i + 1 >= a.length) return false;
            if (a.charCodeAt(i) !== b.charCodeAt(i + 1) || a.charCodeAt(i + 1) !== b.charCodeAt(i)) return false;
            diff = i;
            i++;
        }
    }
    return diff !== -1;
}

function fuzzyWordScore(token, words, baseScore, stepPenalty) {
    let len = token.length;
    if (len < 4 || !words || words.length === 0) return -1;

    if (len === 4) {
        for (let i = 0; i < words.length; i++) {
            if (isAdjacentTransposition(token, words[i])) return baseScore;
        }
        return -1;
    }

    let maxDist = len >= 7 ? 2 : 1;
    let bestDist = maxDist + 1;

    for (let i = 0; i < words.length; i++) {
        let w = words[i];
        if (w.length < 4) continue;
        let d = damerauDistance(token, w, Math.min(maxDist, bestDist - 1));
        if (d < bestDist) {
            bestDist = d;
            if (bestDist === 1) break;
        }
        if (w.length > len + 1) {
            let pref = w.slice(0, len);
            let dp = damerauDistance(token, pref, Math.min(1, bestDist - 1));
            if (dp < bestDist) {
                bestDist = dp;
                if (bestDist === 1) break;
            }
        }
    }

    if (bestDist <= maxDist) return Math.max(4, baseScore - (bestDist - 1) * stepPenalty);
    return -1;
}

function matchWords(token, words, exactScore, prefixScore) {
    let best = -1;
    for (let i = 0; i < words.length; i++) {
        let w = words[i];
        if (w === token) return exactScore;
        if (w.indexOf(token) === 0 && prefixScore > best) best = prefixScore;
    }
    return best;
}

function scoreToken(token, entry) {
    let best = -1;

    let tw = matchWords(token, entry.titleWords, 120, 96);
    if (tw > best) best = tw;
    if (best < 100 && entry.titleAcronym && entry.titleAcronym === token && token.length >= 2) best = 100;
    if (best < 76 && (entry.title.indexOf(token) !== -1 || (token.length >= 4 && entry.titleCompact.indexOf(token) !== -1))) {
        best = 76;
    }

    let kw = matchWords(token, entry.keywordWords, 84, 68);
    if (kw > best) best = kw;
    let sw = matchWords(token, entry.sectionWords, 80, 66);
    if (sw > best) best = sw;

    if (best < 54) {
        if (entry.keywords.indexOf(token) !== -1 || entry.section.indexOf(token) !== -1) {
            best = 54;
        } else if (token.length >= 4 && (entry.keywordsCompact.indexOf(token) !== -1 || entry.sectionCompact.indexOf(token) !== -1 || entry.allCompact.indexOf(token) !== -1)) {
            best = 52;
        }
    }

    let dw = matchWords(token, entry.descWords, 56, 44);
    if (dw > best) best = dw;
    if (best < 32 && entry.desc.indexOf(token) !== -1) best = 32;

    if (best >= 0) return best;

    let ft = fuzzyWordScore(token, entry.titleWords, 46, 16);
    if (ft > best) best = ft;
    let fk = fuzzyWordScore(token, entry.keywordWords, 34, 12);
    if (fk > best) best = fk;
    let fs = fuzzyWordScore(token, entry.sectionWords, 32, 12);
    if (fs > best) best = fs;
    let fd = fuzzyWordScore(token, entry.descWords, 22, 8);
    if (fd > best) best = fd;

    return best;
}

function scoreEntry(entry, rawQuery, tokens) {
    if (!entry || !tokens || tokens.length === 0) return -1;

    let total = 0;
    let titleHits = 0;

    for (let i = 0; i < tokens.length; i++) {
        let tok = tokens[i];
        let s = scoreToken(tok, entry);
        if (s < 0) return -1;
        total += s;
        if (s >= 76) titleHits++;
    }

    let avg = total / tokens.length;
    let normQ = normalize(rawQuery);
    let compactQ = compact(normQ);

    if (normQ !== "") {
        if (entry.title === normQ) avg += 220;
        else if (entry.title.indexOf(normQ) === 0) avg += 120;
        else if (entry.title.indexOf(normQ) !== -1) avg += 65;
        else if (compactQ.length >= 4 && entry.titleCompact.indexOf(compactQ) !== -1) avg += 50;
        else if (entry.keywords.indexOf(normQ) !== -1 || entry.section.indexOf(normQ) !== -1) avg += 30;
        else if (entry.desc.indexOf(normQ) !== -1) avg += 18;
    }

    if (tokens.length > 1 && titleHits === tokens.length) avg += 40;
    avg -= Math.min(8, entry.title.length * 0.08);
    return avg;
}

function escapeHtml(text) {
    return String(text || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function highlightMatch(text, query, color) {
    let raw = String(text || "");
    if (!raw) return "";
    let tokens = tokenize(query).filter(t => t.length >= 2);
    if (tokens.length === 0) return escapeHtml(raw);

    let lower = raw.toLowerCase();
    let ranges = [];
    for (let i = 0; i < tokens.length; i++) {
        let tok = tokens[i];
        let idx = lower.indexOf(tok);
        while (idx !== -1) {
            ranges.push([idx, idx + tok.length]);
            idx = lower.indexOf(tok, idx + tok.length);
        }
    }
    if (ranges.length === 0) return escapeHtml(raw);

    ranges.sort((a, b) => a[0] - b[0] || b[1] - a[1]);
    let merged = [ranges[0]];
    for (let i = 1; i < ranges.length; i++) {
        let last = merged[merged.length - 1];
        if (ranges[i][0] <= last[1]) {
            if (ranges[i][1] > last[1]) last[1] = ranges[i][1];
        } else {
            merged.push(ranges[i]);
        }
    }

    let out = "";
    let pos = 0;
    let col = String(color || "#cba6f7");
    for (let i = 0; i < merged.length; i++) {
        let r = merged[i];
        if (r[0] > pos) out += escapeHtml(raw.slice(pos, r[0]));
        out += "<font color=\"" + col + "\">" + escapeHtml(raw.slice(r[0], r[1])) + "</font>";
        pos = r[1];
    }
    if (pos < raw.length) out += escapeHtml(raw.slice(pos));
    return out;
}
