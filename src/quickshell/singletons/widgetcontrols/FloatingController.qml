pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: controller

    signal setIndexRequested(var screen, string index)
    signal showSystemUsageRequested(var screen)
    signal showNotesRequested(var screen)
    signal openRequested(var screen)
    signal closeRequested(var screen)

    property bool closedAny: false

    function targetScreen(screen) {
        if (screen) return screen;
        if (Quickshell.cursorScreen) return Quickshell.cursorScreen;
        return Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function setIndex(index, screen) {
        let target = targetScreen(screen);
        if (target) controller.setIndexRequested(target, index);
    }

    function showSystemUsage(screen) {
        let target = targetScreen(screen);
        if (target) controller.showSystemUsageRequested(target);
    }

    function showNotes(screen) {
        let target = targetScreen(screen);
        if (target) controller.showNotesRequested(target);
    }

    function open(screen) {
        let target = targetScreen(screen);
        if (target) controller.openRequested(target);
    }

    function close(screen) {
        controller.closedAny = false;
        controller.closeRequested(screen || null);
        return controller.closedAny;
    }

    function toggle(screen) {
        if (!controller.close(null)) controller.open(screen);
    }

    IpcHandler {
        target: "floating"

        function setIndex(index: string) {
            controller.setIndex(index, null);
        }

        function showSystemUsage() {
            controller.showSystemUsage(null);
        }

        function showNotes() {
            controller.showNotes(null);
        }

        function open() {
            controller.open(null);
        }

        function close() {
            controller.close(null);
        }

        function toggle() {
            controller.toggle(null);
        }

        function forceReload() {
            Quickshell.reload(true)
        }
    }
}
