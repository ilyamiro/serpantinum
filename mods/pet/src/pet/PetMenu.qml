import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

// Right-click menu for the bar bed. Full-screen overlay like the shell's tray / desktop menus:
// clicking anywhere outside (or Escape) closes it.
PanelWindow {
    id: menu

    property var bed: null
    signal closed()

    screen: bed && bed.barScreen ? bed.barScreen : null
    color: "transparent"
    WlrLayershell.namespace: "qs-pet-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(v) {
        return bed ? bed.s(v) : v;
    }

    function close() {
        menu.closed();
    }

    readonly property bool petOn: PetState.enabled
    readonly property rect anchorRect: bed ? bed.screenRect() : Qt.rect(0, 0, 0, 0)
    readonly property bool openUp: anchorRect.y > height / 2

    function act(id) {
        if (id === "toggle") {
            PetState.toggleFromBed(menu.bed);
        } else if (id === "treat") {
            PetState.requestTreatDrop(menu.bed);
        } else if (id === "chase") {
            PetState.chaseRequested();
        } else if (id === "sounds") {
            PetState.setSounds(!PetState.soundsOn);
            return;
        } else if (id === "power") {
            PetState.powerRequested(!PetState.enabled);
        }
        menu.close();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.close()
    }

    Rectangle {
        id: box
        width: menu.s(206)
        height: col.implicitHeight + menu.s(8)
        x: Math.round(Math.max(menu.s(6), Math.min(menu.width - width - menu.s(6), menu.anchorRect.x + menu.anchorRect.width / 2 - width / 2)))
        y: Math.round(menu.openUp ? menu.anchorRect.y - height - menu.s(6) : menu.anchorRect.y + menu.anchorRect.height + menu.s(6))
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, 0.08)
        clip: true

        opacity: 0
        scale: 0.96
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: menu.s(4)
            spacing: menu.s(2)

            ClickButton {
                visible: menu.petOn
                width: parent.width
                height: menu.s(29)
                cornerRadius: menu.s(8)
                contentAlignment: Qt.AlignLeft
                horizontalPadding: menu.s(10)
                buttonIcon: String.fromCodePoint(PetState.out ? 0xF02E3 : 0xF011B)
                iconFontSize: menu.s(15)
                textFontSize: menu.s(12)
                buttonText: PetState.out ? "Send to bed" : "Call kitty out"
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: menu.act("toggle")
            }

            ClickButton {
                visible: menu.petOn
                enabled: PetState.treats > 0
                opacity: enabled ? 1.0 : 0.45
                width: parent.width
                height: menu.s(29)
                cornerRadius: menu.s(8)
                contentAlignment: Qt.AlignLeft
                horizontalPadding: menu.s(10)
                buttonIcon: String.fromCodePoint(0xF023A)
                iconFontSize: menu.s(15)
                textFontSize: menu.s(12)
                buttonText: PetState.treats > 0 ? ("Drop a treat (" + PetState.treats + ")") : "No treats yet"
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: menu.act("treat")
            }

            ClickButton {
                visible: menu.petOn
                enabled: PetState.out
                opacity: enabled ? 1.0 : 0.45
                width: parent.width
                height: menu.s(29)
                cornerRadius: menu.s(8)
                contentAlignment: Qt.AlignLeft
                horizontalPadding: menu.s(10)
                buttonIcon: String.fromCodePoint(0xF046E)
                iconFontSize: menu.s(15)
                textFontSize: menu.s(12)
                buttonText: "Chase my cursor"
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: menu.act("chase")
            }

            ClickButton {
                visible: menu.petOn
                width: parent.width
                height: menu.s(29)
                cornerRadius: menu.s(8)
                contentAlignment: Qt.AlignLeft
                horizontalPadding: menu.s(10)
                buttonIcon: String.fromCodePoint(PetState.soundsOn ? 0xF057E : 0xF0581)
                iconFontSize: menu.s(15)
                textFontSize: menu.s(12)
                buttonText: PetState.soundsOn ? "Sounds: on" : "Sounds: off"
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: menu.act("sounds")
            }

            Item {
                visible: menu.petOn
                width: parent.width
                height: menu.s(5)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - menu.s(12)
                    height: 1
                    color: Qt.alpha(ThemeBackend.text, 0.1)
                }
            }

            ClickButton {
                width: parent.width
                height: menu.s(29)
                cornerRadius: menu.s(8)
                contentAlignment: Qt.AlignLeft
                horizontalPadding: menu.s(10)
                buttonIcon: String.fromCodePoint(0xF0425)
                iconFontSize: menu.s(15)
                textFontSize: menu.s(12)
                buttonText: menu.petOn ? "Turn pet off" : "Turn pet on"
                accentColor: menu.petOn ? Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.22) : ThemeBackend.blue
                bgOpacity: ThemeBackend.elementOpacity
                textColor: menu.petOn ? ThemeBackend.red : ThemeBackend.base
                onClicked: menu.act("power")
            }
        }
    }
}
