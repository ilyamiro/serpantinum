pragma Singleton
import QtQuick

QtObject {
    id: root

    property var shapes: ({})
    property var bands: ({})
    property int revision: 0
    property int bandRevision: 0

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function publish(screenName, id, shape) {
        if (!screenName || !id) return;
        const cur = root.shapes[screenName] ? root.shapes[screenName][id] : undefined;
        if (cur !== undefined && same(cur, shape)) return;
        const next = Object.assign({}, root.shapes);
        next[screenName] = Object.assign({}, next[screenName] || {});
        next[screenName][id] = shape;
        root.shapes = next;
        root.revision++;
    }

    function withdraw(screenName, id) {
        if (!screenName || !root.shapes[screenName] || root.shapes[screenName][id] === undefined) return;
        const next = Object.assign({}, root.shapes);
        next[screenName] = Object.assign({}, next[screenName]);
        delete next[screenName][id];
        root.shapes = next;
        root.revision++;
    }

    function claimBand(screenName, id, band) {
        if (!screenName || !id) return;
        const cur = root.bands[screenName] ? root.bands[screenName][id] : undefined;
        if (cur !== undefined && same(cur, band)) return;
        const next = Object.assign({}, root.bands);
        next[screenName] = Object.assign({}, next[screenName] || {});
        next[screenName][id] = band;
        root.bands = next;
        root.bandRevision++;
    }

    function releaseBand(screenName, id) {
        if (!screenName || !root.bands[screenName] || root.bands[screenName][id] === undefined) return;
        const next = Object.assign({}, root.bands);
        next[screenName] = Object.assign({}, next[screenName]);
        delete next[screenName][id];
        root.bands = next;
        root.bandRevision++;
    }

    function shapesOn(screenName) {
        return root.shapes[screenName] || {};
    }

    function bandsOn(screenName) {
        return root.bands[screenName] || {};
    }
}
