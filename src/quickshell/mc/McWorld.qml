import QtQuick
import Quickshell.Services.UPower
import "."

// Live Minecraft wallpaper: real-time sky, drifting hills, flowers, wandering mobs
// (a creeper comes out at night) and Steve. `running: false` freezes it all.
Item {
    id: world
    property bool running: true
    // Plugged in: smooth 60 fps motion. On battery: coarse pixel steps (~4% CPU instead of ~15%).
    readonly property bool smoothMotion: !UPower.onBattery
    readonly property int px: Math.max(3, Math.round(height / 270))

    property date now: new Date()
    Timer { interval: 30000; running: world.running; repeat: true; triggeredOnStart: true; onTriggered: world.now = new Date() }
    property real hourOverride: -1      // for previews
    readonly property real hour: hourOverride >= 0 ? hourOverride : now.getHours() + now.getMinutes() / 60

    McSky {
        id: sky
        anchors.fill: parent
        px: world.px
        hour: world.hour
        active: world.running
        tickMs: world.smoothMotion ? 0 : 250
    }

    Terrain {
        id: terrain
        anchors.fill: parent
        px: world.px
        night: sky.night
        running: world.running
        tickMs: world.smoothMotion ? 0 : 250
    }

    // Flowers and grass tufts on top of the ground strip.
    Canvas {
        id: flora
        x: 0
        width: parent.width
        y: terrain.groundY - height
        height: world.px * 5
        antialiasing: false
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = world.px;
            let n = Math.floor(width / (p * 9));
            for (let i = 0; i < n; i++) {
                let h = (i * 2654435761) % 97;
                if (h % 3 === 0) continue;
                let x = i * p * 9 + (h % 5) * p;
                if (h % 7 === 0) {           // poppy
                    ctx.fillStyle = "#3f8f2a"; ctx.fillRect(x + p, 2 * p, p, 3 * p);
                    ctx.fillStyle = "#d82020"; ctx.fillRect(x, 0, 3 * p, 2 * p);
                    ctx.fillStyle = "#2a1010"; ctx.fillRect(x + p, p, p, p);
                } else if (h % 7 === 3) {    // dandelion
                    ctx.fillStyle = "#3f8f2a"; ctx.fillRect(x + p, 2 * p, p, 3 * p);
                    ctx.fillStyle = "#f0d020"; ctx.fillRect(x, p, 3 * p, 2 * p);
                } else {                      // grass tuft
                    ctx.fillStyle = "#5aa83a";
                    ctx.fillRect(x, 3 * p, p, 2 * p);
                    ctx.fillRect(x + p, 2 * p, p, 3 * p);
                    ctx.fillRect(x + 2 * p, 3 * p, p, 2 * p);
                }
            }
        }
        // darken with the landscape at night
        layer.enabled: false
    }
    Rectangle {
        anchors.fill: flora
        color: "#000814"
        opacity: sky.night * 0.55
    }

    // Day mobs fade out at night, the creeper fades in.
    Repeater {
        model: [
            { kind: "sheep", at: 0.15 }, { kind: "sheep", at: 0.22 }, { kind: "pig", at: 0.45 },
            { kind: "cow", at: 0.62 }, { kind: "chicken", at: 0.8 }, { kind: "chicken", at: 0.84 }
        ]
        delegate: McMob {
            required property var modelData
            kind: modelData.kind
            px: world.px
            minX: world.px * 8
            maxX: world.width - world.px * 8
            groundY: terrain.groundY
            glide: world.smoothMotion
            x: world.width * modelData.at
            running: world.running && sky.night < 0.9
            opacity: 1 - sky.night * 0.9
            visible: opacity > 0.05
        }
    }
    McMob {
        kind: "creeper"
        px: world.px
        minX: world.width * 0.3
        maxX: world.width * 0.9
        groundY: terrain.groundY
        glide: world.smoothMotion
        x: world.width * 0.7
        speed: world.px * 4
        running: world.running && sky.night > 0.5
        opacity: Math.max(0, (sky.night - 0.4) / 0.6)
        visible: opacity > 0.05
    }

    SteveVisitor {
        anchors.fill: parent
        z: 10
        active: true
        style: "nether"
        target: terrain.groundItem
        homeFrac: 0.35
        trackMs: 2000   // the ground never moves here
        walkStepMs: world.smoothMotion ? 0 : 150
        px: world.px
        sleeping: world.hour >= 23 || world.hour < 6
        phrases: ["Привіт!", "Хочу алмазів", "Де моя кирка?", "Покрафтимо?", "Кріпер позаду!", "Гарна погода", "Мммм..."]
    }
}
