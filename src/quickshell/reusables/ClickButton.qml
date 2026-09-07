import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

Item {
    id: root

    property int horizontalPadding: 12
    property int cornerRadius: 10

    property string buttonText: ""
    property string subText: ""
    property string buttonIcon: ""
    property int iconFontSize: 15
    property int textFontSize: 12
    
    property int maxTextWidth: 0
    property int maxWidth: 0
    property int contentAlignment: Qt.AlignHCenter

    property real rawTextWidth: Math.max(mainLabel.visible ? mainLabel.implicitWidth : 0, subLabel.visible ? subLabel.implicitWidth : 0)
    property real boundedTextWidth: root.maxTextWidth > 0 ? Math.min(rawTextWidth, root.maxTextWidth) : rawTextWidth

    property real calculatedContentWidth: (iconLabel.visible ? iconLabel.implicitWidth : 0)
                                         + (iconLabel.visible && textCol.visible ? mainRow.spacing : 0)
                                         + (textCol.visible ? boundedTextWidth : 0)

    property real desiredWidth: calculatedContentWidth + horizontalPadding * 2
    implicitWidth: root.maxWidth > 0 ? Math.min(desiredWidth, root.maxWidth) : desiredWidth
    implicitHeight: 30

    property real availableTextWidth: Math.max(0, root.width - (root.horizontalPadding * 2) - (iconLabel.visible ? (iconLabel.implicitWidth + mainRow.spacing) : 0))

    property color accentColor: "#313244"
    property color textColor: "#cdd6f4"

    property bool action_highlight: false
    property string clickSound: "reusables/clickbutton/click.wav"
    property int acceptedButtons: Qt.LeftButton

    signal clicked()
    signal rightClicked()
    signal triggered()
    signal wheel(var wheel)

    property real flashOpacity: 0.0
    property real popScale: 1.0

    property bool isHoveredOrHighlighted: btnMa.containsMouse || root.action_highlight

    Rectangle {
        id: btnShape
        anchors.fill: parent
        radius: root.cornerRadius
        clip: true
        color: (btnMa.pressed && root.enabled) ? Qt.darker(root.accentColor, 1.28) : (root.isHoveredOrHighlighted ? Qt.darker(root.accentColor, 1.14) : root.accentColor)
        opacity: 1.0

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        scale: ((btnMa.pressed && root.enabled) ? 0.985 : (root.isHoveredOrHighlighted ? 1.015 : 1.0)) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
        }

        RowLayout {
            id: mainRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: root.contentAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            anchors.left: root.contentAlignment === Qt.AlignLeft ? parent.left : undefined
            anchors.leftMargin: root.contentAlignment === Qt.AlignLeft ? root.horizontalPadding : 0
            anchors.right: root.contentAlignment === Qt.AlignRight ? parent.right : undefined
            anchors.rightMargin: root.contentAlignment === Qt.AlignRight ? root.horizontalPadding : 0
            spacing: 8

            Text {
                id: iconLabel
                visible: root.buttonIcon !== ""
                text: root.buttonIcon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.iconFontSize
                color: root.textColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                id: textCol
                visible: root.buttonText !== "" || root.subText !== ""
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    id: mainLabel
                    visible: root.buttonText !== ""
                    text: root.buttonText
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.textFontSize
                    color: root.textColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.maxTextWidth > 0 ? Math.min(root.maxTextWidth, root.availableTextWidth) : root.availableTextWidth) + 2
                }

                Text {
                    id: subLabel
                    visible: root.subText !== ""
                    text: root.subText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.max(10, root.textFontSize - 6)
                    color: root.textColor
                    opacity: 0.75
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.maxTextWidth > 0 ? Math.min(root.maxTextWidth, root.availableTextWidth) : root.availableTextWidth) + 2
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.acceptedButtons
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: mouse => {
            if (!root.enabled) return;
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
                return;
            }
            btnPopAnim.start();
            root.flashOpacity = 0.15;
            btnFlashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx(root.clickSound);
            }
            root.clicked();
            root.triggered();
        }

        onWheel: wheel => {
            if (!root.enabled) return;
            root.wheel(wheel);
        }
    }
}
