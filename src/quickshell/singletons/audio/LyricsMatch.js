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

// Video-site titles: "Song「曲名」歌ってみた【Singer】", "A - Song (X OST) [Sub Español] FMV"...
var JUNK_GROUP_RE = /\s*[\(\[（](?:[^)\]）]*?)(?:ost|sub|subs|subtitulad[oa]|traduc|lyrics?|letra|romaji|español|espanol|english|eng|cover|歌ってみた|official|oficial|m\/?v|fmv|pv|video|audio|hd|4k|1080p)(?:[^)\]）]*)[)\]）]/gi;
var JUNK_TAIL_RE = /\s*(?:[-–—|/]\s*)?(?:fmv|m\/?v|pv|歌ってみた|cover(?:ed)?(?:\s+by\s+.*)?|lyrics?(?:\s+video)?|letra|sub\s+español)\s*$/i;

function cleanVideoTitle(str) {
    var s = String(str || "");
    s = s.replace(/【[^】]*】/g, " ").replace(/\[[^\]]*\]/g, " ");
    for (var i = 0; i < 3; i++) s = s.replace(JUNK_GROUP_RE, " ");
    for (var j = 0; j < 3; j++) s = s.replace(JUNK_TAIL_RE, "");
    return cleanString(s);
}

// Titles to try for one track: the cleaned title, and for 「…」/『…』 both
// the quoted name and what's outside it ("Renai Circulation「恋愛サーキュレーション」").
function titleVariants(raw) {
    var out = [];
    function add(t) {
        t = cleanString(t || "");
        if (t && out.indexOf(t) === -1) out.push(t);
    }
    var c = cleanVideoTitle(raw);
    add(c);
    var q = /[「『]([^」』]+)[」』]/.exec(c);
    if (q) {
        add(q[1]);
        add(c.replace(/[「『][^」』]+[」』]/, " "));
    }
    var comp = splitCompoundTrack(c);
    if (comp) {
        add(comp.part2);
        add(comp.part1);
    }
    return out;
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

// "Hecha Pa' Mí" and "Hecha pa' mi" are the same title: drop accents
// (Latin only; kana/hangul stay composed) and punctuation.
function stripAccents(str) {
    var s = String(str || "");
    if (!s.normalize) return s;
    return s.replace(/[\u00C0-\u024F]/g, function (ch) { return ch.normalize("NFD").replace(/[\u0300-\u036f]/g, ""); });
}

function normalizeForMatch(str) {
    return stripAccents(cleanString(str)).toLowerCase()
        .replace(/[\uFF01-\uFF5E]/g, function (ch) { return String.fromCharCode(ch.charCodeAt(0) - 0xFEE0); })
        .replace(/[\uFEFF\u2018\u2019\u201A\u201B\u2032\u2035“”"'!¡?¿.,;:~～・…]/g, "")
        .replace(/\s+/g, " ").trim();
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
// remix...): its lyrics are timed for another audio.
var OTHER_VERSION_RE = /(オルゴール|カラオケ|\(inst\.?\)|\binst\.?$)|\b(en vivo|ao vivo|live|directo|concierto|concert|ac[uú]stic[oa]?|acoustic|unplugged|remix|mix|sped up|speed up|slowed|reverb|nightcore|karaoke|instrumental|off vocal|tv size|tv ver|piano|music box|cover|versi[oó]n|version|edit|demo|ensayo|session)\b/i;

function isOtherVersion(item, session) {
    var mine = (session.rawTitle || session.title || "") + " " + (session.album || "");
    var theirs = (item.trackName || item.name || "") + " " + (item.albumName || "");
    var m = theirs.match(OTHER_VERSION_RE);
    if (!m) return false;
    var word = (m[1] || m[2]).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return !new RegExp(m[2] ? "\\b" + word + "\\b" : word, "i").test(mine);
}

// Credit lines some sources put at 0:00 ("作词 : …", "Composer: …"): not sung.
var CREDIT_RE = /^\s*(作词|作詞|作曲|编曲|編曲|词|曲|制作人|製作人|监制|混音|母带|和声|吉他|贝斯|鼓|弦乐|录音|出品|发行|OP|SP|lyrics?|lyricist|composer|arranger|producer|written by|music by|vocals?)\s*[:：]/i;

function isCreditLine(text) {
    return CREDIT_RE.test(String(text || ""));
}

// Time of the first sung line of an LRC (null without synced lyrics).
// Candidates whose lyrics were already parsed carry it as `first`.
function firstLineTime(item) {
    if (item && typeof item.first === "number") return item.first;
    var lrc = item && item.syncedLyrics ? String(item.syncedLyrics) : "";
    var re = /\[(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)\]\s*(\S.*)?/g, m;
    while ((m = re.exec(lrc)) !== null) {
        if (m[3] && m[3].trim() !== "" && !isCreditLine(m[3])) return parseFloat(m[1]) * 60 + parseFloat(m[2]);
    }
    return null;
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
    if (score < 0) score = scoreTitleOnly(item, session);
    if (score < 0) score = scoreAliases(item, session);
    if (score < 0 && item.themeMatch) score = 40;
    if (score < 0) return score;

    var album = normalizeForMatch(item.albumName || "");
    var wantAlbum = normalizeForMatch(session.album || "");
    if (album && wantAlbum && album === wantAlbum) score += 12;

    score += scoreDuration(item.duration || 0, session.durationSec || 0);

    if ((item.syncedLyrics && String(item.syncedLyrics).trim() !== "") || typeof item.first === "number") score += 20;
    else if (item.plainLyrics && String(item.plainLyrics).trim() !== "") score += 2;
    if (isOtherVersion(item, session)) score -= 30;
    // the singer is named in the video title or is the channel: that upload
    if (artistNamed(item.artistName || "", session)) score += 15;
    // "(Boyce Avenue acoustic cover)": that singer's take, not the original's
    var al = session.aliases || [];
    for (var c = 0; c < al.length; c++) {
        if (al[c].cover && scoreDirect(item.trackName || item.name || "", item.artistName || "", al[c].title, al[c].artist) > 0) { score += 30; break; }
    }
    // the exact title as the player shows it ("Babel (feat. X)") marks the same release
    var rawT = String(session.rawTitle || "").trim().toLowerCase();
    if (rawT && String(item.trackName || item.name || "").trim().toLowerCase() === rawT) score += 6;
    return score;
}

function artistNamed(artist, session) {
    var where = normalizeForMatch((session.rawTitle || "") + " " + (session.rawArtist || ""));
    var names = String(artist || "").split(/\s*(?:,|&|\/| x | feat\.? | ft\.? )\s*/i);
    for (var i = 0; i < names.length; i++) {
        var a = normalizeForMatch(names[i]);
        if (a.length >= 3 && (" " + where + " ").indexOf(" " + a + " ") !== -1) return true;
    }
    return false;
}

// Covers and uploads ("歌ってみた", fan videos): the artist is the uploader,
// not the singer. Accept an EXACT title match only when the length fits.
function scoreTitleOnly(item, session) {
    var t = normalizeForMatch(item.trackName || item.name || "");
    var vars = titleVariants(session.rawTitle || session.title || "");
    var dur = Number(item.duration || 0), target = Number(session.durationSec || 0);
    if (!(dur > 0 && target > 0 && Math.abs(dur - target) <= 6)) return -100;
    for (var i = 0; i < vars.length; i++) {
        if (t && t === normalizeForMatch(vars[i])) return 30;
    }
    return -100;
}

// One ranking for every candidate from every source (lrclib, NetEase...).
// Returns [{ item, score, first }] best first, only the acceptable ones.
// Consensus: the first-line time most uploads of THIS version agree on wins
// (live/remix uploads don't vote); word-level sync only counts as a bonus
// when it agrees with that consensus.
function rankCandidates(list, session) {
    if (!Array.isArray(list) || list.length === 0) return [];
    var starts = [];
    for (var j = 0; j < list.length; j++)
        starts.push(isOtherVersion(list[j], session) ? null : firstLineTime(list[j]));
    var ranked = [];
    for (var i = 0; i < list.length; i++) {
        var sc = scoreLrclibCandidate(list[i], session);
        var agree = 0;
        if (starts[i] !== null) {
            for (var k = 0; k < starts.length; k++) {
                if (k !== i && starts[k] !== null && Math.abs(starts[k] - starts[i]) <= 1.0) agree++;
            }
            sc += Math.min(30, agree * 4);
            if (list[i].hasWordSync && agree > 0) sc += 8;
        }
        var center = 0;
        if (starts[i] !== null && agree > 0) {
            var sum = starts[i], n = 1;
            for (var c = 0; c < starts.length; c++) {
                if (c !== i && starts[c] !== null && Math.abs(starts[c] - starts[i]) <= 1.0) { sum += starts[c]; n++; }
            }
            center = Math.abs(starts[i] - sum / n);
        }
        if (sc >= MIN_ACCEPT_SCORE) ranked.push({ item: list[i], score: sc, first: firstLineTime(list[i]), agree: agree, center: center });
    }
    // ties: the upload closest to the centre of the timing everyone agrees on
    ranked.sort(function (x, y) { return (y.score - x.score) || (x.center - y.center); });
    return ranked;
}

function pickBestLrclibResult(list, session) {
    var r = rankCandidates(list, session);
    return r.length > 0 ? r[0].item : null;
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

// A NetEase song as a candidate (first: 0 until its lyrics arrive)
function netEaseItem(s) {
    var artists = (s.ar || s.artists || []).map(function (a) { return a.name || ""; });
    return {
        trackName: s.name || "",
        artistName: artists.join(", "),
        albumName: (s.al && s.al.name) || (s.album && s.album.name) || "",
        duration: (s.dt || s.duration || 0) / 1000.0,
        first: 0
    };
}

// NetEase songs worth fetching lyrics for: the best few by title, artist,
// duration and version (not only the first hit).
function pickNetEaseSongs(songs, session, n) {
    var scored = [];
    for (var i = 0; i < (songs || []).length; i++) {
        var s = songs[i];
        var item = netEaseItem(s);
        var sc = scoreLrclibCandidate(item, session);
        if (sc >= MIN_ACCEPT_SCORE - 20) scored.push({ song: s, item: item, score: sc });
    }
    scored.sort(function (x, y) { return y.score - x.score; });
    return scored.slice(0, n || 3);
}

// NetEase searches: "artist title", plus the cleaned title alone (the
// "artist" of a fan upload is the channel, which NetEase won't know).
function buildNetEaseQueries(session) {
    var out = [];
    var q1 = ((session.artist || "") + " " + (session.title || "")).trim();
    if (q1) out.push(q1);
    var vars = titleVariants(session.rawTitle || session.title || "");
    for (var i = 0; i < vars.length && out.length < 3; i++) {
        if (out.indexOf(vars[i]) === -1) out.push(vars[i]);
    }
    return out;
}

function buildLrclibSearchQueries(session) {
    var queries = [((session.artist || "") + " " + (session.title || "")).trim()];
    // cleaned video-site titles early: the caller may only send the first few
    var vars0 = titleVariants(session.rawTitle || session.title || "");
    for (var v0 = 0; v0 < vars0.length; v0++) queries.push(vars0[v0]);
    queries.push(((session.title || "") + " " + (session.artist || "")).trim());
    queries.push(session.title || "");
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

// ---- Other names for the same song -------------------------------------
// session.aliases = [{ title, artist }] found on the way: 『Song』 by Artist
// in the video title, an anime's theme song, the kana/hangul name NetEase
// returns for a romanised title. Candidates are matched against them too.

// "…『Gift』 by Masayoshi Oishi" → [{ title: "Gift", artist: "Masayoshi Oishi" }]
function titleAliases(raw) {
    var out = [];
    var s = String(raw || "");
    var by = /\bby\s+([^\[\(（【|]+?)\s*(?:[\[\(（【|].*)?$/i.exec(s);
    var q = /[「『]([^」』]+)[」』]/.exec(s);
    if (q && by) out.push({ title: cleanString(q[1]), artist: cleanString(by[1]) });
    // "Renuévame by Marcos Witt con letra en HD"
    var sb = /^([^|\[\(（【]+?)\s+by\s+([^|\[\(（【]+?)(?:\s+(?:con|with|w\/|letra|lyrics?|en\s+hd|hd|official|oficial)\b.*)?$/i.exec(s);
    if (sb && !q && sb[1].split(/\s+/).length <= 6 && sb[2].trim().length >= 4) out.push({ title: cleanString(sb[1]), artist: cleanString(sb[2]) });
    // "Song | Singer | Anime FULL OP | Letra": the first two pieces, either way round
    var segs = s.split(/\s+\|\s+/).map(function (x) { return cleanVideoTitle(x); }).filter(function (x) { return x; });
    if (segs.length >= 3) {
        out.push({ title: segs[0], artist: segs[1] });
        out.push({ title: segs[1], artist: segs[0] });
    }
    // K-pop style: "BTS (방탄소년단) 'Dynamite' Official MV"
    var kq = /^([^'‘’"“”]+?)\s*['‘’"“]([^'‘’"“”]{2,})['’"”]/.exec(s);
    if (kq) {
        var ka = cleanString(kq[1].replace(/[\(（][^)）]*[)）]/g, " "));
        if (ka) out.push({ title: cleanString(kq[2]), artist: ka });
    }
    // "Song - Original Artist ft. X (Cover Artist acoustic cover)"
    var cov = /[\(\[]\s*([^()\[\]]+?)\s+(?:acoustic\s+|piano\s+|ac[uú]stic[oa]\s+)?cover\s*[\)\]]/i.exec(s)
        || /\bcover(?:ed)?\s+(?:by|de|por)\s+([^()\[\]|]+)/i.exec(s);
    var parts = s.replace(/[\(\[][^)\]]*[\)\]]/g, " ").split(/\s+[-–—]\s+/);
    if (parts.length >= 2) {
        var song = cleanString(parts[0]);
        var orig = cleanString(parts[1].replace(/\s+(?:ft\.?|feat\.?|x|&)\s.*$/i, "").replace(/\s+on\s+spotify.*$/i, ""));
        if (cov && song) out.push({ title: song, artist: cleanString(cov[1]), cover: true });
        if (cov && song && orig) out.push({ title: song, artist: orig });
    }
    return out;
}

// Romanisation, only to compare a romanised title with its kana/hangul one
// ("Sarang Surowo" ↔ 사랑스러워, "Papapa" ↔ パパパ). Kanji can't be read here.
var HANGUL_L = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"];
var HANGUL_V = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"];
var HANGUL_T = ["", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"];
var KANA = "ア:a イ:i ウ:u エ:e オ:o カ:ka キ:ki ク:ku ケ:ke コ:ko サ:sa シ:shi ス:su セ:se ソ:so タ:ta チ:chi ツ:tsu テ:te ト:to " +
    "ナ:na ニ:ni ヌ:nu ネ:ne ノ:no ハ:ha ヒ:hi フ:fu ヘ:he ホ:ho マ:ma ミ:mi ム:mu メ:me モ:mo ヤ:ya ユ:yu ヨ:yo " +
    "ラ:ra リ:ri ル:ru レ:re ロ:ro ワ:wa ヲ:o ン:n ガ:ga ギ:gi グ:gu ゲ:ge ゴ:go ザ:za ジ:ji ズ:zu ゼ:ze ゾ:zo " +
    "ダ:da ヂ:ji ヅ:zu デ:de ド:do バ:ba ビ:bi ブ:bu ベ:be ボ:bo パ:pa ピ:pi プ:pu ペ:pe ポ:po ヴ:vu " +
    "ァ:a ィ:i ゥ:u ェ:e ォ:o ャ:ya ュ:yu ョ:yo";
var KANA_MAP = (function () {
    var m = {};
    KANA.split(" ").forEach(function (p) { var kv = p.split(":"); m[kv[0]] = kv[1]; });
    return m;
})();

function romanize(str) {
    var s = String(str || "");
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c >= 0x3041 && c <= 0x3096) c += 0x60;            // hiragana → katakana
        var ch = String.fromCharCode(c);
        if (c >= 0xAC00 && c <= 0xD7A3) {
            var x = c - 0xAC00;
            out += HANGUL_L[Math.floor(x / 588)] + HANGUL_V[Math.floor((x % 588) / 28)] + HANGUL_T[x % 28];
        } else if (ch === "ッ") {
            out += "\u0001";                                   // doubles the next consonant
        } else if (ch === "ー") {
            out += out.length ? out.charAt(out.length - 1) : "";
        } else if (KANA_MAP[ch] !== undefined) {
            var r = KANA_MAP[ch];
            // キャ → kya, シャ → sha
            if (/^[ャュョァィゥェォ]$/.test(ch) && /i$/.test(out)) out = out.slice(0, -1) + (/(sh|ch|j)i$/.test(out) ? r.slice(-1) : r);
            else out += r;
        } else {
            out += ch;
        }
    }
    return out.replace(/\u0001(.)/g, "$1$1").replace(/\u0001/g, "");
}

// Consonant outline that survives loose romanisations
// ("sarangseureowo" / "Sarang Surowo" → "srnksr").
function soundKey(str) {
    var s = stripAccents(romanize(String(str || ""))).toLowerCase();
    if (/[^\x00-\x7f]/.test(s.replace(/[\s\p{P}]/gu, ""))) return "";   // kanji etc. left: can't compare
    s = s.replace(/[^a-z]/g, "").replace(/ch/g, "c").replace(/sh/g, "s").replace(/ts/g, "t").replace(/ng/g, "n");
    s = s.replace(/[aeiouyhw]/g, "").replace(/g/g, "k").replace(/d/g, "t").replace(/[bvf]/g, "p")
        .replace(/l/g, "r").replace(/j/g, "c").replace(/z/g, "s");
    return s.replace(/(.)\1+/g, "$1");
}

// The same title written in another script?
// minKey: how many consonants the outline needs (short ones match too easily)
function sameSound(a, b, minKey) {
    var ra = normalizeForMatch(romanize(a)).replace(/\s+/g, "");
    var rb = normalizeForMatch(romanize(b)).replace(/\s+/g, "");
    if (ra && ra === rb) return true;
    var ka = soundKey(a), kb = soundKey(b);
    return ka.length >= (minKey || 5) && ka === kb;
}

function hasNonLatin(str) {
    return /[぀-ヿ㐀-鿿가-힣]/.test(String(str || ""));
}

// Romanised parts of the title ("Loveable (Sarang Surowo)" → both).
function soundVariants(session) {
    var out = titleVariants(session.rawTitle || session.title || "").slice();
    var paren = /[\(（]([^)）]+)[)）]/g, m;
    var raw = String(session.rawTitle || "");
    while ((m = paren.exec(raw)) !== null) out.push(m[1]);
    out.forEach(function (v) { var c = splitCompoundTrack(v); if (c) { out.push(c.part1); out.push(c.part2); } });
    return out;
}

// NetEase songs whose kana/hangul name reads like the romanised title:
// their real names, to search LRCLIB with.
function nativeAliases(songs, session) {
    var out = [];
    var vars = soundVariants(session);
    for (var i = 0; i < (songs || []).length; i++) {
        var s = songs[i];
        var name = cleanString(s.name || "");
        if (!hasNonLatin(name)) continue;
        for (var j = 0; j < vars.length; j++) {
            if (sameSound(name, vars[j])) {
                var ar = (s.ar || s.artists || [])[0];
                out.push({ title: name, artist: ar ? (ar.name || "") : "" });
                break;
            }
        }
    }
    return out;
}

// ---- Anime openings / endings --------------------------------------------
// "OreSuki - Opening Full // sub Español", "Hamefura op; Sub español",
// "Akuyaku Reijou Level 99 ED. Full [...]": the anime name, OP/ED and number.
function animeThemeHint(raw) {
    var s = String(raw || "").replace(/【[^】]*】/g, " ").replace(/\[[^\]]*\]/g, " ");
    var m = /^(.*?)\s*[-–—|:;,/]?\s*(?:\b|\/)(op|opening|ed|ending)\s*\.?\s*(\d{1,2})?(?=$|[\s.;:,\-–—|/『「(\[)\]）]|full|part)/i.exec(s);
    if (!m) return null;
    // "Shape of You - Ed Sheeran": a name, not an ending
    var after = s.slice(m.index + m[0].length);
    if (/^\s+[A-Z][a-z]+/.test(after) && !/^\s+(full|part|ver|version|sub|subs|lyrics?|letra|rom|romaji|tv|ending|opening|theme|song|movie|season)\b/i.test(after)) return null;
    // the anime is the last piece before OP/ED: "Song | Singer | Evangelion FULL OP",
    // "LiSA - Gurenge (Demon Slayer: Kimetsu no Yaiba OP)", "Shingeki no Kyojin -『Song』|"
    var pieces = m[1].replace(/[「『][^」』]*[」』]/g, "|").split(/[|(（]/);
    var anime = "";
    for (var i = pieces.length - 1; i >= 0 && !anime; i--)
        anime = pieces[i].replace(/\b(full|ver\.?|version|tv size)\b/gi, " ").replace(/^[\s\-–—:;,/]+|[\s\-–—|:;,/]+$/g, "").trim();
    anime = anime.replace(/\b(?:op|ed)$/i, "").trim();
    if (anime.length < 3) return null;
    var t = m[2].toLowerCase();
    // names to try in order: that piece, a [bracketed] name ("[Ore wo Suki nano wa…]"),
    // the piece without its last word ("Oresuki Hanakotoba" → "Oresuki")
    var names = [anime];
    var br = /\[([^\]]{6,})\]/.exec(String(raw || ""));
    if (br && !JUNK_GROUP_RE.test("[" + br[1] + "]")) names.push(br[1].trim());
    JUNK_GROUP_RE.lastIndex = 0;
    var words = anime.split(/\s+/);
    if (words.length >= 2) names.push(words.slice(0, -1).join(" "));
    return { anime: anime, names: names, type: (t === "op" || t === "opening") ? "OP" : "ED", seq: m[3] ? parseInt(m[3]) : 0 };
}

// try = which of hint.names (see animeThemeHint)
function animeUrl(hint, tryIdx) {
    var name = hint.names ? (hint.names[tryIdx || 0] || "") : hint.anime;
    return "https://api.animethemes.moe/anime?q=" + encodeURIComponent(name)
        + "&include=animethemes.song.artists,synonyms&page%5Bsize%5D=4";
}

// From the AnimeThemes answer: the theme songs of that type and the
// Japanese names of the anime (NetEase files theme songs under them).
function animeThemePlan(resp, hint, tryIdx) {
    var plan = { songs: [], jpNames: [] };
    var want = normalizeForMatch(hint.names ? hint.names[tryIdx || 0] : hint.anime);
    var list = resp && Array.isArray(resp.anime) ? resp.anime : [];
    for (var i = 0; i < list.length; i++) {
        var a = list[i];
        var names = [a.name || ""].concat((a.synonyms || []).map(function (x) { return x.text || ""; }));
        // the anime must really be the one named in the title
        var ok = names.some(function (n) {
            var nn = normalizeForMatch(n);
            return nn && (nn === want || (want.length >= 6 && nn.indexOf(want) === 0) || (nn.length >= 6 && want.indexOf(nn) === 0)
                || (want.length >= 6 && (" " + nn + " ").indexOf(" " + want + " ") !== -1));    // "Neon Genesis Evangelion"
        });
        if (!ok) continue;
        names.forEach(function (n) {
            if (hasNonLatin(n) && plan.jpNames.indexOf(n) === -1) plan.jpNames.push(n);
        });
        (a.animethemes || []).forEach(function (t) {
            if (t.type !== hint.type || !t.song || !t.song.title) return;
            if (hint.seq && t.sequence && t.sequence !== hint.seq) return;
            var artist = (t.song.artists || []).map(function (x) { return x.name || ""; }).join(", ");
            if (!plan.songs.some(function (p) { return p.title === t.song.title; }))
                plan.songs.push({ title: t.song.title, artist: artist });
        });
    }
    plan.songs = plan.songs.slice(0, 4);
    plan.jpNames = plan.jpNames.slice(0, 2);
    return plan;
}

// "<anime name> OP" on NetEase: the songs it files as that anime's OP/ED.
var THEME_MARK = {
    OP: /(\bOP\d*\b|オープニング|片头曲|主题曲|主題歌|opening)/i,
    ED: /(\bED\d*\b|エンディング|片尾曲|ending)/i
};

function animeCore(name) {
    return normalizeForMatch(name).replace(/[\s「」『』…\.・]/g, "").slice(0, 8);
}

function pickNetEaseThemeSongs(songs, plan, hint) {
    var out = [];
    var cores = plan.jpNames.map(animeCore).filter(function (c) { return c.length >= 3; });
    for (var i = 0; i < (songs || []).length; i++) {
        var s = songs[i];
        var meta = [s.name || "", (s.al && s.al.name) || ""].concat(s.alia || [], s.tns || []).join(" ");
        var flat = normalizeForMatch(meta).replace(/[\s「」『』…\.・]/g, "");
        // filed under the anime's Japanese name, or (Chinese listings) named like the theme song
        var named = plan.songs.some(function (p) { return sameSound(s.name || "", p.title, 3); });
        if (!named && !cores.some(function (c) { return flat.indexOf(c) !== -1; })) continue;
        if (!THEME_MARK[hint.type].test(meta)) continue;
        if (OTHER_VERSION_RE.test(s.name || "")) continue;
        var ar = (s.ar || s.artists || [])[0];
        var item = netEaseItem(s);
        item.themeMatch = true;
        out.push({ song: s, item: item, alias: { title: cleanString(s.name || ""), artist: ar ? (ar.name || "") : "" } });
    }
    return out.slice(0, 3);
}

// Best score of a candidate against the aliases (-100 if none fits)
function scoreAliases(item, session) {
    var best = -100;
    var al = session.aliases || [];
    var t = item.trackName || item.name || "";
    var dur = Number(item.duration || 0), target = Number(session.durationSec || 0);
    var lenOk = dur > 0 && target > 0 && Math.abs(dur - target) <= 8;
    for (var i = 0; i < al.length; i++) {
        var sc = -100;
        if (al[i].artist) sc = scoreDirect(t, item.artistName || "", al[i].title, al[i].artist);
        // artist written another way (斉藤朱夏 / Shuka Saitou): the title and the length must fit
        if (sc < 0 && lenOk && (normalizeForMatch(t) === normalizeForMatch(al[i].title) || sameSound(t, al[i].title, 3))) sc = 40;
        if (sc > best) best = sc;
    }
    return best;
}

// Lyrics without timing (many worship songs are only that on LRCLIB): the
// best one when nothing synced was found. Their length may differ (live
// takes), so it doesn't count against them; the title and singer must fit.
function pickPlain(list, session) {
    var best = null, bestScore = 0;
    for (var i = 0; i < (list || []).length; i++) {
        var it = list[i];
        if (!it || it.instrumental || !it.plainLyrics || String(it.plainLyrics).trim() === "") continue;
        if (isOtherVersion(it, session)) continue;
        var t = it.trackName || it.name || "";
        var sc = scoreTitleArtist(t, it.artistName || "", session.title || "", session.artist || "");
        var al = session.aliases || [];
        for (var j = 0; j < al.length; j++)
            if (al[j].artist) sc = Math.max(sc, scoreDirect(t, it.artistName || "", al[j].title, al[j].artist));
        if (sc < 0 && artistNamed(it.artistName || "", session)) {
            var vars = titleVariants(session.rawTitle || session.title || "");
            for (var k = 0; k < vars.length; k++)
                if (normalizeForMatch(t) === normalizeForMatch(vars[k])) sc = 60;
        }
        if (sc < 53) continue;
        var d = Math.abs(Number(it.duration || 0) - Number(session.durationSec || 0));
        if (d <= 6) sc += 10;
        if (sc > bestScore) { bestScore = sc; best = it; }
    }
    return best;
}
