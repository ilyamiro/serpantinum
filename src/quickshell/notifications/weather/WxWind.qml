import QtQuick
import QtQuick.Shapes

WxHero {
    id: wind

    Shape {
        width: 100
        height: 100
        scale: wind.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        transform: Translate { x: Math.sin(wind.phase * Math.PI * 2) * 4 }

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#ffffff"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 6 30 L 60 30 C 82 30 82 6 66 6 C 58 6 54 12 54 16" }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#e6f3ff"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 2 52 L 82 52 C 100 52 100 78 84 78 C 76 78 72 72 72 68" }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#d3e8fa"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 14 74 L 46 74 C 62 74 62 94 50 94 C 44 94 40 90 40 86" }
        }
    }
}
