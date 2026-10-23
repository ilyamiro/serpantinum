import QtQuick
import Quickshell
import Quickshell.Wayland
import "../singletons/widgetcontrols"

// Transparent full-screen layer that owns the keyboard while dock mode is active (DockNavController).
// Its input region is empty, so the mouse still reaches the dock, the preview and the windows below.
PanelWindow {
    id: keys

    screen: DockNavController.screen
    visible: DockNavController.active

    WlrLayershell.namespace: "dock-nav"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: DockNavController.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent
        focus: DockNavController.active

        Keys.onPressed: function(event) {
            if (DockNavController.handleKey(event.key, event.modifiers)) event.accepted = true;
        }

        onFocusChanged: if (DockNavController.active && !focus) forceActiveFocus()
    }

    onVisibleChanged: if (visible) focusTimer.restart()
    Timer { id: focusTimer; interval: 40; onTriggered: if (keys.contentItem) keys.contentItem.forceActiveFocus() }
}
