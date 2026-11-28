import QtQuick
import "../../"

Loader {
    id: gridLoader

    property bool gridActive: false
    property real stepSize: Scaler.s(20)
    property real lineWidth: 1.0
    property color lineColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.1)

    active: gridLoader.gridActive

    sourceComponent: ShaderEffect {
        anchors.fill: parent
        property vector2d itemSize: Qt.vector2d(width, height)
        property real stepSize: gridLoader.stepSize
        property real lineWidth: gridLoader.lineWidth
        property color lineColor: gridLoader.lineColor

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/grid_pattern.frag.qsb"
    }
}
