pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property var calendarSettings: {
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("calendar", {});
        }
        return {};
    }

    readonly property bool enabled: !!calendarSettings.enabled
    readonly property string url: calendarSettings.url || ""
    readonly property int intervalMinutes: {
        let val = Number(calendarSettings.interval);
        return (!isNaN(val) && val > 0) ? val : 15;
    }

    property var data: ({ "lastSync": 0, "events": {}, "count": 0 })
    property var eventsMap: ({})
    property int totalCount: 0
    property double lastSyncTime: 0
    property bool isLoading: false
    property string lastError: ""

    signal calendarUpdated()

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            root.refresh(false);
        }
    }

    function refresh(force) {
        if (!Caching.serpantinumDir) return;
        if (!root.enabled && !force) return;
        if (!root.url && !force) return;

        root.isLoading = true;
        syncProcess.running = false;
        syncProcess.running = true;
    }

    function eventsForDate(dateKey) {
        if (!dateKey || !root.eventsMap) return [];
        return root.eventsMap[dateKey] || [];
    }

    function hasEvents(dateKey) {
        let evs = eventsForDate(dateKey);
        return evs && evs.length > 0;
    }

    function eventCount(dateKey) {
        let evs = eventsForDate(dateKey);
        return evs ? evs.length : 0;
    }

    function parseJson(rawText) {
        root.isLoading = false;
        if (!rawText) return;
        let txt = typeof rawText === "function" ? rawText() : rawText;
        if (typeof txt !== "string") txt = String(txt || "");
        txt = txt.trim();
        if (txt === "") return;

        try {
            let parsed = JSON.parse(txt);
            root.data = parsed;
            root.eventsMap = parsed.events || {};
            root.totalCount = parsed.count || 0;
            root.lastSyncTime = parsed.lastSync || 0;
            root.lastError = parsed.error || "";
            root.calendarUpdated();
        } catch(e) {
            root.lastError = "Failed to parse calendar JSON";
        }
    }

    Process {
        id: syncProcess
        command: {
            if (!Caching.serpantinumDir) return [];
            let script = Caching.serpantinumDir + "/scripts/calendar.sh";
            let calUrl = root.url || "";
            let escapedUrl = calUrl.replace(/'/g, "'\\''");
            return ["bash", "-c", script + " --sync --url '" + escapedUrl + "'"];
        }
        stdout: StdioCollector {
            id: syncOut
            onStreamFinished: {
                root.parseJson(syncOut.text);
            }
        }
        onExited: {
            root.isLoading = false;
        }
    }

    FileView {
        id: calendarWatcher
        path: Caching.cacheDir ? (Caching.cacheDir + "/calendar/calendar.json") : ""
        watchChanges: true
        onLoaded: root.parseJson(typeof calendarWatcher.text === "function" ? calendarWatcher.text() : calendarWatcher.text)
        onFileChanged: root.parseJson(typeof calendarWatcher.text === "function" ? calendarWatcher.text() : calendarWatcher.text)
    }

    Timer {
        id: autoSyncTimer
        interval: root.intervalMinutes * 60000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh(false)
    }

    Component.onCompleted: {
        if (typeof Config !== "undefined" && Config.dataReady) {
            root.refresh(false);
        }
    }
}
