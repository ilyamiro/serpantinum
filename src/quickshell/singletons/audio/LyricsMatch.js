.pragma library

// Shared title/artist matching for NetEase + lrclib lyrics search.
// Keep this file free of Qt types so Node can unit-test the same logic.

var MIN_ACCEPT_SCORE = 55;

function cleanString(str) {
    if (!str) return "";
    var s = String(str);
    s = s.replace(/\s*[\(\[\{](?:feat\.?|ft\.?|with|official|video|audio|lyrics?|remaster(?:ed)?|deluxe|version|live|radio\s*edit|explicit|clean|bonus|mono|stereo)[^)\]\}]*[)\]\}]/gi, "");
    s = s.replace(/\s*[-–—|]\s*(?:official(?:\s+music)?\s+video|lyrics?\s+video|audio|visualizer|mv)\s*$/gi, "");
    s = s.replace(/\s{2,}/g, " ").trim();
    return s;
}

function normalizeForMatch(str) {
    return cleanString(str).toLowerCase().replace(/[“”"']/g, "").replace(/\s+/g, " ").trim();
}

function durationSecondsFromMpris(length) {
    var len = Number(length);
    if (!isFinite(len) || len <= 0) return 0;
    // MPRIS length is microseconds; some clients expose ms or seconds.
    // ≥ 1_000_000 → microseconds (≥1s), else >1000 → milliseconds, else seconds.
    if (len >= 1000000) return len / 1000000.0;
    if (len > 1000) return len / 1000.0;
    return len;
}

function scoreTitleArtist(candidateTitle, candidateArtist, wantTitle, wantArtist) {
    var t = normalizeForMatch(candidateTitle || "");
    var a = normalizeForMatch(candidateArtist || "");
    var wantT = normalizeForMatch(wantTitle || "");
    var wantA = normalizeForMatch(wantArtist || "");

    var titleScore = 0;
    if (t && wantT && t === wantT) titleScore = 40;
    else if (t && wantT && (t.indexOf(wantT) !== -1 || wantT.indexOf(t) !== -1)) titleScore = 18;

    var artistScore = 0;
    if (a && wantA && a === wantA) artistScore = 35;
    else if (a && wantA && (a.indexOf(wantA) !== -1 || wantA.indexOf(a) !== -1)) artistScore = 18;

    // Reject clear mismatches (same title, wrong artist / vice versa)
    if (wantA && artistScore < 18) return -100;
    if (wantT && titleScore < 18) return -100;

    return titleScore + artistScore;
}

function scoreDuration(candidateSec, targetSec) {
    var dur = Number(candidateSec || 0);
    var target = Number(targetSec || 0);
    if (!(dur > 0 && target > 0)) return 0;
    var diff = Math.abs(dur - target);
    if (diff <= 1.5) return 28;
    if (diff <= 3) return 18;
    if (diff <= 6) return 8;
    if (diff > 15) return -40;
    return -Math.min(24, diff);
}

function scoreLrclibCandidate(item, session) {
    if (!item) return -999;
    if (item.instrumental) return -50;

    var score = scoreTitleArtist(
        item.trackName || item.name || "",
        item.artistName || "",
        session.title || "",
        session.artist || ""
    );
    if (score < 0) return score;

    var album = normalizeForMatch(item.albumName || "");
    var wantAlbum = normalizeForMatch(session.album || "");
    if (album && wantAlbum && album === wantAlbum) score += 12;

    score += scoreDuration(item.duration || 0, session.durationSec || 0);

    if (item.syncedLyrics && String(item.syncedLyrics).trim() !== "") score += 20;
    else if (item.plainLyrics && String(item.plainLyrics).trim() !== "") score += 2;
    if (item.hasWordSync) score += 8;
    return score;
}

function pickBestLrclibResult(list, session) {
    if (!Array.isArray(list) || list.length === 0) return null;
    var best = null;
    var bestScore = -999;
    for (var i = 0; i < list.length; i++) {
        var sc = scoreLrclibCandidate(list[i], session);
        if (sc > bestScore) {
            bestScore = sc;
            best = list[i];
        }
    }
    if (!best || bestScore < MIN_ACCEPT_SCORE) return null;
    return best;
}

function pickBestNetEaseSong(songs, wantTitle, wantArtist, targetDurSec) {
    if (!songs || songs.length === 0) return null;
    var best = null;
    var bestScore = -999;
    for (var i = 0; i < songs.length; i++) {
        var s = songs[i];
        var artist = "";
        if (s.ar && s.ar.length > 0) artist = s.ar[0].name || "";
        else if (s.artists && s.artists.length > 0) artist = s.artists[0].name || "";

        var score = scoreTitleArtist(s.name || "", artist, wantTitle || "", wantArtist || "");
        if (score < 0) continue;

        var dur = ((s.dt || s.duration || 0) / 1000.0);
        score += scoreDuration(dur, targetDurSec || 0);

        if (score > bestScore) {
            bestScore = score;
            best = s;
        }
    }
    if (!best || bestScore < MIN_ACCEPT_SCORE) return null;
    return best;
}

function buildLrclibSearchQueries(session) {
    var queries = [
        ((session.artist || "") + " " + (session.title || "")).trim(),
        ((session.title || "") + " " + (session.artist || "")).trim(),
        session.title || "",
        ((session.rawArtist || "") + " " + (session.rawTitle || "")).trim(),
        session.rawTitle || ""
    ];
    var seen = {};
    var uniq = [];
    for (var i = 0; i < queries.length; i++) {
        var q = (queries[i] || "").trim();
        if (!q || seen[q]) continue;
        seen[q] = true;
        uniq.push(q);
    }
    return uniq;
}
