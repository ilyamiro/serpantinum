import QtQuick
import "."

// A strip of grass with a mini Steve: he dances by the jukebox while music plays,
// wanders around when it doesn't, sleeps in his bed when `sleeping`, and hops on
// track change or click.
Item {
    id: stage
    property bool playing: false
    property real beat: 0          // 0..1 kick/bass level
    property string trackId: ""
    property bool active: true
    property int px: 2
    property bool showJukebox: true
    property bool showBed: false
    property bool sleeping: false
    // Arrive gliding on elytra (from the bar) instead of dropping straight down.
    property bool elytraArrival: false

    implicitHeight: px * 15

    readonly property real groundH: px * 3
    readonly property real steveW: px * 6
    readonly property real steveH: px * 8
    readonly property real jukeW: px * 8
    readonly property real floorY: height - groundH
    readonly property real danceX: jukeW + px * 3
    readonly property real minX: showJukebox ? danceX : px * 2
    readonly property real bedW: px * 12
    readonly property real bedX: width - bedW - px * 2
    readonly property real maxX: (showBed ? bedX - px : width) - steveW

    property real steveX: danceX + px * 20
    property real hopY: 0
    property bool walking: walkAnim.running
    property bool facingLeft: false
    property int walkFrame: 0
    property bool armsUp: false
    property bool jumping: hopAnim.running || dropAnim.running
    readonly property bool gliding: glideAnim.running
    property bool lying: false
    property bool headingToBed: false

    readonly property var palette: ({
        // Same colors as the Steve on the bar's workspace islands.
        "H": "#3b2a1a", "F": "#c69c7a", "e": "#3a3fbf", "b": "#6b4a30",
        "C": "#00a8a8", "c": "#008080", "P": "#46399a", "g": "#5a5a5a",
        "o": "#2a1a0e", "T": "#3b2a1a", "S": "#000000", "W": "#8a5a3a",
        "w": "#5e3a22", "L": "#b07e52", "R": "#c8282e", "r": "#9a1c22",
        "U": "#f2f2f2", "u": "#cfcfcf"
    })
    readonly property var standSprite: [".HHHH.", ".HFFH.", ".eFFe.", ".FbbF.", "CCCCCC", "FcCCcF", ".PPPP.", ".gggg."]
    readonly property var walkSprites: [
        [".HHHH.", ".HFFH.", ".eFFe.", ".FbbF.", "CCCCCC", "FcCCcF", ".PP.P.", "g...g."],
        [".HHHH.", ".HFFH.", ".eFFe.", ".FbbF.", "CCCCCC", "FcCCcF", ".P.PP.", ".g...g"]
    ]
    readonly property var danceSprite: ["FHHHH.", "CHFFH.", "CeFFe.", ".FbbF.", ".CCCCC", ".cCCcF", ".PPPP.", ".g..g."]
    readonly property var jumpSprite: ["FHHHHF", "CHFFHC", "CeFFeC", ".FbbF.", ".CCCC.", ".cCCc.", ".P..P.", "g....g"]
    readonly property var sleepSprite: [".HHHH.", ".HFFH.", ".bFFb.", ".FFFF.", "CCCCCC", "FcCCcF", ".PPPP.", ".gggg."]
    readonly property var bedSprite: ["UUURRRRRRRRR", "uuuRrrrrrrrR", "WWWWWWWWWWWW", "w..........w"]
    readonly property var jukeSprite: ["oooooooo", "oTTSSTTo", "oTTTTTTo", "oWLWWLWo", "oWwWWwWo", "oWWWWWWo", "oLWWWWLo", "oooooooo"]

    function paintSprite(ctx, sprite) {
        for (let y = 0; y < sprite.length; y++)
            for (let x = 0; x < sprite[y].length; x++) {
                let ch = sprite[y][x];
                if (ch === ".") continue;
                ctx.fillStyle = palette[ch];
                ctx.fillRect(x * px, y * px, px, px);
            }
    }

    function walkTo(x) {
        x = Math.max(minX, Math.min(maxX, x));
        if (Math.abs(x - steveX) < px) return;
        facingLeft = x < steveX;
        walkAnim.stop();
        walkAnim.to = x;
        walkAnim.duration = Math.abs(x - steveX) / (px * 18) * 1000;
        walkAnim.start();
    }

    function hop() {
        if (lying) {
            // Poke him awake for a moment; he goes back to bed if it's still night.
            lying = false;
            hopAnim.start();
            backToBedTimer.restart();
            return;
        }
        if (!hopAnim.running && !dropAnim.running && !glideAnim.running) hopAnim.start();
    }

    function goToBed() {
        if (!showBed) return;
        let target = maxX;
        if (Math.abs(steveX - target) < px) {
            lying = true;
        } else {
            headingToBed = true;
            walkTo(target);
        }
    }

    Timer {
        id: backToBedTimer
        interval: 2500
        onTriggered: if (stage.sleeping) stage.goToBed()
    }

    onSleepingChanged: {
        if (sleeping) goToBed();
        else { lying = false; headingToBed = false; }
    }

    // Arrival: Steve has just jumped off the bar's workspace islands and falls in from above.
    SequentialAnimation {
        id: dropAnim
        ScriptAction {
            script: {
                walkAnim.stop();
                stage.lying = false;
                stage.steveX = (stage.sleeping && stage.showBed) ? stage.maxX
                    : stage.playing ? stage.danceX : stage.minX + stage.px * 20;
                stage.hopY = -stage.px * 45;
            }
        }
        PauseAnimation { duration: 380 }
        NumberAnimation { target: stage; property: "hopY"; to: 0; duration: 380; easing.type: Easing.InQuad }
        NumberAnimation { target: stage; property: "hopY"; to: -stage.px * 2; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: stage; property: "hopY"; to: 0; duration: 90; easing.type: Easing.InQuad }
        ScriptAction { script: if (stage.sleeping) stage.goToBed() }
    }
    function arrive() {
        hopAnim.stop();
        if (elytraArrival) glideAnim.restart();
        else dropAnim.restart();
    }
    onActiveChanged: if (active) arrive()
    Component.onCompleted: if (active) arrive()

    // Glide in from the top-left with a firework trail and touch down next to the bed.
    SequentialAnimation {
        id: glideAnim
        ScriptAction {
            script: {
                walkAnim.stop();
                dropAnim.stop();
                stage.lying = false;
                elytra.facingLeft = false;
                elytra.flyX = stage.minX - elytra.spriteW;
                elytra.flyY = stage.floorY - stage.px * 80;
                elytra.flying = false;
            }
        }
        PauseAnimation { duration: 650 }
        ScriptAction { script: { elytra.flying = true; elytra.burst(); } }
        ParallelAnimation {
            NumberAnimation { target: elytra; property: "flyX"; to: (stage.showBed ? stage.maxX : stage.minX + stage.px * 20) - elytra.spriteW / 2; duration: 1300; easing.type: Easing.OutSine }
            NumberAnimation { target: elytra; property: "flyY"; to: stage.floorY - elytra.spriteH - stage.px * 2; duration: 1300; easing.type: Easing.InOutQuad }
        }
        ScriptAction {
            script: {
                elytra.flying = false;
                stage.steveX = stage.showBed ? stage.maxX : stage.minX + stage.px * 20;
                stage.hopY = -stage.px * 3;
            }
        }
        NumberAnimation { target: stage; property: "hopY"; to: 0; duration: 140; easing.type: Easing.InQuad }
        ScriptAction { script: if (stage.sleeping) stage.goToBed() }
    }

    ElytraFlight {
        id: elytra
        z: 10
        x: 0
        y: 0
        width: 1
        height: 1
        px: stage.px
        active: stage.active
    }

    onPlayingChanged: {
        if (playing) walkTo(danceX);
        else wanderTimer.restart();
    }
    onTrackIdChanged: hop()
    onWidthChanged: if (steveX > maxX) steveX = Math.max(minX, maxX)

    NumberAnimation {
        id: walkAnim
        target: stage
        property: "steveX"
        easing.type: Easing.Linear
        onFinished: {
            stage.walkFrame = 0;
            if (stage.headingToBed && stage.sleeping) stage.lying = true;
            stage.headingToBed = false;
        }
    }

    SequentialAnimation {
        id: hopAnim
        NumberAnimation { target: stage; property: "hopY"; to: -stage.px * 5; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: stage; property: "hopY"; to: 0; duration: 220; easing.type: Easing.InQuad }
    }

    Timer {
        interval: 140
        repeat: true
        running: stage.active && stage.walking
        onTriggered: stage.walkFrame = 1 - stage.walkFrame
    }

    // Dance: swap the raised arm on every kick, with a fallback tempo when there is no beat data.
    property bool beatHigh: false
    onBeatChanged: {
        if (!playing || walking) return;
        if (!beatHigh && beat > 0.55) {
            beatHigh = true;
            armsUp = !armsUp;
            facingLeft = !facingLeft;
        } else if (beatHigh && beat < 0.35) {
            beatHigh = false;
        }
    }
    Timer {
        interval: 420
        repeat: true
        running: stage.active && stage.playing && !stage.walking && stage.beat < 0.05
        onTriggered: { stage.armsUp = !stage.armsUp; stage.facingLeft = !stage.facingLeft; }
    }

    Timer {
        id: wanderTimer
        interval: 2500 + Math.random() * 3000
        repeat: true
        running: stage.active && !stage.playing && !stage.sleeping && !stage.gliding
        onTriggered: {
            interval = 2500 + Math.random() * 3000;
            if (!stage.walking && !stage.jumping)
                stage.walkTo(stage.minX + Math.random() * (stage.maxX - stage.minX));
        }
    }

    // Grass ground.
    Canvas {
        id: ground
        x: 0
        y: stage.floorY
        width: stage.width
        height: stage.groundH
        antialiasing: false
        onWidthChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = stage.px;
            let cols = Math.ceil(width / p);
            for (let x = 0; x < cols; x++) {
                // Deterministic speckle so the texture doesn't shimmer on repaint.
                let n = (x * 73 + 11) % 7;
                ctx.fillStyle = "#6cbf3c";
                ctx.fillRect(x * p, 0, p, p);
                ctx.fillStyle = n < 3 ? "#3f7f26" : "#6cbf3c";
                ctx.fillRect(x * p, p, p, p);
                ctx.fillStyle = n === 5 ? "#5e402a" : "#8a6142";
                ctx.fillRect(x * p, p * 2, p, p);
            }
        }
    }

    // Jukebox.
    Canvas {
        id: jukebox
        visible: stage.showJukebox
        x: 0
        y: stage.floorY - height
        width: stage.jukeW
        height: stage.jukeW
        antialiasing: false
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            stage.paintSprite(ctx, stage.jukeSprite);
        }
    }

    Repeater {
        model: 3
        delegate: McText {
            id: note
            text: "♪"
            font.pixelSize: stage.px * 6
            // Note block particle colors.
            color: ["#5cff5c", "#ff5ca8", "#5cc8ff"][index % 3]
            property real t: 0
            x: jukebox.x + jukebox.width / 2 - width / 2 + Math.sin(t * Math.PI * 2 + index * 2) * stage.px * 3
            y: jukebox.y - height * 0.6 - t * stage.px * 14
            opacity: stage.playing && stage.showJukebox ? Math.sin(t * Math.PI) : 0.0
            SequentialAnimation on t {
                loops: Animation.Infinite
                running: stage.active && stage.playing
                PauseAnimation { duration: index * 500 }
                NumberAnimation { from: 0; to: 1; duration: 1500; easing.type: Easing.OutQuad }
            }
        }
    }

    // Bed.
    Canvas {
        id: bed
        visible: stage.showBed
        x: stage.bedX
        y: stage.floorY - height
        width: stage.bedW
        height: stage.px * 4
        antialiasing: false
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            stage.paintSprite(ctx, stage.bedSprite);
        }
    }

    Repeater {
        model: 3
        delegate: McText {
            text: "z"
            font.pixelSize: stage.px * (4 + index)
            color: "#ffffff"
            property real t: 0
            x: stage.bedX + stage.px * 2 + t * stage.px * 8 + Math.sin(t * Math.PI * 2) * stage.px
            y: bed.y - height - t * stage.px * 12
            opacity: stage.lying ? Math.sin(t * Math.PI) : 0.0
            SequentialAnimation on t {
                loops: Animation.Infinite
                running: stage.active && stage.lying
                PauseAnimation { duration: index * 700 }
                NumberAnimation { from: 0; to: 1; duration: 2100 }
            }
        }
    }

    Canvas {
        id: steve
        visible: !stage.gliding
        width: stage.steveW
        height: stage.steveH
        // Lying: rotated a quarter turn with the head on the pillow.
        x: stage.lying ? stage.bedX + stage.steveH / 2 - width / 2 : stage.steveX
        y: stage.lying
            ? bed.y + stage.px - stage.steveW / 2 - height / 2
            : stage.floorY - height + stage.hopY - (stage.playing && !stage.walking ? stage.beat * stage.px * 2 : 0)
        rotation: stage.lying ? -90 : 0
        antialiasing: false
        transform: Scale { origin.x: steve.width / 2; xScale: stage.facingLeft && !stage.lying ? -1 : 1 }

        property var sprite: stage.lying ? stage.sleepSprite
            : stage.jumping ? stage.jumpSprite
            : stage.walking ? stage.walkSprites[stage.walkFrame]
            : (stage.playing && stage.armsUp) ? stage.danceSprite
            : stage.standSprite
        onSpriteChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            stage.paintSprite(ctx, sprite);
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -stage.px * 2
            cursorShape: Qt.PointingHandCursor
            onClicked: stage.hop()
        }
    }
}
