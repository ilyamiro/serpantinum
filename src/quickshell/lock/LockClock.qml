import QtQuick
import "../"
import "redactor"

Item {
    id: clockModule
    required property var screenRoot

    property var currentTime: new Date()
    readonly property bool concealed: screenRoot.inputActive || screenRoot.centerReveal > 0.02
    readonly property real fit: Math.min(width / LockLayoutStore.refW, height / LockLayoutStore.refH)

    anchors.fill: parent
    opacity: clockModule.concealed ? 0.0 : 1.0
    scale: clockModule.concealed ? 0.92 : 1.0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
        width: LockLayoutStore.refW
        height: LockLayoutStore.refH
        anchors.centerIn: parent
        scale: clockModule.fit

        LockLayoutView {
            anchors.fill: parent
            scope: "screen"
            ctx: clockModule.screenRoot
        }
    }
}
