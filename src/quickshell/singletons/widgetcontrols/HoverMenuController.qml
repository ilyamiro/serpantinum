import QtQuick

Item {
    id: controller

    property bool isVisible: false
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false
    property bool isSideBar: false
    property var screen: null
    property bool menuHovered: false
    property int hoveredItems: 0
    readonly property bool itemHovered: hoveredItems > 0

    Timer {
        id: hideTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!controller.menuHovered && controller.hoveredItems <= 0) {
                controller.isVisible = false;
            }
        }
    }

    function place(scr, posX, posY, isRight, isBottom, isSide) {
        hideTimer.stop();
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.alignRight = isRight;
        controller.alignBottom = isBottom;
        controller.isSideBar = isSide;
    }

    function resetHover() {
        hideTimer.stop();
        hoveredItems = 0;
    }

    function itemExited() {
        hoveredItems = Math.max(0, hoveredItems - 1);
        if (hoveredItems <= 0 && !menuHovered) {
            requestHide();
        }
    }

    function requestHide() {
        if (!controller.menuHovered && controller.hoveredItems <= 0) {
            hideTimer.restart();
        }
    }

    function cancelHide() {
        hideTimer.stop();
    }
}
