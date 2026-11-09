import QtQuick

Item {
    id: fog
    property bool on: false
    property real phase: 0
    visible: on

    readonly property real unit: width / 100
    readonly property var bars: [
        { row: 0, x0: 8, x1: 92, dark: false },
        { row: 1, x0: 8, x1: 50, dark: false },
        { row: 1, x0: 58, x1: 94, dark: true },
        { row: 2, x0: 12, x1: 40, dark: true },
        { row: 2, x0: 46, x1: 90, dark: true },
        { row: 3, x0: 24, x1: 84, dark: true },
        { row: 4, x0: 38, x1: 68, dark: true }
    ]

    Repeater {
        model: fog.on ? fog.bars : []
        delegate: Rectangle {
            required property var modelData
            x: (modelData.x0 + Math.sin(fog.phase * Math.PI * 2 + modelData.row * 1.1) * 2.5) * fog.unit
            y: (57 + modelData.row * 7.2) * fog.unit
            width: (modelData.x1 - modelData.x0) * fog.unit
            height: 4.4 * fog.unit
            radius: height / 2
            color: modelData.dark ? "#cdd6df" : "#f6f9fc"
        }
    }
}
