import QtQuick
import QtQuick.Shapes

WxHero {
    id: wind
    aspect: 255 / 400

    readonly property var lines: [
        { path: "M 78 90 C 130 82 175 84 215 86 C 245 88 275 90 295 77 C 320 60 318 20 282 14 C 252 10 235 40 252 58 C 265 70 283 62 280 50", dash: [6, 30] },
        { path: "M 40 128 C 110 120 190 122 250 127 C 290 131 325 139 348 130 C 382 116 385 75 352 70 C 325 66 312 95 330 110 C 342 119 355 108 350 98", dash: [6, 35] },
        { path: "M 96 166 C 140 158 190 160 240 162 C 280 164 288 239 232 239 C 200 236 195 199 222 192 C 238 189 245 204 235 211", dash: [6, 27] },
        { path: "M 30 91 L 52 90", dash: [1.5, 9] },
        { path: "M 48 167 L 70 166", dash: [1.5, 9] }
    ]

    Repeater {
        model: wind.on ? wind.lines : []
        delegate: Shape {
            id: line
            required property var modelData
            width: 400
            height: 255
            scale: wind.width / 400
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: "#bfffffff"
                strokeWidth: 14
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: line.modelData.path }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#ffffff"
                strokeWidth: 14
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                strokeStyle: ShapePath.DashLine
                dashPattern: line.modelData.dash
                dashOffset: (1 - wind.phase) * (line.modelData.dash[0] + line.modelData.dash[1]) * 2
                PathSvg { path: line.modelData.path }
            }
        }
    }
}
