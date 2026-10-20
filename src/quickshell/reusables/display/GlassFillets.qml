import QtQuick
import "../../"
import "../"

WallpaperBlur {
    id: root

    required property Rectangle card
    readonly property real margin: Math.ceil(filletRadius) + 64
    readonly property real leftMargin: margin
    readonly property real rightMargin: margin
    readonly property real topMargin: margin
    readonly property real bottomMargin: margin

    property bool armed: filletRadius > 0.5
    onFilletRadiusChanged: if (filletRadius > 0.5) armed = true

    standalone: true
    earsOnly: true
    surfaceEnabled: armed
    maskItem: earMask

    x: card.x - leftMargin
    y: card.y - topMargin
    width: card.width + leftMargin + rightMargin
    height: card.height + topMargin + bottomMargin

    topLeftRadius: card.topLeftRadius
    topRightRadius: card.topRightRadius
    bottomLeftRadius: card.bottomLeftRadius
    bottomRightRadius: card.bottomRightRadius
    boxRect: Qt.rect(leftMargin, topMargin, card.width, card.height)
    bezelSize: Math.max(5, Math.min(26, Math.min(card.width, card.height) * 0.36))

    function earX(i) {
        if (filletDir.y !== 0) return i === 0 ? leftMargin - filletRadius : leftMargin + card.width;
        return filletDir.x < 0 ? leftMargin + filletInset : leftMargin + card.width - filletInset - filletRadius;
    }

    function earY(i) {
        if (filletDir.x !== 0) return i === 0 ? topMargin - filletRadius : topMargin + card.height;
        return filletDir.y < 0 ? topMargin + filletInset : topMargin + card.height - filletInset - filletRadius;
    }

    function earIndex(i) {
        if (filletDir.y < 0) return i === 0 ? 1 : 0;
        if (filletDir.y > 0) return i === 0 ? 3 : 2;
        if (filletDir.x < 0) return i === 0 ? 2 : 0;
        return i === 0 ? 3 : 1;
    }

    Item {
        id: earMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.active

        Repeater {
            model: root.active ? 2 : 0

            ShaderEffect {
                required property int index
                visible: root.filletRadius > 0.5
                x: root.earX(index)
                y: root.earY(index)
                width: root.filletRadius
                height: root.filletRadius
                property vector2d itemSize: Qt.vector2d(width, height)
                property real cornerIndex: root.earIndex(index)
                property color color: "black"
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
            }
        }
    }
}
