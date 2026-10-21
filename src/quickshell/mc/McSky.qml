import QtQuick

// Minecraft-style sky for the given time of day: banded gradient, square sun/moon on
// an arc, flat block clouds, stars at night and pixel rain.
Item {
    id: sky
    property real hour: 12          // fractional local hour, 0..24
    property bool raining: false
    property bool active: true
    property int px: 3
    // >0: move clouds/stars in coarse steps every tickMs instead of smooth 60 fps
    // animation (live wallpaper uses this to save CPU).
    property int tickMs: 0

    // Sky colors (top, bottom) at key hours; interpolated in between.
    readonly property var keys: [
        [0.0, "#0a0e26", "#161d42"],
        [5.0, "#0a0e26", "#161d42"],
        [6.5, "#3d5aa6", "#e39a62"],
        [8.5, "#4f7bd0", "#8fb2ea"],
        [16.5, "#4f7bd0", "#8fb2ea"],
        [18.5, "#2e3f86", "#d8714a"],
        [20.0, "#0a0e26", "#161d42"],
        [24.0, "#0a0e26", "#161d42"]
    ]

    function lerpColor(a, b, t) {
        let ca = Qt.color(a), cb = Qt.color(b);
        return Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t, 1);
    }
    function skyAt(which) {
        for (let i = 0; i < keys.length - 1; i++) {
            let a = keys[i], b = keys[i + 1];
            if (hour >= a[0] && hour <= b[0]) {
                let t = (hour - a[0]) / Math.max(0.001, b[0] - a[0]);
                return lerpColor(a[which], b[which], t);
            }
        }
        return Qt.color(keys[0][which]);
    }
    readonly property color topColor: raining ? Qt.darker(skyAt(1), 1.5) : skyAt(1)
    readonly property color bottomColor: raining ? Qt.darker(skyAt(2), 1.5) : skyAt(2)

    // 1 at night, 0 by day, fading through dusk and dawn.
    readonly property real night: hour >= 20 || hour < 5 ? 1
        : hour >= 18.5 ? (hour - 18.5) / 1.5
        : hour < 6.5 ? (6.5 - hour) / 1.5 : 0

    Canvas {
        id: bands
        anchors.fill: parent
        antialiasing: false
        property color c1: sky.topColor
        property color c2: sky.bottomColor
        onC1Changed: requestPaint()
        onC2Changed: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let n = 14;
            let h = Math.ceil(height / n);
            for (let i = 0; i < n; i++) {
                ctx.fillStyle = sky.lerpColor(c1, c2, i / (n - 1));
                ctx.fillRect(0, i * h, width, h);
            }
        }
    }

    // Stars.
    Repeater {
        model: 46
        delegate: Rectangle {
            // Deterministic pseudo-random placement.
            readonly property real rx: ((index * 7919) % 1000) / 1000
            readonly property real ry: ((index * 104729) % 1000) / 1000
            x: rx * sky.width
            y: ry * sky.height * 0.75
            width: index % 5 === 0 ? sky.px * 2 : sky.px
            height: width
            color: index % 4 === 0 ? "#fff3c0" : "#ffffff"
            opacity: sky.night * (0.4 + 0.6 * twinkle)
            property real twinkle: 1
            Timer {
                interval: sky.tickMs * 4
                repeat: true
                running: sky.active && sky.night > 0 && sky.tickMs > 0
                onTriggered: parent.twinkle = 0.6 + 0.4 * Math.sin(Date.now() / 900 + index * 1.7)
            }
            SequentialAnimation on twinkle {
                loops: Animation.Infinite
                running: sky.active && sky.night > 0 && sky.tickMs === 0
                PauseAnimation { duration: (index * 331) % 2500 }
                NumberAnimation { to: 0.2; duration: 900 }
                NumberAnimation { to: 1.0; duration: 900 }
            }
        }
    }

    // Sun by day, moon by night, both square like in the game.
    Canvas {
        id: orb
        readonly property bool isSun: sky.hour >= 6 && sky.hour < 18
        readonly property real frac: isSun ? (sky.hour - 6) / 12 : (((sky.hour - 18) + 24) % 24) / 12
        width: sky.px * 16
        height: width
        x: frac * (sky.width + width) - width
        y: sky.height * 0.62 - Math.sin(Math.PI * frac) * sky.height * 0.52
        antialiasing: false
        opacity: sky.raining ? 0.35 : 1.0
        onIsSunChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = sky.px;
            for (let y = 0; y < 16; y++) {
                for (let x = 0; x < 16; x++) {
                    let edge = x < 2 || y < 2 || x > 13 || y > 13;
                    let c;
                    if (isSun) {
                        c = edge ? "#ffb300" : ((x > 4 && x < 11 && y > 4 && y < 11) ? "#fffbd0" : "#ffe25c");
                    } else {
                        c = edge ? "#9a9aae" : "#dcdce8";
                        // Craters.
                        if ((x === 5 && y === 5) || (x === 6 && y === 5) || (x === 5 && y === 6)
                            || (x === 10 && y === 8) || (x === 9 && y === 9) || (x === 10 && y === 9)
                            || (x === 6 && y === 11))
                            c = "#a8a8bc";
                    }
                    ctx.fillStyle = c;
                    ctx.fillRect(x * p, y * p, p, p);
                }
            }
        }
    }

    // Flat block clouds drifting across.
    Repeater {
        model: 3
        delegate: Canvas {
            id: cloud
            readonly property var shape: [
                ["..XXXX......", ".XXXXXXXX...", "XXXXXXXXXXXX", "..XXXXXXXX.."],
                ["....XXXX", "..XXXXXXX", "XXXXXXXXXX", ".XXXXXXX.."],
                [".XXXXX.....", "XXXXXXXXXX.", ".XXXXXXXXXX"]
            ][index]
            width: sky.px * 2 * 12
            height: sky.px * 2 * 4
            y: sky.height * (0.06 + index * 0.11)
            antialiasing: false
            opacity: (sky.raining ? 0.95 : 0.85) * (1 - sky.night * 0.7)
            property color tint: sky.raining ? "#8a8f9a" : "#ffffff"
            onTintChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let p = sky.px * 2;
                for (let y = 0; y < shape.length; y++)
                    for (let x = 0; x < shape[y].length; x++) {
                        if (shape[y][x] !== "X") continue;
                        ctx.fillStyle = y === shape.length - 1 ? Qt.darker(tint, 1.12) : tint;
                        ctx.fillRect(x * p, y * p, p, p);
                    }
            }
            property real t: 0
            x: ((t + index * 0.37) % 1) * (sky.width + width) - width
            NumberAnimation on t {
                from: 0
                to: 1
                duration: 90000 + index * 35000
                loops: Animation.Infinite
                running: sky.active && sky.tickMs === 0
            }
            Timer {
                interval: sky.tickMs
                repeat: true
                running: sky.active && sky.tickMs > 0
                onTriggered: parent.t = (parent.t + sky.tickMs / (90000 + index * 35000)) % 1
            }
        }
    }

    // Rain.
    Repeater {
        model: sky.raining ? 60 : 0
        delegate: Rectangle {
            readonly property real rx: ((index * 7907) % 1000) / 1000
            width: sky.px
            height: sky.px * 5
            color: "#5a7cff"
            opacity: 0.55
            x: rx * sky.width
            property real t: 0
            y: -height + ((t + rx * 3.7) % 1) * (sky.height + height)
            NumberAnimation on t {
                from: 0
                to: 1
                duration: 700 + (index * 37) % 400
                loops: Animation.Infinite
                running: sky.active
            }
        }
    }
}
