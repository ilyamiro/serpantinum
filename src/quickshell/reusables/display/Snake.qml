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
    property string simKey: ""
    property rect snakeRect

    readonly property string _ownKey: "snake-" + Math.random().toString(36).slice(2)
    property string _acquiredKey: ""
    property var _sim: null

    function ensureSim() {
        const key = root.simKey !== "" ? root.simKey : root._ownKey;
        if (root._sim && root._acquiredKey === key) return;
        if (root._sim) Sim.release(root._acquiredKey);
        root._sim = Sim.acquire(key);
        root._acquiredKey = key;
    }

    Component.onDestruction: if (root._sim) Sim.release(root._acquiredKey)

    onWidthChanged: if (root._sim && root._sim.isInitialized()) root._sim.resize(root.width / root.unit, root.height / root.unit)
    onHeightChanged: if (root._sim && root._sim.isInitialized()) root._sim.resize(root.width / root.unit, root.height / root.unit)
    onSegmentsChanged: if (root._sim && root._sim.isInitialized()) root._sim.setLength(root.segments)

    function sync() {
        const sim = root._sim;
        sim.prepare();
        const n = sim.count();
        const unit = root.unit;
        const b = sim.bounds();
        const margin = 30;
        const x0 = Math.floor((b.x - margin) * unit);
        const y0 = Math.floor((b.y - margin) * unit);
        shader.x = x0;
        shader.y = y0;
        shader.width = Math.ceil((b.x + b.width + margin) * unit) - x0;
        shader.height = Math.ceil((b.y + b.height + margin) * unit) - y0;
        shader.area = Qt.vector4d(shader.x / unit, shader.y / unit, shader.width / unit, shader.height / unit);
        root.snakeRect = Qt.rect(shader.x, shader.y, shader.width, shader.height);

        const pairs = Math.min(48, Math.floor(n / 2) + 3);
        for (let q = 0; q < pairs; q++) shader["j" + q] = sim.pair(q);

        shader.head = sim.headVector();
        shader.tail = sim.tailVector();
        const tongue = sim.tongueAlpha();
        if (tongue > 0) {
            shader.tongueA = sim.tongueBase();
            shader.tongueB = sim.tongueTips();
        }
        shader.params = Qt.vector4d(n, tongue, 1 / (unit * Math.max(1, Screen.devicePixelRatio)), root.shadowStrength);
    }

    FrameAnimation {
        running: root.running && root.visible && root.width > 0 && root.height > 0
        onTriggered: {
            root.ensureSim();
            const sim = root._sim;
            if (!sim.isInitialized()) sim.init(root.width / root.unit, root.height / root.unit, root.segments);
            else if (sim.count() !== Math.max(16, Math.min(96, root.segments))) sim.setLength(root.segments);
            sim.advance(frameTime, root);
            root.sync();
            if (!shader.visible) shader.visible = true;
        }
    }

    ShaderEffect {
        id: shader
        visible: false

        property vector4d area
        property vector4d params
        property color fillColor: root.color
        property vector4d head
        property vector4d tail
        property vector4d tongueA
        property vector4d tongueB
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
