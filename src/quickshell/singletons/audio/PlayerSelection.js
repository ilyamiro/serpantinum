.pragma library

function busName(player) {
    // Quickshell exposes dbusName; accept busName from older adapters as well.
    return String(player.dbusName || player.busName || "");
}

function sourceKey(value) {
    // Earlier versions of this feature stored category policies, not applications.
    return !value || ["prefer-spotify", "spotify-only", "browser-only"].indexOf(value) >= 0
        ? "automatic" : String(value);
}

function serviceName(player) {
    return busName(player).replace(/^org\.mpris\.MediaPlayer2\./i, "")
        .replace(/^:\d+\.\d+$/, "")
        .replace(/[._-](?:instance|pid)(?:[._-].+|\d.*)$/i, "")
        .replace(/(?:[._-]\d+)+$/, "")
        .replace(/^\d+$/, "");
}

function applicationKeys(player, players) {
    let keys = [];
    let desktop = String(player.desktopEntry || "").trim().replace(/\.desktop$/, "");
    const service = serviceName(player);
    const identity = String(player.identity || "").trim();
    // An instance may expose DesktopEntry later than another instance of the same app.
    if (!desktop && service && players) {
        let entries = [];
        for (let other of players) {
            if (!other || serviceName(other) !== service) continue;
            let entry = String(other.desktopEntry || "").trim().replace(/\.desktop$/, "");
            if (entry && entries.indexOf(entry) < 0) entries.push(entry);
        }
        if (entries.length === 1) desktop = entries[0];
    }
    if (desktop) keys.push("desktop:" + desktop);
    if (service) keys.push("mpris:" + service);
    if (identity) keys.push("identity:" + identity);
    return keys;
}

function matches(player, key, players) {
    return applicationKeys(player, players).indexOf(key) >= 0;
}

function sources(players, selectedKey, selectedName) {
    selectedKey = sourceKey(selectedKey);
    let result = [];
    for (let player of players.filter(p => p).slice().sort((a, b) => busName(a).localeCompare(busName(b)))) {
        let keys = applicationKeys(player, players);
        if (!keys.length) continue;
        // Retain a saved fallback key if DesktopEntry becomes available later.
        let key = keys.indexOf(selectedKey) >= 0 ? selectedKey : keys[0];
        if (result.some(source => source.key === key)) continue;
        let name = String(player.identity || "").trim() || String(player.desktopEntry || "").trim() || serviceName(player);
        result.push({key: key, name: name, available: true});
    }
    if (selectedKey !== "automatic" && !result.some(source => source.key === selectedKey))
        result.push({key: selectedKey, name: selectedName || selectedKey.replace(/^[^:]+:/, ""), available: false});
    result.sort((a, b) => a.name.localeCompare(b.name) || a.key.localeCompare(b.key));
    return result;
}

function select(players, key, lastPlayingBus, stoppedState, selectedBus) {
    let candidates = players.filter(p => p).slice().sort((a, b) => busName(a).localeCompare(busName(b)));
    key = sourceKey(key);
    if (key !== "automatic") {
        candidates = candidates.filter(p => matches(p, key, players));
        // Keep the chosen instance, including while paused, until it disconnects.
        const current = candidates.find(p => busName(p) === selectedBus);
        if (current) return current;
    }
    // Keep Automatic's existing fallback order, including paused players.
    return candidates.find(p => p.isPlaying)
        || candidates.find(p => lastPlayingBus !== "" && busName(p) === lastPlayingBus)
        || candidates.find(p => p.playbackState !== stoppedState && p.trackTitle !== "")
        || candidates.find(p => p.canControl)
        || candidates[0] || null;
}
