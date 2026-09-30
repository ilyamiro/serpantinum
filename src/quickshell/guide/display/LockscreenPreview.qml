import QtQuick

Item {
    id: root

    property string style: "default"
    property bool thumbnail: false

    readonly property string assetName: {
        switch (root.style) {
        case "compact": return "bloom"
        case "focus": return "orbit"
        case "tessera": return "tessera"
        default: return "veil"
        }
    }

    clip: true

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../../assets/lockscreen/" + root.assetName + ".jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.thumbnail ? 0 : 1
        border.color: Qt.alpha(ThemeBackend.surface2, 0.7)
    }
}
