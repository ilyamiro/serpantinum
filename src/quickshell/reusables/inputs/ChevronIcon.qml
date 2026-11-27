import QtQuick
import "../../"

Item {
    id: root
    implicitWidth: 16
    implicitHeight: 16

    property color color: ThemeBackend.text
    property real armThickness: Math.max(1.5, (width / 0.38) * 0.048)
    property real armLength: Math.max(5, (width / 0.38) * 0.19)
    property real dotSize: armThickness
    property int colorDuration: 150

    Item {
        id: pivotNode
        x: (root.width - (root.armLength * 0.766)) / 2
        y: root.height / 2
        width: 0
        height: 0

        Rectangle {
            anchors.centerIn: parent
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: root.color
            antialiasing: true
            Behavior on color { ColorAnimation { duration: root.colorDuration } }
        }

        Rectangle {
            x: 0
            y: -root.armThickness / 2
            width: root.armLength
            height: root.armThickness
            radius: height / 2
            transformOrigin: Item.Left
            rotation: 40
            color: root.color
            antialiasing: true
            Behavior on color { ColorAnimation { duration: root.colorDuration } }
        }

        Rectangle {
            x: 0
            y: -root.armThickness / 2
            width: root.armLength
            height: root.armThickness
            radius: height / 2
            transformOrigin: Item.Left
            rotation: -40
            color: root.color
            antialiasing: true
            Behavior on color { ColorAnimation { duration: root.colorDuration } }
        }
    }
}
