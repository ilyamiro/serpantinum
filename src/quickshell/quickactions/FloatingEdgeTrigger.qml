import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: trigger

    property var host: null
    property string edge: "left"
    property real inset: 0
    property real thickness: 3
    property real startA: 0
    property real lengthA: 0
    property real startB: 0
    property real lengthB: 0

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property bool hovered: visible && (areaA.containsMouse || areaB.containsMouse)

    onVisibleChanged: {
        if (!visible && host) host.handleEdgeHandoff();
    }

    WlrLayershell.namespace: "qs-floating-edge"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }

    margins {
        top: edge === "top" ? inset : 0
        bottom: edge === "bottom" ? inset : 0
        left: edge === "left" ? inset : 0
        right: edge === "right" ? inset : 0
    }

    implicitWidth: horizontal ? 0 : thickness
    implicitHeight: horizontal ? thickness : 0

    mask: Region {
        Region { item: areaA }
        Region { item: areaB }
    }

    function edgePos(area, mx, my) {
        return horizontal ? mx + area.x : my + area.y;
    }

    MouseArea {
        id: areaA
        x: trigger.horizontal ? trigger.startA : 0
        y: trigger.horizontal ? 0 : trigger.startA
        width: trigger.horizontal ? trigger.lengthA : trigger.width
        height: trigger.horizontal ? trigger.height : trigger.lengthA
        hoverEnabled: true
        enabled: trigger.lengthA > 0
        onEntered: trigger.host.handleEdgeEntered(trigger.edge, trigger.edgePos(areaA, mouseX, mouseY))
        onPositionChanged: mouse => trigger.host.handleEdgePositionChanged(trigger.edge, trigger.edgePos(areaA, mouse.x, mouse.y))
        onExited: {
            if (trigger.visible) trigger.host.handleEdgeExited();
        }
    }

    MouseArea {
        id: areaB
        x: trigger.horizontal ? trigger.startB : 0
        y: trigger.horizontal ? 0 : trigger.startB
        width: trigger.horizontal ? trigger.lengthB : trigger.width
        height: trigger.horizontal ? trigger.height : trigger.lengthB
        hoverEnabled: true
        enabled: trigger.lengthB > 0
        onEntered: trigger.host.handleEdgeEntered(trigger.edge, trigger.edgePos(areaB, mouseX, mouseY))
        onPositionChanged: mouse => trigger.host.handleEdgePositionChanged(trigger.edge, trigger.edgePos(areaB, mouse.x, mouse.y))
        onExited: {
            if (trigger.visible) trigger.host.handleEdgeExited();
        }
    }
}
