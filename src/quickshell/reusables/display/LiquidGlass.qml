import QtQuick
import "../../"

ShaderEffect {
    id: root

    property variant src
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0
    property color tintColor: ThemeBackend.base
    property real tintAmount: 0
    property real bezel: Math.max(5, Math.min(26, Math.min(width, height) * 0.36))
    property real thickness: bezel * 1.15
    property real ior: 1.5
    property real dispersion: 0.11
    property real frost: 1.5
    property real rim: 0.45
    property real saturation: 1.25
    property rect sourceRect: Qt.rect(0, 0, 1, 1)
    property point cursorPos: Qt.point(0, 0)
    property real hover: 0
    property real clear: 0
    property real glassPad: 0
    property real shadowAmt: 0
    property real energy: 0
    property real nest: 0
    property real morph: 0
    property real motion: 0
    property rect validRect: Qt.rect(0, 0, 1, 1)
    property real unpremul: 0
    property Item field: null
    property vector4d fieldInfo: field ? Qt.vector4d(1, field.smoothing, field.origin.x, field.origin.y) : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs0: field ? field.s0 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs1: field ? field.s1 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs2: field ? field.s2 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs3: field ? field.s3 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs4: field ? field.s4 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fs5: field ? field.s5 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr0: field ? field.r0 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr1: field ? field.r1 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr2: field ? field.r2 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr3: field ? field.r3 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr4: field ? field.r4 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fr5: field ? field.r5 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fk0: field ? field.k0 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fk1: field ? field.k1 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fo0: field ? field.o0 : Qt.vector4d(0, 0, 0, 0)
    property vector4d fo1: field ? field.o1 : Qt.vector4d(0, 0, 0, 0)

    property vector2d itemSize: Qt.vector2d(width, height)
    property vector4d radii: Qt.vector4d(topLeftRadius, topRightRadius, bottomRightRadius, bottomLeftRadius)
    property vector4d srcRect: Qt.vector4d(sourceRect.x, sourceRect.y, sourceRect.width, sourceRect.height)
    property vector2d cursor: Qt.vector2d(cursorPos.x, cursorPos.y)
    property vector4d sampleBounds: Qt.vector4d(validRect.x, validRect.y, validRect.x + validRect.width, validRect.y + validRect.height)

    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/liquid_glass.frag.qsb"
}
