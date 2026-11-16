import QtQuick
import QtQuick.Shapes
import "BatteryKinds.js" as K

Item {
    id: illu

    property string kind: ""
    property bool animate: true
    property real radius: 0
    property bool backdrop: true

    readonly property var spec: K.resolve(kind)
    property real phase: 0
    readonly property bool running: animate && spec.pulse && visible && width > 0 && Window.window !== null && Window.window.visible
    readonly property real pulse: (1 + Math.sin(phase * Math.PI * 2)) / 2

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 1600
        loops: Animation.Infinite
        running: illu.running
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            visible: illu.backdrop
            anchors.fill: parent
            radius: illu.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: illu.spec.a }
                GradientStop { position: 1.0; color: illu.spec.b }
            }
        }

        Rectangle {
            visible: illu.backdrop
            anchors.fill: parent
            radius: illu.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2effffff" }
                GradientStop { position: 0.5; color: "#00ffffff" }
                GradientStop { position: 1.0; color: "#14000000" }
            }
        }

        Item {
            id: cell
            width: parent.width * 0.5
            height: parent.height * 0.74
            anchors.centerIn: parent
            opacity: illu.spec.pulse ? 0.8 + 0.2 * illu.pulse : 1

            Rectangle {
                x: (parent.width - width) / 2
                width: parent.width * 0.4
                height: parent.height * 0.1
                radius: height / 2
                color: "#ffffff"
            }

            Rectangle {
                id: shell
                y: parent.height * 0.08
                width: parent.width
                height: parent.height * 0.92
                radius: width * 0.22
                color: "#33000000"
                border.color: "#ffffff"
                border.width: Math.max(2, width * 0.09)

                Rectangle {
                    readonly property real inset: shell.border.width + Math.max(1, shell.width * 0.04)
                    readonly property real full: shell.height - 2 * inset
                    x: inset
                    width: shell.width - 2 * inset
                    height: Math.max(width * 0.3, full * illu.spec.level)
                    y: shell.height - inset - height
                    radius: Math.max(1, shell.radius - inset * 0.6)
                    color: illu.spec.fluid
                }

                Shape {
                    visible: illu.spec.bolt
                    anchors.centerIn: parent
                    width: 102.7
                    height: 186.8
                    scale: shell.width * 0.3 / 102.7
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        strokeColor: "transparent"
                        fillColor: "#ffffff"
                        PathSvg { path: "M 34.8 2 L 2.8 98 h 32 l -16 80 l 80 -112 h -48 l 32 -64 h -48 Z" }
                    }
                }
            }
        }
    }
}
