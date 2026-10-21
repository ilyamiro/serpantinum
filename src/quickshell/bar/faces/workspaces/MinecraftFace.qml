import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../../../reusables"
import "../../../"
import "../../../mc"

// Minecraft islands: each workspace is a floating grass island and a mini Steve
// hops island by island to the active workspace.
Item {
    id: mcFaceRoot
    property var widget: null
    property bool vertical: false

    property int px: widget ? Math.max(1, Math.round(widget.s(2))) : 2

    property real islandW: px * 8
    property real islandH: px * 5
    property real steveW: px * 6
    property real steveH: px * 8
    property real headroom: px * 3
    property real hopHeight: px * 5

    property real cellW: islandW
    property real cellH: headroom + steveH + islandH
    property real cellSpacing: vertical ? 0 : px * 3

    implicitWidth: cellsGrid.implicitWidth
    implicitHeight: cellsGrid.implicitHeight

    property int activeIdx: widget ? widget.activeIndex : -1

    // Steve's position: the island he stands on, plus the hop in progress.
    property int steveIdx: -1
    property int hopFrom: 0
    property int hopTo: 0
    property real hopT: 0
    property bool jumping: hopAnim.running

    function cellX(i) { return cellsGrid.x + (vertical ? 0 : i * (cellW + cellSpacing)); }
    function cellY(i) { return cellsGrid.y + (vertical ? i * (cellH + cellSpacing) : 0); }

    function nextHop() {
        if (activeIdx < 0) return;
        if (steveIdx < 0 || steveIdx >= (widget ? widget.workspaceCount : 0)) {
            steveIdx = activeIdx;
            hopFrom = activeIdx;
            hopTo = activeIdx;
            return;
        }
        if (steveIdx === activeIdx) return;
        let remaining = Math.abs(activeIdx - steveIdx);
        hopFrom = steveIdx;
        hopTo = steveIdx + (activeIdx > steveIdx ? 1 : -1);
        hopT = 0;
        hopAnim.duration = remaining > 3 ? 95 : 170;
        hopAnim.restart();
    }

    onActiveIdxChanged: if (!hopAnim.running) nextHop()
    Component.onCompleted: nextHop()

    NumberAnimation {
        id: hopAnim
        target: mcFaceRoot
        property: "hopT"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: {
            mcFaceRoot.steveIdx = mcFaceRoot.hopTo;
            mcFaceRoot.hopFrom = mcFaceRoot.hopTo;
            mcFaceRoot.landed(mcFaceRoot.steveIdx);
            mcFaceRoot.nextHop();
        }
    }

    signal landed(int idx)

    // When the music or calendar popup opens, Steve jumps off his island and drops out of
    // the bar (he lands in the popup's grass strip); he falls back onto his island when it closes.
    property bool musicOpen: false
    property real awayOffset: 0
    property bool away: false
    readonly property bool travelling: leaveAnim.running || returnAnim.running || flyAnim.running || pearlAnim.running || stuntAnim.running
    property bool calendarOpen: false
    property bool networkOpen: false
    property string stuntKind: ""     // "nether" (settings), "end" (system panel), "slime" (volume)

    FileView {
        path: Caching.runDir ? (Caching.runDir + "/current_widget") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text().trim();
            let w = "";
            try {
                let parsed = JSON.parse(txt);
                w = (parsed && typeof parsed === "object") ? (parsed.widget || "") : String(parsed);
            } catch (e) {
                w = txt;
            }
            mcFaceRoot.pendingWidget = w;
            widgetSettle.restart();
        }
    }

    // The widget file gets rewritten several times per open/close; act on the settled value only.
    property string pendingWidget: ""
    Timer {
        id: widgetSettle
        interval: 150
        onTriggered: {
            let w = mcFaceRoot.pendingWidget;
            mcFaceRoot.calendarOpen = (w === "calendar");
            mcFaceRoot.networkOpen = (w === "network");
            mcFaceRoot.stuntKind = w === "guide" ? "nether" : (w === "system" ? "end" : (w === "volume" ? "slime" : ""));
            mcFaceRoot.musicOpen = (w === "music" || w === "calendar" || w === "network" || mcFaceRoot.stuntKind !== "");
        }
    }

    onMusicOpenChanged: {
        if (musicOpen) {
            returnAnim.stop();
            if (calendarOpen && steve.visible) flyAnim.restart();
            else if (networkOpen && steve.visible) pearlAnim.restart();
            else if (stuntKind !== "" && steve.visible) stuntAnim.restart();
            else leaveAnim.restart();
        } else if (away || leaveAnim.running || flyAnim.running || pearlAnim.running || stuntAnim.running) {
            if (stuntAnim.running) { stuntAnim.stop(); mcFaceRoot.endStunt(); }
            leaveAnim.stop();
            if (flyAnim.running) { flyAnim.stop(); endFlight(); }
            if (pearlAnim.running) { pearlAnim.stop(); pearl.visible = false; restoreModule(); }
            returnAnim.restart();
        }
    }

    // Calendar/weather: Steve puts on elytra and rockets across the bar to the weather in
    // the middle, then dives down into the popup (where he glides to his bed).
    property real flyTargetX: 0
    property real flyStartY: 0
    property real savedModuleZ: 0
    readonly property var barModule: widget ? widget.module : null

    function startFlight() {
        away = true;
        elytra.flyX = steve.x - (elytra.spriteW - steve.width) / 2;
        elytra.flyY = steve.y + steve.height - elytra.spriteH;
        flyStartY = elytra.flyY;
        let g = mcFaceRoot.mapToGlobal(0, 0);
        flyTargetX = Screen.width / 2 + px * 30 - g.x - elytra.spriteW / 2;
        elytra.facingLeft = flyTargetX < elytra.flyX;
        liftModule();
        elytra.flying = true;
        elytra.burst();
    }

    function endFlight() {
        elytra.flying = false;
        restoreModule();
    }

    // Let Steve's stunts leave the workspaces capsule and draw over neighbouring modules.
    property bool moduleLifted: false
    function liftModule() {
        if (!barModule || moduleLifted) return;
        savedModuleZ = barModule.z;
        barModule.z = 1000;
        barModule.clip = false;
        moduleLifted = true;
    }
    function restoreModule() {
        if (!barModule || !moduleLifted) return;
        barModule.z = savedModuleZ;
        barModule.clip = true;
        moduleLifted = false;
    }

    // Wi-Fi/Bluetooth: Steve throws an ender pearl towards the network modules on the right
    // and teleports away (he reappears on top of the network popup's core block).
    property real pearlStartY: 0
    property real pearlTargetX: 0
    SequentialAnimation {
        id: pearlAnim
        ScriptAction {
            script: {
                mcFaceRoot.liftModule();
                let g = mcFaceRoot.mapToGlobal(0, 0);
                mcFaceRoot.pearlTargetX = Screen.width * 0.8 - g.x;
                pearl.x = steve.x + steve.width / 2;
                pearl.y = steve.y;
                mcFaceRoot.pearlStartY = steve.y;
            }
        }
        PauseAnimation { duration: 160 }
        ScriptAction { script: pearl.visible = true }
        ParallelAnimation {
            NumberAnimation { target: pearl; property: "x"; to: mcFaceRoot.pearlTargetX; duration: 800; easing.type: Easing.Linear }
            SequentialAnimation {
                NumberAnimation { target: pearl; property: "y"; to: mcFaceRoot.pearlStartY - mcFaceRoot.px * 3; duration: 320; easing.type: Easing.OutQuad }
                NumberAnimation { target: pearl; property: "y"; to: mcFaceRoot.pearlStartY + mcFaceRoot.px * 6; duration: 480; easing.type: Easing.InQuad }
            }
        }
        ScriptAction {
            script: {
                pearl.visible = false;
                barTp.burst(pearl.x, pearl.y);
                barTp.burst(steve.x + steve.width / 2, steve.y + steve.height / 2);
                mcFaceRoot.away = true;
            }
        }
        PauseAnimation { duration: 1000 }
        ScriptAction { script: mcFaceRoot.restoreModule() }
    }

    // Portal / slime stunts: a prop appears next to Steve's island and he leaves through it.
    property real stuntX: 0
    property real stuntY: 0
    property real stuntFade: 1
    property real propOpen: 0
    property real stuntTargetX: 0
    property real stuntTargetY: 0

    function startStunt() {
        liftModule();
        prop.kind = stuntKind;
        prop.x = steve.x - stuntX + steve.width + px * 3;
        prop.y = steve.y - stuntY + steve.height - prop.height;
        stuntTargetX = prop.x + prop.width / 2 - (steve.x - stuntX + steve.width / 2);
        stuntTargetY = stuntKind === "slime" ? -prop.height : (stuntKind === "end" ? -prop.height * 0.2 : 0);
    }
    function endStunt() {
        stuntX = 0;
        stuntY = 0;
        stuntFade = 1;
        propOpen = 0;
        restoreModule();
    }

    SequentialAnimation {
        id: stuntAnim
        ScriptAction { script: mcFaceRoot.startStunt() }
        NumberAnimation { target: mcFaceRoot; property: "propOpen"; from: 0; to: 1; duration: 320; easing.type: Easing.OutBack }
        // Hop over to the prop.
        ParallelAnimation {
            NumberAnimation { target: mcFaceRoot; property: "stuntX"; to: mcFaceRoot.stuntTargetX; duration: 320; easing.type: Easing.InOutSine }
            SequentialAnimation {
                NumberAnimation { target: mcFaceRoot; property: "stuntY"; to: mcFaceRoot.stuntTargetY - mcFaceRoot.px * 5; duration: 170; easing.type: Easing.OutQuad }
                NumberAnimation { target: mcFaceRoot; property: "stuntY"; to: mcFaceRoot.stuntTargetY; duration: 150; easing.type: Easing.InQuad }
            }
        }
        ScriptAction {
            script: {
                if (mcFaceRoot.stuntKind === "nether") {
                    barTp.colors = ["#a020f0", "#d070ff", "#6a0dad", "#e0a0ff"];
                    barTp.burst(prop.x + prop.width / 2, prop.y + prop.height / 2);
                } else if (mcFaceRoot.stuntKind === "end") {
                    barTp.colors = ["#0b0b14", "#2a2a4a", "#9a6aff", "#3fd0a0"];
                    barTp.burst(prop.x + prop.width / 2, prop.y);
                } else {
                    barTp.colors = ["#7fdc6a", "#4fae3a", "#b8f0a8"];
                    barTp.burst(prop.x + prop.width / 2, prop.y);
                }
            }
        }
        // Leave: fade into the Nether portal, sink through the End portal, or get launched by slime.
        ParallelAnimation {
            NumberAnimation { target: mcFaceRoot; property: "stuntFade"; to: mcFaceRoot.stuntKind === "slime" ? 1 : 0; duration: 420 }
            NumberAnimation {
                target: mcFaceRoot
                property: "stuntY"
                to: mcFaceRoot.stuntKind === "end" ? mcFaceRoot.stuntTargetY + steve.height
                    : (mcFaceRoot.stuntKind === "slime" ? -mcFaceRoot.cellH * 3 : mcFaceRoot.stuntTargetY)
                duration: 420
                easing.type: mcFaceRoot.stuntKind === "slime" ? Easing.OutQuad : Easing.InQuad
            }
        }
        ScriptAction { script: mcFaceRoot.away = true }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: mcFaceRoot; property: "propOpen"; to: 0; duration: 260; easing.type: Easing.InBack }
        PauseAnimation { duration: 600 }
        ScriptAction { script: mcFaceRoot.endStunt() }
    }

    // Little hop on the island (clicks and idle fidgeting).
    property real pokeY: 0
    function poke() {
        if (pokeAnim.running || travelling || jumping || away) return;
        pokeAnim.restart();
    }
    SequentialAnimation {
        id: pokeAnim
        NumberAnimation { target: mcFaceRoot; property: "pokeY"; to: -mcFaceRoot.px * 4; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: mcFaceRoot; property: "pokeY"; to: 0; duration: 190; easing.type: Easing.InQuad }
        ScriptAction { script: mcFaceRoot.landed(mcFaceRoot.steveIdx) }
    }
    Timer {
        interval: 9000
        repeat: true
        running: steve.visible && !mcFaceRoot.travelling
        onTriggered: {
            interval = 7000 + Math.random() * 9000;
            if (Math.random() < 0.6) mcFaceRoot.poke();
        }
    }

    Canvas {
        id: prop
        z: 4
        property string kind: "nether"
        readonly property int cols: kind === "end" ? 7 : (kind === "slime" ? 8 : 6)
        readonly property int rows: kind === "end" ? 3 : (kind === "slime" ? 8 : 10)
        visible: mcFaceRoot.propOpen > 0.01
        width: cols * mcFaceRoot.px
        height: rows * mcFaceRoot.px
        scale: mcFaceRoot.propOpen
        transformOrigin: Item.Bottom
        antialiasing: false
        property real swirl: 0
        NumberAnimation on swirl { from: 0; to: 1; duration: 900; loops: Animation.Infinite; running: prop.visible }
        onSwirlChanged: requestPaint()
        onKindChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = mcFaceRoot.px;
            for (let y = 0; y < rows; y++)
                for (let x = 0; x < cols; x++) {
                    let c;
                    if (kind === "end") {
                        if (x === 0 || x === cols - 1) c = (y === 1) ? "#2f8f6f" : "#dcd6a0";
                        else {
                            let n = (x * 31 + y * 17 + Math.floor(swirl * 6)) % 11;
                            c = n === 0 ? "#9a6aff" : (n === 3 ? "#3fd0a0" : (n === 6 ? "#ffffff" : "#05050c"));
                        }
                    } else if (kind === "slime") {
                        let edge = x === 0 || y === 0 || x === 7 || y === 7;
                        let core = x >= 2 && x <= 5 && y >= 2 && y <= 5;
                        c = edge ? "#5fbf4a" : (core ? "#4f9e3c" : "#7fdc6a");
                        if (y === 1 && (x === 1 || x === 2)) c = "#c8f8b8";
                    } else {
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
        id: pearl
        z: 6
        visible: false
        width: mcFaceRoot.px * 5
        height: width
        antialiasing: false
        Component.onCompleted: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = mcFaceRoot.px;
            let rows = [".tTt.", "tMMTt", "TMTTt", "tTTKt", ".ttt."];
            let pal = { "t": "#2c8a7a", "T": "#3fbfa8", "M": "#c8fff0", "K": "#145a50" };
            for (let y = 0; y < 5; y++)
                for (let x = 0; x < 5; x++) {
                    let ch = rows[y][x];
                    if (ch === ".") continue;
                    ctx.fillStyle = pal[ch];
                    ctx.fillRect(x * p, y * p, p, p);
                }
        }
    }

    TeleportBurst {
        id: barTp
        z: 6
        x: 0
        y: 0
        width: 1
        height: 1
        px: mcFaceRoot.px
    }

    SequentialAnimation {
        id: flyAnim
        ScriptAction { script: mcFaceRoot.startFlight() }
        ParallelAnimation {
            NumberAnimation { target: elytra; property: "flyX"; to: mcFaceRoot.flyTargetX; duration: 1000; easing.type: Easing.InOutSine }
            SequentialAnimation {
                NumberAnimation { target: elytra; property: "flyY"; to: mcFaceRoot.flyStartY - mcFaceRoot.px * 4; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { target: elytra; property: "flyY"; to: mcFaceRoot.flyStartY + mcFaceRoot.px * 2; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        NumberAnimation { target: elytra; property: "flyY"; to: mcFaceRoot.cellH * 2.5; duration: 260; easing.type: Easing.InQuad }
        ScriptAction { script: mcFaceRoot.endFlight() }
    }

    ElytraFlight {
        id: elytra
        z: 5
        x: 0
        y: 0
        width: 1
        height: 1
        px: mcFaceRoot.px
        active: true
    }

    SequentialAnimation {
        id: leaveAnim
        NumberAnimation { target: mcFaceRoot; property: "awayOffset"; to: -mcFaceRoot.hopHeight; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: mcFaceRoot; property: "awayOffset"; to: mcFaceRoot.cellH * 2; duration: 260; easing.type: Easing.InQuad }
        ScriptAction { script: mcFaceRoot.away = true }
    }

    SequentialAnimation {
        id: returnAnim
        ScriptAction { script: mcFaceRoot.endStunt() }
        ScriptAction { script: { mcFaceRoot.away = false; mcFaceRoot.awayOffset = -mcFaceRoot.cellH * 1.5; } }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: mcFaceRoot; property: "awayOffset"; to: 0; duration: 300; easing.type: Easing.InQuad }
        ScriptAction { script: mcFaceRoot.landed(mcFaceRoot.steveIdx) }
    }

    readonly property var palette: ({
        "E": "#6cbf3c", "e": "#3f7f26", "D": "#8a6142", "d": "#5e402a", "s": "#7d7d7d",
        "H": "#3b2a1a", "F": "#c69c7a", "b": "#6b4a30", "i": "#3a3fbf",
        "C": "#00a8a8", "c": "#008080", "P": "#46399a", "g": "#5a5a5a",
        "R": "#e23b3b", "Y": "#ffe25c", "L": "#4fa83a", "M": "#c23a2a", "W": "#f2f2f2"
    })

    readonly property var islandSprite: ["EEEEEEEE", "eDeDDeDe", ".DdDDdD.", "..dDsd..", "...ds..."]
    readonly property var steveStand: [".HHHH.", ".HFFH.", ".iFFi.", ".FbbF.", "CCCCCC", "FcCCcF", ".PPPP.", ".gggg."]
    readonly property var steveJump: ["FHHHHF", "CHFFHC", "CiFFiC", ".FbbF.", ".CCCC.", ".cCCc.", ".P..P.", "g....g"]
    // One-column flowers/mushrooms on occupied islands: [top, stem].
    readonly property var decorations: [["R", "L"], ["Y", "L"], ["M", "W"], ["L", "L"]]

    function paintSprite(ctx, sprite, ox, oy) {
        for (let y = 0; y < sprite.length; y++) {
            let row = sprite[y];
            for (let x = 0; x < row.length; x++) {
                let ch = row[x];
                if (ch === ".") continue;
                ctx.fillStyle = palette[ch];
                ctx.fillRect(ox + x * px, oy + y * px, px, px);
            }
        }
    }

    Grid {
        id: cellsGrid
        anchors.centerIn: parent
        rows: mcFaceRoot.vertical ? -1 : 1
        columns: mcFaceRoot.vertical ? 1 : -1
        spacing: mcFaceRoot.cellSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: cell
                required property int index

                width: mcFaceRoot.cellW
                height: mcFaceRoot.cellH

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool isHovered: cellMouse.containsMouse
                property bool initAnimTrigger: false

                Canvas {
                    id: islandCanvas
                    x: 0
                    // Two extra rows above the grass for the decoration.
                    y: parent.height - mcFaceRoot.islandH - mcFaceRoot.px * 2 + islandBob.y
                    width: mcFaceRoot.islandW
                    height: mcFaceRoot.islandH + mcFaceRoot.px * 2
                    antialiasing: false
                    opacity: (cell.isOccupied || cell.isActive) ? 1.0 : (cell.isHovered ? 0.7 : 0.4)
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Item {
                        id: islandBob
                        y: cell.isHovered && !cell.isActive ? -mcFaceRoot.px : 0
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    }

                    // Island dips when Steve lands on it.
                    transform: Translate { id: landDip; y: 0 }
                    SequentialAnimation {
                        id: dipAnim
                        NumberAnimation { target: landDip; property: "y"; to: mcFaceRoot.px; duration: 60; easing.type: Easing.OutQuad }
                        NumberAnimation { target: landDip; property: "y"; to: 0; duration: 180; easing.type: Easing.OutBack }
                    }
                    Connections {
                        target: mcFaceRoot
                        function onLanded(idx) { if (idx === cell.index) dipAnim.restart(); }
                    }

                    property bool occupied: cell.isOccupied
                    onOccupiedChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        let p = mcFaceRoot.px;
                        mcFaceRoot.paintSprite(ctx, mcFaceRoot.islandSprite, 0, p * 2);
                        if (occupied) {
                            let deco = mcFaceRoot.decorations[cell.index % mcFaceRoot.decorations.length];
                            let col = cell.index % 2 === 0 ? 7 : 0;
                            ctx.fillStyle = mcFaceRoot.palette[deco[0]];
                            ctx.fillRect(col * p, 0, p, p);
                            ctx.fillStyle = mcFaceRoot.palette[deco[1]];
                            ctx.fillRect(col * p, p, p, p);
                        }
                    }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    y: cell.initAnimTrigger ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on y { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
                }

                Component.onCompleted: {
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 50 + 100;
                        if (widget.moduleActive) animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Timer {
                    id: animTimer
                    running: false
                    repeat: false
                    onTriggered: cell.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widget) widget.focusWorkspace(cell.index);
                    }
                }
            }
        }
    }

    Canvas {
        id: steve
        z: 3
        width: mcFaceRoot.steveW
        height: mcFaceRoot.steveH
        antialiasing: false
        visible: widget && widget.workspaceCount > 0 && mcFaceRoot.activeIdx >= 0 && mcFaceRoot.steveIdx >= 0 && !mcFaceRoot.away

        readonly property real t: mcFaceRoot.hopT
        x: {
            let a = mcFaceRoot.cellX(mcFaceRoot.hopFrom), b = mcFaceRoot.cellX(mcFaceRoot.hopTo);
            return a + (b - a) * t + (mcFaceRoot.islandW - width) / 2 + mcFaceRoot.stuntX;
        }
        y: {
            let a = mcFaceRoot.cellY(mcFaceRoot.hopFrom), b = mcFaceRoot.cellY(mcFaceRoot.hopTo);
            let arc = mcFaceRoot.jumping ? mcFaceRoot.hopHeight * 4 * t * (1 - t) : 0;
            return a + (b - a) * t + mcFaceRoot.headroom - arc + mcFaceRoot.awayOffset + mcFaceRoot.stuntY + mcFaceRoot.pokeY;
        }
        opacity: mcFaceRoot.stuntFade

        property bool pose: mcFaceRoot.jumping || mcFaceRoot.travelling || pokeAnim.running

        // Click: hop (the island bounces); right-click: hearts. Clicks on the island itself
        // still switch workspaces since this only covers Steve.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    barTp.colors = ["#ff3040", "#ff8090", "#d01020"];
                    barTp.burst(steve.x + steve.width / 2, steve.y);
                } else {
                    mcFaceRoot.poke();
                }
            }
        }
        onPoseChanged: requestPaint()
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            mcFaceRoot.paintSprite(ctx, pose ? mcFaceRoot.steveJump : mcFaceRoot.steveStand, 0, 0);
        }
    }
}
