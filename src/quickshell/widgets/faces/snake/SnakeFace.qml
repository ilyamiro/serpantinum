import QtQuick
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool previewMode: false
    property string widgetId: ""
    readonly property bool inputPassthrough: true
    readonly property Item inputItem: hitArea
    property int snakeLength: 48
    property real snakeSpeed: 1

    property real minWidth: root.previewMode ? 50 : Math.round(Screen.width * Math.SQRT1_2 / 2)
    property real minHeight: root.previewMode ? 50 : Math.round(Screen.height * Math.SQRT1_2 / 2)
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    Item {
        id: hitArea
        readonly property real pad: 60
    }

    Snake {
        id: snake
        anchors.fill: parent
        running: root.visible
        simKey: root.previewMode || root.widgetId === "" ? "" : "widget-" + root.widgetId
        segments: root.snakeLength
        speed: root.snakeSpeed
        unit: root.previewMode ? Math.min(1, Math.min(root.width, root.height) / 360) : 1
        color: ThemeBackend.primary
        shadowStrength: (0.299 * ThemeBackend.base.r + 0.587 * ThemeBackend.base.g + 0.114 * ThemeBackend.base.b) < 0.5 ? 0.56 : 0.36

        onSnakeRectChanged: {
            const r = snake.snakeRect;
            if (r.x >= hitArea.x && r.y >= hitArea.y && r.x + r.width <= hitArea.x + hitArea.width && r.y + r.height <= hitArea.y + hitArea.height) return;
            hitArea.x = r.x - hitArea.pad;
            hitArea.y = r.y - hitArea.pad;
            hitArea.width = r.width + hitArea.pad * 2;
            hitArea.height = r.height + hitArea.pad * 2;
        }
    }
}
