import QtQuick
import "../../"
import "Snake.js" as Sim

Item {
    id: root

    property color color: "white"
    property real shadowStrength: 0.56
    property bool running: false
    property real unit: 1
    property int segments: 48
    property real speed: 1
    property string simKey: ""
    property rect snakeRect

    readonly property string _ownKey: "snake-" + Math.random().toString(36).slice(2)
    property string _acquiredKey: ""
    property var _sim: null
    property int _syncedVersion: -1
    property int _chunks: 1

    function ensureSim() {
        const key = root.simKey !== "" ? root.simKey : root._ownKey;
        if (root._sim && root._acquiredKey === key) return;
        if (root._sim) Sim.release(root._acquiredKey);
        root._sim = Sim.acquire(key);
        root._acquiredKey = key;
        root._syncedVersion = -1;
    }

    Component.onDestruction: if (root._sim) Sim.release(root._acquiredKey)

    onWidthChanged: if (root._sim && root._sim.isInitialized()) root._sim.resize(root.width / root.unit, root.height / root.unit)
    onHeightChanged: if (root._sim && root._sim.isInitialized()) root._sim.resize(root.width / root.unit, root.height / root.unit)
    onSegmentsChanged: if (root._sim && root._sim.isInitialized()) root._sim.setLength(root.segments)
    onUnitChanged: root._syncedVersion = -1
    onShadowStrengthChanged: root._syncedVersion = -1

    function sync() {
        const sim = root._sim;
        sim.prepare();
        const n = sim.count();
        const unit = root.unit;
        root._chunks = sim.chunkCount();

        const pairs = Math.min(48, Math.floor(n / 2) + 3);
        const joints = [];
        for (let q = 0; q < pairs; q++) joints.push(sim.pair(q));
        const head = sim.headVector();
        const tail = sim.tailVector();
        const tongue = sim.tongueAlpha();
        const tongueA = tongue > 0 ? sim.tongueBase() : null;
        const tongueB = tongue > 0 ? sim.tongueTips() : null;
        const params = Qt.vector4d(n, tongue, 1 / (unit * Math.max(1, Screen.devicePixelRatio)), root.shadowStrength);
        const none = Qt.vector4d(0, 0, 0, 0);

        const skips = [];
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (let k = 0; k < root._chunks; k++) {
            const effect = chunkRepeater.itemAt(k);
            if (!effect) continue;
            const b = sim.chunkRect(k);
            const x0 = Math.floor(b.x * unit);
            const y0 = Math.floor(b.y * unit);
            const x1 = Math.ceil((b.x + b.width) * unit);
            const y1 = Math.ceil((b.y + b.height) * unit);
            effect.x = x0;
            effect.y = y0;
            effect.width = x1 - x0;
            effect.height = y1 - y0;
            effect.area = Qt.vector4d(x0 / unit, y0 / unit, (x1 - x0) / unit, (y1 - y0) / unit);
            for (let s = 0; s < 5; s++) effect["skip" + s] = s < skips.length ? skips[s] : none;
            skips.push(Qt.vector4d(x0 / unit, y0 / unit, x1 / unit, y1 / unit));

            for (let q = 0; q < pairs; q++) effect["j" + q] = joints[q];
            effect.head = head;
            effect.tail = tail;
            if (tongueA) {
                effect.tongueA = tongueA;
                effect.tongueB = tongueB;
            }
            effect.params = params;
            if (!effect.visible) effect.visible = true;

            minX = Math.min(minX, x0);
            minY = Math.min(minY, y0);
            maxX = Math.max(maxX, x1);
            maxY = Math.max(maxY, y1);
        }
        root.snakeRect = Qt.rect(minX, minY, maxX - minX, maxY - minY);
    }

    FrameAnimation {
        running: root.running && root.visible && root.width > 0 && root.height > 0
        onTriggered: {
            root.ensureSim();
            const sim = root._sim;
            if (!sim.isInitialized()) sim.init(root.width / root.unit, root.height / root.unit, root.segments);
            else if (sim.count() !== Math.max(16, Math.min(96, root.segments))) sim.setLength(root.segments);
            sim.advance(frameTime, root, root.speed);
            const version = sim.version();
            if (version === root._syncedVersion) return;
            root._syncedVersion = version;
            root.sync();
        }
    }

    Repeater {
        id: chunkRepeater
        model: root._chunks

        ShaderEffect {
            visible: false

            property vector4d area
            property vector4d params
            property color fillColor: root.color
            property vector4d head
            property vector4d tail
            property vector4d tongueA
            property vector4d tongueB
            property vector4d skip0
            property vector4d skip1
            property vector4d skip2
            property vector4d skip3
            property vector4d skip4
            property vector4d j0
            property vector4d j1
            property vector4d j2
            property vector4d j3
            property vector4d j4
            property vector4d j5
            property vector4d j6
            property vector4d j7
            property vector4d j8
            property vector4d j9
            property vector4d j10
            property vector4d j11
            property vector4d j12
            property vector4d j13
            property vector4d j14
            property vector4d j15
            property vector4d j16
            property vector4d j17
            property vector4d j18
            property vector4d j19
            property vector4d j20
            property vector4d j21
            property vector4d j22
            property vector4d j23
            property vector4d j24
            property vector4d j25
            property vector4d j26
            property vector4d j27
            property vector4d j28
            property vector4d j29
            property vector4d j30
            property vector4d j31
            property vector4d j32
            property vector4d j33
            property vector4d j34
            property vector4d j35
            property vector4d j36
            property vector4d j37
            property vector4d j38
            property vector4d j39
            property vector4d j40
            property vector4d j41
            property vector4d j42
            property vector4d j43
            property vector4d j44
            property vector4d j45
            property vector4d j46
            property vector4d j47

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/widgets/snake.frag.qsb"
        }
    }
}
