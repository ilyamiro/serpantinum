import QtQuick

// Steve gliding on elytra with a firework spark trail. Fill the space the flight
// happens in, then move him with flyX/flyY; sparks stay where they were emitted.
Item {
    id: flight
    property int px: 2
    property real flyX: 0
    property real flyY: 0
    property bool flying: false
    property bool facingLeft: false
    property bool active: true

    readonly property real spriteW: px * 12
    readonly property real spriteH: px * 6

    readonly property var palette: ({
        "H": "#3b2a1a", "F": "#c69c7a", "i": "#3a3fbf", "C": "#00a8a8", "c": "#008080",
        "P": "#46399a", "g": "#5a5a5a", "E": "#9d97c0", "e": "#6a6490", "R": "#c8282e", "r": "#e8e0d0"
    })
    // Side view, head to the right, wings spread above, firework rocket in hand.
    readonly property var sprite: [
        "...eEEEEe...",
        ".eEEEEEEEEe.",
        "ggPPCCCCHHHH",
        "ggPPCCCCFFFH",
        "..PPCcCCFiFH",
        "......FrR..."
    ]

    // Burst of sparks on take-off, then a steady trail from the boots.
    function burst() {
        for (let i = 0; i < 6; i++) spawn(true);
    }
    property int nextSpark: 0
    function spawn(big) {
        let p = sparks.itemAt(nextSpark);
        nextSpark = (nextSpark + 1) % sparks.count;
        if (!p) return;
        let tailX = facingLeft ? flyX + spriteW : flyX;
        p.launch(tailX, flyY + spriteH * 0.55, big);
    }

    Timer {
        interval: 45
        repeat: true
        running: flight.active && flight.flying
        onTriggered: flight.spawn(false)
    }

    Repeater {
        id: sparks
        model: 18
        delegate: Rectangle {
            id: spark
            width: flight.px
            height: flight.px
            visible: life > 0
            opacity: life
            property real life: 0
            property real vx: 0
            property real vy: 0
            readonly property var colors: ["#ff5555", "#ffff55", "#55ffff", "#55ff55", "#ffffff", "#ff55ff"]

            function launch(x0, y0, big) {
                x = x0;
                y = y0;
                let a = Math.random() * Math.PI * 2;
                let sp = (big ? 6 : 2) * flight.px;
                vx = Math.cos(a) * sp + (flight.facingLeft ? 1 : -1) * flight.px * 2;
                vy = Math.sin(a) * sp;
                color = colors[Math.floor(Math.random() * colors.length)];
                width = big ? flight.px * 2 : flight.px;
                height = width;
                life = 1;
                fade.restart();
            }

            NumberAnimation {
                id: fade
                target: spark
                property: "life"
                to: 0
                duration: 600
            }
            Timer {
                interval: 30
                repeat: true
                running: spark.life > 0
                onTriggered: { spark.x += spark.vx * 0.3; spark.y += spark.vy * 0.3 + flight.px * 0.15; }
            }
        }
    }

    Canvas {
        id: body
        visible: flight.flying
        x: flight.flyX
        y: flight.flyY
        width: flight.spriteW
        height: flight.spriteH
        antialiasing: false
        transform: Scale { origin.x: body.width / 2; xScale: flight.facingLeft ? -1 : 1 }
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = flight.px;
            for (let y = 0; y < flight.sprite.length; y++)
                for (let x = 0; x < flight.sprite[y].length; x++) {
                    let ch = flight.sprite[y][x];
                    if (ch === ".") continue;
                    ctx.fillStyle = flight.palette[ch];
                    ctx.fillRect(x * p, y * p, p, p);
                }
        }
    }
}
