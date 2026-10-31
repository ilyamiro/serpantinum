pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "LyricsMatch.js" as LyricsMatch
import "TrackInfo.js" as TrackInfo

Item {
    id: root

    property int subscribers: 0
    property var customPlayer: null
    readonly property var player: customPlayer || MprisController.activePlayer

    readonly property bool isMediaActive: {
        try {
            return !!player && player.playbackState !== MprisPlaybackState.Stopped && (player.trackTitle || "") !== "";
        } catch (e) {
            return false;
        }
    }
    readonly property string trackTitle: {
        try {
            return player ? String(player.trackTitle || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string trackArtist: {
        try {
            return player ? String(player.trackArtist || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string currentTrackKey: isMediaActive ? (trackArtist.trim() + " - " + trackTitle.trim()) : ""

    property var localCache: ({})

    function getMemCache() {
        try {
            if (typeof globalThis !== "undefined" && globalThis) {
                if (!globalThis._serpantinumLyrics) globalThis._serpantinumLyrics = {};
                return globalThis._serpantinumLyrics;
            }
        } catch(e) {}
        if (!root.localCache) root.localCache = {};
        return root.localCache;
    }

    property var lyrics: []
    property bool hasLyrics: false
    property bool loading: false
    property string activeFetchKey: ""
    property string lastFetchedKey: ""
    property real currentPosition: 0
    property var activeSession: null

    // Manual sync per song (seconds): + shows the lyrics earlier, - later.
    // For lyrics timed for a slightly different recording.
    property real userOffset: 0
    property var offsets: ({})
    readonly property real syncPosition: currentPosition + userOffset

    function nudgeOffset(delta) {
        let key = root.currentTrackKey;
        if (!key) return;
        let v = Math.round((root.userOffset + delta) * 10) / 10;
        if (Math.abs(v) < 0.05) v = 0;
        root.userOffset = v;
        let o = Object.assign({}, root.offsets);
        if (v === 0) delete o[key]; else o[key] = v;
        root.offsets = o;
        saveOffsetsProcess.payload = JSON.stringify(o);
        saveOffsetsProcess.running = false;
        saveOffsetsProcess.running = true;
        root.nextBoundaryTime = root.computeNextBoundary();
    }

    // Lyrics without timing: no line is "current"; the view scrolls them
    // along with the song instead (unsyncedProgress)
    readonly property bool unsynced: !!(sourceInfo && sourceInfo.unsynced)
    readonly property real unsyncedProgress: {
        let d = getPlayerDurationSec();
        return d > 1 ? Math.max(0, Math.min(1, currentPosition / d)) : 0;
    }

    readonly property int currentIndex: {
        if (!hasLyrics || lyrics.length === 0 || unsynced) return -1;
        let pos = syncPosition;
        let idx = -1;
        for (let i = 0; i < lyrics.length; i++) {
            if (pos >= lyrics[i].time) {
                idx = i;
            } else {
                break;
            }
        }
        return idx;
    }

    function subscribe() {
        subscribers++;
        triggerSearch();
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            searchTimeoutTimer.stop();
            cacheReadProcess.running = false;
            fileReadProcess.running = false;
            if (loading) {
                loading = false;
                lastFetchedKey = "";
                activeFetchKey = "";
                activeSession = null;
            }
        }
    }

    function getPlayerDurationSec() {
        if (!root.player || !root.player.length) return 0;
        return LyricsMatch.durationSecondsFromMpris(root.player.length);
    }

    function pickBestNetEaseSong(songs, session) {
        let wantT = session ? session.title : root.trackTitle;
        let wantA = session ? session.artist : root.trackArtist;
        let targetDur = session && session.durationSec > 0 ? session.durationSec : getPlayerDurationSec();
        return LyricsMatch.pickBestNetEaseSong(songs, wantT, wantA, targetDur);
    }

    function getLineOpacity(idx, curIdx) {
        if (root.unsynced) return 0.85;
        if (curIdx < 0) return 0.50;
        if (idx === curIdx) return 1.0;
        let d = Math.abs(idx - curIdx);
        if (d === 1) return 0.60;
        if (d === 2) return 0.38;
        return Math.max(0.20, 0.38 - ((d - 2) * 0.08));
    }

    function renderActiveLineText(modelData, pos, highlightColor, textColor) {
        if (!modelData.words || modelData.words.length === 0) {
            return modelData.text !== "" ? modelData.text : "♪";
        }
        let activeIdx = -1;
        for (let i = 0; i < modelData.words.length; i++) {
            let w = modelData.words[i];
            let end = (w.endTime !== undefined && w.endTime > w.time) ? w.endTime : (i < modelData.words.length - 1 ? modelData.words[i + 1].time : (w.time + 0.8));
            if (pos >= w.time && pos < end) {
                activeIdx = i;
                break;
            }
        }
        let highlight = highlightColor ? highlightColor.toString() : "#cba6f7";
        let baseText = textColor ? textColor.toString() : "#cdd6f4";
        let parsedTextCol = Qt.color(baseText);
        let upcoming = Qt.rgba(parsedTextCol.r, parsedTextCol.g, parsedTextCol.b, 0.40).toString();
        let html = "";
        for (let i = 0; i < modelData.words.length; i++) {
            let w = modelData.words[i];
            let end = (w.endTime !== undefined && w.endTime > w.time) ? w.endTime : (i < modelData.words.length - 1 ? modelData.words[i + 1].time : (w.time + 0.8));

            let space = "";
            if (i < modelData.words.length - 1) {
                let nextW = modelData.words[i + 1];
                if (!w.text.endsWith(" ") && !nextW.text.startsWith(" ")) {
                    if (/\S/.test(w.text) && !/^[,.\!?:;)\]]/.test(nextW.text)) {
                        space = " ";
                    }
                }
            }

            let escaped = w.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

            if (i === activeIdx) {
                html += "<font color='" + highlight + "'>" + escaped + "</font>" + space;
            } else if (pos >= end || (activeIdx !== -1 && i < activeIdx)) {
                html += "<font color='" + baseText + "'>" + escaped + "</font>" + space;
            } else {
                html += "<font color='" + upcoming + "'>" + escaped + "</font>" + space;
            }
        }
        return html.trim();
    }

    property real polledPosition: 0
    property real nextBoundaryTime: Infinity

    function computeNextBoundary() {
        let ly = root.lyrics;
        if (!root.hasLyrics || !ly || ly.length === 0) return Infinity;
        let p = root.syncPosition;
        let idx = -1;
        for (let i = 0; i < ly.length; i++) {
            if (p >= ly[i].time) idx = i;
            else break;
        }
        let best = Infinity;
        if (idx + 1 < ly.length) best = ly[idx + 1].time;
        if (idx >= 0) {
            let words = ly[idx].words;
            if (words) {
                for (let i = 0; i < words.length; i++) {
                    let w = words[i];
                    let end = (w.endTime !== undefined && w.endTime > w.time) ? w.endTime : (i < words.length - 1 ? words[i + 1].time : (w.time + 0.8));
                    if (w.time > p && w.time < best) best = w.time;
                    if (end > p && end < best) best = end;
                }
            }
        }
        return best - root.userOffset;   // in player time
    }

    property real pendingJumpPosition: -1
    property real seekGuardTarget: 0
    property double seekGuardUntil: 0

    function noteSeek(t) {
        root.seekGuardTarget = t;
        root.seekGuardUntil = Date.now() + 1500;
        root.pendingJumpPosition = -1;
        root.polledPosition = t;
        root.currentPosition = t;
    }

    function applyPosition(pos) {
        if (typeof pos !== "number" || !isFinite(pos) || pos < 0) return;

        if (root.seekGuardUntil > 0) {
            if (Date.now() < root.seekGuardUntil && Math.abs(pos - root.seekGuardTarget) > 1.5) return;
            root.seekGuardUntil = 0;
        }

        root.polledPosition = pos;

        if (pos < root.currentPosition - 0.3) {
            let pending = root.pendingJumpPosition;
            if (pending >= 0 && Math.abs(pos - pending) < 1.5) {
                root.pendingJumpPosition = -1;
                root.currentPosition = pos;
            } else {
                root.pendingJumpPosition = pos;
            }
            return;
        }

        root.pendingJumpPosition = -1;
        if (pos >= root.nextBoundaryTime) {
            root.currentPosition = pos;
        }
    }

    onCurrentPositionChanged: root.nextBoundaryTime = root.computeNextBoundary()

    function refreshForLyrics() {
        if (root.hasLyrics && positionTimer.running) root.currentPosition = root.polledPosition;
        root.nextBoundaryTime = root.computeNextBoundary();
    }

    onLyricsChanged: root.refreshForLyrics()
    onHasLyricsChanged: root.refreshForLyrics()

    Timer {
        id: positionTimer
        interval: 100
        repeat: true
        running: root.subscribers > 0 && root.isMediaActive && (root.player ? root.player.isPlaying : false)
        onRunningChanged: {
            if (running) positionTimer.interval = 25;
        }
        onTriggered: {
            if (root.player) {
                if (typeof root.player.positionChanged === "function") {
                    root.player.positionChanged();
                }
                root.applyPosition(root.player.position);
            } else {
                root.applyPosition(MprisController.livePosition);
            }
            if (!root.hasLyrics) {
                positionTimer.interval = 250;
            } else {
                positionTimer.interval = (root.nextBoundaryTime - root.polledPosition < 0.3) ? 25 : 100;
            }
        }
    }

    Timer {
        id: searchTimeoutTimer
        interval: 14000
        repeat: false
        onTriggered: {
            // decide with whatever arrived (a slow source doesn't block)
            if (root.activeSession && !root.activeSession.decided) root.decide(root.activeSession);
        }
    }

    Connections {
        target: MprisController
        function onLivePositionChanged() {
            if (!root.player || !root.player.isPlaying) {
                root.currentPosition = MprisController.livePosition;
            }
        }
        function onActivePlayerChanged() {
            if (!root.customPlayer) {
                root.triggerSearch();
            }
        }
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            if (!root.player) return;
            if (root.player.isPlaying) {
                if (!positionTimer.running) root.applyPosition(root.player.position);
            } else {
                root.pendingJumpPosition = -1;
                root.currentPosition = root.player.position;
            }
        }
        function onTrackTitleChanged() {
            root.triggerSearch();
        }
        function onTrackArtistChanged() {
            root.triggerSearch();
        }
        function onPlaybackStateChanged() {
            root.triggerSearch();
        }
    }

    onCurrentTrackKeyChanged: {
        root.userOffset = root.offsets[root.currentTrackKey] || 0;
        triggerSearch();
    }
    onPlayerChanged: triggerSearch()

    property double lastAttemptAt: 0

    function resetPositionGuards() {
        root.pendingJumpPosition = -1;
        root.seekGuardUntil = 0;
    }

    function triggerSearch() {
        if (root.subscribers <= 0) return;

        if (!isMediaActive || currentTrackKey === "") {
            lastFetchedKey = "";
            activeFetchKey = "";
            activeSession = null;
            lyrics = [];
            hasLyrics = false;
            loading = false;
            searchTimeoutTimer.stop();
            return;
        }

        let isNewKey = currentTrackKey !== activeFetchKey;
        if (!isNewKey) {
            if (lyrics && lyrics.length > 0) return;
            if (loading) return;
            if (Date.now() - lastAttemptAt < 30000) return;
        }

        lastFetchedKey = currentTrackKey;
        activeFetchKey = currentTrackKey;
        if (activeSession) activeSession.decided = true;
        activeSession = null;
        searchTimeoutTimer.stop();
        cacheReadProcess.running = false;
        if (isNewKey) resetPositionGuards();
        lyrics = [];
        hasLyrics = false;
        loading = true;
        lastAttemptAt = Date.now();
        checkCacheAndFetch(currentTrackKey);
    }

    // Cache entries (v2): { v, algo, lines, source, top: [{ info, lines }], duration }
    // Bump ALGO when the search/ranking changes: old picks are searched again.
    readonly property int cacheAlgo: 7
    function restoreEntry(entry, key) {
        root.sourceInfo = entry.source || null;
        root.cachedTop = (entry.top || []).map((t, i) => ({ info: t.info, lines: i === 0 ? entry.lines : t.lines }));
        root.candidates = root.cachedTop.map(t => t.info);
        applyLyrics(entry.lines, key, false);
    }

    function entryFits(entry) {
        if (!entry || entry.v !== 2 || entry.algo !== root.cacheAlgo || !Array.isArray(entry.lines) || entry.lines.length === 0) return false;
        let now = getPlayerDurationSec();
        // another length = another video/recording under the same name: search again
        return !(now > 1 && entry.duration > 1 && Math.abs(now - entry.duration) > 3);
    }

    function checkCacheAndFetch(key) {
        let mem = getMemCache();
        if (mem && entryFits(mem[key])) {
            restoreEntry(mem[key], key);
            return;
        }

        root.loading = true;
        cacheReadProcess.running = false;
        cacheReadProcess.targetKey = key;
        cacheReadProcess.running = true;
    }

    function saveLyricsToDisk(key, parsedList) {
        if (!key || !parsedList || parsedList.length === 0) return;
        try {
            let entry = {
                v: 2,
                algo: root.cacheAlgo,
                lines: parsedList,
                source: root.sourceInfo,
                top: (root.cachedTop || []).map((t, i) => ({ info: t.info, lines: i === 0 ? [] : t.lines })),
                duration: getPlayerDurationSec()
            };
            let mem = getMemCache();
            if (mem) mem[key] = entry;
            let jsonStr = JSON.stringify(entry);
            if (saveLyricsProcess.running) {
                saveLyricsProcess.running = false;
            }
            saveLyricsProcess.pendingKey = key;
            saveLyricsProcess.pendingData = jsonStr;
            saveLyricsProcess.running = true;
        } catch (e) {}
    }

    function cleanString(str) {
        return LyricsMatch.cleanString(str);
    }

    function parseYrc(yrcText) {
        if (!yrcText || typeof yrcText !== "string") return null;
        let lines = yrcText.split("\n");
        let result = [];
        let hasAnyWord = false;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line) continue;

            let lineTime = -1;
            let content = "";

            let msMatch = line.match(/^\[(\d+),(\d+)\](.*)$/);
            if (msMatch) {
                lineTime = parseFloat(msMatch[1]) / 1000.0;
                content = msMatch[3];
            } else {
                let lrcMatch = line.match(/^\[(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)\](.*)$/);
                if (lrcMatch) {
                    lineTime = parseFloat(lrcMatch[1]) * 60 + parseFloat(lrcMatch[2]);
                    content = lrcMatch[3];
                }
            }

            if (lineTime < 0) continue;

            let words = [];
            let wordRegex = /\((\d+),(\d+)(?:,\d+)?\)([^\(\[\n\r]*)/g;
            let match;

            while ((match = wordRegex.exec(content)) !== null) {
                let rawStart = parseFloat(match[1]) / 1000.0;
                let dur = parseFloat(match[2]) / 1000.0;
                let wStart = (rawStart < lineTime) ? (lineTime + rawStart) : rawStart;
                let wEnd = wStart + (dur > 0 ? dur : 0.25);
                let wText = match[3];
                if (wText !== "") {
                    words.push({ time: wStart, endTime: wEnd, text: wText });
                }
            }

            if (words.length === 0) {
                let altRegex = /<(\d+),(\d+)>([^<]*)/g;
                while ((match = altRegex.exec(content)) !== null) {
                    let rawStart = parseFloat(match[1]) / 1000.0;
                    let dur = parseFloat(match[2]) / 1000.0;
                    let wStart = (rawStart < lineTime) ? (lineTime + rawStart) : rawStart;
                    let wEnd = wStart + (dur > 0 ? dur : 0.25);
                    let wText = match[3];
                    if (wText !== "") {
                        words.push({ time: wStart, endTime: wEnd, text: wText });
                    }
                }
            }

            let cleanLine = content.replace(/\(\d+,\d+(?:,\d+)?\)/g, "").replace(/<\d+,\d+>/g, "").trim();
            if (cleanLine === "" && words.length > 0) {
                cleanLine = words.map(function(w) { return w.text; }).join("").trim();
            }

            if (words.length > 0) {
                hasAnyWord = true;
                result.push({
                    time: lineTime,
                    text: cleanLine,
                    words: words
                });
            } else if (cleanLine !== "") {
                result.push({
                    time: lineTime,
                    text: cleanLine,
                    words: []
                });
            }
        }

        if (hasAnyWord && result.length > 0) {
            result.sort(function(a, b) { return a.time - b.time; });
            return result;
        }
        return null;
    }

    function parseEnhancedLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return null;
        let lines = lrcText.split("\n");
        let result = [];
        let hasAnyWord = false;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line) continue;

            let lineTimeMatch = line.match(/^\[(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)\]/);
            if (!lineTimeMatch) continue;

            let lineTime = parseFloat(lineTimeMatch[1]) * 60 + parseFloat(lineTimeMatch[2]);
            let content = line.replace(/^\[\d{1,2}:\d{1,2}(?:\.\d{1,3})?\]/, "").trim();

            let wordRegex = /<(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)>\s*([^<]*)/g;
            let wordMatch;
            let words = [];

            while ((wordMatch = wordRegex.exec(content)) !== null) {
                let wTime = parseFloat(wordMatch[1]) * 60 + parseFloat(wordMatch[2]);
                let wText = wordMatch[3].trim();
                if (wText !== "") {
                    words.push({ time: wTime, endTime: wTime + 0.3, text: wText });
                }
            }

            for (let j = 0; j < words.length - 1; j++) {
                words[j].endTime = words[j + 1].time;
            }

            if (words.length > 0) {
                hasAnyWord = true;
                let cleanLine = content.replace(/<\d{1,2}:\d{1,2}(?:\.\d{1,3})?>/g, " ").replace(/\s+/g, " ").trim();
                result.push({
                    time: lineTime,
                    text: cleanLine,
                    words: words
                });
            } else {
                result.push({
                    time: lineTime,
                    text: content.trim(),
                    words: []
                });
            }
        }

        if (hasAnyWord && result.length > 0) {
            result.sort(function(a, b) { return a.time - b.time; });
            return result;
        }
        return null;
    }

    function parseWordSynced(raw) {
        if (!raw) return null;
        let data = raw;
        if (typeof raw === "string") {
            let trimmed = raw.trim();
            if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
                try {
                    data = JSON.parse(trimmed);
                } catch(e) {
                    data = null;
                }
            }
        }

        if (data && typeof data === "object") {
            let linesArr = Array.isArray(data) ? data : (data.lines || data.lyrics || data.sync || null);
            if (Array.isArray(linesArr) && linesArr.length > 0) {
                let parsed = [];
                for (let i = 0; i < linesArr.length; i++) {
                    let l = linesArr[i];
                    let lineTime = 0;
                    if (l.time !== undefined) lineTime = parseFloat(l.time);
                    else if (l.start_ms !== undefined) lineTime = parseFloat(l.start_ms) / 1000;
                    else if (l.startTime !== undefined) lineTime = parseFloat(l.startTime) / 1000;
                    else if (l.start !== undefined) lineTime = parseFloat(l.start) > 1000 ? parseFloat(l.start) / 1000 : parseFloat(l.start);

                    let wordsArr = l.words || l.syllables || [];
                    let words = [];
                    let lineText = l.text || l.line || "";

                    if (Array.isArray(wordsArr) && wordsArr.length > 0) {
                        for (let j = 0; j < wordsArr.length; j++) {
                            let w = wordsArr[j];
                            let wTime = lineTime;
                            if (w.time !== undefined) wTime = parseFloat(w.time);
                            else if (w.start_ms !== undefined) wTime = parseFloat(w.start_ms) / 1000;
                            else if (w.startTime !== undefined) wTime = parseFloat(w.startTime) / 1000;
                            else if (w.start !== undefined) wTime = parseFloat(w.start) > 1000 ? parseFloat(w.start) / 1000 : parseFloat(w.start);

                            let wEnd = wTime + 0.3;
                            if (w.endTime !== undefined) wEnd = parseFloat(w.endTime) > 1000 ? parseFloat(w.endTime) / 1000 : parseFloat(w.endTime);
                            else if (w.end_ms !== undefined) wEnd = parseFloat(w.end_ms) / 1000;
                            else if (w.duration !== undefined) wEnd = wTime + (parseFloat(w.duration) > 1000 ? parseFloat(w.duration) / 1000 : parseFloat(w.duration));

                            let wText = w.text !== undefined ? w.text : (w.word !== undefined ? w.word : "");
                            if (wText !== "") {
                                words.push({ time: wTime, endTime: wEnd, text: wText });
                            }
                        }

                        for (let j = 0; j < words.length - 1; j++) {
                            if (words[j].endTime <= words[j].time) {
                                words[j].endTime = words[j + 1].time;
                            }
                        }
                    }

                    if (words.length > 0 && lineText === "") {
                        lineText = words.map(function(item) { return item.text; }).join(" ").trim();
                    }

                    if (words.length > 0 || lineText !== "") {
                        if (words.length > 0 && lineTime === 0) {
                            lineTime = words[0].time;
                        }
                        parsed.push({
                            time: lineTime,
                            text: lineText,
                            words: words
                        });
                    }
                }

                if (parsed.length > 0 && parsed.some(function(p) { return p.words && p.words.length > 0; })) {
                    parsed.sort(function(a, b) { return a.time - b.time; });
                    return parsed;
                }
            }
        }

        if (typeof raw === "string") {
            return parseEnhancedLrc(raw);
        }

        return null;
    }

    function parseWordLevelLyrics(raw) {
        if (!raw) return null;
        let res = parseYrc(raw);
        if (res && res.length > 0) return res;
        res = parseWordSynced(raw);
        if (res && res.length > 0) return res;
        return null;
    }

    // Text without timing: one line each, all at 0 (see `unsynced`)
    function parsePlain(text) {
        return String(text || "").split("\n").map(t => t.trim()).filter(t => t !== "")
            .map(t => ({ time: 0, text: t, words: [] }));
    }

    function parseLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return [];
        let lines = lrcText.split("\n");
        let result = [];
        let timeRegex = /\[(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)\]/g;
        // [offset:+/-ms]: a positive offset shows the lyrics earlier
        let offMatch = lrcText.match(/\[offset:\s*([+-]?\d+)\s*\]/i);
        let offset = offMatch ? parseInt(offMatch[1], 10) / 1000 : 0;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line) continue;

            let times = [];
            let match;
            timeRegex.lastIndex = 0;

            while ((match = timeRegex.exec(line)) !== null) {
                times.push(parseFloat(match[1]) * 60 + parseFloat(match[2]));
            }

            if (times.length > 0) {
                let text = line.replace(/\[\d{1,2}:\d{1,2}(?:\.\d{1,3})?\]/g, "").trim();
                for (let j = 0; j < times.length; j++) {
                    result.push({ time: Math.max(0, times[j] - offset), text: text, words: [] });
                }
            }
        }

        result.sort(function(a, b) { return a.time - b.time; });
        return result;
    }

    function applyLyrics(parsedList, key, shouldSaveToDisk) {
        if (key !== root.activeFetchKey) return;
        searchTimeoutTimer.stop();
        root.lyrics = parsedList;
        root.hasLyrics = parsedList && parsedList.length > 0;
        root.loading = false;
        if (root.hasLyrics) {
            if (shouldSaveToDisk !== false) {
                saveLyricsToDisk(key, parsedList);
            }
        }
    }

    // ── Search: gather candidates from every source, then rank once ───────
    // (no source "wins" by answering first: a live take or a badly timed
    // upload used to be applied just because it arrived earlier)
    property var sourceInfo: null          // { source, title, artist, album, duration, manual }
    property var candidates: []            // top results for "Other lyrics": [{ label, source, ... }]
    readonly property var audioSource: {
        try {
            let md = root.player && root.player.metadata ? root.player.metadata : {};
            return TrackInfo.audioSource(root.player ? root.player.trackArtUrl : "", md["xesam:url"] || "", root.player ? root.player.identity : "");
        } catch (e) {
            return { kind: "", player: "" };
        }
    }

    // Every lookup goes through this queue. LRCLIB answers "503 server busy"
    // to bursts (6 of 9 parallel searches failed), which made a song's lyrics
    // appear or not depending on luck: at most 3 LRCLIB requests at a time,
    // and busy/failed answers are retried with a growing pause.
    property var netQueue: []
    property int lrclibActive: 0

    Timer {
        id: netTimer
        interval: 150
        repeat: true
        onTriggered: root.pumpNet()
    }

    function xhrJson(url, headers, session, done, first) {
        session.pending++;
        let job = { url: url, headers: headers, session: session, done: done, tries: 0, due: 0, lrclib: url.indexOf("lrclib.net") !== -1 };
        if (first) root.netQueue.unshift(job);
        else root.netQueue.push(job);
        pumpNet();
    }

    function finishJob(job, data) {
        let session = job.session;
        if (session.key === root.activeFetchKey && !session.decided) {
            try { job.done(data); } catch (e) {}
        }
        session.pending--;
        if (session.pending === 0) decide(session);
    }

    function pumpNet() {
        let now = Date.now();
        let rest = [];
        let q = root.netQueue;
        root.netQueue = [];
        for (let i = 0; i < q.length; i++) {
            let job = q[i];
            if (job.session.decided || job.session.key !== root.activeFetchKey) {
                job.session.pending--;
                continue;
            }
            if (job.due > now || (job.lrclib && root.lrclibActive >= 3)) {
                rest.push(job);
                continue;
            }
            startJob(job);
        }
        root.netQueue = rest.concat(root.netQueue);
        netTimer.running = root.netQueue.length > 0;
    }

    function startJob(job) {
        if (job.lrclib) root.lrclibActive++;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", job.url);
        for (let h in job.headers) xhr.setRequestHeader(h, job.headers[h]);
        xhr.timeout = 8000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (job.lrclib) root.lrclibActive--;
            let st = xhr.status;
            if ((st === 0 || st === 429 || st >= 500) && job.tries < 4 && !job.session.decided && job.session.key === root.activeFetchKey) {
                job.tries++;
                job.due = Date.now() + 500 * job.tries;
                root.netQueue.push(job);
                pumpNet();
                return;
            }
            let data = null;
            if (st === 200) {
                try { data = JSON.parse(xhr.responseText); } catch (e) {}
            }
            finishJob(job, data);
            pumpNet();
        };
        xhr.send();
    }

    function addLrclibCandidate(session, it) {
        if (!it || !it.id || session.seen["l" + it.id]) return;
        session.seen["l" + it.id] = true;
        // LRCLIB sends a "lyricsfile" for untimed lyrics too (lines: []): only start_ms means timing
        let lf = String(it.lyricsfile || it.lyricsFile || "");
        if (!it.syncedLyrics && lf.indexOf("start_ms") === -1) {
            // text only: kept in case nothing synced turns up
            if (it.plainLyrics) session.plain.push(it);
            return;
        }
        it.source = "lrclib";
        session.cands.push(it);
    }

    function firstSungTime(lines) {
        for (let i = 0; i < lines.length; i++) {
            let t = (lines[i].text || "").trim();
            if (t !== "" && !LyricsMatch.isCreditLine(t)) return lines[i].time;
        }
        return null;
    }

    function fetchLyrics(artist, title, requestKey) {
        if (requestKey !== root.currentTrackKey || requestKey !== root.activeFetchKey) return;
        loading = true;
        hasLyrics = false;
        lyrics = [];
        root.sourceInfo = null;
        root.candidates = [];

        let album = "";
        try {
            if (root.player && root.player.trackAlbum)
                album = String(root.player.trackAlbum || "");
            else if (root.player && root.player.metadata && root.player.metadata["xesam:album"])
                album = String(root.player.metadata["xesam:album"] || "");
        } catch (e) {}

        if (activeSession) activeSession.decided = true;
        let cleanT = cleanString(title);
        let session = {
            key: requestKey,
            artist: cleanString(artist),
            title: cleanT !== "" ? cleanT : title,
            rawTitle: title || "",
            rawArtist: artist || "",
            album: cleanString(album),
            durationSec: getPlayerDurationSec(),
            cands: [],
            seen: {},
            aliases: [],
            aliasSeen: {},
            plain: [],
            querySeen: {},
            pending: 0,
            decided: false,
            ranked: []
        };
        activeSession = session;
        searchTimeoutTimer.restart();

        const lrclibHeaders = { "Lrclib-Client": "serpantinum-shell" };
        // lrclib: the exact /get (title + artist + length) and every search query
        if (session.artist !== "" && session.title !== "") {
            let params = "track_name=" + encodeURIComponent(session.title) + "&artist_name=" + encodeURIComponent(session.artist);
            if (session.durationSec > 1) params += "&duration=" + Math.round(session.durationSec);
            xhrJson("https://lrclib.net/api/get?" + params, lrclibHeaders, session, d => addLrclibCandidate(session, d));
        }
        let queries = LyricsMatch.buildLrclibSearchQueries(session);
        for (let i = 0; i < queries.length && i < 8; i++) {
            session.querySeen[queries[i]] = true;
            xhrJson("https://lrclib.net/api/search?q=" + encodeURIComponent(queries[i]), lrclibHeaders, session, list => {
                if (Array.isArray(list)) list.forEach(it => addLrclibCandidate(session, it));
            });
        }
        // NetEase: search, then the lyrics of the best few songs
        let neQueries = LyricsMatch.buildNetEaseQueries(session);
        for (let q = 0; q < neQueries.length; q++)
            neSearch(session, neQueries[q], songs => LyricsMatch.pickNetEaseSongs(songs, session, 3), true);

        // "…『Song』 by Artist": search that pair first
        LyricsMatch.titleAliases(session.rawTitle).forEach(al => addAlias(session, al, true));

        // anime opening/ending: AnimeThemes says which song it is, NetEase
        // finds it filed under the anime's Japanese name
        let hint = LyricsMatch.animeThemeHint(session.rawTitle);
        if (hint) animeLookup(session, hint, 0);
    }

    function animeLookup(session, hint, tryIdx) {
        // AnimeThemes answers 403 to requests without a User-Agent
        xhrJson(LyricsMatch.animeUrl(hint, tryIdx), { "User-Agent": "serpantinum-shell", "Accept": "application/json" }, session, resp => {
            let plan = LyricsMatch.animeThemePlan(resp, hint, tryIdx);
            if (plan.songs.length === 0 && plan.jpNames.length === 0) {
                if (tryIdx + 1 < hint.names.length) animeLookup(session, hint, tryIdx + 1);
                return;
            }
            plan.songs.forEach(sg => addAlias(session, sg, true));
            plan.jpNames.forEach(name => {
                neSearch(session, name + " " + hint.type, songs => {
                    let picks = LyricsMatch.pickNetEaseThemeSongs(songs, plan, hint);
                    picks.forEach(p => addAlias(session, p.alias, true));
                    return picks;
                }, false);
            });
        }, true);
    }

    // Another name for this song (see LyricsMatch aliases): score against it
    // and look it up on LRCLIB too.
    function addAlias(session, al, first) {
        if (!al || !al.title) return;
        let k = (al.title + "|" + (al.artist || "")).toLowerCase();
        if (session.aliasSeen[k]) return;
        session.aliasSeen[k] = true;
        session.aliases.push(al);
        const lrclibHeaders = { "Lrclib-Client": "serpantinum-shell" };
        let qs = al.artist ? [al.title + " " + al.artist.split(",")[0], al.title] : [al.title];
        qs.forEach(q => {
            if (session.querySeen[q]) return;
            session.querySeen[q] = true;
            xhrJson("https://lrclib.net/api/search?q=" + encodeURIComponent(q), lrclibHeaders, session, list => {
                if (Array.isArray(list)) list.forEach(it => addLrclibCandidate(session, it));
            }, first);
        });
    }

    // NetEase search → pick(songs) → lyrics of the picked songs. Songs whose
    // kana/hangul name reads like the title become aliases (LRCLIB files them
    // under that name).
    function neSearch(session, query, pick, native) {
        const neHeaders = { "Referer": "https://music.163.com", "User-Agent": "Mozilla/5.0" };
        xhrJson("https://music.163.com/api/cloudsearch/pc?s=" + encodeURIComponent(query) + "&type=1&limit=10&offset=0", neHeaders, session, sr => {
            let songs = sr && sr.result && sr.result.songs ? sr.result.songs : [];
            if (native) LyricsMatch.nativeAliases(songs, session).forEach(al => addAlias(session, al, true));
            pick(songs).forEach(p => {
                if (session.seen["n" + p.song.id]) return;
                session.seen["n" + p.song.id] = true;
                xhrJson("https://music.163.com/api/song/lyric?id=" + p.song.id + "&lv=1&kv=1&tv=-1&yv=1", neHeaders, session, resp => {
                    if (!resp) return;
                    let lines = null, word = false;
                    if (resp.yrc && resp.yrc.lyric) lines = parseWordLevelLyrics(resp.yrc.lyric);
                    if ((!lines || lines.length === 0) && resp.klyric && resp.klyric.lyric) lines = parseWordLevelLyrics(resp.klyric.lyric);
                    if (lines && lines.length > 0) word = true;
                    else if (resp.lrc && resp.lrc.lyric) lines = parseLrc(resp.lrc.lyric);
                    if (!lines || lines.length === 0) return;
                    let first = firstSungTime(lines);
                    if (first === null) return;
                    let c = Object.assign({}, p.item);
                    c.source = "netease";
                    c.id = p.song.id;
                    c.first = first;
                    c.hasWordSync = word;
                    c.parsed = lines;
                    session.cands.push(c);
                });
            });
        });
    }

    // Lines of a candidate (lrclib ones are parsed only when chosen)
    function candidateLines(c) {
        if (c.parsed) return c.parsed;
        let lines = null;
        try {
            lines = parseWordLevelLyrics(c.lyricsfile || c.lyricsFile) || parseWordLevelLyrics(c.syncedLyrics);
        } catch (e) {
            lines = null;
        }
        if (!lines || lines.length === 0) lines = parseLrc(c.syncedLyrics || "");
        return lines;
    }

    function candidateInfo(c, manual) {
        return {
            source: c.source === "netease" ? "NetEase" : "LRCLIB",
            title: c.trackName || "",
            artist: c.artistName || "",
            album: c.albumName || "",
            duration: Number(c.duration || 0),
            first: LyricsMatch.firstLineTime(c),
            manual: !!manual
        };
    }

    function decide(session) {
        if (session.decided || session.key !== root.activeFetchKey) return;
        session.decided = true;
        searchTimeoutTimer.stop();
        let ranked = LyricsMatch.rankCandidates(session.cands, session);
        session.ranked = ranked;
        // alternatives that are actually different (another start or length),
        // not the same upload five times
        let top = [];
        for (let i = 0; i < ranked.length && top.length < 5; i++) {
            let info = candidateInfo(ranked[i].item, false);
            let dup = top.some(t => t.info.first !== null && info.first !== null
                && Math.abs(t.info.first - info.first) < 0.4 && Math.abs(t.info.duration - info.duration) < 3);
            if (dup) continue;
            let lines = candidateLines(ranked[i].item);
            if (lines && lines.length > 0) top.push({ info: info, lines: lines });
        }
        root.candidates = top.map(t => t.info);
        let fb = root.refetchFallback;
        root.refetchFallback = null;
        if (top.length === 0 && fb && fb.key === session.key && fb.top.length > 0) top = fb.top;
        if (top.length === 0) {
            let p = LyricsMatch.pickPlain(session.plain, session);
            if (p) {
                let info = candidateInfo(p, false);
                info.unsynced = true;
                top = [{ info: info, lines: parsePlain(p.plainLyrics) }];
            }
        }
        if (top.length === 0) {
            root.loading = false;
            root.hasLyrics = false;
            root.lyrics = [];
            return;
        }
        root.sourceInfo = top[0].info;
        root.cachedTop = top;
        applyLyrics(top[0].lines, session.key, true);
    }

    // "Other lyrics": use candidate i instead, and remember it for this song
    property var cachedTop: []
    property bool menuOpen: false           // lyrics options panel (UI state)
    function chooseCandidate(i) {
        let top = root.cachedTop;
        if (!top || i < 0 || i >= top.length) return;
        let chosen = top[i];
        let rest = top.filter((t, k) => k !== i);
        root.cachedTop = [chosen].concat(rest);
        root.candidates = root.cachedTop.map(t => t.info);
        root.sourceInfo = Object.assign({}, chosen.info, { manual: true });
        root.applyLyrics(chosen.lines, root.currentTrackKey, true);
    }

    function refetch() {
        let key = root.currentTrackKey;
        if (!key) return;
        let mem = getMemCache();
        if (mem) delete mem[key];
        removeCacheProcess.targetKey = key;
        removeCacheProcess.running = false;
        removeCacheProcess.running = true;
        // if the new search finds nothing, keep what was showing
        root.refetchFallback = { key: key, top: root.hasLyrics ? root.cachedTop.slice() : [] };
        root.activeFetchKey = "";
        root.lastAttemptAt = 0;
        triggerSearch();
    }
    property var refetchFallback: null

    function loadLocalLyricsFile(filePath) {
        if (!filePath || filePath.trim() === "" || !root.isMediaActive) return;
        let cleanPath = filePath.toString();
        if (cleanPath.startsWith("file://")) {
            cleanPath = cleanPath.substring(7);
        }
        try {
            cleanPath = decodeURIComponent(cleanPath);
        } catch (e) {}

        let key = root.currentTrackKey;
        fileReadProcess.targetKey = key;
        fileReadProcess.command = ["cat", cleanPath];
        fileReadProcess.running = false;
        fileReadProcess.running = true;
    }

    function loadLocalLyricsContent(content, key) {
        if (!content || key !== root.currentTrackKey) return;
        let parsed = parseWordLevelLyrics(content);
        if (!parsed || parsed.length === 0) {
            parsed = parseLrc(content);
        }
        if (parsed && parsed.length > 0) {
            if (root.activeSession) {
                root.activeSession.decided = true;
            }
            root.activeFetchKey = key;
            root.lastFetchedKey = key;
            root.cachedTop = [];
            root.candidates = [];
            root.sourceInfo = { source: "local", title: "", artist: "", album: "", duration: 0, first: null, manual: true };
                applyLyrics(parsed, key, true);
        }
    }

    Process {
        id: cacheReadProcess
        property string targetKey: ""
        command: [
            "bash",
            "-c",
            'CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics-v2"; HASH=$(echo -n "$1" | md5sum | cut -d" " -f1); FILE="$CACHE_DIR/${HASH}.json"; printf "%s\\n" "$1"; if [ -f "$FILE" ] && [ -s "$FILE" ]; then cat "$FILE"; fi',
            "--",
            targetKey
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text;
                let nl = raw.indexOf("\n");
                let echoedKey = nl < 0 ? raw : raw.substring(0, nl);
                let content = nl < 0 ? "" : raw.substring(nl + 1).trim();
                let key = cacheReadProcess.targetKey;
                if (echoedKey !== key.split("\n")[0]) return;
                if (key !== root.currentTrackKey || key !== root.activeFetchKey) return;

                if (content !== "") {
                    try {
                        let entry = JSON.parse(content);
                        if (root.entryFits(entry)) {
                            let mem = root.getMemCache();
                            if (mem) mem[key] = entry;
                            root.restoreEntry(entry, key);
                            return;
                        }
                    } catch(e) {}
                }

                root.fetchLyrics(root.trackArtist, root.trackTitle, key);
            }
        }
    }

    Process {
        id: saveLyricsProcess
        property string pendingKey: ""
        property string pendingData: ""
        command: [
            "bash",
            "-c",
            'CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics-v2"; mkdir -p "$CACHE_DIR"; HASH=$(echo -n "$1" | md5sum | cut -d" " -f1); printf "%s" "$2" > "$CACHE_DIR/${HASH}.json"',
            "--",
            pendingKey,
            pendingData
        ]
        running: false
    }

    Process {
        id: removeCacheProcess
        property string targetKey: ""
        command: ["bash", "-c", 'HASH=$(echo -n "$1" | md5sum | cut -d" " -f1); rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics-v2/${HASH}.json"', "--", targetKey]
        running: false
    }

    Process {
        id: saveOffsetsProcess
        property string payload: "{}"
        command: ["bash", "-c", 'D="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics"; mkdir -p "$D"; printf "%s" "$1" > "$D/offsets.json"', "--", payload]
        running: false
    }

    Process {
        id: loadOffsetsProcess
        command: ["bash", "-c", 'cat "${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics/offsets.json" 2>/dev/null']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let o = JSON.parse(this.text);
                    if (o && typeof o === "object") {
                        root.offsets = o;
                        root.userOffset = o[root.currentTrackKey] || 0;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: fileReadProcess
        property string targetKey: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let content = this.text;
                if (fileReadProcess.targetKey === root.currentTrackKey && content.trim() !== "") {
                    root.loadLocalLyricsContent(content, fileReadProcess.targetKey);
                }
            }
        }
    }
}
