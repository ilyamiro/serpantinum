pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: config

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string userConfigDir: homeDir + "/.config/serpantinum"
    readonly property string settingsJsonPath: Quickshell.env("QS_SETTINGS") ? Quickshell.env("QS_SETTINGS") : (userConfigDir + "/settings.json")

    property bool dataReady: false
    property var rawSettings: ({})
    property var pendingUpdates: ({})

    signal settingsLoaded()

    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function getSetting(key, fallbackValue) {
        if (!rawSettings || typeof rawSettings !== "object") return fallbackValue;

        if (rawSettings.hasOwnProperty(key) && rawSettings[key] !== undefined && rawSettings[key] !== null) {
            return rawSettings[key];
        }

        if (typeof key === "string" && key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let cur = rawSettings;
            for (let i = 0; i < parts.length; i++) {
                if (cur && typeof cur === "object" && cur.hasOwnProperty(parts[i])) {
                    cur = cur[parts[i]];
                } else {
                    return fallbackValue;
                }
            }
            return (cur !== undefined && cur !== null) ? cur : fallbackValue;
        }

        return fallbackValue;
    }

    function setSetting(key, value) {
        let obj = {};
        obj[key] = value;
        updateJsonBulk(obj);
    }

    function updateJsonBulk(dataObj) {
        let temp = Object.assign({}, rawSettings);
        for (let key in dataObj) {
            temp[key] = dataObj[key];
            pendingUpdates[key] = dataObj[key];
        }
        rawSettings = temp;
        saveTimer.restart();
    }

    function flush() {
        let keys = Object.keys(pendingUpdates);
        if (keys.length === 0) return;

        let patchObj = pendingUpdates;
        pendingUpdates = ({});

        let patchStr = JSON.stringify(patchObj);
        let fallbackStr = JSON.stringify(rawSettings);

        let script =
            'target="$1"\n' +
            'patch="$2"\n' +
            'fallback="$3"\n' +
            'dir="$(dirname "$target")"\n' +
            'lock="$target.lock"\n' +
            'mkdir -p "$dir" || exit 1\n' +
            'exec 200>"$lock" || exit 1\n' +
            'flock -x -w 2 200 || exit 1\n' +
            'tmp="$(mktemp "$target.XXXXXX.tmp" 2>/dev/null || mktemp -p "$dir" settings.XXXXXX.tmp)" || exit 1\n' +
            'trap \'rm -f "$tmp"\' EXIT\n' +
            'if [ -s "$target" ] && jq -e . "$target" >/dev/null 2>&1; then\n' +
            '  jq --argjson p "$patch" \'. * $p\' "$target" > "$tmp" 2>/dev/null\n' +
            'else\n' +
            '  jq -n --argjson fb "$fallback" --argjson p "$patch" \'($fb // {}) * ($p // {})\' > "$tmp" 2>/dev/null\n' +
            'fi\n' +
            'if [ -s "$tmp" ] && jq -e . "$tmp" >/dev/null 2>&1; then\n' +
            '  touch "$target"\n' +
            '  cat "$tmp" > "$target"\n' +
            '  chmod 644 "$target" 2>/dev/null || true\n' +
            'fi\n' +
            'rm -f "$tmp"\n';

        Quickshell.execDetached(["bash", "-c", script, "_", settingsJsonPath, patchStr, fallbackStr]);
    }

    Timer {
        id: saveTimer
        interval: 150
        repeat: false
        running: false
        onTriggered: config.flush()
    }

    FileView {
        id: settingsWatcher
        path: config.settingsJsonPath
        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                let raw = typeof text === "function" ? text() : text;
                if (typeof raw === "string") {
                    let trimmed = raw.trim();
                    if (trimmed.length > 0) {
                        let parsed = JSON.parse(trimmed);
                        if (parsed && typeof parsed === "object") {
                            config.rawSettings = Object.assign({}, parsed, config.pendingUpdates);
                        }
                    }
                }
            } catch (e) {
            }
            config.dataReady = true;
            config.settingsLoaded();
        }
    }

    Component.onCompleted: {
        if (settingsWatcher.path) {
            settingsWatcher.reload();
        }
    }

    Component.onDestruction: {
        if (saveTimer.running) {
            saveTimer.stop();
            config.flush();
        }
    }
}
