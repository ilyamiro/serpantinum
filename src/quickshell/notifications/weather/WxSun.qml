import QtQuick
import QtQuick.Shapes

WxHero {
    id: sun

    readonly property string tone: g("tone", "day")
    readonly property color hiColor: tone === "hot" ? "#ffd23f" : tone === "uv" ? "#fcd34d" : tone === "dim" ? "#f4e6c0" : "#fbbf24"
    readonly property color loColor: tone === "hot" ? "#ffae1a" : tone === "uv" ? "#f59e0b" : tone === "dim" ? "#e8c27a" : "#f59e0b"
    readonly property color rayColor: tone === "hot" ? "#ffd23f" : tone === "uv" ? "#fcd34d" : tone === "dim" ? "#f2dca0" : "#fbbf24"

    Item {
        width: 384
        height: 384
        scale: sun.width / 384
        transformOrigin: Item.TopLeft

        Shape {
            anchors.fill: parent
            rotation: sun.phase * 45
            opacity: sun.tone === "dim" ? 0.6 : 1.0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: sun.rayColor
                strokeWidth: 24
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 192 61.7 V 12 M 192 372 V 322.3 M 284.2 99.8 L 319.2 64.8 M 64.8 319.2 L 99.9 284.1 M 99.9 99.7 L 64.9 64.7 M 319.4 319.2 L 284.3 284.1 M 61.7 192 H 12 M 372 192 H 322.3" }
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 150
                    y1: 119.2
                    x2: 234
                    y2: 264.8
                    GradientStop { position: 0.0; color: sun.hiColor }
                    GradientStop { position: 0.5; color: sun.hiColor }
                    GradientStop { position: 1.0; color: sun.loColor }
                }
                PathSvg { path: "M 105 192 a 87 87 0 1 0 174 0 a 87 87 0 1 0 -174 0 Z" }
            }
        }
    }
}
