import QtQuick
import QtQuick.Layouts
import "../"
import "../../"

Item {
    id: root
    implicitWidth: root.s(240)
    implicitHeight: root.s(64)

    property int start: 22
    property int end: 5
    property int hours: 24
    property int tickEvery: 6

    property color accentColor: ThemeBackend.mauve
    property color trackColor: ThemeBackend.surface2
    property color textColor: ThemeBackend.text
    property color subTextColor: ThemeBackend.subtext0
    property string fontFamily: ThemeBackend.fontFamily
    property real trackHeight: root.s(14)
    property real handleSize: root.s(22)
    property real scaleMultiplier: 1.0

    signal committed(int start, int end)

    function s(val) { return Scaler.s(val) * root.scaleMultiplier; }

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function label(h) { return root.pad(h) + ":00"; }

    property int dragStart: start
    property int dragEnd: end
    property bool dragging: false
    property string activeHandle: ""
    readonly property int shownStart: dragging ? dragStart : start
    readonly property int shownEnd: dragging ? dragEnd : end

    readonly property real usable: Math.max(1, trackArea.width - handleSize)
    function centerOf(h) { return handleSize / 2 + (h / hours) * usable; }
    function hourAt(x) {
        let h = Math.round(((x - handleSize / 2) / usable) * hours);
        return Math.max(0, Math.min(hours - 1, h));
    }

    readonly property var segments: shownStart < shownEnd
        ? [{ a: centerOf(shownStart), b: centerOf(shownEnd) }]
        : [{ a: centerOf(shownStart), b: trackArea.width }, { a: 0, b: centerOf(shownEnd) }]

    Text {
        id: summary
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label(root.shownStart) + "  –  " + root.label(root.shownEnd)
        color: root.subTextColor
        font.family: root.fontFamily
        font.pixelSize: root.s(11.5)
        font.bold: true
    }

    Item {
        id: trackArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.bottom
        anchors.topMargin: root.s(6)
        height: root.handleSize

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.trackHeight
            radius: height / 2
            color: trackGlass.active ? "transparent" : Qt.alpha(root.trackColor, ThemeBackend.elementOpacity)
            clip: true

            GlassFill {
                id: trackGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: root.trackColor
                tintAmount: 0.3
            }

            Repeater {
                model: root.segments

                Item {
                    required property var modelData
                    x: modelData.a
                    width: Math.max(0, modelData.b - modelData.a)
                    height: track.height
                    clip: true

                    GlassFill {
                        id: segGlass
                        width: parent.width
                        height: parent.height
                        radius: track.radius
                        forceClear: true
                        tintColor: root.accentColor
                        tintAmount: 0.6
                        tintStrength: 1.0
                        press: root.dragging ? 0.5 : (hover.containsMouse ? 0.2 : 0)
                        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        visible: !segGlass.active
                        width: parent.width
                        height: parent.height
                        radius: track.radius
                        color: root.dragging ? Qt.lighter(root.accentColor, 1.12) : root.accentColor
                    }
                }
            }
        }

        Repeater {
            model: ["start", "end"]

            Rectangle {
                id: handle
                required property string modelData
                readonly property bool isActive: root.dragging && root.activeHandle === modelData
                x: root.centerOf(modelData === "start" ? root.shownStart : root.shownEnd) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.handleSize
                height: root.handleSize
                radius: height / 2
                scale: isActive ? 1.12 : 1.0
                color: handleGlass.active ? "transparent" : (isActive
                    ? Qt.lighter(root.accentColor, 1.3)
                    : (hover.containsMouse ? Qt.lighter(root.accentColor, 1.15) : root.accentColor))
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                GlassFill {
                    id: handleGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: root.accentColor
                    tintAmount: 0.6
                    tintStrength: 1.0
                    press: handle.isActive ? 0.5 : (hover.containsMouse ? 0.2 : 0)
                    Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function apply(x) {
                let h = root.hourAt(x);
                if (root.activeHandle === "start") {
                    if (h !== root.dragEnd) root.dragStart = h;
                } else if (h !== root.dragStart) {
                    root.dragEnd = h;
                }
            }

            onPressed: function(mouse) {
                root.dragStart = root.start;
                root.dragEnd = root.end;
                let ds = Math.abs(mouse.x - root.centerOf(root.start));
                let de = Math.abs(mouse.x - root.centerOf(root.end));
                root.activeHandle = ds <= de ? "start" : "end";
                root.dragging = true;
                apply(mouse.x);
            }
            onPositionChanged: function(mouse) {
                if (root.dragging) apply(mouse.x);
            }
            onReleased: {
                root.dragging = false;
                if (root.dragStart !== root.start || root.dragEnd !== root.end) {
                    root.committed(root.dragStart, root.dragEnd);
                }
            }
            onCanceled: root.dragging = false
        }
    }

    Item {
        anchors.left: trackArea.left
        anchors.right: trackArea.right
        anchors.top: trackArea.bottom
        anchors.topMargin: root.s(4)
        height: root.s(14)

        Repeater {
            model: Math.floor(root.hours / root.tickEvery) + 1

            Text {
                required property int index
                readonly property int h: index * root.tickEvery
                x: root.handleSize / 2 + (h / root.hours) * root.usable - width / 2
                text: root.pad(h)
                color: root.subTextColor
                opacity: 0.7
                font.family: root.fontFamily
                font.pixelSize: root.s(10)
            }
        }
    }
}
