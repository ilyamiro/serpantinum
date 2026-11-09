import QtQuick

Item {
    id: fog
    property bool on: false
    property real phase: 0
    visible: on

    Repeater {
        model: fog.on ? 4 : 0
        delegate: Rectangle {
            required property int index
            width: fog.width * 0.8
            height: fog.height * 0.09
            radius: height / 2
            x: fog.width * (index % 2 === 0 ? 0.05 : 0.15) + Math.sin(fog.phase * Math.PI * 2 + index * 1.7) * fog.width * 0.05
            y: fog.height * (0.52 + index * 0.115)
            color: "#ffffff"
            opacity: 0.55 - index * 0.06
        }
    }
}
