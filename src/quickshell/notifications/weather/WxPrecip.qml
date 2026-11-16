pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: precip
    property var cfg: null
    property var anchor: null
    property real phase: 0
    property bool snow: false
    property bool solid: false

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
    readonly property string flakePath: "m67.578 90.366-1.204-.689a2.9 2.9 0 0 0-.003-1.353l1.207-.69a.83.83 0 0 0 .309-1.141.85.85 0 0 0-1.153-.306l-1.206.69a2.9 2.9 0 0 0-1.184-.677v-1.38A.85.85 0 0 0 63.5 84a.843.843 0 0 0-.844.82v1.38a2.96 2.96 0 0 0-1.185.674l-1.205-.689a.848.848 0 0 0-1.259.616.83.83 0 0 0 .415.832l1.204.689c-.106.445-.105.909.003 1.353l-1.207.69a.83.83 0 0 0-.415.832.83.83 0 0 0 .62.7.85.85 0 0 0 .64-.084l1.205-.69c.334.318.74.55 1.184.675v1.382a.85.85 0 0 0 .844.82.843.843 0 0 0 .844-.82v-1.383c.441-.129.847-.36 1.184-.673l1.206.69a.847.847 0 0 0 1.259-.616.83.83 0 0 0-.415-.832m-4.712-.28a1.24 1.24 0 0 1-.622-1.25 1.25 1.25 0 0 1 .93-1.048 1.27 1.27 0 0 1 1.329.445 1.25 1.25 0 0 1 .093 1.393 1.28 1.28 0 0 1-1.73.46"
    readonly property real cloudW: anchor && anchor.s !== undefined && parent ? anchor.s * parent.width : 0
    readonly property real cloudBottom: anchor && anchor.y !== undefined && parent ? anchor.y * parent.height + cloudW * 222 / 700 : 0
    readonly property int dropCount: heavy || count >= 14 ? 5 : 3
    readonly property int cycles: snow ? 1 : (heavy ? 3 : 2)

    visible: !!cfg
    clip: !solid
    y: parent ? startAt * parent.height : 0
    width: parent ? parent.width : 0
    height: parent ? parent.height * (1 - startAt) : 0

    Repeater {
        model: precip.visible && precip.solid && !precip.snow ? precip.dropCount : 0
        delegate: Rectangle {
            required property int index
            readonly property real offset: index - (precip.dropCount - 1) / 2
            width: Math.max(1.5, precip.cloudW * 0.05)
            height: precip.cloudW * 0.15 + width
            radius: width / 2
            color: "#0a5ad4"
            x: precip.width * precip.centerX + offset * precip.cloudW * 0.15 - width / 2
            y: precip.cloudBottom - precip.cloudW * 0.07 + (Math.abs(offset) % 2 === 1 ? precip.cloudW * 0.1 : 0) - precip.y
        }
    }

    Repeater {
        model: precip.visible && precip.solid && precip.snow ? precip.dropCount : 0
        delegate: Shape {
            id: flakeShape
            required property int index
            readonly property real offset: index - (precip.dropCount - 1) / 2
            readonly property real k: precip.cloudW / 80
            width: 128
            height: 128
            scale: k
            transformOrigin: Item.TopLeft
            x: precip.width * precip.centerX - 64 * k + offset * 15 * k
            y: precip.cloudBottom - 88.5 * k + (Math.abs(offset) % 2 === 1 ? 8 * k : 0) - precip.y
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: "#86c3db"
                PathSvg { path: precip.flakePath }
            }
        }
    }

    Repeater {
        model: precip.visible && !precip.solid ? precip.count : 0
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
