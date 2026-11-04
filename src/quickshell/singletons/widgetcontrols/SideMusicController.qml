pragma Singleton
import QtQuick
import "../../"

HoverMenuController {
    id: controller

    function itemEntered(scr, posX, posY, isRight, isBottom, isSide) {
        hoveredItems++;
        cancelHide();
        show(scr, posX, posY, isRight, isBottom, isSide);
    }

    function show(scr, posX, posY, isRight, isBottom, isSide) {
        place(scr, posX, posY, isRight, isBottom, isSide);
        controller.isVisible = true;
    }

    function hide() {
        resetHover();
        controller.isVisible = false;
    }

    function toggle(scr, posX, posY, isRight, isBottom, isSide) {
        if (controller.isVisible) {
            controller.hide();
        } else {
            controller.show(scr, posX, posY, isRight, isBottom, isSide);
        }
    }
}
