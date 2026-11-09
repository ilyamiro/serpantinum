import QtQuick
import QtQuick.Shapes
import "WeatherKinds.js" as K

WxHero {
    id: shield

    property string severity: "moderate"
    readonly property color base: K.severityColor(severity)
    readonly property real pulse: (1 + Math.sin(phase * Math.PI * 4)) / 2

    Rectangle {
        visible: shield.severity === "extreme"
        anchors.centerIn: parent
        width: parent.width * (1.15 + 0.12 * shield.pulse)
        height: width
        radius: width / 2
        color: Qt.rgba(shield.base.r, shield.base.g, shield.base.b, 0.18 + 0.2 * shield.pulse)
    }

    Rectangle {
        visible: shield.severity !== "moderate"
        anchors.centerIn: parent
        width: parent.width * 1.05
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Qt.rgba(shield.base.r, shield.base.g, shield.base.b, 0.55)
        border.width: Math.max(1, parent.width * 0.04)
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
            PathSvg { path: "M 50 4 L 90 18 L 90 50 C 90 74 72 90 50 98 C 28 90 10 74 10 50 L 10 18 Z" }
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
            PathSvg { path: "M 50 4 L 90 18 L 90 50 C 90 74 72 90 50 98 C 28 90 10 74 10 50 L 10 18 Z" }
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
