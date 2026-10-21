import QtQuick
import "."

// A little side-view mob that wanders along a strip of ground: picks a spot, walks
// there with a two-frame leg cycle, idles, repeats. Click it for a hop and its sound.
Item {
    id: mob
    property string kind: "sheep"      // sheep, pig, chicken, cow, creeper
    property int px: 4
    property real minX: 0
    property real maxX: 400
    property real groundY: 0           // y of the ground top
    property bool running: true
    property real speed: px * 4        // pixels per second
    property bool glide: false        // glide between steps instead of jumping
    readonly property int stepMs: Math.max(120, px / speed * 1000)
    Behavior on x {
        enabled: mob.glide && mob.walkingNow
        NumberAnimation { duration: mob.stepMs; easing.type: Easing.Linear }
    }

    readonly property var defs: ({
        "sheep": {
            pal: { "W": "#e9e9e9", "w": "#cfcfcf", "H": "#d9b8a5", "e": "#1a1a1a", "L": "#d9b8a5" },
            body: ["..WWWWWWW.....", ".WWWWWWWWWW...", "WWWWWWWWWWWHHH", "WWWWwWWWWWWHeH", "WWWWWWWwWWWHHH",
                   "WWwWWWWWWWW.HH", ".WWWWWWWWWW..."],
            legs: [[".L.L.....L.L..", ".L.L.....L.L.."], ["L...L...L...L.", ".L.L.....L.L.."]],
            say: ["Бее!", "Беееее", "Мее?"]
        },
        "pig": {
            pal: { "P": "#f2a5a5", "p": "#e08b8b", "S": "#e88a8a", "n": "#a0505a", "e": "#1a1a1a", "w": "#ffffff" },
            body: ["........PPPP", "PPPPPPPPPwePP".slice(0, 12), "PPPPPPPPPPSS", "PPPPpPPPPPSn", "PPPPPPPPPP.."],
            legs: [["pp.....pp...", "pp.....pp..."], [".pp...pp....", "pp.....pp..."]],
            say: ["Хрю!", "Хрю-хрю", "Рох?"]
        },
        "cow": {
            pal: { "B": "#4a3424", "W": "#e8e8e8", "H": "#3a2a1c", "h": "#c8c8c8", "e": "#111111", "n": "#bfa08a", "L": "#3a2a1c" },
            body: ["..........hh..", "..........HHHH", "BBBWWBBBBBHeHH", "BWWWBBBWWBHHnn", "BBBBBBWWWBBBnn",
                   "BWWBBBBBBBB...", "BBBBWWBBBBB..."],
            legs: [[".LL......LL...", ".LL......LL..."], ["LL......LL....", ".LL......LL..."]],
            say: ["Муу!", "Мууу", "Му?"]
        },
        "chicken": {
            pal: { "W": "#f4f4f4", "w": "#d8d8d8", "R": "#d03030", "Y": "#f0b020", "e": "#1a1a1a", "O": "#e09020" },
            body: ["....WW..", "....WeY.", "....WWR.", "WWWWWW..", "WwwWWW..", ".WWWW..."],
            legs: [["..O.O...", "..O.O..."], ["...O....", "..O.O..."]],
            say: ["Ко-ко!", "Кудах!", "Пі-пі"]
        },
        "creeper": {
            pal: { "G": "#4fa83a", "g": "#2f6f22", "d": "#1f3f18", "l": "#7fd06a" },
            body: ["GlGG", "GdGG", "GGdG", "GGGG", ".GG.", ".gG.", ".GG.", ".Gl.", ".GG.", ".gG."],
            legs: [["GGGG", "G..G"], ["GGGG", ".GG."]],
            say: ["Тсссс...", "...", "Ссссс"]
        }
    })
    readonly property var def: defs[kind] || defs["sheep"]
    readonly property int cols: def.body[0].length
    readonly property int rowsN: def.body.length + 2

    width: cols * px
    height: rowsN * px
    y: groundY - height + hopY
    property real hopY: 0
    property bool facingLeft: false
    property int frame: 0
    property bool walking: walkingNow

    // Both leg frames are painted once; walking just flips which one is shown.
    Repeater {
        model: 2
        Canvas {
            id: sprite
            required property int index
            anchors.fill: parent
            antialiasing: false
            visible: (mob.walking ? mob.frame : 0) === index
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            transform: Scale { origin.x: sprite.width / 2; xScale: mob.facingLeft ? -1 : 1 }
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let rows = mob.def.body.concat(mob.def.legs[index]);
                for (let y = 0; y < rows.length; y++)
                    for (let x = 0; x < rows[y].length; x++) {
                        let ch = rows[y][x];
                        if (ch === "." || !mob.def.pal[ch]) continue;
                        ctx.fillStyle = mob.def.pal[ch];
                        ctx.fillRect(x * mob.px, y * mob.px, mob.px, mob.px);
                    }
            }
        }
    }

    // walking: one pixel step at a time (pixel-art look, and cheap to redraw)
    property real targetX: x
    readonly property bool walkingNow: Math.abs(targetX - x) >= px
    Timer {
        interval: mob.stepMs
        repeat: true
        running: mob.running && mob.walkingNow
        onTriggered: {
            let d = mob.targetX - mob.x;
            mob.x += Math.sign(d) * Math.min(Math.abs(d), mob.px);
            mob.frame = 1 - mob.frame;
            if (!mob.walkingNow) idle.restart();
        }
    }
    Timer {
        id: idle
        interval: 2000 + Math.random() * 6000
        running: mob.running
        onTriggered: mob.wander()
    }
    function wander() {
        if (!running) return;
        let to = minX + Math.random() * Math.max(1, maxX - minX - width);
        to = Math.round(to / px) * px;
        if (Math.abs(to - x) < px * 4) { idle.interval = 1500 + Math.random() * 5000; idle.restart(); return; }
        facingLeft = to < x;
        targetX = to;
        idle.interval = 5000 + Math.random() * 12000;
    }
    Component.onCompleted: { x = Math.round(x / px) * px; targetX = x; }

    // click: hop and talk
    SequentialAnimation {
        id: hop
        NumberAnimation { target: mob; property: "hopY"; to: -mob.px * 5; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: mob; property: "hopY"; to: 0; duration: 200; easing.type: Easing.InQuad }
    }
    McText {
        id: bubble
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: mob.px * 2
        font.pixelSize: mob.px * 4
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Timer { id: bubbleHide; interval: 1600; onTriggered: bubble.opacity = 0 }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -mob.px * 2
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            hop.restart();
            bubble.text = mob.def.say[Math.floor(Math.random() * mob.def.say.length)];
            bubble.opacity = 1;
            bubbleHide.restart();
        }
    }
}
