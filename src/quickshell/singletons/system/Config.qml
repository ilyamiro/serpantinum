pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: config

    readonly property string homeDir: Caching.home
    readonly property string userConfigDir: Caching.configDir
    readonly property string settingsJsonPath: Quickshell.env("QS_SETTINGS") ? Quickshell.env("QS_SETTINGS") : (userConfigDir + "/settings.json")

    property bool dataReady: false
    property var rawSettings: ({})
    readonly property var barMonitors: (rawSettings && rawSettings.bar && Array.isArray(rawSettings.bar.monitors)) ? rawSettings.bar.monitors : null
    property bool isWriting: false
    property var pendingPayload: null
    property string lastWrittenContent: ""

    function isBarEnabledOnScreen(screen) {
        let monitors = config.barMonitors;
        if (!Array.isArray(monitors)) return true;
        let name = (typeof screen === "string") ? screen : (screen && screen.name ? screen.name : "");
        if (!name) return false;
        return monitors.indexOf(name) !== -1;
    }

    readonly property string writerScript:
        'target="$1"\n' +
        'content="$2"\n' +
        'dir="$(dirname "$target")"\n' +
        'mkdir -p "$dir" || exit 1\n' +
        'tmp="$dir/.settings_tmp_$$\"\n' +
        'trap \'rm -f "$tmp"\' EXIT INT TERM HUP\n' +
        'printf "%s\\n" "$content" > "$tmp" || exit 1\n' +
        'if [ -s "$tmp" ]; then\n' +
        '  chmod 644 "$tmp" 2>/dev/null || true\n' +
        '  mv "$tmp" "$target"\n' +
        'fi\n'

    signal settingsLoaded()

    function areEqual(a, b) {
        if (a === b) return true;
        if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
        if (Array.isArray(a) !== Array.isArray(b)) return false;
        let keysA = Object.keys(a);
        let keysB = Object.keys(b);
        if (keysA.length !== keysB.length) return false;
        for (let i = 0; i < keysA.length; i++) {
            let k = keysA[i];
            if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
            if (!areEqual(a[k], b[k])) return false;
        }
        return true;
    }

    function setNestedValue(obj, path, value) {
        let parts = typeof path === "string" ? path.split(".") : [path];
        let cur = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            let p = parts[i];
            if (!cur[p] || typeof cur[p] !== "object") {
                cur[p] = {};
            }
            cur = cur[p];
        }
        cur[parts[parts.length - 1]] = value;
    }

    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function cloneValue(val) {
        if (val === null || typeof val !== "object") return val;
        if (Array.isArray(val)) {
            let arr = new Array(val.length);
            for (let i = 0; i < val.length; i++) {
                let item = val[i];
                arr[i] = (item === undefined || typeof item === "function") ? null : cloneValue(item);
            }
            return arr;
        }
        let obj = {};
        for (let k in val) {
            if (Object.prototype.hasOwnProperty.call(val, k)) {
                let v = val[k];
                if (v !== undefined && typeof v !== "function") obj[k] = cloneValue(v);
            }
        }
        return obj;
    }

    function _resolveSetting(key, fallbackValue) {
        if (!rawSettings || typeof rawSettings !== "object") {
            return fallbackValue;
        }
        if (Object.prototype.hasOwnProperty.call(rawSettings, key) && rawSettings[key] !== undefined && rawSettings[key] !== null) {
            return rawSettings[key];
        }
        if (typeof key === "string" && key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let cur = rawSettings;
            for (let i = 0; i < parts.length; i++) {
                if (cur && typeof cur === "object" && Object.prototype.hasOwnProperty.call(cur, parts[i])) {
                    cur = cur[parts[i]];
                } else {
                    return fallbackValue;
                }
            }
            return (cur !== undefined && cur !== null) ? cur : fallbackValue;
        }
        return fallbackValue;
    }

    function peekSetting(key, fallbackValue) {
        return _resolveSetting(key, fallbackValue);
    }

    function getSetting(key, fallbackValue) {
        let val = _resolveSetting(key, fallbackValue);
        if (val !== null && typeof val === "object") {
            return cloneValue(val);
        }
        return val;
    }

    function setSetting(key, value) {
        let obj = {};
        obj[key] = value;
        updateJsonBulk(obj);
    }

    function updateJsonBulk(dataObj) {
        let next = cloneValue(rawSettings || {});
        for (let key in dataObj) {
            let val = dataObj[key];
            let clonedVal = (val !== null && typeof val === "object") ? cloneValue(val) : val;
            if (typeof key === "string" && key.indexOf(".") !== -1) {
                setNestedValue(next, key, clonedVal);
            } else {
                next[key] = clonedVal;
            }
        }
        if (areEqual(rawSettings, next)) return;
        rawSettings = next;
        dispatchWrite(next);
    }

    function replaceSettings(settingsObj) {
        if (!settingsObj || typeof settingsObj !== "object") return;
        let next = cloneValue(settingsObj);
        if (areEqual(rawSettings, next)) return;
        rawSettings = next;
        dispatchWrite(next);
    }

    function dispatchWrite(settingsObj) {
        if (isWriting) {
            pendingPayload = cloneValue(settingsObj);
            return;
        }
        isWriting = true;
        let str = JSON.stringify(settingsObj, null, 2);
        lastWrittenContent = str;
        writerProc.command = ["bash", "-c", writerScript, "_", settingsJsonPath, str + "\n"];
        writerProc.running = true;
    }

    Process {
        id: writerProc
        command: []
        onExited: function(exitCode, exitStatus) {
            config.isWriting = false;
            if (config.pendingPayload !== null) {
                let next = config.pendingPayload;
                config.pendingPayload = null;
                config.dispatchWrite(next);
            } else {
                config.settingsLoaded();
            }
        }
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
                    if (config.isWriting || config.pendingPayload !== null) {
                        config.dataReady = true;
                        return;
                    }

                    if (trimmed === config.lastWrittenContent.trim()) {
                        config.dataReady = true;
                        return;
                    }
                    if (trimmed.length > 0) {
                        let parsed = JSON.parse(trimmed);
                        if (parsed && typeof parsed === "object") {
                            if (!config.areEqual(config.rawSettings, parsed)) {
                                config.rawSettings = parsed;
                                config.settingsLoaded();
                            }
                        }
                    }
                }
            } catch (e) {
            }
            config.dataReady = true;
        }
    }

    Component.onCompleted: {
        if (settingsWatcher.path) {
            settingsWatcher.reload();
        }
    }

    Component.onDestruction: {
        let targetObj = pendingPayload !== null ? pendingPayload : rawSettings;
        let str = JSON.stringify(targetObj, null, 2);
        lastWrittenContent = str;
        Quickshell.execDetached(["bash", "-c", writerScript, "_", settingsJsonPath, str + "\n"]);
    }
}
