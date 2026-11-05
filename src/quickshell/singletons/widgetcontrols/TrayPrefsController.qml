pragma Singleton
import QtQuick

Item {
    id: controller

    signal menuTriggered()

    property bool isVisible: false
    property var screen: null
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false

    function show(scr, posX, posY, alignR, alignB) {
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.alignRight = Boolean(alignR);
        controller.alignBottom = Boolean(alignB);
        controller.isVisible = true;
        controller.menuTriggered();
    }

    function hide() {
        controller.isVisible = false;
    }

    function toggle(scr, posX, posY, alignR, alignB) {
        if (controller.isVisible) {
            controller.hide();
        } else {
            controller.show(scr, posX, posY, alignR, alignB);
        }
    }
}
