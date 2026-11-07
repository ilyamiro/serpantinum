pragma Singleton
import QtQuick
import "../../"

HoverMenuController {
    id: controller

    property string activeItemId: ""
    property real barSpanStart: 0
    property real barSpanEnd: 0

    function itemEntered(itemId, scr, posX, posY, isRight, isBottom, isSide, spanStart, spanEnd) {
        hoveredItems++;
        cancelHide();
        show(itemId, scr, posX, posY, isRight, isBottom, isSide, spanStart, spanEnd);
    }

    function show(itemId, scr, posX, posY, isRight, isBottom, isSide, spanStart, spanEnd) {
        controller.barSpanStart = spanStart !== undefined ? spanStart : 0;
        controller.barSpanEnd = spanEnd !== undefined ? spanEnd : 0;
        place(scr, posX, posY, isRight, isBottom, isSide);
        controller.activeItemId = itemId;
        controller.isVisible = true;
    }

    function hide() {
        resetHover();
        controller.activeItemId = "";
        controller.isVisible = false;
    }

    function toggle(itemId, scr, posX, posY, isRight, isBottom, isSide, spanStart, spanEnd) {
        if (controller.isVisible && controller.activeItemId === itemId) {
            controller.hide();
        } else {
            controller.show(itemId, scr, posX, posY, isRight, isBottom, isSide, spanStart, spanEnd);
        }
    }
}
