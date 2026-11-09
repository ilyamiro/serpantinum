import QtQuick
import "WeatherKinds.js" as K

Item {
    id: illu

    property string kind: ""
    property bool animate: true
    property real radius: 0
    property bool alignRight: false
    property bool backdrop: true

    readonly property var spec: K.resolve(kind)
    readonly property var colors: K.skyColors(spec.sky, spec.sev)
    property real phase: 0
    readonly property bool running: animate && visible && width > 0 && Window.window !== null && Window.window.visible

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 6000
        loops: Animation.Infinite
        running: illu.running
    }

    Item {
        id: art
        anchors.fill: parent
        clip: true

        Rectangle {
            visible: illu.backdrop
            anchors.fill: parent
            radius: illu.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: illu.colors[0] }
                GradientStop { position: 1.0; color: illu.colors[1] }
            }
        }

        Rectangle {
            visible: illu.backdrop
            anchors.fill: parent
            radius: illu.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2effffff" }
                GradientStop { position: 0.5; color: "#00ffffff" }
                GradientStop { position: 1.0; color: "#14000000" }
            }
        }

        Rectangle {
            visible: illu.backdrop && illu.spec.ground === "ice"
            anchors.fill: parent
            radius: illu.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 0.81; color: "#00ffffff" }
                GradientStop { position: 0.82; color: "#8cffffff" }
                GradientStop { position: 1.0; color: "#8cffffff" }
            }
        }

        WxParticles { anchors.fill: parent; cfg: illu.spec.particles || null; phase: illu.phase }

        Item {
            id: stage
            height: art.height
            width: height
            x: (illu.alignRight ? art.width - width : (art.width - width) / 2) + illu.spec.off[0] * width
            y: illu.spec.off[1] * height

            WxWaves { cfg: illu.spec.waves || null; phase: illu.phase; cornerRadius: illu.radius }

            Item {
                id: scene
                anchors.fill: parent
                scale: illu.spec.gov ? 0.8 : 1.0
                transformOrigin: Item.TopLeft

                WxSun { cfg: illu.spec.sun || null; phase: illu.phase }
                WxCrystal { cfg: illu.spec.crystal || null; phase: illu.phase }
                WxCrystal { cfg: illu.spec.crystals ? illu.spec.crystals[0] : null; phase: illu.phase }
                WxCrystal { cfg: illu.spec.crystals ? illu.spec.crystals[1] : null; phase: illu.phase }
                WxPrecip { cfg: illu.spec.rain || null; anchor: illu.spec.cloud || null; phase: illu.phase }
                WxPrecip { cfg: illu.spec.snow || null; anchor: illu.spec.cloud || null; phase: illu.phase; snow: true }
                WxBolt { cfg: illu.spec.bolt || null; phase: illu.phase }
                WxCloud { cfg: illu.spec.cloud || null; phase: illu.phase }
                WxFog { anchors.fill: parent; on: illu.spec.fog === true; phase: illu.phase }
                WxWind { cfg: illu.spec.wind || null; phase: illu.phase }
                WxThermo { cfg: illu.spec.thermo || null; phase: illu.phase }
                WxFlame { cfg: illu.spec.flame || null; phase: illu.phase }
            }
        }

        Item {
            height: art.height
            width: height
            x: illu.alignRight ? art.width - width : (art.width - width) / 2

            WxShield { cfg: illu.spec.shield || null; phase: illu.phase; severity: illu.spec.sev }
        }
    }
}
