import QtQuick
import "../../"

ShaderEffect {
    id: root

    property real radius: 0.0
    property real fillLevel: 0.0
    property real waveAmp: 0.0
    property vector2d itemSize: Qt.vector2d(width, height)
    property real phase: 0.0
    property real vertical: 1.0
    property color color1: ThemeBackend.primary
    property color color2: color1
    property vector4d params: Qt.vector4d(1.0, 0.0, 0.0, 0.0)

    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/fluid/fluid_wave.frag.qsb"
}
