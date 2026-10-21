import QtQuick
import QtQuick.Effects
import "."

// Mini Steve visiting a popup. Fill the popup with this item and point `target` at the
// element he should stand on; he arrives in the given style each time `active` turns on:
//   "nether" - steps out of a Nether portal standing on the target,
//   "end"    - falls out of an End portal opening above the target,
//   "slime"  - drops onto a slime block and keeps bouncing (higher with `bounceLevel`).
// Then he lives there: looks at the cursor and sometimes walks over to it, hops and talks
// when clicked, flips on double-click, gets hearts on right-click, can be picked up and
// dropped, sleeps when `sleeping`, and says things via say().
Item {
    id: visitor
    property bool active: false
    property string style: "nether"
    property Item target: null
    property int px: 3
    property bool wander: true
    property real bounceLevel: 0      // slime only: 0..1, 0 = no idle bouncing
    property real homeFrac: 0.5       // where along the target he lands
    property bool sleeping: false     // lies down with z's
    property bool tired: false        // walks slowly
    property string forcedPose: ""   // e.g. "back" while a password is being typed
    property var phrases: ["Привіт!", "Ой!", "Не чіпай!", "Хочу алмазів", "Де моя кирка?", "Покрафтимо?", "Кріпер позаду!", "Мммм...", "Гей!"]

    // Target geometry in our coordinates, refreshed while visible (targets may animate).
    property real tx: 0
    property real ty: 0
    property real tw: 0
    property real lastTy: 0
    function refresh() {
        if (!target || !target.visible) return;
        let p = visitor.mapFromItem(target, 0, 0);
        tx = p.x;
        ty = p.y;
        tw = target.width;
        // The thing he stands on jumped (e.g. another settings tab got selected): hop along.
        if (arrived && Math.abs(ty - lastTy) > px * 4) hop();
        lastTy = ty;
    }
    property int trackMs: 60          // how often to re-read the target's position
    Timer {
        interval: visitor.trackMs
        repeat: true
        running: visitor.active && visitor.target !== null
        triggeredOnStart: true
        onTriggered: visitor.refresh()
    }

    property bool arrived: false
    property real localX: 0           // Steve's center along the target
    property real dropY: 0            // offset while falling in / after being dropped
    property real hopY: 0
    property real fade: 1
    property string idlePose: "stand"
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    readonly property real steveW: px * 6
    readonly property real steveH: px * 8
    readonly property real blockW: px * 8          // slime block
    readonly property real slimeX: tw - blockW - px * 2
    readonly property real floorY: style === "slime" ? ty - blockW : ty
    readonly property real steveCx: tx + localX
    readonly property bool busy: arrive.running || dragging || fallAnim.running || flip.running

    onActiveChanged: {
        arrived = false;
        arrive.stop();
        walk.stop(); visitor.stepping = false;
        bubble.text = "";
        if (active) {
            refresh();
            lastTy = ty;
            arrive.restart();
        }
    }

    // ---------- talking
    function say(t, ms) {
        if (!active) return;
        bubble.text = t;
        bubbleTimer.interval = ms || 2600;
        bubbleTimer.restart();
    }
    Timer { id: bubbleTimer; onTriggered: bubble.text = "" }

    // ---------- arrival
    property real portalOpen: 0       // 0..1 portal grow/shrink
    SequentialAnimation {
        id: arrive
        ScriptAction {
            script: {
                visitor.localX = visitor.style === "slime" ? visitor.slimeX + visitor.blockW / 2
                    : (visitor.style === "nether" ? visitor.px * 12 : Math.max(visitor.steveW, visitor.tw * visitor.homeFrac));
                visitor.fade = visitor.style === "nether" ? 0 : 1;
                visitor.dropY = visitor.style === "nether" ? 0 : -visitor.px * 70;
                visitor.portalOpen = 0;
            }
        }
        PauseAnimation { duration: 600 }
        NumberAnimation { target: visitor; property: "portalOpen"; to: 1; duration: 350; easing.type: Easing.OutBack }
        ScriptAction {
            script: {
                visitor.arrived = true;
                fx.colors = visitor.style === "end" ? ["#0b0b14", "#2a2a4a", "#9a6aff", "#3fd0a0"]
                    : (visitor.style === "slime" ? ["#7fdc6a", "#4fae3a", "#b8f0a8"] : ["#a020f0", "#d070ff", "#6a0dad", "#e0a0ff"]);
                if (visitor.style !== "slime") fx.burst(visitor.steveCx, visitor.floorY - visitor.steveH / 2 + (visitor.style === "end" ? visitor.dropY : 0));
            }
        }
        ParallelAnimation {
            NumberAnimation { target: visitor; property: "fade"; to: 1; duration: 300 }
            NumberAnimation { target: visitor; property: "dropY"; to: 0; duration: 520; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                if (visitor.style === "slime") {
                    fx.burst(visitor.steveCx, visitor.floorY);
                    landBounce.restart();
                } else if (visitor.style === "end") {
                    fx.burst(visitor.steveCx, visitor.floorY);
                }
                visitor.arrivedSignal();
            }
        }
        PauseAnimation { duration: 700 }
        NumberAnimation { target: visitor; property: "portalOpen"; to: 0; duration: 300; easing.type: Easing.InBack }
        ScriptAction {
            script: {
                // Step away from the Nether portal into the middle of the target.
                if (visitor.style === "nether") visitor.walkTo(Math.max(visitor.steveW, visitor.tw * visitor.homeFrac));
            }
        }
    }
    signal arrivedSignal()

    // Slime: a few decaying bounces after landing.
    SequentialAnimation {
        id: landBounce
        NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * 12; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 220; easing.type: Easing.InQuad }
        NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * 6; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 160; easing.type: Easing.InQuad }
    }
    // Slime: keeps bouncing with the volume.
    SequentialAnimation {
        id: slimeLoop
        loops: Animation.Infinite
        running: visitor.active && visitor.arrived && visitor.style === "slime" && visitor.bounceLevel > 0.01
            && !visitor.sleeping && !visitor.busy && !landBounce.running && !hopAnim.running && !walk.running && !visitor.stepping
            && Math.abs(visitor.localX - (visitor.slimeX + visitor.blockW / 2)) < visitor.px * 2
        NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * (2 + 14 * visitor.bounceLevel); duration: 200 + 180 * visitor.bounceLevel; easing.type: Easing.OutQuad }
        NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 200 + 180 * visitor.bounceLevel; easing.type: Easing.InQuad }
        onStopped: visitor.hopY = 0
    }

    // ---------- moves
    function hop() {
        if (!hopAnim.running && !busy && !sleeping) hopAnim.start();
    }
    SequentialAnimation {
        id: hopAnim
        NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * 5; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 220; easing.type: Easing.InQuad }
    }

    // Double-click: a backflip.
    SequentialAnimation {
        id: flip
        ParallelAnimation {
            NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * 12; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: steve; property: "rotation"; from: 0; to: steve.facingLeft ? 360 : -360; duration: 520; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 260 }
                NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 260; easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: steve.rotation = 0 }
    }

    // Live-wallpaper mode: >0 walks in pixel steps every walkStepMs (few redraws) and
    // idles longer; 0 keeps the smooth popup behaviour.
    property int walkStepMs: 0
    property real stepTarget: 0
    property bool stepping: false
    Timer {
        interval: visitor.walkStepMs
        repeat: true
        running: visitor.active && visitor.stepping
        onTriggered: {
            let d = visitor.stepTarget - visitor.localX;
            visitor.localX += Math.sign(d) * Math.min(Math.abs(d), visitor.px * 2);
            if (Math.abs(visitor.stepTarget - visitor.localX) < visitor.px) visitor.stepping = false;
        }
    }

    function walkTo(x) {
        let maxX = tw - steveW / 2 - (style === "slime" ? blockW + px * 2 : 0);
        if (style === "slime" && x > maxX) x = slimeX + blockW / 2;   // hop back up onto the block
        else x = Math.max(steveW / 2, Math.min(maxX, x));
        if (Math.abs(x - localX) < px) return;
        steve.facingLeft = x < localX;
        if (walkStepMs > 0) { stepTarget = x; stepping = true; return; }
        walk.to = x;
        walk.duration = Math.abs(x - localX) / (px * (tired ? 7 : 16)) * 1000;
        walk.restart();
    }
    NumberAnimation { id: walk; target: visitor; property: "localX"; easing.type: Easing.Linear }

    // Picked up and let go: fall back onto the target and land in a puff of dust.
    function drop() {
        let maxX = tw - steveW / 2;
        localX = Math.max(steveW / 2, Math.min(maxX, dragX - tx));
        if (style === "slime" && localX > slimeX - steveW / 2) localX = slimeX + blockW / 2;
        dropY = Math.min(0, (dragY + steveH / 2) - floorY);
        fallAnim.fallTime = Math.max(120, Math.sqrt(Math.abs(dropY)) * 28);
        fallAnim.restart();
    }
    SequentialAnimation {
        id: fallAnim
        property int fallTime: 300
        NumberAnimation { target: visitor; property: "dropY"; to: 0; duration: fallAnim.fallTime; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                fx.colors = ["#9a9a9a", "#c8c8c8", "#6a6a6a"];
                fx.burst(visitor.steveCx, visitor.floorY);
                visitor.say(["Ай!", "Обережно!", "Ще раз!", "Вуу!"][Math.floor(Math.random() * 4)], 1600);
            }
        }
    }

    // ---------- getting hurt / celebrating
    property real hurtLevel: 0
    function hurt(text) {
        if (!arrived) return;
        walk.stop(); visitor.stepping = false;
        hurtAnim.restart();
        say(text || "Ой!", 2000);
    }
    SequentialAnimation {
        id: hurtAnim
        ScriptAction { script: { visitor.hurtLevel = 1; fx.colors = ["#ff3030", "#a01010", "#ff8080"]; fx.burst(visitor.steveCx, visitor.floorY - visitor.steveH / 2); } }
        ParallelAnimation {
            NumberAnimation { target: visitor; property: "hurtLevel"; to: 0; duration: 600 }
            NumberAnimation { target: visitor; property: "localX"; to: Math.max(visitor.steveW, visitor.localX - visitor.px * 10); duration: 300; easing.type: Easing.OutQuad }
            SequentialAnimation {
                NumberAnimation { target: visitor; property: "hopY"; to: -visitor.px * 6; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { target: visitor; property: "hopY"; to: 0; duration: 180; easing.type: Easing.InQuad }
            }
        }
    }
    function celebrate(text) {
        if (!arrived) return;
        say(text || "Ура!", 3000);
        flip.restart();
        fx.colors = ["#ff5555", "#ffff55", "#55ffff", "#55ff55", "#ff55ff", "#ffffff"];
        fx.burst(steveCx, floorY - steveH * 2);
        celebrateMore.restart();
    }
    Timer {
        id: celebrateMore
        interval: 250
        repeat: true
        property int n: 0
        onTriggered: {
            fx.burst(visitor.steveCx + (Math.random() - 0.5) * visitor.px * 40, visitor.floorY - visitor.steveH * (2 + Math.random() * 3));
            if (++n >= 4) { n = 0; stop(); }
        }
    }

    // ---------- watching the cursor
    HoverHandler { id: hover }
    readonly property real mouseX: hover.point.position.x
    Timer {
        interval: 250
        repeat: true
        running: visitor.active && visitor.arrived && hover.hovered && !visitor.busy && !walk.running && !visitor.stepping && !visitor.sleeping
        onTriggered: steve.facingLeft = visitor.mouseX < visitor.steveCx
    }
    Timer {
        interval: 1600
        repeat: true
        running: visitor.active && visitor.arrived && visitor.wander && hover.hovered && !visitor.busy && !visitor.sleeping
        onTriggered: {
            let dx = visitor.mouseX - visitor.steveCx;
            if (Math.abs(dx) > visitor.tw * 0.25 && Math.random() < 0.4) visitor.walkTo(visitor.mouseX - visitor.tx);
        }
    }

    // ---------- idle
    Timer {
        interval: 3000
        repeat: true
        running: visitor.active && visitor.arrived && !visitor.busy && !visitor.sleeping && !hover.hovered
        onTriggered: {
            interval = (2200 + Math.random() * 2800) * (visitor.walkStepMs > 0 ? 3 : 1);
            let r = Math.random();
            if (visitor.wander && r < 0.4) visitor.walkTo(Math.random() * visitor.tw);
            else if (r < 0.6) { visitor.idlePose = "wave"; waveEnd.restart(); }
            else if (r < 0.75) visitor.hop();
            else if (r < 0.85 && visitor.style === "slime") visitor.walkTo(visitor.slimeX + visitor.blockW / 2);
            else steve.facingLeft = !steve.facingLeft;
        }
    }
    Timer { id: waveEnd; interval: 700; onTriggered: visitor.idlePose = "stand" }

    // ---------- portals and blocks
    Canvas {
        id: portal
        visible: visitor.active && visitor.style !== "slime" && visitor.portalOpen > 0.01
        readonly property int cols: visitor.style === "end" ? 7 : 6
        readonly property int rows: visitor.style === "end" ? 3 : 10
        width: cols * visitor.px
        height: rows * visitor.px
        x: visitor.style === "end" ? visitor.steveCx - width / 2 : visitor.tx + visitor.px * 12 - width / 2
        y: visitor.style === "end" ? visitor.floorY - visitor.px * 70 - visitor.steveH - height / 2 : visitor.floorY - height
        scale: visitor.portalOpen
        transformOrigin: visitor.style === "end" ? Item.Center : Item.Bottom
        antialiasing: false
        property real swirl: 0
        NumberAnimation on swirl { from: 0; to: 1; duration: 900; loops: Animation.Infinite; running: portal.visible }
        onSwirlChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = visitor.px;
            for (let y = 0; y < rows; y++)
                for (let x = 0; x < cols; x++) {
                    let c;
                    if (visitor.style === "end") {
                        // Frame blocks with an eye of ender at both ends, starry void in between.
                        if (x === 0 || x === cols - 1) c = (y === 1) ? "#2f8f6f" : "#dcd6a0";
                        else {
                            let n = (x * 31 + y * 17 + Math.floor(swirl * 6)) % 11;
                            c = n === 0 ? "#9a6aff" : (n === 3 ? "#3fd0a0" : (n === 6 ? "#ffffff" : "#05050c"));
                        }
                    } else {
                        // Obsidian frame, purple swirl inside.
                        if (x === 0 || x === cols - 1 || y === 0 || y === rows - 1) c = (x + y) % 3 === 0 ? "#1d1430" : "#120c1e";
                        else {
                            let n = (x * 7 + y * 3 + Math.floor(swirl * 8)) % 5;
                            c = n === 0 ? "#d070ff" : (n < 3 ? "#8a20d8" : "#6a0dad");
                        }
                    }
                    ctx.fillStyle = c;
                    ctx.fillRect(x * p, y * p, p, p);
                }
        }
    }

    Canvas {
        id: slimeBlock
        visible: visitor.active && visitor.style === "slime" && visitor.tw > 0
        width: visitor.blockW
        height: visitor.blockW
        x: visitor.tx + visitor.slimeX
        y: visitor.ty - height + (visitor.hopY === 0 && visitor.arrived ? visitor.px * 0.5 : 0)
        antialiasing: false
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = visitor.px;
            for (let y = 0; y < 8; y++)
                for (let x = 0; x < 8; x++) {
                    let edge = x === 0 || y === 0 || x === 7 || y === 7;
                    let core = x >= 2 && x <= 5 && y >= 2 && y <= 5;
                    ctx.fillStyle = edge ? "#5fbf4a" : (core ? "#4f9e3c" : "#7fdc6a");
                    ctx.fillRect(x * p, y * p, p, p);
                }
            ctx.fillStyle = "#c8f8b8";
            ctx.fillRect(p, p, p * 2, p);
        }
    }

    TeleportBurst {
        id: fx
        anchors.fill: parent
        px: visitor.px
    }

    // Floating z's while asleep.
    Repeater {
        model: 3
        delegate: McText {
            text: "z"
            font.pixelSize: visitor.px * (4 + index)
            color: "#ffffff"
            property real t: 0
            x: visitor.steveCx + visitor.px * 2 + t * visitor.px * 8
            y: visitor.floorY - visitor.steveW - height - t * visitor.px * 12
            visible: visitor.active && visitor.arrived && visitor.sleeping
            opacity: Math.sin(t * Math.PI)
            SequentialAnimation on t {
                loops: Animation.Infinite
                running: visitor.active && visitor.sleeping
                PauseAnimation { duration: index * 700 }
                NumberAnimation { from: 0; to: 1; duration: 2100 }
            }
        }
    }

    MiniSteve {
        id: steve
        px: visitor.px
        visible: visitor.active && visitor.arrived && visitor.tw > 0
        opacity: visitor.fade
        readonly property bool lying: visitor.sleeping && !visitor.dragging && !visitor.busy
        x: visitor.dragging ? visitor.dragX - width / 2 : visitor.steveCx - width / 2
        y: visitor.dragging ? visitor.dragY - height / 2
            : (lying ? visitor.floorY - visitor.steveW / 2 - height / 2 : visitor.floorY - height + visitor.dropY + visitor.hopY)
        rotation: lying ? -90 : 0
        layer.enabled: visitor.hurtLevel > 0.01
        layer.effect: MultiEffect {
            colorization: visitor.hurtLevel * 0.85
            colorizationColor: "#ff2020"
        }
        pose: visitor.forcedPose !== "" && !visitor.dragging && !flip.running && !hopAnim.running ? visitor.forcedPose
            : visitor.dragging || (arrive.running && visitor.dropY < -1) || fallAnim.running || hopAnim.running || flip.running
            || landBounce.running || visitor.hopY < -visitor.px ? "jump" : visitor.idlePose

        MouseArea {
            anchors.fill: parent
            anchors.margins: -visitor.px * 2
            cursorShape: visitor.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            property point pressAt: Qt.point(0, 0)

            onPressed: mouse => {
                if (mouse.button !== Qt.LeftButton) return;
                pressAt = Qt.point(mouse.x, mouse.y);
            }
            onPositionChanged: mouse => {
                if (!pressed || !(mouse.buttons & Qt.LeftButton)) return;
                let p = mapToItem(visitor, mouse.x, mouse.y);
                if (!visitor.dragging && Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) > visitor.px * 3) {
                    walk.stop(); visitor.stepping = false;
                    hopAnim.stop();
                    visitor.hopY = 0;
                    visitor.dragging = true;
                    visitor.say("Пусти!", 1500);
                }
                if (visitor.dragging) {
                    visitor.dragX = Math.max(0, Math.min(visitor.width, p.x));
                    visitor.dragY = Math.max(0, Math.min(visitor.height, p.y));
                }
            }
            onReleased: mouse => {
                if (visitor.dragging) {
                    visitor.dragging = false;
                    visitor.drop();
                }
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    fx.colors = ["#ff3040", "#ff8090", "#d01020"];
                    fx.burst(visitor.steveCx, visitor.floorY - visitor.steveH);
                    visitor.say("❤", 1400);
                    return;
                }
                if (visitor.sleeping) {
                    visitor.say("Ммм... ще 5 хвилин", 1800);
                    return;
                }
                visitor.hop();
                visitor.say(visitor.phrases[Math.floor(Math.random() * visitor.phrases.length)]);
            }
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !visitor.sleeping && !visitor.busy) {
                    hopAnim.stop();
                    flip.restart();
                    visitor.say("Сальто!", 1400);
                }
            }
        }
    }

    // Chat bubble above his head, like a chat line in the game.
    Rectangle {
        id: bubbleBox
        visible: visitor.active && visitor.arrived && bubble.text !== ""
        color: Qt.rgba(0, 0, 0, 0.72)
        width: bubble.implicitWidth + visitor.px * 4
        height: bubble.implicitHeight + visitor.px * 2
        x: Math.max(0, Math.min(visitor.width - width, steve.x + steve.width / 2 - width / 2))
        y: Math.max(0, steve.y - height - visitor.px * 3)

        McText {
            id: bubble
            anchors.centerIn: parent
            text: ""
            font.pixelSize: Math.max(10, visitor.px * 4)
            color: "#ffffff"
        }
    }
}
