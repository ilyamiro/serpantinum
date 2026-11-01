import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Item {
    id: root
    implicitWidth: size
    implicitHeight: size

    property int size: 44
    property int cornerRadius: 12

    property int iconSize: 18

    property color accentColor: ThemeBackend.accent
    property color textColor: ThemeBackend.crust
    property real bgOpacity: 1.0
    property real glassShadow: 1
    function withBgOpacity(c) { return Qt.rgba(c.r, c.g, c.b, c.a * root.bgOpacity); }

    property bool action_highlight: false
    property string clickSound: "reusables/iconbutton/click.wav"

    property var paintCanvas: function(ctx, canvas) {}

    signal clicked()
    signal triggered()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled

    function requestPaint() {
        iconCanvas.requestPaint()
    }

    Rectangle {
        id: btnShape
        anchors.fill: parent
        radius: root.cornerRadius
        clip: !glass.active
        color: glass.active ? "transparent" : root.withBgOpacity(!root.enabled ? root.accentColor : (btnMa.pressed ? Qt.darker(root.accentColor, 1.12) : (root.isHoveredOrHighlighted ? Qt.lighter(root.accentColor, 1.12) : root.accentColor)))
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlassFill {
            id: glass
            anchors.fill: parent
            shadow: root.glassShadow
            press: btnMa.pressed ? 1 : (root.isHoveredOrHighlighted ? 0.25 : 0)
            pulse: Math.min(1, root.flashOpacity * 2.5)
            Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            radius: root.cornerRadius
            tintColor: root.accentColor
            tintAmount: (btnMa.pressed ? 0.55 : (root.isHoveredOrHighlighted ? 0.42 : 0.3)) * root.bgOpacity
            Behavior on tintAmount { NumberAnimation { duration: 150 } }
        }

        scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 1.08 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
        }

        Canvas {
            id: iconCanvas
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (root.paintCanvas) {
                    root.paintCanvas(ctx, iconCanvas)
                }
            }

            Connections {
                target: root
                function onTextColorChanged() { iconCanvas.requestPaint() }
                function onIconSizeChanged() { iconCanvas.requestPaint() }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            visible: !glass.active
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                if (!root.enabled) return;
                btnPopAnim.start();
                root.flashOpacity = 0.4;
                btnFlashAnim.start();
                if (typeof Sounds !== "undefined") {
                    Sounds.playSfx(root.clickSound);
                }
                root.clicked();
                root.triggered();
            }
        }
    }
}
