import QtQuick
import "../../"

Item {
    id: root
    visible: false

    property string section: ""
    property var defaults: ({})

    property int _revision: 0
    property var _pendingPatch: ({})
    property bool _hasPending: false

    readonly property var values: {
        let _rev = root._revision;
        let raw = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings : ({});
        let base = {};
        if (root.defaults && typeof root.defaults === "object") {
            let defKeys = Object.keys(root.defaults);
            for (let i = 0; i < defKeys.length; i++) {
                base[defKeys[i]] = root.defaults[defKeys[i]];
            }
        }
        let secObj = root._resolveSection(raw);
        if (secObj && typeof secObj === "object") {
            let secKeys = Object.keys(secObj);
            for (let i = 0; i < secKeys.length; i++) {
                if (secObj[secKeys[i]] !== undefined && secObj[secKeys[i]] !== null) {
                    base[secKeys[i]] = secObj[secKeys[i]];
                }
            }
        }
        if (root._hasPending && root._pendingPatch) {
            let pKeys = Object.keys(root._pendingPatch);
            for (let i = 0; i < pKeys.length; i++) {
                base[pKeys[i]] = root._pendingPatch[pKeys[i]];
            }
        }
        return base;
    }

    function _resolveSection(raw) {
        if (!raw || typeof raw !== "object") return null;
        if (!root.section || root.section === "") return raw;
        if (root.section.indexOf(".") === -1) return raw[root.section];
        let parts = root.section.split(".");
        let cur = raw;
        for (let i = 0; i < parts.length; i++) {
            if (!cur || typeof cur !== "object") return null;
            cur = cur[parts[i]];
        }
        return cur;
    }

    function _fullKey(key) {
        return (root.section && root.section !== "") ? (root.section + "." + key) : key;
    }

    function get(key, fallback) {
        let vals = root.values;
        if (vals && Object.prototype.hasOwnProperty.call(vals, key) && vals[key] !== undefined && vals[key] !== null) {
            return vals[key];
        }
        if (fallback !== undefined) return fallback;
        if (root.defaults && Object.prototype.hasOwnProperty.call(root.defaults, key)) {
            return root.defaults[key];
        }
        return undefined;
    }

    function set(key, value) {
        if (root._hasPending && Object.prototype.hasOwnProperty.call(root._pendingPatch, key)) {
            let nextPending = Object.assign({}, root._pendingPatch);
            delete nextPending[key];
            root._pendingPatch = nextPending;
            if (Object.keys(nextPending).length === 0) {
                root._hasPending = false;
                debounceTimer.stop();
            }
        }
        if (typeof Config !== "undefined") {
            Config.setSetting(root._fullKey(key), value);
        }
    }

    function setMany(obj) {
        if (!obj || typeof obj !== "object") return;
        let keys = Object.keys(obj);
        if (keys.length === 0) return;
        if (root._hasPending) {
            let nextPending = Object.assign({}, root._pendingPatch);
            for (let i = 0; i < keys.length; i++) {
                delete nextPending[keys[i]];
            }
            root._pendingPatch = nextPending;
            if (Object.keys(nextPending).length === 0) {
                root._hasPending = false;
                debounceTimer.stop();
            }
        }
        if (typeof Config !== "undefined") {
            let bulk = {};
            for (let i = 0; i < keys.length; i++) {
                bulk[root._fullKey(keys[i])] = obj[keys[i]];
            }
            Config.updateJsonBulk(bulk);
        }
    }

    function setDebounced(key, value, delayMs) {
        let nextPending = Object.assign({}, root._pendingPatch);
        nextPending[key] = value;
        root._pendingPatch = nextPending;
        root._hasPending = true;
        debounceTimer.interval = (delayMs !== undefined && delayMs > 0) ? delayMs : 150;
        debounceTimer.restart();
    }

    function flush() {
        if (!root._hasPending) return;
        let patch = root._pendingPatch;
        root._pendingPatch = ({});
        root._hasPending = false;
        debounceTimer.stop();
        if (typeof Config !== "undefined") {
            let keys = Object.keys(patch);
            if (keys.length === 0) return;
            let bulk = {};
            for (let i = 0; i < keys.length; i++) {
                bulk[root._fullKey(keys[i])] = patch[keys[i]];
            }
            Config.updateJsonBulk(bulk);
        }
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: root.flush()
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onRawSettingsChanged() {
            root._revision++;
        }
        function onSettingsLoaded() {
            root._revision++;
        }
    }

    Component.onDestruction: root.flush()
}
