import QtQuick
import "../../widgets"

Item {
    id: frame

    property bool active: false
    property bool handlesEnabled: true
    property bool aspectLocked: false
    property bool rot90: false
    property real unit: 1.0
    property real baseLineWidth: 2
    property Item coordinateItem: null

    signal resizeStarted(int ex, int ey)
    signal resizeMoved(int ex, int ey, real dx, real dy, int modifiers)
    signal resizeFinished()

    opacity: frame.active ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    SelectionOutline {
        anchors.fill: parent
        running: frame.active && frame.opacity > 0.001
        lineWidth: frame.baseLineWidth * frame.unit
    }

    Repeater {
        model: [
            { ex: -1, ey: -1 }, { ex: 1, ey: -1 }, { ex: -1, ey: 1 }, { ex: 1, ey: 1 },
            { ex: 0, ey: -1 }, { ex: 0, ey: 1 }, { ex: -1, ey: 0 }, { ex: 1, ey: 0 }
        ]

        delegate: MouseArea {
            id: hit

            readonly property int ex: modelData ? modelData.ex : 0
            readonly property int ey: modelData ? modelData.ey : 0
            readonly property bool corner: hit.ex !== 0 && hit.ey !== 0
            readonly property real u: frame.unit
            readonly property real insetX: Math.max(0, Math.min(18 * hit.u, (frame.width - 8 * hit.u) / 2))
            readonly property real insetY: Math.max(0, Math.min(18 * hit.u, (frame.height - 8 * hit.u) / 2))

            property real startMX: 0
            property real startMY: 0

            visible: hit.corner || !frame.aspectLocked
            enabled: hit.visible && frame.active && frame.handlesEnabled
            z: 20
            width: hit.corner ? 24 * hit.u : (hit.ex === 0 ? frame.width - 2 * hit.insetX : 16 * hit.u)
            height: hit.corner ? 24 * hit.u : (hit.ey === 0 ? frame.height - 2 * hit.insetY : 16 * hit.u)
            x: hit.ex < 0 ? -hit.width / 2 : (hit.ex > 0 ? frame.width - hit.width / 2 : hit.insetX)
            y: hit.ey < 0 ? -hit.height / 2 : (hit.ey > 0 ? frame.height - hit.height / 2 : hit.insetY)
            hoverEnabled: true
            preventStealing: true
            cursorShape: {
                if (hit.corner) {
                    let diag = hit.ex === hit.ey;
                    return (diag !== frame.rot90) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
                }
                let vertical = hit.ey !== 0;
                return (vertical !== frame.rot90) ? Qt.SizeVerCursor : Qt.SizeHorCursor;
            }

            onPressed: (mouse) => {
                let p = frame.coordinateItem ? mapToItem(frame.coordinateItem, mouse.x, mouse.y) : Qt.point(mouse.x, mouse.y);
                startMX = p.x;
                startMY = p.y;
                frame.resizeStarted(hit.ex, hit.ey);
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return;
                let p = frame.coordinateItem ? mapToItem(frame.coordinateItem, mouse.x, mouse.y) : Qt.point(mouse.x, mouse.y);
                frame.resizeMoved(hit.ex, hit.ey, p.x - startMX, p.y - startMY, mouse.modifiers);
            }

            onReleased: frame.resizeFinished()
            onCanceled: frame.resizeFinished()
        }
    }
}
