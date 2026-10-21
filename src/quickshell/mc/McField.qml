import QtQuick
import "."

// Minecraft text field: black box with a gray outline (white when focused) and a
// blinking "_" caret at the end of the text.
Item {
    id: field
    property alias text: input.text
    property alias input: input
    property bool password: false
    property string placeholder: ""
    property int fontSize: 16
    signal accepted()

    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        border.width: 2
        border.color: input.activeFocus ? "#ffffff" : "#a0a0a0"
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        font.family: "Monocraft"
        font.pixelSize: field.fontSize
        color: "#e0e0e0"
        selectionColor: "#3050ff"
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "*"
        clip: true
        cursorDelegate: Item {}
        onAccepted: field.accepted()

        McText {
            visible: input.text === "" && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            font.pixelSize: field.fontSize
            color: "#707070"
        }
        Text {
            id: caret
            x: input.cursorRectangle.x
            anchors.verticalCenter: parent.verticalCenter
            text: "_"
            font: input.font
            color: "#e0e0e0"
            visible: input.activeFocus && blink.on
        }
    }
    Timer {
        id: blink
        property bool on: true
        interval: 500
        repeat: true
        running: input.activeFocus
        onTriggered: on = !on
    }
}
