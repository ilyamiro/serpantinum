import QtQuick
import "../../"

// Cava visualizer drawn by a single ShaderEffect: bars or a wave, horizontal or vertical.
// The owner subscribes to Cava and sets active. Levels are mapped and smoothed here,
// the shaders in assets/shaders only draw them.
Item {
    id: root

    property bool active: false
    property bool continuous: false
    property bool vertical: false
    // Where the bars grow from: "start" (top/left), "center" or "end" (bottom/right)
    property string alignment: "end"
    property int count: 16
    property color color: ThemeBackend.mauve

    // Frequency mapping: low frequencies first, or in the middle and mirrored to both sides
    property bool mirrored: true
    property real curve: 1.25
    property bool interpolate: true
    property real threshold: 0.03
    property real gamma: 1.15

    // How far a level moves to its target per 16 ms, 1 follows cava directly
    property real rise: 1.0
    property real fall: 1.0

    property real maxLength: vertical ? width : height

    // Bars only
    property real spacing: 4
    property real minLength: 2
    property real radiusRatio: 0.5
    property real opacityBase: 1.0
    property real opacityRange: 0.0
    property bool edgeFade: false

    // Guide previews animate a demo while nothing is playing
    property bool previewDemo: false

    // Average of the drawn levels, for owners that fade the wave with loudness
    property real energy: 0.0

    readonly property int levelCount: Math.max(2, Math.min(128, count))

    // Where every level reads the spectrum, rebuilt only when the count or the mapping changes
    readonly property var sourceMap: {
        let n = root.levelCount;
        let srcLen = Cava.barCount;
        let half = (n - 1) / 2;
        let map = [];
        for (let i = 0; i < n; i++) {
            let norm = root.mirrored ? (half > 0 ? Math.abs(i - half) / half : 0) : i / (n - 1);
            let pos = Math.pow(norm, root.curve) * (srcLen - 1);
            let idx0 = Math.floor(pos);
            map.push({ idx0: idx0, idx1: Math.min(srcLen - 1, idx0 + 1), frac: root.interpolate ? pos - idx0 : 0 });
        }
        return map;
    }

    // Fade towards both ends of the wave
    readonly property var waveEdge: {
        let n = root.levelCount;
        let edges = [];
        for (let i = 0; i < n; i++) {
            let edge = Math.min(1.0, Math.sin((i / (n - 1)) * Math.PI) * 2.0);
            edges.push(edge * edge * (3.0 - 2.0 * edge));
        }
        return edges;
    }

    function mapLevels(source) {
        let map = root.sourceMap;
        let out = new Array(map.length).fill(0.0);
        if (!source || source.length === 0) return out;

        // Read the properties once, every read inside a binding is tracked
        let threshold = root.threshold;
        let gamma = root.gamma;
        for (let i = 0; i < map.length; i++) {
            let v0 = source[map[i].idx0] || 0.0;
            let v1 = source[map[i].idx1] || 0.0;
            let raw = v0 + (v1 - v0) * map[i].frac;

            let val = raw < threshold ? 0.0 : Math.pow((raw - threshold) / (1 - threshold), gamma);
            out[i] = Math.max(0.0, Math.min(1.0, val));
        }
        return out;
    }

    function demoLevels(n) {
        let out = [];
        let t = Date.now() / 600;
        let floor = root.continuous ? 0.0 : 0.08;
        for (let i = 0; i < n; i++) {
            let norm = i / (n - 1);
            let wave1 = Math.sin(norm * Math.PI * 2 + t) * 0.5 + 0.5;
            let wave2 = Math.cos(norm * Math.PI * 3 - t * 0.8) * 0.3 + 0.3;
            let env = Math.sin(norm * Math.PI);
            let val = (wave1 * 0.6 + wave2 * 0.4) * env;
            out.push(Math.max(floor, Math.min(1.0, val)));
        }
        return out;
    }

    // Light blur between neighbours, then the fade towards the ends
    function shapeWave(levels) {
        let edges = root.waveEdge;
        let n = levels.length;
        let out = [];
        for (let i = 0; i < n; i++) {
            let prev = i > 0 ? levels[i - 1] : levels[i];
            let next = i < n - 1 ? levels[i + 1] : levels[i];
            out.push((prev * 0.25 + levels[i] * 0.5 + next * 0.25) * edges[i]);
        }
        return out;
    }

    property int demoTick: 0
    Timer {
        interval: 33
        running: root.previewDemo && root.active && root.visible
        repeat: true
        onTriggered: root.demoTick++
    }

    property var targets: {
        let source = root.active ? Cava.barLevels : null;
        let out;
        if (root.previewDemo && root.active && (!source || source.every(v => v === 0))) {
            let dummy = root.demoTick;
            out = demoLevels(root.levelCount);
        } else {
            out = mapLevels(source);
        }
        return root.continuous ? shapeWave(out) : out;
    }

    property var currentLevels: []
    property bool settling: false

    onTargetsChanged: settling = true

    function packLevels(v, o) {
        let m = [];
        for (let k = 0; k < 16; k++) m.push(v[o + k] || 0.0);
        return Qt.matrix4x4(m);
    }

    // The shaders never read past count, so only the used matrices are refreshed
    function uploadLevels(v) {
        for (let m = 0; m < Math.ceil(v.length / 16); m++) {
            effect["levels" + m] = packLevels(v, m * 16);
        }
    }

    Component.onCompleted: {
        uploadLevels(new Array(128).fill(0.0));
        settling = true;
    }

    FrameAnimation {
        running: root.settling && root.visible
        onTriggered: {
            let target = root.targets;
            let cur = root.currentLevels;
            let rise = 1 - Math.pow(1 - root.rise, frameTime / 0.016);
            let fall = 1 - Math.pow(1 - root.fall, frameTime / 0.016);
            let next = new Array(target.length);
            let moving = false;
            let sum = 0.0;

            for (let i = 0; i < target.length; i++) {
                let t = target[i];
                let c = cur[i] || 0.0;
                if (Math.abs(t - c) > 0.001) {
                    c += (t - c) * (t > c ? rise : fall);
                    moving = true;
                } else {
                    c = t;
                }
                next[i] = c;
                sum += c;
            }

            root.currentLevels = next;
            root.energy = next.length > 0 ? sum / next.length : 0.0;
            root.uploadLevels(next);
            if (!moving) root.settling = false;
        }
    }

    ShaderEffect {
        id: effect
        anchors.fill: parent

        // Filled by uploadLevels(), 16 levels per matrix
        property matrix4x4 levels0
        property matrix4x4 levels1
        property matrix4x4 levels2
        property matrix4x4 levels3
        property matrix4x4 levels4
        property matrix4x4 levels5
        property matrix4x4 levels6
        property matrix4x4 levels7
        property color color: root.color
        property size itemSize: Qt.size(width, height)
        property real count: root.levelCount
        property real vertical: root.vertical ? 1.0 : 0.0
        property real alignment: root.alignment === "start" ? 0.0 : (root.alignment === "center" ? 1.0 : 2.0)
        property real maxLength: root.maxLength
        property real spacing: root.spacing
        property real minLength: root.minLength
        property real radiusRatio: root.radiusRatio
        property real opacityBase: root.opacityBase
        property real opacityRange: root.opacityRange
        property real edgeFade: root.edgeFade ? 1.0 : 0.0

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/" + (root.continuous ? "visualizer_wave" : "visualizer_bars") + ".frag.qsb"
    }
}
