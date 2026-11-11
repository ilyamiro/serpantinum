import QtQuick

MouseArea {
    id: handle

    required property var proxy
    required property var face
    required property var workspaceItem
    property var edges: ({ left: false, top: false, right: false, bottom: false })
    property bool isCorner: false

    z: 20
    enabled: face.status === Loader.Ready && proxy.isSelected
    hoverEnabled: true
    preventStealing: true

    property real startMouseX
    property real startMouseY
    property real startWidth
    property real startHeight
    property real startWidgetX
    property real startWidgetY

    onPressed: (mouse) => {
        proxy.bringToFront();
        let localPos = mapToItem(workspaceItem, mouse.x, mouse.y);
        startMouseX = localPos.x;
        startMouseY = localPos.y;
        startWidth = proxy.model.wWidth;
        startHeight = proxy.model.wHeight;
        startWidgetX = proxy.model.wX;
        startWidgetY = proxy.model.wY;
    }

    onPositionChanged: (mouse) => {
        if (pressed) {
            proxy.applyResize(mouse, startMouseX, startMouseY, startWidth, startHeight, startWidgetX, startWidgetY, handle, edges, isCorner);
        }
    }

    onReleased: {
        proxy.finalizeSync();
    }

    onCanceled: {
        proxy.finalizeSync();
    }
}
