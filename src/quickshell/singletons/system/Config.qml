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
    property bool isWriting: false
    property var pendingPayload: null
    property string lastWrittenContent: ""

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

    function getSetting(key, fallbackValue) {
        if (!rawSettings || typeof rawSettings !== "object") {
            if (fallbackValue !== null && typeof fallbackValue === "object") {
                try { return JSON.parse(JSON.stringify(fallbackValue)); } catch (e) { return fallbackValue; }
            }
            return fallbackValue;
        }

        let val = undefined;
        if (rawSettings.hasOwnProperty(key) && rawSettings[key] !== undefined && rawSettings[key] !== null) {
            val = rawSettings[key];
        } else if (typeof key === "string" && key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let cur = rawSettings;
            for (let i = 0; i < parts.length; i++) {
                if (cur && typeof cur === "object" && cur.hasOwnProperty(parts[i])) {
                    cur = cur[parts[i]];
                } else {
                    val = fallbackValue;
                    break;
                }
            }
            if (val === undefined) {
                val = (cur !== undefined && cur !== null) ? cur : fallbackValue;
            }
        } else {
            val = fallbackValue;
        }

        if (val !== null && typeof val === "object") {
            try {
                return JSON.parse(JSON.stringify(val));
            } catch (e) {
                return val;
            }
        }
        return val;
    }

    function setSetting(key, value) {
        let obj = {};
        obj[key] = value;
        updateJsonBulk(obj);
    }

    function updateJsonBulk(dataObj) {
        let next = JSON.parse(JSON.stringify(rawSettings || {}));
        for (let key in dataObj) {
            let val = dataObj[key];
            let clonedVal = (val !== null && typeof val === "object") ? JSON.parse(JSON.stringify(val)) : val;
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

    function dispatchWrite(settingsObj) {
        if (isWriting) {
            pendingPayload = JSON.parse(JSON.stringify(settingsObj));
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
