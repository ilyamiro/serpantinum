import QtQuick
import QtQuick.Shapes

WxHero {
    id: thermo

    readonly property int dir: g("dir", 1)
    readonly property color fluid: dir > 0 ? "#ff5a3c" : "#37b6ff"

    function chevron(i) {
        var y = 16 + i * 24;
        return dir > 0
            ? "M 18 " + (y + 22) + " L 50 " + y + " L 82 " + (y + 22)
            : "M 18 " + y + " L 50 " + (y + 22) + " L 82 " + y;
    }

    function ripple(i) {
        var step = dir > 0 ? 2 - i : i;
        var wave = Math.max(0, Math.cos((phase * 2 - step / 3) * Math.PI * 2));
        return Qt.rgba(1, 1, 1, 0.45 + 0.55 * wave);
    }

    Item {
        x: (parent.width - width) / 2
        width: parent.width * 0.36
        height: parent.height

        Rectangle {
            x: (parent.width - width) / 2
            y: parent.height * 0.02
            width: parent.width * 0.4
            height: parent.height * 0.78
            radius: width / 2
            color: "#f4f8fc"
            border.color: "#ffffff"
            border.width: Math.max(1, width * 0.1)
        }
        Rectangle {
            x: (parent.width - width) / 2
            y: parent.height * (thermo.dir > 0 ? 0.16 : 0.5)
            width: parent.width * 0.16
            height: parent.height * 0.7 - y + parent.height * 0.02
            radius: width / 2
            color: thermo.fluid
        }
        Rectangle {
            x: (parent.width - width) / 2
            y: parent.height * 0.64
            width: parent.width * 0.78
            height: width
            radius: width / 2
            color: thermo.fluid
            border.color: "#ffffff"
            border.width: Math.max(1, width * 0.1)
        }
    }

    Shape {
        x: parent.width * 0.7125
        y: parent.height * 0.3
        width: 100
        height: 100
        scale: parent.width * 0.325 / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: thermo.ripple(0)
            strokeWidth: 9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: thermo.chevron(0) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: thermo.ripple(1)
            strokeWidth: 9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: thermo.chevron(1) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: thermo.ripple(2)
            strokeWidth: 9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: thermo.chevron(2) }
        }
    }
}
