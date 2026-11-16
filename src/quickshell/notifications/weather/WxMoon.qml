import QtQuick
import QtQuick.Shapes

WxHero {
    id: moon

    transform: Translate { y: Math.sin(moon.phase * Math.PI * 2) * moon.height * 0.02 }

    Item {
        width: 384
        height: 384
        scale: moon.width / 384
        transformOrigin: Item.TopLeft

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 90
                    y1: 80
                    x2: 280
                    y2: 300
                    GradientStop { position: 0.0; color: "#f8efd0" }
                    GradientStop { position: 1.0; color: "#e2cd8c" }
                }
                PathSvg { path: "M 187.3 72.1 A 120 120 0 1 0 304.5 233.9 A 100 100 0 0 1 187.3 72.1 Z" }
            }
        }
    }
}
