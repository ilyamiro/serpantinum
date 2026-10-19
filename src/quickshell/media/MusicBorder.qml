import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import "../"

Item {
    id: borderLayer
    required property var root
    property alias maskRectOuter: maskRectOuter
    property alias chargeAnim: chargeAnim

    anchors.fill: parent
    visible: !ThemeBackend.liquidGlass

    Shape {
        id: maskRectOuter
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.GeometryRenderer

        property real sw: root.s(6)
        property real inset: (sw / 2) + root.s(0.5)
        property real w: width
        property real h: height
        property real r: ThemeBackend.borderRadius - inset
        
        property real straightLines: 2 * (w - 2 * inset - 2 * r) + 2 * (h - 2 * inset - 2 * r)
        property real arcLines: 2 * Math.PI * r
        property real perimeter: straightLines + arcLines

        property real drawProgress: 0

        NumberAnimation on drawProgress {
            id: chargeAnim
            from: 0
            to: maskRectOuter.perimeter
            duration: 1200
            easing.type: Easing.OutCubic
            running: false
        }

        ShapePath {
            strokeWidth: maskRectOuter.sw
            strokeColor: "black"
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            dashPattern: [maskRectOuter.perimeter / maskRectOuter.sw, maskRectOuter.perimeter / maskRectOuter.sw]
            dashOffset: (maskRectOuter.perimeter - maskRectOuter.drawProgress) / maskRectOuter.sw

            startX: maskRectOuter.inset
            startY: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r

            PathLine { x: maskRectOuter.inset; y: maskRectOuter.inset + maskRectOuter.r }
            PathArc { 
                x: maskRectOuter.inset + maskRectOuter.r; y: maskRectOuter.inset 
                radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
            }
            PathLine { x: maskRectOuter.w - maskRectOuter.inset - maskRectOuter.r; y: maskRectOuter.inset }
            PathArc { 
                x: maskRectOuter.w - maskRectOuter.inset; y: maskRectOuter.inset + maskRectOuter.r 
                radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
            }
            PathLine { x: maskRectOuter.w - maskRectOuter.inset; y: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r }
            PathArc { 
                x: maskRectOuter.w - maskRectOuter.inset - maskRectOuter.r; y: maskRectOuter.h - maskRectOuter.inset 
                radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
            }
            PathLine { x: maskRectOuter.inset + maskRectOuter.r; y: maskRectOuter.h - maskRectOuter.inset }
            PathArc { 
                x: maskRectOuter.inset; y: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r 
                radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
            }
        }
    }

    Item {
        id: gradContainer
        anchors.fill: parent
        visible: false
        opacity: ThemeBackend.elementOpacity
        clip: true

        Rectangle {
            width: Math.max(parent.width, parent.height) * 2
            height: width
            anchors.centerIn: parent
            
            NumberAnimation on rotation {
                from: 0; to: 360; duration: 5000
                loops: Animation.Infinite
                running: root.active
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.bc1; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                GradientStop { position: 0.33; color: root.bc2; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                GradientStop { position: 0.66; color: root.bc3; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                GradientStop { position: 1.0; color: root.bc4; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
            }
        }
    }

    MultiEffect {
        source: gradContainer
        anchors.fill: parent
        maskEnabled: true
        maskSource: maskRectOuter
    }
}
