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

    function crest(b, amp, cycles, drift, p) {
        var d = "";
        for (var i = 0; i <= 40; i++) {
            var x = i * 2.5;
            var t = x / 100;
            var y = b + amp * Math.sin((t * cycles + p * drift) * Math.PI * 2)
                + amp * 0.3 * Math.sin((t * cycles * 2 - p * drift) * Math.PI * 2);
            d += (i === 0 ? "M " : " L ") + x + " " + y;
        }
        return d;
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
            fillColor: "#2b78c4"
            PathSvg { path: waves.crest(waves.b1, 5, 1.1, 1, waves.phase) + waves.closing }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#4aa0ea"
            PathSvg { path: waves.crest(waves.b2, 4, 0.9, -1, waves.phase) + waves.closing }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#73ffffff"
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: waves.crest(waves.b2, 4, 0.9, -1, waves.phase) }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#9fd8ff"
            PathSvg { path: waves.crest(waves.b3, 3.5, 1.3, 1, waves.phase) + waves.closing }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#a6ffffff"
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: waves.crest(waves.b3, 3.5, 1.3, 1, waves.phase) }
        }
    }
}
