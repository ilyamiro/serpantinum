import QtQuick

Item {
    property var cfg: null
    property real phase: 0
    property real aspect: 1

    function g(key, fallback) {
        return cfg && cfg[key] !== undefined ? cfg[key] : fallback;
    }

    readonly property bool on: !!cfg
    readonly property real cx: g("x", 0.5)
    readonly property real cy: g("y", 0.5)
    readonly property real sz: g("s", 0.5)

    width: sz * (parent ? parent.width : 0)
    height: width * aspect
    x: cx * (parent ? parent.width : 0) - width / 2
    y: cy * (parent ? parent.height : 0) - height / 2
    visible: on
}
