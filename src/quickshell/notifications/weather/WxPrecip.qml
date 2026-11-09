pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: precip
    property var cfg: null
    property var anchor: null
    property real phase: 0
    property bool snow: false

    readonly property real startAt: cfg && cfg.top !== undefined ? cfg.top : 0.5
    readonly property bool heavy: !!(cfg && cfg.heavy)
    readonly property int count: cfg && cfg.n ? cfg.n : 0
    readonly property real centerX: anchor && anchor.x !== undefined ? anchor.x : 0.5
    readonly property real spanX: anchor && anchor.s !== undefined ? anchor.s * 0.8 : 0.8
    readonly property int stride: {
        var n = Math.max(1, count);
        var s = Math.max(1, Math.round(n * 0.618));
        var gcd = function (a, b) { while (b) { var t = a % b; a = b; b = t; } return a; };
        while (gcd(s, n) !== 1) s++;
        return s;
    }
    readonly property real lean: 12 * Math.PI / 180
    readonly property int cycles: snow ? 1 : (heavy ? 3 : 2)

    visible: !!cfg
    clip: true
    y: parent ? startAt * parent.height : 0
    width: parent ? parent.width : 0
    height: parent ? parent.height * (1 - startAt) : 0

    Repeater {
        model: precip.visible ? precip.count : 0
        delegate: Item {
            id: drop
            required property int index
            readonly property real u: precip.width
            readonly property int column: (index * precip.stride) % precip.count
            readonly property int tier: Math.min(column, precip.count - 1 - column) % 3
            readonly property real slot: (column + 0.5) / precip.count
            readonly property real hash: Math.abs(Math.sin((index + 1) * 12.9898) * 43758.5453)
            readonly property real stagger: hash - Math.floor(hash)
            readonly property real t: (stagger + precip.phase * precip.cycles) % 1
            readonly property real env: Math.min(1, t / 0.2, (1 - t) / 0.3)
            readonly property real fade: env * env * (3 - 2 * env)
            readonly property real len: u * (precip.heavy ? 0.12 : 0.095) * (0.8 + 0.1 * tier)
            readonly property real thick: Math.max(1, u * (precip.heavy ? 0.016 : 0.014) * (0.85 + 0.15 * tier))
            readonly property real flake: u * (0.032 + 0.014 * tier)
            readonly property real travel: precip.height + len
            readonly property real baseX: precip.width * (precip.centerX + (slot - 0.5) * precip.spanX)

            width: precip.snow ? flake : thick
            height: precip.snow ? flake : len
            x: precip.snow
                ? baseX + Math.sin((t + slot) * Math.PI * 2) * u * 0.03 - width / 2
                : baseX - (t - 0.5) * travel * Math.tan(precip.lean) - width / 2
            y: t * travel - height
            rotation: precip.snow ? 0 : 12
            opacity: fade * (precip.snow ? 0.6 + 0.15 * tier : 0.88 + 0.06 * tier)

            Rectangle {
                visible: !precip.snow
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#8fc8ff" }
                    GradientStop { position: 1.0; color: "#dff1ff" }
                }
            }
            Rectangle {
                visible: precip.snow
                anchors.fill: parent
                radius: width / 2
                color: "#ffffff"
            }
        }
    }
}
