import QtQuick

Item {
    id: haze
    property var cfg: null
    property real phase: 0
    visible: !!cfg
    readonly property bool dust: !!(cfg && cfg.dust)

    Repeater {
        model: haze.visible ? haze.cfg.n : 0
        delegate: Rectangle {
            required property int index
            readonly property real seedX: (index * 0.6180339) % 1
            readonly property real seedY: (index * 0.4142136) % 1
            readonly property real d: Math.min(haze.width, haze.height) * (0.04 + 0.05 * ((index * 5) % 4) / 3)
            width: d
            height: d
            radius: d / 2
            x: haze.width * seedX + Math.sin((haze.phase + seedX) * Math.PI * 2) * d
            y: ((seedY + haze.phase) % 1) * (haze.height + d) - d
            color: haze.dust ? (index % 2 === 0 ? "#d9a766" : "#a9743e") : (index % 3 === 0 ? "#8d8f94" : index % 3 === 1 ? "#b59a6c" : "#7a6a55")
            opacity: 0.35 + 0.4 * ((index * 3) % 5) / 4
        }
    }
}
