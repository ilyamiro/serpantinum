pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Hover preview for dock apps: a strip with one card per window of the hovered app, each showing the
// window's latest snapshot. Separate from DockAppMenuController (the right-click menu).
Item {
    id: controller

    property bool isVisible: false
    property var screen: null
    property real targetX: 0
    property real targetY: 0
    property string dockPosition: "bottom"
    property string desktopId: ""
    property string appName: ""
    property string appIcon: ""
    property string groupKey: ""
    property var windows: []
    property real buttonSize: 0
    // bumped on every show so snapshots rewritten since the last hover are re-read
    property int revision: 0

    // keyboard navigation (DockNavController) drives the preview instead of the pointer
    property bool navMode: false
    property int selectedIndex: -1

    property var _pending: null
    property string _pendingId: ""

    // Called while the pointer is on a dock button: shows the preview after a short delay.
    // The dock's magnification shifts icons under a stationary pointer, so a button can see rapid
    // leave/enter pairs. Leaving therefore only starts a short hide timer (see scheduleHide) and entering
    // cancels it; the show delay is not restarted for an app that is already pending.
    function request(scr, posX, posY, dockPos, dId, name, icon, key, winList, btnSize) {
        if (controller.navMode) return;   // the keyboard owns the preview
        if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible) return;   // never over the right-click menu
        hideTimer.stop();
        if (!winList || winList.length === 0) { controller.scheduleHide(); return; }
        controller._pending = { scr: scr, x: posX, y: posY, pos: dockPos, id: dId, name: name, icon: icon, key: key, wins: winList, btn: btnSize };
        if (controller.isVisible) {
            controller.show();   // a preview is already open: switch to this app at once, no delay
        } else if (!showTimer.running || controller._pendingId !== dId) {
            controller._pendingId = dId;
            showTimer.restart();
        }
    }

    function show() {
        let p = controller._pending;
        if (!p) return;
        controller.screen = p.scr;
        controller.targetX = p.x;
        controller.targetY = p.y;
        controller.dockPosition = p.pos || "bottom";
        controller.desktopId = p.id || "";
        controller.appName = p.name || "";
        controller.appIcon = p.icon || "";
        controller.groupKey = p.key || "";
        controller.windows = p.wins || [];
        controller.buttonSize = p.btn || 0;
        controller.revision++;
        controller.isVisible = true;
    }

    function scheduleHide() {
        if (controller.navMode) return;
        hideTimer.restart();
    }

    // Keyboard mode: show the preview for the selected app at once and mark one window as selected.
    function showNav(scr, posX, posY, dockPos, dId, name, icon, key, winList, btnSize, selected) {
        controller.navMode = true;
        controller.selectedIndex = selected;
        controller._pending = { scr: scr, x: posX, y: posY, pos: dockPos, id: dId, name: name, icon: icon, key: key, wins: winList, btn: btnSize };
        controller.show();
    }

    // Keyboard mode stays on while the selected app simply has no windows to preview.
    function navEmpty() {
        controller.navMode = true;
        controller.selectedIndex = -1;
        controller.hide();
    }

    function navHide() {
        controller.navMode = false;
        controller.selectedIndex = -1;
        controller.hide();
    }

    function cancelHide() { hideTimer.stop(); }

    function hide() {
        showTimer.stop();
        hideTimer.stop();
        controller._pending = null;
        controller._pendingId = "";
        controller.isVisible = false;
        controller.windows = [];
    }

    Timer { id: showTimer; interval: 350; repeat: false; onTriggered: controller.show() }
    Timer { id: hideTimer; interval: 260; repeat: false; onTriggered: controller.hide() }

    // Keep the cards in step with the live window list (a window closed or restored from the preview, etc.).
    Connections {
        target: (typeof WindowTracker !== "undefined") ? WindowTracker : null
        function onUpdated() {
            if (controller.navMode || !controller.isVisible || controller.groupKey === "") return;
            let g = WindowTracker.groups ? WindowTracker.groups[controller.groupKey] : null;
            let list = (g && g.windows) ? g.windows : [];
            if (list.length === 0) controller.hide();
            else controller.windows = list;
        }
    }

    // Scripting/testing hook:  quickshell ipc call dockpreview showapp <appId>
    IpcHandler {
        target: "dockpreview"

        function showapp(appId: string): void {
            let groups = (typeof WindowTracker !== "undefined" && WindowTracker.groups) ? WindowTracker.groups : {};
            for (let k in groups) {
                let g = groups[k];
                if (!g || !g.windows || g.windows.length === 0) continue;
                if (String(g.appId).toLowerCase() !== appId.toLowerCase() && k !== appId) continue;
                // show it on the screen the app's first window is on, with the dock's own icon/name for it
                let outName = g.windows[0].output || "";
                let scr = null;
                for (let i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === outName) scr = Quickshell.screens[i];
                if (!scr && Quickshell.screens.length > 0) scr = Quickshell.screens[0];
                let apps = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.apps) ? Config.rawSettings.dock.apps : [];
                let icon = "", name = g.appId;
                for (let i = 0; i < apps.length; i++) {
                    let did = String(apps[i].desktop_id || "").replace(/\.desktop$/, "");
                    if (did.toLowerCase() === String(g.appId).toLowerCase() || did === appId) { icon = apps[i].icon || ""; name = apps[i].name || name; break; }
                }
                let w = scr ? scr.width : 1920, h = scr ? scr.height : 1080;
                controller._pending = { scr: scr, x: w / 2, y: h - 40, pos: "bottom", id: g.desktopId, name: name, icon: icon, key: k, wins: g.windows, btn: 48 };
                controller.show();
                return;
            }
        }

        function hide(): void { controller.hide(); }

        // quickshell ipc call dockpreview list <appId>   -> JSON of that app's window instances
        function list(appId: string): string {
            let ws = (typeof WindowTracker !== "undefined" && WindowTracker.windows) ? WindowTracker.windows : [];
            let out = [];
            for (let i = 0; i < ws.length; i++) {
                let w = ws[i];
                if (String(w.appId).toLowerCase() !== appId.toLowerCase()) continue;
                out.push({ address: "0x" + w.nativeId, hasWayland: Boolean(w.native && w.native.wayland), title: w.title, minimized: Boolean(w.minimized), workspace: w.workspaceLabel, focused: Boolean(w.focused) });
            }
            return JSON.stringify(out);
        }

        // quickshell ipc call dockpreview activate <address>   -> what a click on that window's card/dock icon does
        function activate(address: string): void {
            let ws = (typeof WindowTracker !== "undefined" && WindowTracker.windows) ? WindowTracker.windows : [];
            let want = address.replace(/^0x/, "");
            for (let i = 0; i < ws.length; i++) {
                if (String(ws[i].nativeId).replace(/^0x/, "") === want) { WindowTracker.focusWindow(ws[i]); return; }
            }
        }
    }
}
