import QtQuick
import QtQuick.Shapes

WxHero {
    id: thermo

    readonly property int dir: g("dir", 1)
    readonly property color fluid: dir > 0 ? "#ff5a3c" : "#37b6ff"

    Item {
        x: 0
        width: parent.width * 0.42
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
        x: parent.width * 0.5
        y: parent.height * 0.14
        width: 100
        height: 100
        scale: parent.width * 0.5 / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: thermo.fluid
            strokeColor: "#ffffff"
            strokeWidth: 5
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: thermo.dir > 0 ? "M 50 4 L 94 52 L 66 52 L 66 96 L 34 96 L 34 52 L 6 52 Z" : "M 50 96 L 94 48 L 66 48 L 66 4 L 34 4 L 34 48 L 6 48 Z" }
        }
    }
}
