import QtQuick
import QtQuick.Shapes

WxHero {
    id: bolt
    opacity: 0.86 + 0.14 * Math.max(0, Math.sin(phase * Math.PI * 4))

    Shape {
        width: 100
        height: 100
        scale: bolt.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "#ffe14d"
            strokeColor: "#fff7c2"
            strokeWidth: 3
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M 62 0 L 24 54 L 46 54 L 34 100 L 78 40 L 54 40 L 72 0 Z" }
        }
    }
}
