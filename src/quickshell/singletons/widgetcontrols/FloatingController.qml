pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: controller

    property var instances: []

    function registerInstance(panel) {
        if (!panel) return;
        let list = controller.instances.slice();
        if (list.indexOf(panel) === -1) {
            list.push(panel);
            controller.instances = list;
        }
    }

    function unregisterInstance(panel) {
        if (!panel) return;
        let list = controller.instances.filter(p => p && p !== panel);
        controller.instances = list;
    }

    function targetScreen(screen) {
        return Compositor.resolveTargetScreen(screen);
    }

    function instanceFor(screen) {
        let target = targetScreen(screen);
        if (!target) return null;
        for (let i = 0; i < controller.instances.length; i++) {
            let panel = controller.instances[i];
            if (panel && panel.matchesScreen(target)) return panel;
        }
        return null;
    }

    function setIndex(index, screen) {
        let panel = instanceFor(screen);
        if (panel) panel.setIndex(index);
    }

    function showTab(id, screen) {
        let panel = instanceFor(screen);
        if (panel) panel.showTab(id, 0);
    }

    function showSystemUsage(screen) {
        showTab("system", screen);
    }

    function showNotes(screen) {
        showTab("notes", screen);
    }

    function open(screen) {
        let panel = instanceFor(screen);
        if (panel) panel.openPanel();
    }

    function close(screen) {
        let closedAny = false;
        for (let i = 0; i < controller.instances.length; i++) {
            let panel = controller.instances[i];
            if (!panel) continue;
            if (!screen || panel.matchesScreen(screen)) {
                if (panel.closePanel()) closedAny = true;
            }
        }
        return closedAny;
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
            ShellRouter.reload();
        }
    }
}
