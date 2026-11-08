import QtQuick
import "../../"
import "../../../"

Rectangle {
    id: root

    default property alias cardContent: cardHolder.data
    property real padX: 0
    property real padY: 0

    implicitWidth: cardHolder.childrenRect.width + padX * 2
    implicitHeight: cardHolder.childrenRect.height + padY * 2
    radius: ThemeBackend.borderRadius
    color: cardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)

    GlassFill {
        id: cardGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: ThemeBackend.surface0
        tintAmount: 0.3
    }

    Item {
        id: cardHolder
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
