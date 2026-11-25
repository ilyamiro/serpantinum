import QtQuick
import "StartSnake.js" as Sim

Item {
    id: root

    property color color: "white"
    property color shadowColor: Qt.rgba(0, 0, 0, 0.56)
    property bool running: false
    property real unit: 1

    property bool _initialized: false

    onWidthChanged: if (root._initialized) Sim.resize(root.width / root.unit, root.height / root.unit)
    onHeightChanged: if (root._initialized) Sim.resize(root.width / root.unit, root.height / root.unit)

    FrameAnimation {
        running: root.running && root.visible && root.width > 0 && root.height > 0
        onTriggered: {
            if (!root._initialized) {
                Sim.init(root.width / root.unit, root.height / root.unit);
                root._initialized = true;
            }
            Sim.advance(frameTime);
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        width: Math.ceil(440 * root.unit)
        height: width
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            if (!root._initialized) return;
            Sim.prepare();
            canvas.x = Math.round(Sim.centerX() * root.unit - canvas.width / 2);
            canvas.y = Math.round(Sim.centerY() * root.unit - canvas.height / 2);

            const ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            Sim.draw(ctx, -canvas.x, -canvas.y, root.unit, root.color, root.shadowColor);
        }
    }
}
