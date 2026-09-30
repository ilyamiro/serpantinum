import QtQuick
import QtQuick.Shapes
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 170
    property real minHeight: 170
    property real maxWidth: 800
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 1.0

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ThemeBackend.surface0
        border.width: Math.max(1, width * 0.012)
        border.color: ThemeBackend.surface1
    }

    Repeater {
        model: 12
        delegate: Rectangle {
            required property int index
            width: Math.max(2, root.width * 0.018)
            height: index % 3 === 0 ? root.height * 0.075 : root.height * 0.04
            radius: width / 2
            color: index % 3 === 0 ? ThemeBackend.text : ThemeBackend.overlay0
            anchors.centerIn: parent
            transform: Rotation {
                angle: index * 30
                origin.x: 0
                origin.y: root.height * -0.395
            }
        }
    }

    Rectangle {
        width: parent.width * 0.035
        height: parent.height * 0.29
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        transformOrigin: Item.Bottom
        rotation: (parseInt(DateTime.hour) % 12) * 30 + parseInt(DateTime.minute) * 0.5
        color: ThemeBackend.text
        radius: width / 2
    }

    Rectangle {
        width: parent.width * 0.022
        height: parent.height * 0.39
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        transformOrigin: Item.Bottom
        rotation: parseInt(DateTime.minute) * 6 + parseInt(DateTime.second) * 0.1
        color: ThemeBackend.mauve
        radius: width / 2
    }

    Rectangle {
        width: parent.width * 0.055
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: ThemeBackend.mauve
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.27
        spacing: 2

        Text {
            width: root.width * 0.65
            text: DateTime.timeShort
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(12, root.width * 0.09)
            font.weight: Font.Black
            color: ThemeBackend.text
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: root.width * 0.65
            text: DateTime.dateBadge
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(8, root.width * 0.045)
            font.letterSpacing: 1
            color: ThemeBackend.mauve
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
