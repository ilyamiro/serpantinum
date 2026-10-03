import QtQuick
import QtQuick.Layouts
import "../../singletons"
import "../../"
import "../../reusables"

Item {
    id: root

    property var scaleFunc: null
    property string selectedId: NotesManager.activeId

    signal noteActivated(string id)
    signal createRequested()

    function s(val) { return typeof scaleFunc === "function" ? scaleFunc(val) : val; }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    readonly property color cSurface1: ThemeBackend.surface1
    readonly property color cText: ThemeBackend.text
    readonly property color cSubtext0: ThemeBackend.subtext0
    readonly property color cMauve: ThemeBackend.mauve
    readonly property color cCrust: ThemeBackend.crust

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(8)

            Text {
                text: I18n.t("quickactions.notepad.title")
                font.family: ThemeBackend.fontFamily
                font.bold: true
                font.pixelSize: root.s(14)
                color: root.cText
            }

            Item { Layout.fillWidth: true }

            ClickButton {
                buttonText: I18n.t("quickactions.notepad.new")
                onTriggered: root.createRequested()
            }

            DeleteButton {
                Layout.preferredWidth: root.s(30)
                Layout.preferredHeight: root.s(30)
                enabled: root.selectedId !== ""
                onTriggered: NotesManager.deleteNoteAtIndex(NotesManager.activeIndex())
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: notesList
                anchors.fill: parent
                spacing: root.s(4)
                model: NotesManager.notesModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: parent
                    visible: NotesManager.notesModel.count === 0
                    text: I18n.t("quickactions.notepad.empty_list")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: root.cSubtext0
                    horizontalAlignment: Text.AlignHCenter
                }

                delegate: Item {
                    id: noteDelegateWrapper
                    width: notesList.width
                    height: noteDelegateWrapper.isDismissing ? 0 : noteDelegateCard.height

                    property bool isSelected: model.id === root.selectedId
                    property real dragX: 0
                    property bool isDismissing: false

                    scale: (noteCardMa.pressed && !noteCardMa.draggingH) ? 0.98 : 1.0
                    Behavior on scale {
                        enabled: !noteCardMa.draggingH
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
                    }

                    NumberAnimation {
                        id: noteResetAnim
                        target: noteDelegateWrapper
                        property: "dragX"
                        from: noteDelegateWrapper.dragX
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: noteDismissAnim
                        target: noteDelegateWrapper
                        property: "dragX"
                        from: noteDelegateWrapper.dragX
                        to: 0
                        duration: 200
                        easing.type: Easing.OutQuad
                        onFinished: NotesManager.deleteNoteAtIndex(index)
                    }

                    Rectangle {
                        id: noteDelegateCard
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: root.s(52)
                        radius: Math.min(ThemeBackend.borderRadius, root.s(12))
                        color: {
                            if (noteDelegateWrapper.isSelected) return root.cMauve;
                            return noteCardMa.containsMouse && !noteCardMa.draggingH
                                ? Qt.lighter(root.cSurface1, 1.04) : root.cSurface1;
                        }
                        clip: true

                        transform: Translate { x: noteDelegateWrapper.dragX }
                        opacity: Math.max(0.0, 1.0 - (Math.abs(noteDelegateWrapper.dragX) / (noteDelegateCard.width * 0.75)))

                        Behavior on color {
                            enabled: !noteCardMa.draggingH
                            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: root.s(12)
                            anchors.rightMargin: root.s(12)
                            spacing: root.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: NotesManager.noteTitle({ content: model.content, title: model.title })
                                font.family: ThemeBackend.fontFamily
                                font.bold: noteDelegateWrapper.isSelected
                                font.pixelSize: root.s(12)
                                color: noteDelegateWrapper.isSelected ? root.cCrust : root.cText
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: NotesManager.previewSnippet(model.content)
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                color: noteDelegateWrapper.isSelected
                                    ? root.alpha(root.cCrust, 0.85)
                                    : root.cSubtext0
                                elide: Text.ElideRight
                                maximumLineCount: 1

                                Behavior on color {
                                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: model.updatedAt > 0
                                text: {
                                    let d = new Date(model.updatedAt);
                                    return d.toLocaleDateString() + " " + d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(8)
                                color: noteDelegateWrapper.isSelected
                                    ? root.alpha(root.cCrust, 0.65)
                                    : root.alpha(root.cSubtext0, 0.75)
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: noteCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !noteDelegateWrapper.isDismissing
                            cursorShape: Qt.PointingHandCursor

                            property real startRootX: 0
                            property real startRootY: 0
                            property bool draggingH: false

                            onPressed: (mouse) => {
                                let pt = mapToItem(notesList, mouse.x, mouse.y);
                                startRootX = pt.x;
                                startRootY = pt.y;
                                draggingH = false;
                                noteResetAnim.stop();
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                let pt = mapToItem(notesList, mouse.x, mouse.y);
                                let dx = pt.x - startRootX;
                                let dy = pt.y - startRootY;

                                if (!draggingH) {
                                    if (Math.abs(dx) > root.s(6) && Math.abs(dx) > Math.abs(dy)) {
                                        draggingH = true;
                                        noteCardMa.preventStealing = true;
                                    }
                                }

                                if (draggingH)
                                    noteDelegateWrapper.dragX = dx;
                            }

                            onReleased: (mouse) => {
                                noteCardMa.preventStealing = false;
                                if (draggingH) {
                                    let threshold = noteDelegateCard.width * 0.25;
                                    if (Math.abs(noteDelegateWrapper.dragX) > threshold) {
                                        noteDelegateWrapper.isDismissing = true;
                                        noteDismissAnim.from = noteDelegateWrapper.dragX;
                                        noteDismissAnim.to = noteDelegateWrapper.dragX > 0
                                            ? noteDelegateCard.width * 1.2
                                            : -noteDelegateCard.width * 1.2;
                                        noteDismissAnim.start();
                                    } else {
                                        noteResetAnim.from = noteDelegateWrapper.dragX;
                                        noteResetAnim.start();
                                    }
                                    draggingH = false;
                                } else {
                                    root.noteActivated(model.id);
                                }
                            }

                            onCanceled: {
                                noteCardMa.preventStealing = false;
                                if (draggingH) {
                                    noteResetAnim.from = noteDelegateWrapper.dragX;
                                    noteResetAnim.start();
                                    draggingH = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
