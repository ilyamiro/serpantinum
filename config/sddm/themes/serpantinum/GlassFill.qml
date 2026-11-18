import QtQuick

Glass {
    id: fill

    required property var greeter
    property real press: 0
    property real pulse: 0
    property real shadow: 0
    readonly property bool active: greeter.effect === "glass"

    visible: active
    src: greeter.wallpaperSource
    sourceRect: greeter.glassRect(fill)
    energy: Math.min(1, press * 0.45 + pulse)
    shadowAmt: shadow
}
