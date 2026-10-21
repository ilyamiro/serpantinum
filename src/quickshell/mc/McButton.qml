import QtQuick
import "../"
import "."

// Stone GUI button: gray bevel, white outline on hover, like Minecraft menus.
// `selected` gives the pressed-in white-framed look used for active tabs/presets.
Item {
    id: btn
    property string label: ""
    property string icon: ""
    property int fontSize: 14
    property int iconSize: fontSize
    property int bevel: 2
    property int horizontalPadding: 8
    property bool interactive: true
    property bool selected: false
    readonly property bool hovered: ma.containsMouse && interactive && enabled

    signal clicked()

    implicitWidth: (btn.label !== "" ? contentRow.implicitWidth + horizontalPadding * 2 : 28)
    implicitHeight: 28

    McPanel {
        anchors.fill: parent
        bevel: btn.bevel
        fill: btn.selected ? "#8c8c8c"
            : (ma.pressed && btn.hovered ? "#5a5a5a" : (btn.hovered ? "#7c7c7c" : "#5e5e5e"))
        light: btn.selected ? "#cfcfcf" : "#a0a0a0"
        dark: "#2e2e2e"
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Math.max(1, btn.bevel)
        border.color: "#ffffff"
        visible: btn.hovered || btn.selected
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Math.round(btn.fontSize * 0.5)
        opacity: btn.enabled ? 1.0 : 0.5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            text: btn.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: btn.iconSize
            color: btn.hovered || btn.selected ? "#ffffff" : "#d0d0d0"
        }
        McText {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.label !== ""
            text: btn.label
            font.pixelSize: btn.fontSize
            color: btn.hovered || btn.selected ? "#ffffff" : "#d0d0d0"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.interactive && btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
            btn.clicked();
        }
    }
}
