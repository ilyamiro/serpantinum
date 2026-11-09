import QtQuick
import QtQuick.Shapes
import "WeatherKinds.js" as K

WxHero {
    id: shield

    property string severity: "moderate"
    readonly property color base: K.severityColor(severity)
    readonly property real pulse: (1 + Math.sin(phase * Math.PI * 4)) / 2
    readonly property real unit: width / 100
    readonly property real ringScale: 1.24
    readonly property string outline: "M 50 4 L 90 18 L 90 50 C 90 74 72 90 50 98 C 28 90 10 74 10 50 L 10 18 Z"

    Shape {
        visible: shield.severity === "extreme"
        width: 100
        height: 100
        scale: shield.unit
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(shield.base.r, shield.base.g, shield.base.b, 0.18 + 0.2 * shield.pulse)
            strokeWidth: 26 + 16 * shield.pulse
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: shield.outline }
        }
    }

    Shape {
        visible: shield.severity !== "moderate"
        x: shield.unit * 50 * (1 - shield.ringScale)
        y: shield.unit * 51 * (1 - shield.ringScale)
        width: 100
        height: 100
        scale: shield.unit * shield.ringScale
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(shield.base.r, shield.base.g, shield.base.b, 0.55)
            strokeWidth: 3.2
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: shield.outline }
        }
    }

    Shape {
        x: parent.width * 0.02
        y: parent.height * 0.04
        width: 100
        height: 100
        scale: shield.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#55000000"
            PathSvg { path: shield.outline }
        }
    }

    Shape {
        width: 100
        height: 100
        scale: shield.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#ffffff"
            strokeWidth: 5
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: 50; y1: 4; x2: 50; y2: 98
                GradientStop { position: 0.0; color: Qt.lighter(shield.base, 1.25) }
                GradientStop { position: 1.0; color: Qt.darker(shield.base, 1.1) }
            }
            PathSvg { path: shield.outline }
        }
    }

    Rectangle {
        x: (parent.width - width) / 2
        y: parent.height * 0.24
        width: Math.max(2, parent.width * 0.12)
        height: parent.height * 0.34
        radius: width / 2
        color: "#ffffff"
    }
    Rectangle {
        x: (parent.width - width) / 2
        y: parent.height * 0.65
        width: Math.max(2, parent.width * 0.13)
        height: width
        radius: width / 2
        color: "#ffffff"
    }
}
