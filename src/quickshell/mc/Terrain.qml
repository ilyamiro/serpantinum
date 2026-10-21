import QtQuick

// Blocky landscape: distant hills with trees drifting by (a slow "panorama"), and a
// flat strip of grass, dirt and stone in front for Steve to walk on.
Item {
    id: terrain
    property int px: 4
    property real night: 0                 // 0 day .. 1 night, darkens everything
    property bool running: true            // false pauses the drifting hills
    property int tickMs: 0                 // >0: step the hills one pixel-block at a time (saves CPU)
    readonly property real block: px * 8
    readonly property int groundBlocks: 4
    readonly property real groundY: height - block * groundBlocks
    property alias groundItem: ground

    // Far hills: twice the screen wide and periodic, scrolled endlessly.
    Item {
        id: hills
        width: terrain.width * 2
        height: terrain.height
        property real off: 0
        x: -off
        NumberAnimation on off { from: 0; to: terrain.width; duration: 160000; loops: Animation.Infinite; running: terrain.running && terrain.tickMs === 0 }
        Timer {
            interval: terrain.tickMs
            repeat: true
            running: terrain.running && terrain.tickMs > 0
            onTriggered: hills.off = (hills.off + terrain.width * terrain.tickMs / 160000) % terrain.width
        }

        Canvas {
            anchors.fill: parent
            antialiasing: false
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let b = terrain.block * 0.75;
                let cols = Math.ceil(terrain.width / b);
                let base = terrain.groundY;
                function h(i) {
                    let t = (i % cols) / cols * Math.PI * 2;
                    return Math.round(3 + 2.2 * Math.sin(t * 2) + 1.4 * Math.sin(t * 5 + 1) + 0.8 * Math.sin(t * 9 + 2));
                }
                for (let rep = 0; rep < 2; rep++) {
                    for (let i = 0; i < cols; i++) {
                        let x = (rep * cols + i) * b;
                        let n = h(i);
                        for (let k = 0; k < n + 2; k++) {
                            let y = base - (n - k) * b;
                            ctx.fillStyle = k === 0 ? "#4f8f3a" : (k < 3 ? "#5e4630" : "#55555c");
                            ctx.fillRect(x, y, b + 1, b + 1);
                        }
                        // A tree now and then.
                        if (i % 11 === 4) {
                            let top = base - n * b;
                            ctx.fillStyle = "#4a3520";
                            for (let t = 1; t <= 3; t++) ctx.fillRect(x, top - t * b, b + 1, b + 1);
                            ctx.fillStyle = "#2f6f2a";
                            for (let lx = -1; lx <= 1; lx++)
                                for (let ly = 3; ly <= 5; ly++)
                                    if (!(Math.abs(lx) === 1 && ly === 5)) ctx.fillRect(x + lx * b, top - ly * b, b + 1, b + 1);
                        }
                    }
                }
            }
        }
        // Haze so the hills read as distant.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.55, 0.7, 0.95, 0.35 * (1 - terrain.night))
        }
    }

    // Foreground ground strip.
    Canvas {
        id: groundCanvas
        x: 0
        y: terrain.groundY
        width: terrain.width
        height: terrain.height - terrain.groundY
        antialiasing: false
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = terrain.px;
            let cols = Math.ceil(width / p), rows = Math.ceil(height / p);
            for (let y = 0; y < rows; y++) {
                for (let x = 0; x < cols; x++) {
                    let n = (x * 73 + y * 151 + (x * y) % 7) % 13;
                    let c;
                    if (y < 2) c = n < 4 ? "#5fa83a" : "#6cbf3c";
                    else if (y === 2) c = (n < 6) ? "#4f8f2f" : "#8a6142";
                    else if (y < 16) c = n === 3 ? "#5e402a" : (n === 7 ? "#9a7050" : "#8a6142");
                    else {
                        c = n === 2 ? "#6a6a6a" : (n === 9 ? "#8a8a8a" : "#7a7a7a");
                        if ((x * 7 + y * 3) % 97 === 0) c = "#2a2a2a";   // coal
                        if ((x * 11 + y * 5) % 181 === 0) c = "#5fe0e0"; // diamond
                    }
                    ctx.fillStyle = c;
                    ctx.fillRect(x * p, y * p, p, p);
                }
            }
        }
    }

    // Night tint over the landscape.
    Rectangle {
        anchors.fill: parent
        color: "#000814"
        opacity: terrain.night * 0.55
    }

    // What Steve stands on.
    Item {
        id: ground
        x: terrain.block
        width: terrain.width - terrain.block * 2
        y: terrain.groundY
        height: 1
    }
}
