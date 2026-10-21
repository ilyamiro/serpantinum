import QtQuick

// Pixel particle burst (purple ender teleport by default). Fill the area, then call burst(x, y).
Item {
    id: tp
    property int px: 2
    property var colors: ["#a020f0", "#d070ff", "#6a0dad", "#e0a0ff"]

    property int next: 0
    function burst(cx, cy) {
        for (let i = 0; i < 14; i++) {
            let p = parts.itemAt(next);
            next = (next + 1) % parts.count;
            if (p) p.launch(cx, cy);
        }
    }

    Repeater {
        id: parts
        model: 28
        delegate: Rectangle {
            id: part
            visible: life > 0
            opacity: life
            property real life: 0
            property real vx: 0
            property real vy: 0
            function launch(cx, cy) {
                let a = Math.random() * Math.PI * 2;
                let r = Math.random() * tp.px * 3;
                x = cx + Math.cos(a) * r;
                y = cy + Math.sin(a) * r;
                vx = Math.cos(a) * tp.px * (0.5 + Math.random());
                vy = Math.sin(a) * tp.px * (0.5 + Math.random()) - tp.px * 0.8;
                width = tp.px * (Math.random() < 0.3 ? 2 : 1);
                height = width;
                color = tp.colors[Math.floor(Math.random() * tp.colors.length)];
                life = 1;
                fade.restart();
            }
            NumberAnimation { id: fade; target: part; property: "life"; to: 0; duration: 700 + Math.random() * 300 }
            Timer {
                interval: 30
                repeat: true
                running: part.life > 0
                onTriggered: { part.x += part.vx; part.y += part.vy; part.vy *= 0.92; part.vx *= 0.92; }
            }
        }
    }
}
