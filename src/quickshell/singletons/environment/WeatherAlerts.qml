pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "WeatherRules.js" as Rules

Item {
    id: root

    readonly property string weatherDir: Caching.serpantinumDir ? Caching.getCacheDir("weather") : ""
    readonly property int sendSpacing: 700
    readonly property real keepDelivered: 24 * 3600000

    readonly property var defaults: Rules.DEFAULTS

    property var delivered: ({})
    property var lastDelivered: ({})
    property string locationKey: ""
    property bool stateLoaded: false
    property bool rawLoaded: false
    property bool aqiLoaded: false
    property var forecastRaw: null
    property var aqiRaw: null
    property real evaluatedFetchedAt: 0
    property real pendingFetchedAt: 0
    property bool lastQuiet: false
    property var queue: []

    readonly property var fallbacks: ({
        "rain_soon": { "title": "Rain expected", "body": "Rain is expected around {time}." },
        "snow_soon": { "title": "Snow expected", "body": "Snow is expected around {time}." },
        "heavy_rain": { "title": "Heavy rain", "body": "Heavy rain is expected around {time}." },
        "heavy_snow": { "title": "Heavy snow", "body": "Heavy snow is expected around {time}." },
        "thunderstorm": { "title": "Thunderstorm", "body": "Thunderstorms are expected around {time}." },
        "ice": { "title": "Icy conditions", "body": "Freezing rain or ice is expected around {time}." },
        "fog": { "title": "Fog", "body": "Low visibility is expected around {time}." },
        "temp_rise": { "title": "Warmer today", "body": "Today will be {delta} warmer than yesterday, with a high of {max}." },
        "temp_drop": { "title": "Colder today", "body": "Today will be {delta} colder than yesterday, with a high of {max}." },
        "hot": { "title": "Extreme heat", "body": "It will feel like {temp} today. Stay hydrated." },
        "cold": { "title": "Extreme cold", "body": "It will feel like {temp} today. Dress warmly." },
        "wind": { "title": "Strong wind", "body": "Gusts up to {speed} are expected around {time}." },
        "uv": { "title": "High UV index", "body": "The UV index will reach {value} around {time}. Use sun protection." },
        "air_quality": { "title": "Poor air quality", "body": "The air quality index is {value}. Limit time outdoors." },
        "daily_clear": { "title": "Clear skies", "today": "Clear skies today. High {max}, low {min}.", "tomorrow": "Clear skies tomorrow. High {max}, low {min}." },
        "daily_cloudy": { "title": "Cloudy", "today": "Cloudy today. High {max}, low {min}.", "tomorrow": "Cloudy tomorrow. High {max}, low {min}." },
        "daily_rain": { "title": "Rain", "today": "Rain today. High {max}, low {min}.", "tomorrow": "Rain tomorrow. High {max}, low {min}." },
        "daily_snow": { "title": "Snow", "today": "Snow today. High {max}, low {min}.", "tomorrow": "Snow tomorrow. High {max}, low {min}." },
        "daily_storm": { "title": "Thunderstorms", "today": "Thunderstorms today. High {max}, low {min}.", "tomorrow": "Thunderstorms tomorrow. High {max}, low {min}." },
        "daily_fog": { "title": "Fog", "today": "Fog today. High {max}, low {min}.", "tomorrow": "Fog tomorrow. High {max}, low {min}." }
    })

    function settings() {
        return Config.getSetting("weatherAlerts", root.defaults);
    }

    function isQuietNow() {
        return Rules.isQuietHour(root.settings(), new Date().getHours());
    }

    function resolveText(key, args) {
        let parts = key.split(".");
        let kind = parts[1];
        let leaf = parts[2];
        let fb = (root.fallbacks[kind] && root.fallbacks[kind][leaf]) ? root.fallbacks[kind][leaf] : key;
        let text = I18n.t(key, fb);
        for (let k in args) {
            text = text.replace(new RegExp("\\{" + k + "\\}", "g"), args[k]);
        }
        return text;
    }

    function pruneState() {
        let now = Date.now();
        let next = {};
        for (let id in root.delivered) {
            if (Number(root.delivered[id]) > now) next[id] = root.delivered[id];
        }
        root.delivered = next;
        let cutoff = now - 7 * 24 * 3600000;
        let lasts = {};
        for (let k in root.lastDelivered) {
            if (Number(root.lastDelivered[k]) > cutoff) lasts[k] = root.lastDelivered[k];
        }
        root.lastDelivered = lasts;
    }

    function saveState() {
        if (!stateFile.path) return;
        root.pruneState();
        stateFile.setText(JSON.stringify({
            "location": root.locationKey,
            "delivered": root.delivered,
            "lastDelivered": root.lastDelivered
        }) + "\n");
    }

    function loadState(text) {
        try {
            if (text && text.trim().length > 0) {
                let data = JSON.parse(text);
                if (data && typeof data === "object") {
                    root.locationKey = data.location ? String(data.location) : "";
                    root.delivered = data.delivered || {};
                    root.lastDelivered = data.lastDelivered || {};
                }
            }
        } catch (e) {}
        root.pruneState();
        root.stateLoaded = true;
        root.maybeReload();
    }

    function currentLocationKey() {
        let d = Weather.data || {};
        if (d.latitude === undefined || d.longitude === undefined) return "";
        return Number(d.latitude).toFixed(2) + "," + Number(d.longitude).toFixed(2);
    }

    function checkLocation() {
        let key = root.currentLocationKey();
        if (key === "") return;
        if (root.locationKey !== key) {
            let hadState = root.locationKey !== "";
            root.locationKey = key;
            if (hadState) {
                root.delivered = {};
                root.lastDelivered = {};
                root.queue = [];
            }
            root.saveState();
        }
    }

    function enqueue(alert) {
        if (!alert || !alert.id || !alert.kind) return;
        let now = Date.now();
        if (!root.stateLoaded) return;
        if (Number(root.delivered[alert.id]) > now) return;
        if (alert.expires && Number(alert.expires) <= now) return;
        if (!alert.bypassQuiet && root.isQuietNow()) return;
        for (let i = 0; i < root.queue.length; i++) {
            if (root.queue[i].id === alert.id) return;
        }
        root.queue = root.queue.concat([alert]);
    }

    function sendNext() {
        if (root.queue.length === 0) return;
        let alert = root.queue[0];
        root.queue = root.queue.slice(1);
        let now = Date.now();
        if (Number(root.delivered[alert.id]) > now) return;
        if (alert.expires && Number(alert.expires) <= now) return;
        if (!alert.bypassQuiet && root.isQuietNow()) return;
        let until = Math.max(Number(alert.expires) || 0, now + root.keepDelivered);
        let delivered = Object.assign({}, root.delivered);
        delivered[alert.id] = until;
        root.delivered = delivered;
        let lasts = Object.assign({}, root.lastDelivered);
        lasts[alert.kind.indexOf("daily_") === 0 ? "daily" : alert.kind] = now;
        root.lastDelivered = lasts;
        root.saveState();
        Quickshell.execDetached([
            "serpantinum-core", "notify",
            "--app", "Weather",
            "--urgency", alert.urgency === "critical" ? "critical" : "normal",
            "--icon", "weather-kind-" + alert.kind,
            "--",
            alert.title,
            alert.body
        ]);
    }

    function maybeReload() {
        let d = Weather.data || {};
        let fetched = Number(d.fetched_at) || 0;
        if (!root.stateLoaded || !Config.dataReady || !I18n.isReady || !weatherDir) return;
        if (fetched <= 0 || fetched === root.evaluatedFetchedAt || fetched === root.pendingFetchedAt) return;
        root.checkLocation();
        root.pendingFetchedAt = fetched;
        root.rawLoaded = false;
        root.aqiLoaded = false;
        forecastFile.reload();
    }

    function evaluate() {
        let d = Weather.data || {};
        if (!root.stateLoaded || !root.rawLoaded || !root.aqiLoaded || !root.forecastRaw) return;
        if (!Config.dataReady || !I18n.isReady) return;
        root.evaluatedFetchedAt = Number(d.fetched_at) || 0;
        root.lastQuiet = root.isQuietNow();
        root.pruneState();
        let result = Rules.evaluate({
            "forecast": root.forecastRaw,
            "aqi": root.aqiRaw,
            "unit": d.unit || "metric",
            "now": Date.now(),
            "settings": root.settings(),
            "state": { "delivered": root.delivered, "lastDelivered": root.lastDelivered },
            "quiet": root.lastQuiet,
            "offline": d.offline === true,
            "fetchedAt": root.evaluatedFetchedAt
        });
        for (let i = 0; i < result.alerts.length; i++) {
            let a = result.alerts[i];
            root.enqueue({
                "id": a.id,
                "kind": a.kind,
                "title": root.resolveText(a.titleKey, a.args),
                "body": root.resolveText(a.bodyKey, a.args),
                "urgency": a.urgency,
                "bypassQuiet": a.bypassQuiet,
                "expires": a.expires
            });
        }
    }

    function parseFile(file) {
        try {
            let txt = typeof file.text === "function" ? file.text() : file.text;
            return txt && txt.trim().length > 0 ? JSON.parse(txt) : null;
        } catch (e) {
            return null;
        }
    }

    FileView {
        id: stateFile
        path: root.weatherDir ? root.weatherDir + "/alerts_state.json" : ""
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (!root.stateLoaded) root.loadState(typeof stateFile.text === "function" ? stateFile.text() : stateFile.text);
        }
        onLoadFailed: {
            if (!root.stateLoaded) root.loadState("");
        }
    }

    FileView {
        id: forecastFile
        path: root.weatherDir ? root.weatherDir + "/forecast_raw.json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.forecastRaw = root.parseFile(forecastFile);
            root.rawLoaded = true;
            aqiFile.reload();
        }
        onLoadFailed: {
            root.forecastRaw = null;
            root.pendingFetchedAt = 0;
        }
    }

    FileView {
        id: aqiFile
        path: root.weatherDir ? root.weatherDir + "/air_quality_raw.json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.aqiRaw = root.parseFile(aqiFile);
            root.aqiLoaded = true;
            root.pendingFetchedAt = 0;
            root.evaluate();
        }
        onLoadFailed: {
            root.aqiRaw = null;
            root.aqiLoaded = true;
            root.pendingFetchedAt = 0;
            root.evaluate();
        }
    }

    Connections {
        target: Weather
        function onWeatherUpdated() {
            root.maybeReload();
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.maybeReload();
        }
    }

    Connections {
        target: I18n
        function onLanguageChanged() {
            root.maybeReload();
        }
    }

    Timer {
        id: sendTimer
        interval: root.sendSpacing
        repeat: true
        running: root.queue.length > 0
        onTriggered: root.sendNext()
    }

    Timer {
        id: quietTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            if (!root.stateLoaded) return;
            let quiet = root.isQuietNow();
            if (root.lastQuiet && !quiet) {
                root.evaluate();
            } else if (root.evaluatedFetchedAt === 0) {
                root.maybeReload();
            }
            root.lastQuiet = quiet;
        }
    }

    Component.onCompleted: {
        root.lastQuiet = root.isQuietNow();
    }
}
