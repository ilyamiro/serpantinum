pragma Singleton
import QtQuick
import "../../"

HoverMenuController {
    id: controller

    property string activeItemId: ""

    function itemEntered(itemId, scr, posX, posY, isRight, isBottom, isSide) {
        hoveredItems++;
        cancelHide();
        show(itemId, scr, posX, posY, isRight, isBottom, isSide);
    }

    function show(itemId, scr, posX, posY, isRight, isBottom, isSide) {
        place(scr, posX, posY, isRight, isBottom, isSide);
        controller.activeItemId = itemId;
        controller.isVisible = true;
    }

    function hide() {
        resetHover();
        controller.activeItemId = "";
        controller.isVisible = false;
    }

    function toggle(itemId, scr, posX, posY, isRight, isBottom, isSide) {
        if (controller.isVisible && controller.activeItemId === itemId) {
            controller.hide();
        } else {
            controller.show(itemId, scr, posX, posY, isRight, isBottom, isSide);
        }
    }
}
