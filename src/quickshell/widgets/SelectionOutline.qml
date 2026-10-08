import QtQuick
import "../"

// Wavy outline around a selected widget, drawn by assets/shaders/widget_outline.frag.
// The owner sets running while the outline is shown, the wave only moves then.
ShaderEffect {
    id: root

    property bool running: false
    property real phase: 0.0

    NumberAnimation on phase {
        running: root.running
        from: 0.0
        to: Math.PI * 2
        duration: 3200
        loops: Animation.Infinite
    }

    readonly property real inset: 2.5
    readonly property real baseRadius: (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null) ? ThemeBackend.borderRadius : 12
    readonly property real perimeter: 2 * (width + height - 4 * inset - 4 * radius) + 2 * Math.PI * radius

    property color color: (typeof ThemeBackend !== "undefined") ? (ThemeBackend.primary || ThemeBackend.blue || "#89b4fa") : "#89b4fa"
    property size itemSize: Qt.size(width, height)
    property real radius: Math.max(2, Math.min(baseRadius + 4, (width - 2 * inset) / 2, (height - 2 * inset) / 2))
    property real lineWidth: 2
    property real amplitude: 0.9
    property real frequency: perimeter > 0 ? (2 * Math.PI * Math.max(4, Math.round(perimeter / 28))) / perimeter : 0

    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/widget_outline.frag.qsb"
}
