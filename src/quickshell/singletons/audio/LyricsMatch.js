.pragma library

// Shared title/artist matching for NetEase + lrclib lyrics search.
// Keep this file free of Qt types so Node can unit-test the same logic.

var MIN_ACCEPT_SCORE = 55;

function cleanString(str) {
    if (!str) return "";
    var s = String(str);
    s = s.replace(/\.(?:mp3|flac|wav|m4a|ogg|aac|wma|opus)$/i, "");
    s = s.replace(/[\u2018\u2019\u201A\u201B\u2032\u2035]/g, "'");
    s = s.replace(/\s*[\(\[\{](?:feat\.?|ft\.?|with|official|video|audio|lyrics?|remaster(?:ed)?|deluxe|version|live|radio\s*edit|explicit|clean|bonus|mono|stereo)[^)\]\}]*[)\]\}]/gi, "");
    s = s.replace(/\s*[-–—|/]\s*(?:official(?:\s+music)?\s+video|lyrics?\s+video|audio|visualizer|mv)\s*$/gi, "");
    s = s.replace(/\s*[-–—|/]\s*$/g, "");
    s = s.replace(/^(?:группа|виа|the\s+band)\s+/gi, "");
    s = s.replace(/\s{2,}/g, " ").trim();
    return s;
}

function splitCompoundTrack(str) {
    if (!str) return null;
    var cleaned = cleanString(str);
    var parts = cleaned.split(/\s*[-–—]\s*/);
    if (parts.length >= 2 && parts[0].trim() !== "" && parts[1].trim() !== "") {
        return {
            part1: cleanString(parts[0]),
            part2: cleanString(parts.slice(1).join(" - "))
        };
    }
    return null;
}

function normalizeForMatch(str) {
    return cleanString(str).toLowerCase().replace(/[\u2018\u2019\u201A\u201B\u2032\u2035“”"']/g, "").replace(/\s+/g, " ").trim();
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

function scoreDirect(candidateTitle, candidateArtist, wantTitle, wantArtist) {
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

function scoreTitleArtist(candidateTitle, candidateArtist, wantTitle, wantArtist) {
    var s1 = scoreDirect(candidateTitle, candidateArtist, wantTitle, wantArtist);
    var compound = splitCompoundTrack(wantTitle);
    if (compound) {
        var s2 = scoreDirect(candidateTitle, candidateArtist, compound.part2, compound.part1);
        var s3 = scoreDirect(candidateTitle, candidateArtist, compound.part1, compound.part2);
        return Math.max(s1, s2, s3);
    }
    return s1;
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

// Words that mark a different recording of the same song (live, acoustic,
// remix...): its lyrics are timed for another audio, so it should not win
// over the studio take unless that is what is playing.
var OTHER_VERSION_RE = /(オルゴール|カラオケ|\(inst\.?\)|\binst\.?$)|\b(en vivo|ao vivo|live|directo|concierto|concert|ac[uú]stic[oa]?|acoustic|unplugged|remix|mix|sped up|speed up|slowed|reverb|nightcore|karaoke|instrumental|off vocal|tv size|tv ver|piano|music box|cover|versi[oó]n|version|edit|demo|ensayo|session)\b/i;

function isOtherVersion(item, session) {
    var mine = (session.rawTitle || session.title || "") + " " + (session.album || "");
    var theirs = (item.trackName || item.name || "") + " " + (item.albumName || "");
    var m = theirs.match(OTHER_VERSION_RE);
    if (!m) return false;
    var word = (m[1] || m[2]).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return !new RegExp(m[2] ? "\\b" + word + "\\b" : word, "i").test(mine);
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
    if (isOtherVersion(item, session)) score -= 30;
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
        var album = (s.al && s.al.name) || (s.album && s.album.name) || "";
        if (isOtherVersion({ trackName: s.name || "", albumName: album }, { title: wantTitle || "" })) score -= 30;

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
        session.title || ""
    ];
    var compound = splitCompoundTrack(session.title || "");
    if (compound) {
        queries.push((compound.part1 + " " + compound.part2).trim());
        queries.push((compound.part2 + " " + compound.part1).trim());
        queries.push(compound.part2);
        queries.push(compound.part1);
    }
    queries.push(((session.rawArtist || "") + " " + (session.rawTitle || "")).trim());
    queries.push(session.rawTitle || "");

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
