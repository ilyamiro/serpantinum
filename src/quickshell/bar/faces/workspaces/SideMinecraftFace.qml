import QtQuick

Item {
    id: sideMinecraftFaceRoot
    property var widget: null

    implicitWidth: faceLoader.item ? faceLoader.item.implicitWidth : 0
    implicitHeight: faceLoader.item ? faceLoader.item.implicitHeight : 0

    Loader {
        id: faceLoader
        anchors.centerIn: parent
        source: Qt.resolvedUrl("MinecraftFace.qml")
        onLoaded: {
            item.vertical = true;
            item.widget = Qt.binding(function() { return sideMinecraftFaceRoot.widget; });
        }
    }
}
