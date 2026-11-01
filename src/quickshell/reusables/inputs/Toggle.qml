import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root
    implicitWidth: mainRow.implicitWidth + horizontalPadding * 2
    implicitHeight: 32

    property int horizontalPadding: 10
    property int cornerRadius: 16
    property real trackWidth: 44
    property real trackHeight: 24

    property string buttonText: ""
    property string buttonIcon: ""
    property int iconFontSize: 15
    property int textFontSize: 12

    property bool checked: false
    property color accentColor: ThemeBackend.accent
    property color baseColor: ThemeBackend.surface0
    property color handleColor: ThemeBackend.crust
    property color handleOffColor: ThemeBackend.text
    property color textColor: ThemeBackend.text

    activeFocusOnTab: root.enabled
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            btnMa.clicked(null);
            event.accepted = true;
        }
    }

    property bool action_highlight: false
    property string toggleSound: "reusables/toggle/sfx.wav"

    signal toggled(bool checked)
    signal clicked()
    signal triggered()

    property real flashOpacity: 0.0
    property real popScale: 1.0
    property real stretch: 0.0

    onCheckedChanged: {
        if (handleGlass.active) stretchAnim.restart();
    }

    SequentialAnimation {
        id: stretchAnim
        NumberAnimation { target: root; property: "stretch"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "stretch"; to: 0.0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled

    RowLayout {
        id: mainRow
        layoutDirection: I18n.layoutDirection
        anchors.centerIn: parent
        spacing: 10

        Text {
            id: iconLabel
            visible: root.buttonIcon !== ""
            text: root.buttonIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.iconFontSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: mainLabel
            visible: root.buttonText !== ""
            text: root.buttonText
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: root.textFontSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            id: track
            implicitWidth: root.trackWidth
            implicitHeight: root.trackHeight
            radius: Math.min(height / 2, root.cornerRadius)
            color: trackGlass.active ? "transparent" : (root.checked ? root.accentColor : (root.isHoveredOrHighlighted ? Qt.lighter(root.baseColor, 1.2) : root.baseColor))
            opacity: root.enabled ? 1.0 : 0.5
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            GlassFill {
                id: trackGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: root.checked ? root.accentColor : root.baseColor
                tintAmount: root.checked ? 0.7 : (root.isHoveredOrHighlighted ? 0.4 : 0.3)
                Behavior on tintAmount { NumberAnimation { duration: 250 } }
            }

            scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 0.95 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            Rectangle {
                id: handle
                readonly property real inset: Math.max(2, Math.round(parent.height / 8))
                width: parent.height - inset * 2 + (handleGlass.active && btnMa.pressed ? 8 : 0) + (handleGlass.active ? 10 * root.stretch : 0)
                height: parent.height - inset * 2
                radius: Math.min(height / 2, Math.max(0, root.cornerRadius - inset))
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - inset : inset
                color: handleGlass.active ? "transparent" : (root.checked ? root.handleColor : root.handleOffColor)

                GlassFill {
                    id: handleGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: root.checked ? root.handleColor : root.handleOffColor
                    tintAmount: 0.45
                    shadow: 1
                    press: btnMa.pressed ? 1 : 0
                    pulse: Math.min(1, root.flashOpacity * 2.5)
                    Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                visible: root.activeFocus
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#ffffff"
                opacity: root.flashOpacity
                visible: !trackGlass.active
                PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
            }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (!root.enabled) return;
            root.checked = !root.checked;
            btnPopAnim.start();
            root.flashOpacity = 0.2;
            btnFlashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx(root.toggleSound);
            }
            root.toggled(root.checked);
            root.clicked();
            root.triggered();
        }
    }
}
