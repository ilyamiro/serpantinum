import QtQuick

// Minecraft GUI box: 1px black outline, then a bevel (light top-left, dark
// bottom-right for raised; swapped for an inset slot), then the fill.
Item {
    id: panel
    property bool inset: false
    property int bevel: 2
    property bool outline: true
    property color fill: inset ? "#262626" : "#3a3a3a"
    property color light: inset ? "#141414" : "#6a6a6a"
    property color dark: inset ? "#5a5a5a" : "#161616"

    readonly property int o: outline ? 1 : 0

    Rectangle { anchors.fill: parent; color: "#000000"; visible: panel.outline }
    Rectangle {
        x: panel.o; y: panel.o
        width: parent.width - panel.o * 2
        height: parent.height - panel.o * 2
        color: panel.dark
    }
    Rectangle {
        x: panel.o; y: panel.o
        width: parent.width - panel.o * 2 - panel.bevel
        height: parent.height - panel.o * 2 - panel.bevel
        color: panel.light
    }
    Rectangle {
        x: panel.o + panel.bevel; y: panel.o + panel.bevel
        width: parent.width - (panel.o + panel.bevel) * 2
        height: parent.height - (panel.o + panel.bevel) * 2
        color: panel.fill
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
