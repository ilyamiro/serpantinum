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

    property string buttonIcon: ""
    property string iconFont: ThemeBackend.iconFont
    property int iconFontSize: 18
    property int iconOffsetX: 0
    property int iconOffsetY: 0

    property color accentColor: ThemeBackend.surface0
    property color textColor: "#11111b"
    property real bgOpacity: 1.0

    property bool action_highlight: false
    property string clickSound: "reusables/iconbutton/click.wav"
    property int acceptedButtons: Qt.LeftButton

    signal clicked()
    signal rightClicked()
    signal triggered()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled

    Item {
        id: btnContainer
        anchors.fill: parent

        scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 1.08 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
        }

        Rectangle {
            id: btnShape
            anchors.fill: parent
            radius: root.cornerRadius
            clip: true
            color: !root.enabled ? root.accentColor : (btnMa.pressed ? Qt.darker(root.accentColor, 1.12) : (root.isHoveredOrHighlighted ? Qt.lighter(root.accentColor, 1.12) : root.accentColor))
            opacity: (root.enabled ? 1.0 : 0.5) * root.bgOpacity

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.iconOffsetX
            anchors.verticalCenterOffset: root.iconOffsetY
            text: root.buttonIcon
            font.family: root.iconFont
            font.pixelSize: root.iconFontSize
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.5
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            enabled: root.enabled
            acceptedButtons: root.acceptedButtons
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: (mouse) => {
                if (!root.enabled) return;
                if (mouse.button === Qt.RightButton) {
                    root.rightClicked();
                    return;
                }
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
