import QtQuick
import QtQuick.Shapes

WxHero {
    id: bolt
    aspect: 186.8 / 102.7
    opacity: 0.86 + 0.14 * Math.max(0, Math.sin(phase * Math.PI * 4))

    Shape {
        width: 102.7
        height: 186.8
        scale: bolt.width / 102.7
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 8.7
                y1: 17.1
                x2: 80.9
                y2: 142.1
                GradientStop { position: 0.0; color: "#f7b23b" }
                GradientStop { position: 0.5; color: "#f7b23b" }
                GradientStop { position: 1.0; color: "#f59e0b" }
            }
            PathSvg { path: "M 34.8 2 L 2.8 98 h 32 l -16 80 l 80 -112 h -48 l 32 -64 h -48 Z" }
        }
    }
}
