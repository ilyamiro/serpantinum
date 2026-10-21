import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"
import "../../mc"

Item {
    id: root

    property int horizontalPadding: 12
    property int cornerRadius: 10

    property string buttonText: ""
    property string subText: ""
    property string buttonIcon: ""
    property string iconFont: ThemeBackend.iconFont
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

    // Minecraft look (used by the bar): stone bevel instead of a rounded fill, pixel font,
    // and the "on" state shown as a colored label like Minecraft chat color codes.
    property bool mcStyle: false
    property color mcActiveColor: "#55ff55"
    function mcLuma(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b; }
    readonly property bool mcActive: mcLuma(accentColor) - mcLuma(ThemeBackend.surface0) > 0.25
    readonly property color mcFill: (btnMa.pressed && root.enabled) ? "#3e3e3e" : (root.isHoveredOrHighlighted ? "#6e6e6e" : "#575757")
    readonly property color effectiveTextColor: mcStyle ? (mcActive ? mcActiveColor : "#e6e6e6") : textColor

    Rectangle {
        id: btnShape
        anchors.fill: parent
        radius: root.mcStyle ? 0 : root.cornerRadius
        clip: true
        color: root.mcStyle ? "transparent" : ((btnMa.pressed && root.enabled) ? Qt.darker(root.accentColor, 1.28) : (root.isHoveredOrHighlighted ? Qt.darker(root.accentColor, 1.14) : root.accentColor))
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

        McPanel {
            anchors.fill: parent
            visible: root.mcStyle
            fill: root.mcFill
            light: Qt.lighter(root.mcFill, 1.45)
            dark: Qt.darker(root.mcFill, 1.9)
        }
        Rectangle {
            anchors.fill: parent
            visible: root.mcStyle && root.isHoveredOrHighlighted
            color: "transparent"
            border.width: 2
            border.color: "#ffffff"
        }

        RowLayout {
            id: mainRow
            layoutDirection: I18n.layoutDirection
            x: {
                if (root.contentAlignment === Qt.AlignHCenter) {
                    return Math.round((parent.width - width) / 2);
                }
                let alignLeft = (root.contentAlignment === Qt.AlignLeft && !I18n.rtl) || (root.contentAlignment === Qt.AlignRight && I18n.rtl);
                return alignLeft ? root.horizontalPadding : (parent.width - width - root.horizontalPadding);
            }
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                id: iconLabel
                visible: root.buttonIcon !== ""
                text: root.buttonIcon
                font.family: root.iconFont
                font.pixelSize: root.iconFontSize
                color: root.effectiveTextColor
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
                    font.family: root.mcStyle ? "Monocraft" : ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.textFontSize
                    color: root.effectiveTextColor
                    style: root.mcStyle ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(color.r / 4, color.g / 4, color.b / 4, 1)
                    horizontalAlignment: root.contentAlignment === Qt.AlignHCenter ? Text.AlignHCenter : I18n.textAlignment
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.maxTextWidth > 0 ? Math.min(root.maxTextWidth, root.availableTextWidth) : root.availableTextWidth) + 2
                }

                Text {
                    id: subLabel
                    visible: root.subText !== ""
                    text: root.subText
                    font.family: root.mcStyle ? "Monocraft" : "JetBrains Mono"
                    font.pixelSize: Math.max(10, root.textFontSize - 6)
                    color: root.effectiveTextColor
                    horizontalAlignment: root.contentAlignment === Qt.AlignHCenter ? Text.AlignHCenter : I18n.textAlignment
                    opacity: 0.75
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.ceil(root.maxTextWidth > 0 ? Math.min(root.maxTextWidth, root.availableTextWidth) : root.availableTextWidth) + 2
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.mcStyle ? 0 : root.cornerRadius
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
