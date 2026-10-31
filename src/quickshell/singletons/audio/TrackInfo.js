.pragma library

// What is playing, as far as lyrics are concerned: cleaned title/artist,
// the title variants worth searching for, and where the audio comes from.
// Keep this file free of Qt types so Node can unit-test it.

// Where the audio comes from, from the MPRIS art URL / track URL.
function audioSource(artUrl, trackUrl, identity) {
    var u = String(artUrl || "") + " " + String(trackUrl || "");
    var kind = "";
    if (/ytimg\.com|youtube\.com|youtu\.be|googleusercontent\.com/i.test(u)) kind = "YouTube";
    else if (/scdn\.co|spotify/i.test(u)) kind = "Spotify";
    else if (/sndcdn\.com|soundcloud/i.test(u)) kind = "SoundCloud";
    else if (/dzcdn\.net|deezer/i.test(u)) kind = "Deezer";
    else if (/mzstatic\.com|apple/i.test(u)) kind = "Apple Music";
    else if (/bandcamp|bcbits/i.test(u)) kind = "Bandcamp";
    else if (/tidal/i.test(u)) kind = "TIDAL";
    else if (/^\s*file:\/\//i.test(String(trackUrl || "")) || /^\s*file:\/\//i.test(String(artUrl || ""))) kind = "Local";
    var player = String(identity || "").trim();
    return { kind: kind, player: player };
}

// Channel-style names that are the uploader, not the singer.
var UPLOADER_RE = /(\s-\s*topic$|\bvevo$|\bch\.(?:\s|$)|\bchannel$|\bofficial$|\bofficial channel$|\brecords$|\bmusic$|\blyrics?$|\bjpop$|\bkpop$)/i;

function looksLikeUploader(artist) {
    return UPLOADER_RE.test(String(artist || "").trim());
}

// Video-site title words that mark a different recording.
var VERSION_RE = /\b(en vivo|ao vivo|live|directo|concierto|concert|ac[uú]stic[oa]?|acoustic|unplugged|remix|sped up|speed up|slowed|reverb|nightcore|karaoke|instrumental|cover|demo)\b|歌ってみた|弾いてみた/i;

function versionTags(raw) {
    var m = String(raw || "").match(new RegExp(VERSION_RE.source, "gi"));
    return m ? m.map(function (x) { return x.toLowerCase(); }) : [];
}
