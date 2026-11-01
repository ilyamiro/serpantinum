import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "LyricsMatch.js" as LyricsMatch
import "PlayerSelection.js" as PlayerSelection

Item {
    id: root

    property int subscribers: 0
    property var player: MprisController.activePlayer

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

    // Cache keys describe songs; request identity also describes their source.
    // A generation prevents an old A response being accepted after A -> B -> A.
    readonly property string requestIdentity: JSON.stringify([
        player ? PlayerSelection.busName(player) : "", currentTrackKey,
        player && player.metadata ? String(player.metadata["mpris:trackid"] || "") : "",
        player ? player.trackAlbum : ""
    ])
    property int requestGeneration: 0
    property var cacheReader: null
    property var fileReader: null
    readonly property bool contentAvailable: isMediaActive && hasLyrics && !loading
    readonly property bool showContent: !MprisController.hideUnavailableLyrics || contentAvailable

    function invalidate() {
        requestGeneration++;
        activeSession = null;
        activeFetchKey = "";
        lastFetchedKey = "";
        hasLyrics = false;
        lyrics = [];
        loading = false;
        searchTimeoutTimer.stop();
        if (cacheReader) cacheReader.running = false;
        if (fileReader) fileReader.running = false;
        pendingJumpPosition = -1;
        seekGuardUntil = 0;
        currentPosition = player ? player.position : 0;
        polledPosition = currentPosition;
        Qt.callLater(root.triggerSearch);
    }

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

    readonly property int currentIndex: {
        if (!hasLyrics || lyrics.length === 0) return -1;
        let pos = currentPosition;
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
            requestGeneration++;
            searchTimeoutTimer.stop();
            if (cacheReader) cacheReader.running = false;
            if (fileReader) fileReader.running = false;
            if (loading || (activeSession && !activeSession.done)) {
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
        let p = root.currentPosition;
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
        return best;
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
        running: root.subscribers > 0 && root.contentAvailable && (root.player ? root.player.isPlaying : false)
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
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.loading && root.activeSession && !root.activeSession.done) {
                root.loading = false;
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
    }

    onRequestIdentityChanged: invalidate()
    onPlayerChanged: invalidate()

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
        if (activeSession) activeSession.done = true;
        activeSession = null;
        searchTimeoutTimer.stop();
        if (cacheReader) cacheReader.running = false;
        if (isNewKey) resetPositionGuards();
        lyrics = [];
        hasLyrics = false;
        loading = true;
        lastAttemptAt = Date.now();
        checkCacheAndFetch(currentTrackKey);
    }

    function checkCacheAndFetch(key) {
        let mem = getMemCache();
        if (mem && mem[key] && Array.isArray(mem[key]) && mem[key].length > 0) {
            applyLyrics(mem[key], key, false);
            return;
        }

        root.loading = true;
        root.cacheReader = lyricsReadComponent.createObject(root, {
            targetKey: key, generation: root.requestGeneration, localFile: false,
            command: ["bash", "-c",
                'CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics"; HASH=$(echo -n "$1" | md5sum | cut -d" " -f1); FILE="$CACHE_DIR/${HASH}.json"; if [ -f "$FILE" ] && [ -s "$FILE" ]; then cat "$FILE"; fi',
                "--", key]
        });
        root.cacheReader.running = true;
    }

    function saveLyricsToDisk(key, parsedList) {
        if (!key || !parsedList || parsedList.length === 0) return;
        try {
            let jsonStr = JSON.stringify(parsedList);
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

    function parseLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return [];
        let lines = lrcText.split("\n");
        let result = [];
        let timeRegex = /\[(\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)\]/g;

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
                    result.push({ time: times[j], text: text, words: [] });
                }
            }
        }

        result.sort(function(a, b) { return a.time - b.time; });
        return result;
    }

    function applyLyrics(parsedList, key, shouldSaveToDisk) {
        if (key !== root.activeFetchKey || key !== root.currentTrackKey || root.subscribers <= 0) return;
        searchTimeoutTimer.stop();
        root.lyrics = parsedList;
        root.hasLyrics = parsedList && parsedList.length > 0;
        root.loading = false;
        if (root.hasLyrics) {
            let mem = getMemCache();
            if (mem) mem[key] = parsedList;
            if (shouldSaveToDisk !== false) {
                saveLyricsToDisk(key, parsedList);
            }
        }
    }

    function checkCompletion(session) {
        if (!isCurrentSession(session) || session.done) return;
        if (session.netEaseDone && session.lrclibDone) {
            session.done = true;
            searchTimeoutTimer.stop();
            if (session.lineCandidate && session.lineCandidate.length > 0) {
                applyLyrics(session.lineCandidate, session.key, true);
            } else {
                root.loading = false;
                root.hasLyrics = false;
                root.lyrics = [];
            }
        }
    }

    function applyLrclibRecord(resp, session) {
        if (!isCurrentSession(session) || session.done) return false;
        if (!resp) return false;
        let rawLyricsFile = resp.lyricsfile || resp.lyricsFile || resp.lyrics_file;
        let wordLyrics = null;
        try {
            wordLyrics = parseWordLevelLyrics(rawLyricsFile) || parseWordLevelLyrics(resp.syncedLyrics);
        } catch (e) {
            wordLyrics = null;
        }
        if (wordLyrics && wordLyrics.length > 0) {
            session.hasWordLyrics = true;
            session.done = true;
            session.lrclibDone = true;
            applyLyrics(wordLyrics, session.key, true);
            return true;
        }
        if (resp.syncedLyrics && String(resp.syncedLyrics).trim() !== "") {
            let lines = parseLrc(resp.syncedLyrics);
            if (lines && lines.length > 0) {
                // Apply immediately — do not wait for NetEase / do not keep a weak first hit
                session.lineCandidate = lines;
                session.lrclibDone = true;
                session.done = true;
                applyLyrics(lines, session.key, true);
                return true;
            }
        }
        return false;
    }

    function fetchLyrics(artist, title, requestKey) {
        if (requestKey !== root.currentTrackKey || requestKey !== root.activeFetchKey) return;
        loading = true;
        hasLyrics = false;
        lyrics = [];

        let cleanT = cleanString(title);
        let cleanA = cleanString(artist);
        let album = "";
        try {
            if (root.player && root.player.trackAlbum)
                album = String(root.player.trackAlbum || "");
            else if (root.player && root.player.metadata && root.player.metadata["xesam:album"])
                album = String(root.player.metadata["xesam:album"] || "");
        } catch (e) {}
        album = cleanString(album);

        let session = {
            generation: root.requestGeneration,
            key: requestKey,
            artist: cleanA,
            title: cleanT !== "" ? cleanT : title,
            rawTitle: title || "",
            rawArtist: artist || "",
            album: album,
            durationSec: getPlayerDurationSec(),
            done: false,
            hasWordLyrics: false,
            netEaseDone: false,
            lrclibDone: false,
            lineCandidate: null
        };

        activeSession = session;
        searchTimeoutTimer.restart();

        fetchNetEase(session);
        fetchLrclib(session);
    }

    function fetchNetEase(session) {
        let query = (session.artist + " " + session.title).trim();
        if (query === "") query = session.title;

        // cloudsearch is generally more reliable than the legacy web search endpoint
        let url = "https://music.163.com/api/cloudsearch/pc?s=" + encodeURIComponent(query) + "&type=1&limit=8&offset=0";
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Referer", "https://music.163.com");
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            if (xhr.status === 200) {
                try {
                    let resp = JSON.parse(xhr.responseText);
                    let songs = resp.result && resp.result.songs ? resp.result.songs : [];
                    let bestSong = pickBestNetEaseSong(songs, session);

                    if (bestSong && bestSong.id) {
                        fetchNetEaseLyric(bestSong.id, session);
                        return;
                    }
                } catch(e) {}
            }

            fetchNetEaseLegacy(session);
        };

        xhr.send();
    }

    function fetchNetEaseLegacy(session) {
        if (!isCurrentSession(session) || session.done) return;
        let query = (session.artist + " " + session.title).trim();
        if (query === "") query = session.title;
        let url = "https://music.163.com/api/search/get/web?csrf_token=&hlpretag=&hlposttag=&s=" + encodeURIComponent(query) + "&type=1&offset=0&total=true&limit=8";
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Referer", "https://music.163.com");
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            if (xhr.status === 200) {
                try {
                    let resp = JSON.parse(xhr.responseText);
                    let songs = resp.result && resp.result.songs ? resp.result.songs : [];
                    let bestSong = pickBestNetEaseSong(songs, session);
                    if (bestSong && bestSong.id) {
                        fetchNetEaseLyric(bestSong.id, session);
                        return;
                    }
                } catch(e) {}
            }

            session.netEaseDone = true;
            checkCompletion(session);
        };

        xhr.send();
    }

    function fetchNetEaseLyric(songId, session) {
        let url = "https://music.163.com/api/song/lyric?id=" + songId + "&lv=1&kv=1&tv=-1&yv=1";
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Referer", "https://music.163.com");
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            if (xhr.status === 200) {
                try {
                    let resp = JSON.parse(xhr.responseText);
                    let wordLyrics = null;

                    if (resp.yrc && resp.yrc.lyric) {
                        wordLyrics = parseWordLevelLyrics(resp.yrc.lyric);
                    }
                    if (!wordLyrics && resp.klyric && resp.klyric.lyric) {
                        wordLyrics = parseWordLevelLyrics(resp.klyric.lyric);
                    }

                    if (wordLyrics && wordLyrics.length > 0) {
                        session.hasWordLyrics = true;
                        session.done = true;
                        applyLyrics(wordLyrics, session.key, true);
                        return;
                    }

                    if (resp.lrc && resp.lrc.lyric) {
                        let lines = parseLrc(resp.lrc.lyric);
                        if (lines && lines.length > 0) {
                            if (!session.lineCandidate || lines.length > session.lineCandidate.length) {
                                session.lineCandidate = lines;
                            }
                        }
                    }
                } catch(e) {}
            }

            session.netEaseDone = true;
            checkCompletion(session);
        };

        xhr.send();
    }

    function fetchLrclib(session) {
        if (session.artist === "" || session.title === "") {
            fetchLrclibSearch(session, 0);
            return;
        }

        // Do NOT send album_name on /get: players (VK/Firefox/etc) often expose a
        // playlist/collection name that does not match lrclib and causes 404.
        let params = "track_name=" + encodeURIComponent(session.title) + "&artist_name=" + encodeURIComponent(session.artist);
        if (session.durationSec && session.durationSec > 1) {
            params += "&duration=" + encodeURIComponent(String(Math.round(session.durationSec)));
        }

        let url = "https://lrclib.net/api/get?" + params;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "serpantinum-shell");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            if (xhr.status === 200) {
                try {
                    let resp = JSON.parse(xhr.responseText);
                    if (applyLrclibRecord(resp, session))
                        return;
                } catch(e) {}
            }

            fetchLrclibSearch(session, 0);
        };

        xhr.send();
    }

    function fetchLrclibSearch(session, attempt) {
        if (!isCurrentSession(session) || session.done) return;

        let uniq = LyricsMatch.buildLrclibSearchQueries(session);
        if (uniq.length === 0) {
            session.lrclibDone = true;
            checkCompletion(session);
            return;
        }

        let idx = Math.max(0, attempt || 0);
        if (idx >= uniq.length) {
            session.lrclibDone = true;
            checkCompletion(session);
            return;
        }

        let url = "https://lrclib.net/api/search?q=" + encodeURIComponent(uniq[idx]);
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "serpantinum-shell");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            if (xhr.status === 200) {
                try {
                    let list = JSON.parse(xhr.responseText);
                    let best = LyricsMatch.pickBestLrclibResult(list, session);
                    if (best) {
                        if (applyLrclibRecord(best, session))
                            return;
                        if (best.id) {
                            fetchLrclibById(best, session, uniq, idx);
                            return;
                        }
                    }
                } catch(e) {}
            }

            fetchLrclibSearch(session, idx + 1);
        };

        xhr.send();
    }

    function fetchLrclibById(best, session, queries, idx) {
        // Canonical /get using the matched record's own metadata (album from lrclib is OK)
        let params = "track_name=" + encodeURIComponent(best.trackName || best.name || session.title)
            + "&artist_name=" + encodeURIComponent(best.artistName || session.artist);
        if (best.albumName) params += "&album_name=" + encodeURIComponent(best.albumName);
        if (best.duration) params += "&duration=" + encodeURIComponent(String(Math.round(Number(best.duration))));

        let url = "https://lrclib.net/api/get?" + params;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "serpantinum-shell");

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (!isCurrentSession(session) || session.done) return;

            let applied = false;
            if (xhr.status === 200) {
                try {
                    applied = applyLrclibRecord(JSON.parse(xhr.responseText), session);
                } catch(e) {}
            }
            if (!applied)
                applied = applyLrclibRecord(best, session);
            if (session.done) return;
            if (applied) {
                session.lrclibDone = true;
                checkCompletion(session);
                return;
            }
            fetchLrclibSearch(session, idx + 1);
        };

        xhr.send();
    }

    function isCurrentSession(session) {
        return session === root.activeSession && session.generation === root.requestGeneration
            && session.key === root.activeFetchKey && session.key === root.currentTrackKey
            && root.subscribers > 0;
    }

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
        if (root.fileReader) root.fileReader.running = false;
        root.fileReader = lyricsReadComponent.createObject(root, {
            targetKey: key, generation: root.requestGeneration, localFile: true,
            command: ["cat", cleanPath]
        });
        root.fileReader.running = true;
    }

    function loadLocalLyricsContent(content, key) {
        if (!content || key !== root.currentTrackKey) return;
        let parsed = parseWordLevelLyrics(content);
        if (!parsed || parsed.length === 0) {
            parsed = parseLrc(content);
        }
        if (parsed && parsed.length > 0) {
            // A user-selected file wins over outstanding cache/network reads.
            root.requestGeneration++;
            if (root.cacheReader) root.cacheReader.running = false;
            if (root.activeSession) {
                root.activeSession.done = true;
            }
            root.activeFetchKey = key;
            root.lastFetchedKey = key;
            applyLyrics(parsed, key, true);
        }
    }

    Component {
        id: lyricsReadComponent
        Process {
            id: reader
            required property string targetKey
            required property int generation
            required property bool localFile
            // These values belong to this invocation, not to a reusable process
            // whose target may have changed before stdout finishes.
            onExited: {
                if (root.cacheReader === reader) root.cacheReader = null;
                if (root.fileReader === reader) root.fileReader = null;
                reader.destroy();
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    if (reader.generation !== root.requestGeneration || root.subscribers <= 0) return;
                    if (reader !== (reader.localFile ? root.fileReader : root.cacheReader)) return;
                    let key = reader.targetKey;
                    if (key !== root.currentTrackKey || key !== root.activeFetchKey) return;
                    let content = this.text.trim();
                    if (reader.localFile) {
                        root.loadLocalLyricsContent(content, key);
                        return;
                    }
                    if (content !== "") {
                        try {
                            let parsed = JSON.parse(content);
                            if (Array.isArray(parsed) && parsed.length > 0) {
                                root.applyLyrics(parsed, key, false);
                                return;
                            }
                        } catch(e) {}
                    }
                    root.fetchLyrics(root.trackArtist, root.trackTitle, key);
                }
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
            'CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/lyrics"; mkdir -p "$CACHE_DIR"; HASH=$(echo -n "$1" | md5sum | cut -d" " -f1); printf "%s" "$2" > "$CACHE_DIR/${HASH}.json"',
            "--",
            pendingKey,
            pendingData
        ]
        running: false
    }

}
