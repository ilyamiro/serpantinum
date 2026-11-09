import QtQuick
import QtQuick.Effects
import "WeatherKinds.js" as K

Item {
    id: bg

    property string kind: ""
    property real radius: 8
    property bool mirror: false
    property color surface: "#45475a"
    property real textureOpacity: 0.16

    readonly property real sl: surface.hslLightness
    readonly property bool onDark: sl < 0.5

    function tone(src, d) {
        var c = Qt.color(src);
        return Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, Math.max(0, Math.min(1, sl + d)), 1);
    }

    readonly property var pal: K.card(kind)
    readonly property real k: pal.strength
    readonly property color cLeft: tone(pal.left, 0)
    readonly property color cRight: tone(pal.right, 0)
    readonly property color cGlow: tone(pal.glow, 0)
    readonly property color cDark: tone(pal.dark, onDark ? -0.06 : 0)
    readonly property string mood: pal.mood
    readonly property color moodColor: mood === "moody" ? cDark : cGlow
    readonly property real moodTop: mood === "cool" ? k * 0.45 : mood === "moody" ? k * 0.7 : 0
    readonly property real moodBottom: mood === "glow" || mood === "alert" ? k * 0.5 : 0

    Rectangle {
        anchors.fill: parent
        radius: bg.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(bg.mirror ? bg.cRight : bg.cLeft, bg.mirror ? bg.k * 0.7 : bg.k) }
            GradientStop { position: 1.0; color: Qt.alpha(bg.mirror ? bg.cLeft : bg.cRight, bg.mirror ? bg.k : bg.k * 0.7) }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: bg.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(bg.moodColor, bg.moodTop) }
            GradientStop { position: 0.55; color: Qt.alpha(bg.moodColor, 0) }
            GradientStop { position: 1.0; color: Qt.alpha(bg.moodColor, bg.moodBottom) }
        }
    }

    Item {
        id: texture
        readonly property real side: Math.max(bg.height * 1.7, 90)
        width: side
        height: side
        anchors.verticalCenter: parent.verticalCenter
        x: bg.mirror ? bg.width * 0.18 - side / 2 : bg.width * 0.82 - side / 2
        opacity: bg.textureOpacity
        visible: bg.width > 0 && bg.height > 0

        layer.enabled: visible
        layer.smooth: true
        layer.textureSize: Qt.size(64, 64)
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 20
            brightness: bg.onDark ? -0.25 : 0.25
            colorization: 0.7
            colorizationColor: bg.cGlow
        }

        WeatherIllustration {
            anchors.fill: parent
            anchors.margins: texture.side * 0.14
            kind: bg.kind
            animate: false
            backdrop: false
        }
    }
}
