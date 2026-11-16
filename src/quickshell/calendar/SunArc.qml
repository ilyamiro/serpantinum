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
    readonly property real inset: Math.max(3, Scaler.s(5)) / 2 + 1
    readonly property real arcW: width - 2 * inset
    readonly property real arcH: Math.max(0, height - labelH - Scaler.s(4))
    readonly property real progress: sunsetMin > sunriseMin ? (nowMin - sunriseMin) / (sunsetMin - sunriseMin) : -1
    readonly property bool sunUp: progress >= 0 && progress <= 1
    property bool revealed: true
    property real shownProgress: Math.max(0, Math.min(1, progress)) - (revealed ? 0 : Math.min(1 / 3, Math.max(0, Math.min(1, progress))))
    Behavior on shownProgress { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    readonly property real angle: Math.PI * (1 - shownProgress)
    readonly property real sunX: inset + arcW / 2 + (arcW / 2) * Math.cos(angle)
    readonly property real arcRy: Math.max(0, arcH - inset)
    readonly property real sunY: arcH - arcRy * Math.sin(angle)

    readonly property real gap: 0.11
    readonly property real strokeW: Math.max(3, Scaler.s(5))

    function px(a) { return inset + arcW / 2 + (arcW / 2) * Math.cos(a); }
    function py(a) { return arcH - arcRy * Math.sin(a); }

    readonly property real activeEnd: sunUp ? angle : (progress > 1 ? 0 : Math.PI)
    readonly property real trackStart: sunUp ? angle - gap : Math.PI
    readonly property string arcRadii: (arcW / 2) + " " + arcRy

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.arcH
                GradientStop { position: 0.0; color: Qt.alpha(root.progressColor, 0.12) }
                GradientStop { position: 1.0; color: Qt.alpha(root.progressColor, 0.0) }
            }
            PathSvg {
                path: root.sunUp && root.shownProgress > 0.001
                    ? "M " + root.inset + " " + root.arcH + " A " + root.arcRadii + " 0 0 1 " + root.sunX + " " + root.sunY + " L " + root.sunX + " " + root.arcH + " Z"
                    : ""
            }
        }

        ShapePath {
            strokeColor: Qt.alpha(root.progressColor, 0.28)
            strokeWidth: root.strokeW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: root.trackStart > 0.02
                    ? "M " + root.px(root.trackStart) + " " + root.py(root.trackStart) + " A " + root.arcRadii + " 0 0 1 " + (root.inset + root.arcW) + " " + root.arcH
                    : ""
            }
        }

        ShapePath {
            strokeColor: root.progressColor
            strokeWidth: root.strokeW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: root.activeEnd < Math.PI - 0.02
                    ? "M " + root.inset + " " + root.arcH + " A " + root.arcRadii + " 0 0 1 " + root.px(root.activeEnd) + " " + root.py(root.activeEnd)
                    : ""
            }
        }
    }

    Rectangle {
        visible: root.sunUp
        width: Scaler.s(14)
        height: width
        radius: width / 2
        x: root.sunX - width / 2
        y: root.sunY - height / 2
        color: root.progressColor
    }

    Text {
        x: root.inset - width / 2
        anchors.bottom: parent.bottom
        text: root.sunriseText
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Scaler.s(10.5)
        color: root.labelColor
    }

    Text {
        x: root.inset + root.arcW - width / 2
        anchors.bottom: parent.bottom
        text: root.sunsetText
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Scaler.s(10.5)
        color: root.labelColor
    }
}
