import QtQuick
import QtQuick.Shapes
import "../"

Item {
    id: root

    property real sunriseMin: 0
    property real sunsetMin: 0
    property real nowMin: 0
    property string sunriseText: ""
    property string sunsetText: ""
    property color trackColor: ThemeBackend.surface1
    property color progressColor: ThemeBackend.yellow
    property color labelColor: ThemeBackend.subtext0

    readonly property real labelH: Scaler.s(14)
    readonly property real arcW: width
    readonly property real arcH: Math.max(0, height - labelH - Scaler.s(4))
    readonly property real progress: sunsetMin > sunriseMin ? (nowMin - sunriseMin) / (sunsetMin - sunriseMin) : -1
    readonly property bool sunUp: progress >= 0 && progress <= 1
    readonly property real angle: Math.PI * (1 - Math.max(0, Math.min(1, progress)))
    readonly property real sunX: arcW / 2 + (arcW / 2) * Math.cos(angle)
    readonly property real sunY: arcH - arcH * Math.sin(angle)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: Math.max(1, Scaler.s(2))
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 4]
            PathSvg { path: "M 0 " + root.arcH + " A " + (root.arcW / 2) + " " + root.arcH + " 0 0 1 " + root.arcW + " " + root.arcH }
        }

        ShapePath {
            strokeColor: root.progressColor
            strokeWidth: Math.max(1, Scaler.s(2))
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: root.sunUp && root.progress > 0.001
                    ? "M 0 " + root.arcH + " A " + (root.arcW / 2) + " " + root.arcH + " 0 0 1 " + root.sunX + " " + root.sunY
                    : ""
            }
        }
    }

    Rectangle {
        visible: root.sunUp
        width: Scaler.s(9)
        height: width
        radius: width / 2
        x: root.sunX - width / 2
        y: root.sunY - height / 2
        color: root.progressColor
        border.width: Math.max(1, Scaler.s(2))
        border.color: ThemeBackend.base
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: root.sunriseText
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Scaler.s(10.5)
        color: root.labelColor
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: root.sunsetText
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Scaler.s(10.5)
        color: root.labelColor
    }
}
