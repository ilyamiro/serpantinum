import QtQuick
import QtQuick.Controls.Basic
import QtQml.Models

Item {
    id: chooser

    required property var greeter
    required property var sessions
    required property int selectedIndex
    required property bool active
    property string title: greeter.trLabel("Session", "Сессия")
    property string glyph: "󰍹"
    property string iconFont: "Symbols Nerd Font Mono"
    property var backdrop: null
    readonly property bool opened: menu.visible
    readonly property string selectedName: names.revision >= 0 ? nameAt(selectedIndex) : ""
    signal chosen(int index)
    signal dismissed()

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight
    opacity: active && names.count > 0 ? 1 : 0
    visible: opacity > 0
    enabled: active

    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    function nameAt(index) {
        return names.objectAt(index)?.name ?? ""
    }

    function open() {
        if (active && names.count > 0) {
            menu.cursorIndex = Math.max(0, Math.min(selectedIndex, names.count - 1))
            greeter.sounds?.play("reusables/dropdown/click.wav")
            menu.open()
        }
    }

    function close() {
        menu.close()
    }

    function accept(index) {
        if (index >= 0 && index < names.count) {
            greeter.sounds?.play("reusables/dropdown/list.wav")
            chosen(index)
            close()
        }
    }

    onActiveChanged: {
        if (!active)
            close()
    }

    Instantiator {
        id: names
        property int revision: 0
        model: chooser.sessions
        delegate: QtObject { required property string name }
        onObjectAdded: revision++
        onObjectRemoved: revision++
        onCountChanged: {
            if (count === 0 && menu.visible)
                chooser.close()
        }
    }

    component Caption: Text {
        color: chooser.greeter.foreground
        font.family: chooser.greeter.fontFamily
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    component Glyph: Caption {
        font.family: chooser.iconFont
        font.pixelSize: 17
    }

    Button {
        id: trigger
        anchors.fill: parent
        implicitWidth: Math.min(270, Math.max(160, contentItem.implicitWidth + leftPadding + rightPadding))
        implicitHeight: 48
        leftPadding: 13
        rightPadding: 13
        hoverEnabled: true
        text: chooser.selectedName || chooser.title
        Accessible.name: chooser.title + " · " + text

        onClicked: {
            if (chooser.opened)
                chooser.close()
            else
                chooser.open()
        }

        background: Rectangle {
            radius: chooser.greeter.corner
            color: trigger.down ? Qt.darker(chooser.greeter.fieldColor, 1.12)
                 : trigger.hovered || trigger.activeFocus || chooser.opened
                    ? Qt.lighter(chooser.greeter.fieldColor, 1.17) : chooser.greeter.fieldColor
            border.color: Qt.alpha(chooser.greeter.accent, trigger.activeFocus || chooser.opened ? 0.45 : 0)
            scale: trigger.down ? 0.96 : (trigger.hovered ? 1.025 : 1)

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        }

        contentItem: Item {
            implicitWidth: sessionGlyph.implicitWidth + sessionText.implicitWidth + caret.implicitWidth + 20
            implicitHeight: 22

            Glyph {
                id: sessionGlyph
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                color: chooser.greeter.accent
                text: chooser.glyph
            }
            Caption {
                id: sessionText
                anchors { left: sessionGlyph.right; right: caret.left; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                text: trigger.text
            }
            Glyph {
                id: caret
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                color: chooser.greeter.subtle
                text: "󰅂"
                rotation: chooser.opened ? 90 : -90
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
        }
    }

    Popup {
        id: menu
        property int cursorIndex: -1
        parent: chooser
        x: 0
        y: -height - 12
        width: Math.max(286, chooser.width)
        height: body.implicitHeight + topPadding + bottomPadding
        padding: 10
        focus: true
        modal: true
        dim: false
        transformOrigin: Popup.BottomLeft
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: body.forceActiveFocus()
        onClosed: chooser.dismissed()

        function moveCursor(index) {
            const count = names.count
            if (count > 0) {
                cursorIndex = (index + count) % count
                sessionList.positionViewAtIndex(cursorIndex, ListView.Contain)
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.90; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.14 }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 135; easing.type: Easing.InQuad }
                NumberAnimation { property: "scale"; to: 0.94; duration: 150; easing.type: Easing.InQuad }
            }
        }

        background: Item {
            id: popupBackground

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: -2
                radius: chooser.greeter.corner
                color: Qt.rgba(0, 0, 0, 0.15)
            }

            Rectangle {
                anchors.fill: parent
                radius: chooser.greeter.corner
                color: Qt.alpha(chooser.greeter.surface, glass.visible ? 0.32 : 0.98)
                border.color: Qt.alpha(chooser.greeter.foreground, 0.09)
            }

            Glass {
                id: glass
                anchors.fill: parent
                visible: chooser.backdrop !== null && chooser.greeter.effect === "glass"
                src: visible ? chooser.backdrop : null
                tintColor: chooser.greeter.surface
                tintAmount: 0.52
                radius: chooser.greeter.corner
                sourceRect: {
                    if (!visible || !chooser.greeter.width || !chooser.greeter.height)
                        return Qt.rect(0, 0, 1, 1)
                    const stage = chooser.parent
                    const trackedGeometry = menu.scale + menu.x + menu.y + chooser.x + chooser.y
                        + (stage ? stage.x + stage.y + stage.scale : 0)
                    if (!Number.isFinite(trackedGeometry))
                        return Qt.rect(0, 0, 1, 1)
                    const area = popupBackground.mapToItem(chooser.greeter, 0, 0, width, height)
                    return Qt.rect(area.x / chooser.greeter.width, area.y / chooser.greeter.height,
                                   area.width / chooser.greeter.width, area.height / chooser.greeter.height)
                }
            }
        }

        contentItem: FocusScope {
            id: body
            implicitHeight: heading.implicitHeight + 10 + sessionList.height
            focus: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Up:
                    menu.moveCursor(menu.cursorIndex - 1)
                    break
                case Qt.Key_Down:
                    menu.moveCursor(menu.cursorIndex + 1)
                    break
                case Qt.Key_Home:
                    menu.moveCursor(0)
                    break
                case Qt.Key_End:
                    menu.moveCursor(names.count - 1)
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    chooser.accept(menu.cursorIndex)
                    break
                case Qt.Key_Escape:
                    chooser.close()
                    break
                default:
                    return
                }
                event.accepted = true
            }

            Caption {
                id: heading
                anchors { top: parent.top; left: parent.left; leftMargin: 8 }
                font.weight: Font.DemiBold
                text: chooser.title
            }

            ListView {
                id: sessionList
                anchors { top: heading.bottom; topMargin: 10; left: parent.left; right: parent.right }
                height: Math.min(268, Math.max(0, count * 42 + (count - 1) * spacing))
                model: chooser.sessions
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: ItemDelegate {
                    id: row
                    required property int index
                    required property string name
                    readonly property bool current: index === chooser.selectedIndex

                    width: ListView.view.width
                    height: 42
                    padding: 9
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    highlighted: index === menu.cursorIndex
                    text: name
                    Accessible.name: name
                    Accessible.selected: current

                    onHoveredChanged: {
                        if (hovered)
                            menu.cursorIndex = index
                    }
                    onClicked: chooser.accept(index)

                    background: Rectangle {
                        radius: Math.max(4, chooser.greeter.corner - 2)
                        color: row.down ? Qt.alpha(chooser.greeter.accent, 0.29)
                             : row.highlighted ? Qt.alpha(chooser.greeter.accent, 0.19)
                             : row.current ? Qt.alpha(chooser.greeter.accent, 0.10) : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    contentItem: Item {
                        Glyph {
                            id: desktopGlyph
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            color: row.current ? chooser.greeter.accent : chooser.greeter.subtle
                            text: chooser.glyph
                        }
                        Caption {
                            anchors { left: desktopGlyph.right; right: check.left; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: row.name
                            elide: Text.ElideRight
                        }
                        Glyph {
                            id: check
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            color: chooser.greeter.accent
                            text: "󰄬"
                            opacity: row.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }
    }
}
