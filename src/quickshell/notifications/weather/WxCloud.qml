import QtQuick

WxHero {
    id: cloud
    aspect: 0.62

    readonly property string tone: g("tone", "light")
    readonly property color tint: tone === "dark" ? "#59627a" : tone === "mid" ? "#c9d2de" : "#f6f9fc"
    readonly property color shade: Qt.darker(tint, 1.14)

    transform: Translate { y: Math.sin(cloud.phase * Math.PI * 2) * cloud.height * 0.03 }

    Rectangle { x: parent.width * 0.02; y: parent.height * 0.4; width: parent.width * 0.44; height: width; radius: width / 2; color: cloud.tint }
    Rectangle { x: parent.width * 0.54; y: parent.height * 0.28; width: parent.width * 0.44; height: width; radius: width / 2; color: cloud.tint }
    Rectangle { x: parent.width * 0.21; y: 0; width: parent.width * 0.58; height: width; radius: width / 2; color: cloud.tint }
    Rectangle {
        x: parent.width * 0.06
        y: parent.height * 0.52
        width: parent.width * 0.92
        height: parent.height * 0.48
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: cloud.tint }
            GradientStop { position: 1.0; color: cloud.shade }
        }
    }
}
