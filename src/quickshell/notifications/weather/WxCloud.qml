import QtQuick
import QtQuick.Shapes

WxHero {
    id: cloud
    aspect: 222 / 350

    readonly property string tone: g("tone", "light")
    readonly property color tint: tone === "dark" ? "#59627a" : tone === "mid" ? "#c9d2de" : "#f6f9fc"
    readonly property color shade: Qt.darker(tint, 1.14)

    transform: Translate { y: Math.sin(cloud.phase * Math.PI * 2) * cloud.height * 0.03 }

    Shape {
        width: 350
        height: 222
        scale: cloud.width / 350
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 110
                x2: 0
                y2: 222
                GradientStop { position: 0.0; color: cloud.tint }
                GradientStop { position: 1.0; color: cloud.shade }
            }
            PathSvg { path: "M 291 107 l -2.5 0.1 A 83.9 83.9 0 0 0 135.6 43 A 56 56 0 0 0 51 91 a 56.6 56.6 0 0 0 0.8 9 A 60 60 0 0 0 63 219 l 4 -0.2 v 0.2 h 224 a 56 56 0 0 0 0 -112 Z" }
        }
    }
}
