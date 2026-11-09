import QtQuick

WxHero {
    id: sun

    readonly property string tone: g("tone", "day")
    readonly property int rayCount: g("rays", 8)
    readonly property color hiColor: tone === "hot" ? "#fff0a0" : tone === "uv" ? "#fff6c8" : tone === "dim" ? "#f4e6c0" : "#fff1a0"
    readonly property color loColor: tone === "hot" ? "#ff7a1f" : tone === "uv" ? "#ffb02e" : tone === "dim" ? "#e8c27a" : "#ffb938"
    readonly property color rayColor: tone === "hot" ? "#ffd24a" : tone === "dim" ? "#f2dca0" : "#ffe27a"

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * (sun.tone === "uv" ? 1.0 : 0.92)
        height: width
        radius: width / 2
        color: sun.tone === "dim" ? "#00000000" : Qt.rgba(1, 0.9, 0.5, 0.2 + 0.05 * Math.sin(sun.phase * Math.PI * 2))
    }

    Repeater {
        model: sun.on ? sun.rayCount : 0
        delegate: Item {
            required property int index
            anchors.centerIn: parent
            width: sun.width
            height: sun.width
            rotation: index * (360 / sun.rayCount) + sun.phase * (360 / sun.rayCount)
            opacity: sun.tone === "dim" ? 0.6 : 1.0

            Rectangle {
                x: (parent.width - width) / 2
                y: parent.height * 0.02
                width: Math.max(1.2, parent.width * (sun.rayCount > 8 ? 0.05 : 0.07))
                height: parent.height * (index % 2 === 0 ? 0.15 : 0.1)
                radius: width / 2
                color: sun.rayColor
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: width
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: sun.hiColor }
            GradientStop { position: 1.0; color: sun.loColor }
        }
    }
}
