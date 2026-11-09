pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "GovAlertsLib.js" as Lib

Item {
    id: root

    property string _status: "unknown"
    property double _lastSuccess: 0
    property int _sourcesOk: 0
    property int _sourcesTotal: 0
    property string _coverage: "none"
    property var _active: []
    property var _health: []

    readonly property string status: root._status
    readonly property double lastSuccess: root._lastSuccess
    readonly property int sourcesOk: root._sourcesOk
    readonly property int sourcesTotal: root._sourcesTotal
    readonly property string coverage: root._coverage
    readonly property var activeAlerts: root._active
    readonly property var sourceHealth: root._health
    readonly property bool running: root._running

    property bool _enabled: false
    property bool _running: false
    property bool _started: false
    property bool _fileDone: false
    property bool _deliverable: false
    property bool _queuedRefresh: false
    property var _persisted: null
    property var _results: ({})
    property var _planIds: []
    property var _srcs: ({})
    property int _srcsPending: 0
    property var _queue: []
    property var _workers: []
    property int _inflight: 0
    property int _runId: 0
    property int _jobsStarted: 0
    property int _retryCount: 0
    property var _runCtx: ({})
    property var _runOnly: null
    property var _capCache: ({})
    property var _registry: null
    property var _threads: []
    property string _fp: ""
    property double _lastTick: Date.now()

    readonly property int maxConcurrent: 3
    readonly property int maxJobs: 160
    readonly property int registryMaxAge: 3 * 86400000
    readonly property int capCacheMaxAge: 2 * 86400000
    readonly property var retryDelays: [120000, 300000, 600000]

    readonly property string stateDir: Caching.cacheDir ? Caching.getCacheDir("weather") : ""

    function _locationValid() {
        if (typeof Location === "undefined") return false;
        let lat = Number(Location.latitude), lon = Number(Location.longitude);
        return isFinite(lat) && isFinite(lon) && !(lat === 0 && lon === 0);
    }

    function _context() {
        return {
            lat: Number(Location.latitude),
            lon: Number(Location.longitude),
            country: String(Location.countryCode || "").toUpperCase(),
            lang: (typeof I18n !== "undefined" && I18n.currentLang) ? I18n.currentLang : "en",
            now: Date.now()
        };
    }

    function _fingerprint() {
        if (typeof Location === "undefined") return "";
        return Number(Location.latitude).toFixed(2) + "," + Number(Location.longitude).toFixed(2) + "," + String(Location.countryCode || "").toUpperCase();
    }

    function _syncEnabled() {
        if (typeof Config === "undefined" || !Config.dataReady) return;
        let s = Config.getSetting("weatherAlerts", {}) || {};
        let on = s.enabled !== false && s.governmentWarnings !== false;
        if (on === root._enabled && (on || root._status === "disabled")) return;
        root._enabled = on;
        if (on) {
            if (root._status === "disabled") root._status = "unknown";
            root._tryStart();
            if (root._started) root.refresh();
        } else {
            root._stopAll();
            root._active = [];
            root._health = [];
            root._sourcesOk = 0;
            root._sourcesTotal = 0;
            root._status = "disabled";
        }
    }

    function _tryStart() {
        if (root._started || !root._enabled || !root._fileDone) return;
        if (typeof Config === "undefined" || !Config.dataReady || !root._locationValid()) return;
        root._started = true;
        root._fp = root._fingerprint();
        root._applyPersisted();
        root.refresh();
    }

    function _stopAll() {
        root._runId++;
        root._queue = [];
        root._inflight = 0;
        root._running = false;
        root._queuedRefresh = false;
        for (let i = 0; i < root._workers.length; i++) {
            let w = root._workers[i];
            if (w) {
                w.done = true;
                w.running = false;
                w.destroy();
            }
        }
        root._workers = [];
        retryTimer.stop();
    }

    function refresh() {
        root._retryCount = 0;
        retryTimer.stop();
        root._startRun(null);
    }

    function _startRun(only) {
        if (!root._enabled || !root._started) return;
        if (!root._locationValid()) {
            root._status = root._active.length > 0 ? root._status : "unknown";
            return;
        }
        if (root._running) {
            if (only === null) root._queuedRefresh = true;
            return;
        }
        let ctx = root._context();
        let specs = Lib.planSources(ctx);
        root._planIds = specs.map(s => s.id);
        if (only) specs = specs.filter(s => only.indexOf(s.id) >= 0);
        if (specs.length === 0) return;
        root._runCtx = ctx;
        root._runOnly = only;
        root._runId++;
        root._running = true;
        root._queue = [];
        root._jobsStarted = 0;
        root._srcs = {};
        root._srcsPending = specs.length;
        let registryFresh = root._registry && (ctx.now - root._registry.time) < root.registryMaxAge;
        let immediate = [];
        for (let i = 0; i < specs.length; i++) {
            let spec = specs[i];
            let s = {
                id: spec.id, label: spec.label, tier: spec.tier, rank: spec.rank, pending: 0, primaryOk: null, error: "",
                followTotal: 0, followFailed: 0, feedsTotal: 0, feedsOk: 0, na: false, alerts: [], cancels: [], done: false
            };
            root._srcs[spec.id] = s;
            if (spec.id === "feeds" && registryFresh) {
                s.primaryOk = true;
                let jobs = Lib.feedJobs(root._registry.list, ctx);
                if (jobs.length === 0) {
                    s.na = true;
                    immediate.push(s);
                }
                for (let j = 0; j < jobs.length; j++) root._enqueue(s, jobs[j], false);
            } else {
                for (let j = 0; j < spec.jobs.length; j++) root._enqueue(s, spec.jobs[j], true);
            }
        }
        for (let k = 0; k < immediate.length; k++) root._finalizeSource(immediate[k]);
        root._pump();
    }

    function _enqueue(s, job, primary) {
        if (root._jobsStarted >= root.maxJobs) return false;
        root._jobsStarted++;
        job.src = s.id;
        job.rank = s.rank;
        job.primary = primary;
        s.pending++;
        root._queue.push(job);
        return true;
    }

    function _pump() {
        let runId = root._runId;
        while (root._runId === runId && root._inflight < root.maxConcurrent && root._queue.length > 0) {
            let job = root._queue.shift();
            let cached = job.key ? root._capCache[job.key] : null;
            if (cached && (Date.now() - cached.t) < root.capCacheMaxAge) {
                let ctx = Object.assign({}, root._runCtx, { now: Date.now() });
                root._applyResult(job, Lib.handleCap(job, cached.caps, ctx));
                continue;
            }
            root._inflight++;
            let w = workerComp.createObject(root, { job: job, runId: runId });
            root._workers.push(w);
            w.command = root._curlCommand(job);
            w.running = true;
        }
        if (root._runId === runId && root._running && root._queue.length === 0 && root._inflight === 0) root._checkDone();
    }

    function _curlCommand(job) {
        let cmd = ["curl", "-sL", "--fail", "--proto", "=http,https", "--max-redirs", "5", "--connect-timeout", "10",
            "--max-time", String(job.timeout), "--max-filesize", String(job.maxSize), "--compressed", "-A", "serpantinum"];
        for (let i = 0; i < (job.headers || []).length; i++) {
            cmd.push("-H");
            cmd.push(job.headers[i]);
        }
        cmd.push("--noproxy"); cmd.push("*"); cmd.push(job.url);
        return cmd;
    }

    function _jobDone(w) {
        if (w.done) return;
        w.done = true;
        let idx = root._workers.indexOf(w);
        if (idx >= 0) root._workers.splice(idx, 1);
        let job = w.job;
        let runId = w.runId;
        let code = w.code;
        let out = w.out;
        w.destroy();
        if (runId !== root._runId) return;
        root._inflight--;
        let res;
        if (code !== 0) {
            res = { ok: false, error: "curl " + code, alerts: [], cancels: [], jobs: [] };
        } else {
            let ctx = Object.assign({}, root._runCtx, { now: Date.now() });
            res = Lib.handleResult(job, out, ctx);
            if (res.ok && res.caps && job.key) root._cacheCaps(job.key, res.caps);
        }
        root._applyResult(job, res);
        root._pump();
    }

    function _cacheCaps(key, caps) {
        let cache = root._capCache;
        let keys = Object.keys(cache);
        if (keys.length > 300) {
            keys.sort((a, b) => cache[a].t - cache[b].t);
            for (let i = 0; i < 100; i++) delete cache[keys[i]];
        }
        cache[key] = { t: Date.now(), caps: caps };
    }

    function _applyResult(job, res) {
        let s = root._srcs[job.src];
        if (!s || s.done) return;
        s.pending--;
        if (job.kind === "registry") {
            if (res.ok) {
                root._registry = { time: Date.now(), list: res.registry.filter(e => e.official && e.status === "operating") };
            } else if (root._registry) {
                res = { ok: true, alerts: [], cancels: [], jobs: Lib.feedJobs(root._registry.list, root._runCtx) };
            }
            if (res.ok && res.jobs.length === 0) s.na = true;
        }
        if (job.primary) {
            s.primaryOk = res.ok;
            if (!res.ok) s.error = res.error || "";
        } else if (job.kind === "feed") {
            s.feedsTotal++;
            if (res.ok) s.feedsOk++;
            else s.error = res.error || "";
        } else {
            s.followTotal++;
            if (!res.ok) s.followFailed++;
        }
        if (res.ok) {
            s.alerts = s.alerts.concat(res.alerts);
            s.cancels = s.cancels.concat(res.cancels);
            for (let i = 0; i < res.jobs.length; i++) root._enqueue(s, res.jobs[i], false);
        }
        if (s.pending === 0) root._finalizeSource(s);
    }

    function _finalizeSource(s) {
        if (s.done) return;
        s.done = true;
        let ok = s.primaryOk === true;
        if (ok && s.id === "feeds" && !s.na) {
            ok = s.feedsTotal > 0 && s.feedsOk * 2 >= s.feedsTotal && s.followFailed * 2 <= Math.max(1, s.followTotal);
        } else if (ok && s.followTotal > 0) {
            ok = s.followFailed * 2 <= s.followTotal;
        }
        let results = Object.assign({}, root._results);
        if (s.na) {
            delete results[s.id];
        } else if (ok) {
            results[s.id] = { id: s.id, label: s.label, tier: s.tier, ok: true, time: Date.now(), error: "", alerts: s.alerts, cancels: s.cancels };
        } else {
            let prev = results[s.id] || { alerts: [], cancels: [], time: 0 };
            results[s.id] = { id: s.id, label: s.label, tier: s.tier, ok: false, time: prev.time, error: s.error || "failed", alerts: prev.alerts, cancels: prev.cancels };
        }
        root._results = results;
        root._srcsPending--;
        if (root._srcsPending <= 0) root._checkDone();
    }

    function _checkDone() {
        if (!root._running || root._srcsPending > 0) return;
        root._running = false;
        root._recompute(true);
        root._save();
        let failed = [];
        for (let i = 0; i < root._planIds.length; i++) {
            let r = root._results[root._planIds[i]];
            if (r && !r.ok) failed.push(r.id);
        }
        if (failed.length > 0 && root._retryCount < root.retryDelays.length) {
            retryTimer.interval = root.retryDelays[root._retryCount];
            retryTimer.start();
        } else {
            root._retryCount = 0;
        }
        if (root._queuedRefresh) {
            root._queuedRefresh = false;
            root.refresh();
        }
    }

    function _healthList() {
        let now = Date.now();
        let list = [];
        for (let i = 0; i < root._planIds.length; i++) {
            let r = root._results[root._planIds[i]];
            if (!r) continue;
            let live = (r.alerts || []).filter(a => a.end > now).length;
            list.push({ id: r.id, label: r.label, tier: r.tier, ok: r.ok, stale: !r.ok && r.time > 0, lastSuccess: r.time, error: r.error, alerts: live });
        }
        return list;
    }

    function _recompute(deliver) {
        let now = Date.now();
        let health = root._healthList();
        let st = Lib.computeStatus(health);
        let all = [];
        let cancels = [];
        for (let i = 0; i < root._planIds.length; i++) {
            let r = root._results[root._planIds[i]];
            if (!r) continue;
            all = all.concat(r.alerts || []);
            cancels = cancels.concat(r.cancels || []);
        }
        let merged = Lib.mergeAlerts(all, cancels, { threads: root._threads }, now);
        root._threads = merged.threads;
        let sameIds = merged.active.length === root._active.length && merged.active.every((a, i) => a.id === root._active[i].id);
        if (!sameIds) root._active = merged.active;
        root._health = health;
        root._sourcesOk = st.sourcesOk;
        root._sourcesTotal = st.sourcesTotal;
        root._coverage = st.coverage;
        if (root._enabled) root._status = st.status;
        if (deliver) {
            if (st.sourcesOk > 0) {
                root._lastSuccess = now;
                root._deliverable = true;
            }
            root._deliver();
        }
    }

    function _deliver() {
        if (!root._enabled || !root._deliverable) return;
        if (typeof WeatherAlerts === "undefined" || typeof WeatherAlerts.enqueue !== "function") return;
        let now = Date.now();
        for (let i = 0; i < root._active.length; i++) {
            let a = root._active[i];
            if (a.expires <= now) continue;
            WeatherAlerts.enqueue({
                id: a.id, kind: a.kind, title: a.title, body: a.body,
                urgency: a.urgency, bypassQuiet: a.bypassQuiet, expires: a.expires
            });
        }
    }

    function _trimAlert(a) {
        return Object.assign({}, a, { description: String(a.description || "").substring(0, 700), instruction: String(a.instruction || "").substring(0, 400) });
    }

    function _save() {
        if (!stateFile.path) return;
        let results = {};
        let ids = Object.keys(root._results);
        for (let i = 0; i < ids.length; i++) {
            let r = root._results[ids[i]];
            results[ids[i]] = Object.assign({}, r, { alerts: (r.alerts || []).slice(0, 40).map(root._trimAlert) });
        }
        stateFile.setText(JSON.stringify({
            version: 1,
            fp: root._fp,
            savedAt: Date.now(),
            lastSuccess: root._lastSuccess,
            results: results,
            threads: root._threads,
            registry: root._registry
        }) + "\n");
    }

    function _loadFile(raw) {
        root._fileDone = true;
        let data = null;
        try {
            data = JSON.parse(String(raw || ""));
        } catch (e) {
            data = null;
        }
        if (data && data.version === 1) root._persisted = data;
        root._tryStart();
    }

    function _applyPersisted() {
        let d = root._persisted;
        root._persisted = null;
        if (!d) return;
        if (Array.isArray(d.threads)) root._threads = d.threads;
        if (d.registry && Array.isArray(d.registry.list)) root._registry = d.registry;
        if (d.fp === root._fp && d.results && typeof d.results === "object") {
            root._results = d.results;
            root._lastSuccess = Number(d.lastSuccess) || 0;
            root._planIds = Lib.planSources(root._context()).map(s => s.id);
            root._recompute(false);
            if (root._enabled) root._status = "unknown";
        }
    }

    function _locationChanged() {
        if (!root._started) {
            root._tryStart();
            return;
        }
        let fp = root._fingerprint();
        if (fp === root._fp) return;
        root._fp = fp;
        root._results = {};
        root._active = [];
        root._health = [];
        root._deliverable = false;
        root._stopAll();
        if (root._enabled && root._locationValid()) root.refresh();
    }

    Component {
        id: workerComp

        Process {
            id: proc
            property var job: null
            property int runId: 0
            property bool done: false
            property bool gotExit: false
            property bool gotStream: false
            property int code: 0
            property string out: ""

            stdout: StdioCollector {
                onStreamFinished: {
                    proc.out = text;
                    proc.gotStream = true;
                    proc.check();
                }
            }

            onExited: (exitCode, exitStatus) => {
                proc.code = exitCode;
                proc.gotExit = true;
                proc.check();
            }

            function check() {
                if (proc.gotExit && proc.gotStream) root._jobDone(proc);
            }

            property Timer watchdog: Timer {
                interval: ((proc.job ? proc.job.timeout : 30) + 15) * 1000
                running: true
                repeat: false
                onTriggered: {
                    if (proc.done) return;
                    proc.code = proc.code === 0 ? -1 : proc.code;
                    proc.running = false;
                    root._jobDone(proc);
                }
            }
        }
    }

    Connections {
        target: typeof Location !== "undefined" ? Location : null
        function onLocationUpdated() {
            locationDebounce.restart();
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            root._syncEnabled();
            root._tryStart();
        }
    }

    Connections {
        target: typeof WeatherAlerts !== "undefined" ? WeatherAlerts : null
        function onStateLoadedChanged() {
            if (WeatherAlerts.stateLoaded) root._deliver();
        }
    }

    Timer {
        id: locationDebounce
        interval: 3000
        repeat: false
        onTriggered: root._locationChanged()
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: {
            root._retryCount++;
            let failed = [];
            for (let i = 0; i < root._planIds.length; i++) {
                let r = root._results[root._planIds[i]];
                if (r && !r.ok) failed.push(r.id);
            }
            if (failed.length > 0) root._startRun(failed);
        }
    }

    Timer {
        id: refreshTimer
        interval: Math.max(300000, (typeof Weather !== "undefined" && Weather.refreshInterval > 0) ? Weather.refreshInterval : 900000)
        running: root._enabled && root._started
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: tick
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            let n = Date.now();
            let drift = n - root._lastTick;
            root._lastTick = n;
            root._syncEnabled();
            root._tryStart();
            if (!root._enabled || !root._started) return;
            if (drift > 180000) {
                root.refresh();
                return;
            }
            if (!root._running && Object.keys(root._results).length > 0) root._recompute(false);
        }
    }

    FileView {
        id: stateFile
        path: root.stateDir ? root.stateDir + "/gov_alerts.json" : ""
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: root._loadFile(typeof stateFile.text === "function" ? stateFile.text() : stateFile.text)
        onLoadFailed: root._loadFile("")
    }

    Component.onCompleted: {
        root._syncEnabled();
    }
}
