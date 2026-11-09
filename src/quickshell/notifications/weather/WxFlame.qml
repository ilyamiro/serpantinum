import QtQuick
import QtQuick.Shapes

WxHero {
    id: flame
    transform: Scale {
        origin.x: flame.width / 2
        origin.y: flame.height
        yScale: 1 + 0.05 * Math.sin(flame.phase * Math.PI * 4)
        xScale: 1 - 0.02 * Math.sin(flame.phase * Math.PI * 4)
    }

    Shape {
        width: 100
        height: 100
        scale: flame.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 50; y1: 0; x2: 50; y2: 100
                GradientStop { position: 0.0; color: "#ffb02e" }
                GradientStop { position: 1.0; color: "#ff4a1c" }
            }
            PathSvg { path: "M 50 2 C 56 24 82 34 82 62 C 82 84 68 98 50 98 C 32 98 18 84 18 62 C 18 48 28 40 34 28 C 38 40 42 42 46 42 C 46 28 44 14 50 2 Z" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 50; y1: 46; x2: 50; y2: 96
                GradientStop { position: 0.0; color: "#fff3a0" }
                GradientStop { position: 1.0; color: "#ffc23a" }
            }
            PathSvg { path: "M 50 46 C 54 60 68 66 68 78 C 68 88 60 95 50 95 C 40 95 32 88 32 78 C 32 66 44 60 50 46 Z" }
        }
    }
}
