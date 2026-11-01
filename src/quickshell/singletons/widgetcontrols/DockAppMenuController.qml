pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    signal menuTriggered()
    signal requestPin(string desktopId, string name, string icon)
    signal requestUnpin(string desktopId)

    property bool isVisible: false
    property var screen: null
    property real targetX: 0
    property real targetY: 0
    property string dockPosition: "bottom"
    property string desktopId: ""
    property string appName: ""
    property string appIcon: ""
    property bool isPinned: false
    property var windows: []
    property real buttonSize: 0

    function isSameApp(idA, idB) {
        if (!idA || !idB) return false;
        if (idA === idB) return true;
        if (typeof AppMatcher !== "undefined") {
            return AppMatcher.canonicalId(idA) === AppMatcher.canonicalId(idB);
        }
        let a = String(idA).toLowerCase().replace(/\.desktop$/, "");
        let b = String(idB).toLowerCase().replace(/\.desktop$/, "");
        return a === b;
    }

    function show(scr, posX, posY, dockPos, dId, name, icon, pinned, winList, btnSize) {
        if (typeof DockPreviewController !== "undefined") DockPreviewController.hide();   // one popup at a time
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.dockPosition = dockPos || "bottom";
        controller.desktopId = dId || "";
        controller.appName = name || "";
        controller.appIcon = icon || "";
        controller.isPinned = Boolean(pinned);
        controller.windows = winList || [];
        controller.buttonSize = btnSize || 0;
        controller.isVisible = true;
        controller.menuTriggered();
    }

    function hide() {
        controller.isVisible = false;
        controller.windows = [];
    }

    function toggle(scr, posX, posY, dockPos, dId, name, icon, pinned, winList, btnSize) {
        if (controller.isVisible && isSameApp(controller.desktopId, dId)) {
            controller.hide();
        } else {
            controller.show(scr, posX, posY, dockPos, dId, name, icon, pinned, winList, btnSize);
        }
    }

    function pinApp(dId, name, icon) {
        controller.requestPin(dId, name, icon);
        controller.hide();
    }

    function unpinApp(dId) {
        controller.requestUnpin(dId);
        controller.hide();
    }
}
