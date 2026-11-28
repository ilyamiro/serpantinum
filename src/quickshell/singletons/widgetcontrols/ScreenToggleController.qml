import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property var screen: null

    function getFocusedScreen() {
        return Compositor.focusedScreen();
    }

    function getScreen(scr) {
        return Compositor.resolveTargetScreen(scr);
    }

    function show(scr) {
        let target = getScreen(scr);
        if (target !== null && target !== undefined) {
            controller.screen = target;
        } else {
            let focused = getFocusedScreen();
            if (focused !== null && focused !== undefined) {
                controller.screen = focused;
            }
        }
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
    }

    function toggle(scr) {
        let target = getScreen(scr);
        let resolved = target !== null && target !== undefined ? target : getFocusedScreen();

        if (controller.isVisible) {
            if (resolved !== undefined && resolved !== null && controller.screen !== resolved) {
                controller.screen = resolved;
            } else {
                hide();
            }
        } else {
            show(resolved);
        }
    }
}
