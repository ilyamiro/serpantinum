import QtQuick
import "../../../"

Item {
    id: el

    property string variant: "button"
    property var ctx: null

    implicitWidth: faceLoader.item ? faceLoader.item.implicitWidth : 0
    implicitHeight: faceLoader.item ? faceLoader.item.implicitHeight : 0

    QtObject {
        id: host

        property string kbStyle: el.variant
        property bool kbShowIcon: true
        property bool isCompact: false
        property bool lockLook: true
        property bool isPreview: false
        property bool moduleActive: true
        property string orientation: "horizontal"
        property real thickness: Math.round(Scaler.s(34))
        property var barWindow: null
    }

    Loader {
        id: faceLoader
        anchors.centerIn: parent
        source: Qt.resolvedUrl("../../../bar/faces/kb/KbFace.qml")
        onLoaded: item.module = host
    }
}
