import QtQuick
import QtQuick.Shapes

WxHero {
    id: waves

    property real cornerRadius: 0

    readonly property real unit: width / 100
    readonly property real bandTop: cy * 100
    readonly property real span: 100 - bandTop
    readonly property real r: Math.min(50, cornerRadius / Math.max(0.001, unit))
    readonly property real b1: bandTop + 7
    readonly property real b2: bandTop + 7 + (span - 7) * 0.38
    readonly property real b3: bandTop + 7 + (span - 7) * 0.72

    function crest(b, up) {
        var a = up ? -7 : 7;
        return "M 0 " + b + " C 16 " + (b + a) + " 34 " + (b + a) + " 50 " + b + " S 84 " + (b - a) + " 100 " + b;
    }

    readonly property string closing: " L 100 " + (100 - r) + " A " + r + " " + r + " 0 0 1 " + (100 - r) + " 100 L " + r + " 100 A " + r + " " + r + " 0 0 1 0 " + (100 - r) + " Z"

    y: 0
    height: parent ? parent.height : 0

    Shape {
        width: 100
        height: 100
        scale: waves.unit
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: "#bf2f8fdc"
            PathSvg { path: waves.crest(waves.b1, true) + waves.closing }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#58b4f2"
            PathSvg { path: waves.crest(waves.b2, false) + waves.closing }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#a8dcff"
            PathSvg { path: waves.crest(waves.b3, true) + waves.closing }
        }
    }
}
