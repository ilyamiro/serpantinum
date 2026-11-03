pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../"

// Keyboard control of the dock (toggled with e.g. `serpantinum msg toggle dock`).
//   Left / Right        previous / next app
//   Up / Down / Tab     previous / next window of the selected app
//   Enter               focus (or restore) the selected window; launch the app if it has none
//   Backspace / Delete  close the selected window
//   Esc                 leave dock mode
// While active, DockNavKeys (a transparent layer surface) owns the keyboard; it lets the mouse through.
Item {
    id: nav

    property bool active: false
    property var screen: null
    property var dock: null            // the DockWindow of `screen`
    property var items: []             // [{desktopId, name, icon, kind, slot, itemIndex}]
    property int itemIndex: -1         // dock item index of the selected app (matches the buttons' itemIndex)
    property int selected: 0           // position in `items`
    property int winSelected: 0        // window of the selected app
    property var windows: []           // windows of the selected app, in the order the preview shows them

    property var _docks: ({})

    function registerDock(d) {
        if (!d || !d.screen) return;
        nav._docks[d.screen.name] = d;
    }

    function unregisterDock(d) {
        if (!d || !d.screen) return;
        if (nav._docks[d.screen.name] === d) delete nav._docks[d.screen.name];
        if (nav.dock === d) nav.exit();
    }

    function _focusedScreenName() {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) return Hyprland.focusedMonitor.name;
        } catch (e) {}
        return "";
    }

    function toggle() { if (nav.active) nav.exit(); else nav.enter(); }

    function enter() {
        let name = nav._focusedScreenName();
        let d = nav._docks[name];
        if (!d) {
            let keys = Object.keys(nav._docks);
            if (keys.length === 0) return;
            d = nav._docks[keys[0]];
        }
        let list = d.navItems();
        if (list.length === 0) return;
        nav.dock = d;
        nav.screen = d.screen;
        nav.items = list;
        // start on the app that is focused right now, else the first one
        let start = 0;
        for (let i = 0; i < list.length; i++) {
            let info = d.getRunningInfoForApp(list[i].desktopId);
            if (info && info.isFocused) { start = i; break; }
        }
        nav.selected = start;
        nav.winSelected = 0;
        nav.active = true;
        nav._apply();
        idle.restart();
        settle.restart();   // the dock may still be sliding in; place the preview again once it has settled
    }

    function exit() {
        idle.stop();
        nav.active = false;
        if (typeof DockPreviewController !== "undefined") DockPreviewController.navHide();
        nav.dock = null;
        nav.itemIndex = -1;
        nav.windows = [];
    }

    // Re-read the dock (apps can be launched/closed while we are active) and show the preview for the selection.
    function _apply() {
        if (!nav.dock) return;
        nav.items = nav.dock.navItems();
        if (nav.items.length === 0) { nav.exit(); return; }
        nav.selected = Math.max(0, Math.min(nav.items.length - 1, nav.selected));
        let it = nav.items[nav.selected];
        nav.itemIndex = it.itemIndex;
        let info = nav.dock.getRunningInfoForApp(it.desktopId);
        nav.windows = (info && info.hasWindows) ? [].concat(info.here || [], info.elsewhere || []) : [];
        nav.winSelected = nav.windows.length === 0 ? 0 : Math.max(0, Math.min(nav.windows.length - 1, nav.winSelected));
        nav.dock.navPreview(it, nav.winSelected);
    }

    function moveApp(delta) {
        if (!nav.active || nav.items.length === 0) return;
        nav.selected = (nav.selected + delta + nav.items.length) % nav.items.length;
        nav.winSelected = 0;
        nav._apply();
        idle.restart();
    }

    function moveWindow(delta) {
        if (!nav.active || nav.windows.length === 0) return;
        nav.winSelected = (nav.winSelected + delta + nav.windows.length) % nav.windows.length;
        nav._apply();
        idle.restart();
    }

    function activateSelected() {
        if (!nav.active) return;
        let it = nav.items[nav.selected];
        let d = nav.dock;
        let win = nav.windows.length > 0 ? nav.windows[nav.winSelected] : null;
        nav.exit();
        if (win) {
            if (typeof WindowTracker !== "undefined") WindowTracker.focusWindow(win);
        } else if (it && d) {
            d.activateOrLaunch(it.desktopId, 0);
        }
    }

    function closeSelectedWindow() {
        if (!nav.active || nav.windows.length === 0) return;
        let win = nav.windows[nav.winSelected];
        if (typeof WindowTracker !== "undefined") WindowTracker.close(win);
        idle.restart();
        // the tracker updates shortly; refresh the view then
        refresh.restart();
    }

    function handleKey(key, modifiers) {
        switch (key) {
        case Qt.Key_Left:  nav.moveApp(-1); return true;
        case Qt.Key_Right: nav.moveApp(1); return true;
        case Qt.Key_Up:
        case Qt.Key_Backtab: nav.moveWindow(-1); return true;
        case Qt.Key_Down:  nav.moveWindow(1); return true;
        case Qt.Key_Tab:   nav.moveWindow((modifiers & Qt.ShiftModifier) ? -1 : 1); return true;
        case Qt.Key_Return:
        case Qt.Key_Enter: nav.activateSelected(); return true;
        case Qt.Key_Backspace:
        case Qt.Key_Delete: nav.closeSelectedWindow(); return true;
        case Qt.Key_Escape: nav.exit(); return true;
        case Qt.Key_Home:  nav.selected = 0; nav.winSelected = 0; nav._apply(); idle.restart(); return true;
        case Qt.Key_End:   nav.selected = nav.items.length - 1; nav.winSelected = 0; nav._apply(); idle.restart(); return true;
        }
        return false;
    }

    Connections {
        target: (typeof WindowTracker !== "undefined") ? WindowTracker : null
        function onUpdated() { if (nav.active) refresh.restart(); }
    }

    // Scripting/testing hook:  quickshell ipc call docknav key left|right|up|down|tab|enter|backspace|escape|home|end
    //                          quickshell ipc call docknav state
    IpcHandler {
        target: "docknav"

        function key(name: string): string {
            let map = { left: Qt.Key_Left, right: Qt.Key_Right, up: Qt.Key_Up, down: Qt.Key_Down, tab: Qt.Key_Tab, enter: Qt.Key_Return,
                        backspace: Qt.Key_Backspace, delete: Qt.Key_Delete, escape: Qt.Key_Escape, home: Qt.Key_Home, end: Qt.Key_End };
            if (map[name] === undefined) return "unknown key";
            return nav.handleKey(map[name], 0) ? "ok" : "unhandled";
        }

        function state(): string {
            let it = (nav.items.length > 0 && nav.selected < nav.items.length) ? nav.items[nav.selected] : null;
            return JSON.stringify({ active: nav.active, screen: nav.screen ? nav.screen.name : null, selected: nav.selected, count: nav.items.length,
                app: it ? it.desktopId : null, itemIndex: nav.itemIndex, winSelected: nav.winSelected,
                windows: nav.windows.map(function(w) { return w.title; }), previewVisible: DockPreviewController.isVisible, navMode: DockPreviewController.navMode });
        }
    }

    // Never keep the keyboard grabbed if the user walks away.
    Timer { id: idle; interval: 12000; repeat: false; onTriggered: nav.exit() }
    Timer { id: settle; interval: 330; repeat: false; onTriggered: if (nav.active) nav._apply() }
    Timer { id: refresh; interval: 150; repeat: false; onTriggered: nav._apply() }
}
