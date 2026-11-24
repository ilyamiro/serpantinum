import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: dockExclusionWindow
    required property var dockWindow
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "qs-dock-exclusion"
    WlrLayershell.layer: (Compositor.name === "mango" || !dockWindow.dockOnTop) ? WlrLayer.Bottom : WlrLayer.Top
    color: "transparent"
    visible: dockWindow.isEffectivelyExclusive

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: dockWindow.isEffectivelyExclusive ? dockWindow.dockReservedSpace : 0

    anchors {
        top: dockWindow.dockPosition === "top" || dockWindow.isVertical
        bottom: dockWindow.dockPosition === "bottom" || dockWindow.isVertical
        left: dockWindow.dockPosition === "left" || !dockWindow.isVertical
        right: dockWindow.dockPosition === "right" || !dockWindow.isVertical
    }

    implicitHeight: dockWindow.isVertical ? 0 : dockWindow.dockReservedSpace
    implicitWidth: dockWindow.isVertical ? dockWindow.dockReservedSpace : 0

    mask: Region {}
}
