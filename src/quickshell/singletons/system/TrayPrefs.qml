pragma Singleton
import QtQuick
import "../../"

Item {
    id: trayPrefs

    readonly property var hiddenIds: {
        let v = Config.getSetting("bar.trayHiddenIds", []);
        return Array.isArray(v) ? v : [];
    }

    function keyFor(item) {
        if (!item) return "";
        let id = (item.id || "").toString().trim().toLowerCase();
        if (id) return id;
        return (item.title || "").toString().trim().toLowerCase();
    }

    function isHidden(item) {
        let key = keyFor(item);
        if (!key) return false;
        return trayPrefs.hiddenIds.indexOf(key) !== -1;
    }

    function setHidden(item, hidden) {
        let key = keyFor(item);
        if (!key) return;
        let next = trayPrefs.hiddenIds.slice();
        let idx = next.indexOf(key);
        if (hidden && idx === -1) {
            next.push(key);
        } else if (!hidden && idx !== -1) {
            next.splice(idx, 1);
        } else {
            return;
        }
        Config.setSetting("bar.trayHiddenIds", next);
    }
}
