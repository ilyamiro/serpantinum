import QtQuick

// Minecraft-style text: pixel font with a hard drop shadow at a quarter brightness.
Text {
    id: mcText
    font.family: "Monocraft"
    color: "#ffffff"
    property color shadowColor: Qt.rgba(color.r / 4, color.g / 4, color.b / 4, color.a)
    property real shadowOffset: Math.max(1, Math.round(font.pixelSize / 10))

    Text {
        z: -1
        x: mcText.shadowOffset
        y: mcText.shadowOffset
        width: mcText.width
        height: mcText.height
        text: mcText.text
        font: mcText.font
        color: mcText.shadowColor
        horizontalAlignment: mcText.horizontalAlignment
        verticalAlignment: mcText.verticalAlignment
        elide: mcText.elide
        wrapMode: mcText.wrapMode
        fontSizeMode: mcText.fontSizeMode
        minimumPixelSize: mcText.minimumPixelSize
    }
}
