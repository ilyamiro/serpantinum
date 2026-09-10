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

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a);
    }

    function fmtDate(ts) {
        if (!ts) return "";
        let d = new Date(ts);
        function pad(n) { return (n < 10 ? "0" : "") + n; }
        return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
    }

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
                Layout.alignment: Qt.AlignVCenter
                text: I18n.t("quickactions.notepad.title")
                font.family: ThemeBackend.fontFamily
                font.bold: true
                font.pixelSize: root.s(13)
                color: root.cText
            }

            Item { Layout.fillWidth: true }

            ClickButton {
                Layout.alignment: Qt.AlignVCenter
                buttonText: I18n.t("quickactions.notepad.new")
                buttonIcon: "󰐕"
                iconFontSize: root.s(12)
                textFontSize: root.s(11)
                horizontalPadding: root.s(10)
                cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onTriggered: root.createRequested()
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
                    width: parent.width - root.s(24)
                    visible: NotesManager.notesModel.count === 0
                    text: I18n.t("quickactions.notepad.empty_list")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: root.cSubtext0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                delegate: Item {
                    id: noteWrapper
                    width: notesList.width
                    height: card.height

                    readonly property bool isSelected: model.id === root.selectedId
                    property bool expanded: false
                    property real expandProgress: expanded ? 1.0 : 0.0
                    property real dragX: 0
                    property bool isDismissing: false
                    property bool canExpand: {
                        let c = model.content || "";
                        if (c.indexOf("\n") !== -1) return true;
                        return c.length > 60;
                    }

                    Behavior on expandProgress {
                        enabled: !cardMa.draggingV
                        NumberAnimation { duration: 260; easing.type: Easing.OutQuart }
                    }

                    NumberAnimation {
                        id: resetAnim
                        target: noteWrapper
                        property: "dragX"
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: dismissAnim
                        target: noteWrapper
                        property: "dragX"
                        duration: 200
                        easing.type: Easing.OutQuad
                        property string dismissId: ""
                        onFinished: NotesManager.deleteNoteById(dismissId)
                    }

                    Rectangle {
                        id: card
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        readonly property real baseH: root.s(54)
                        readonly property real expandedH: root.s(176)
                        height: baseH + (expandedH - baseH) * noteWrapper.expandProgress

                        radius: Math.min(ThemeBackend.borderRadius, root.s(12))
                        clip: true
                        transform: Translate { x: noteWrapper.dragX }
                        opacity: Math.max(0.0, 1.0 - (Math.abs(noteWrapper.dragX) / (card.width * 0.75)))
                        color: {
                            if (noteWrapper.isSelected) return root.cMauve;
                            if (cardMa.containsMouse && !cardMa.draggingH) return Qt.lighter(root.cSurface1, 1.04);
                            return root.cSurface1;
                        }
                        Behavior on color {
                            enabled: !cardMa.draggingH
                            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            id: headerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: root.s(12)
                            anchors.rightMargin: root.s(12)
                            anchors.topMargin: root.s(9)
                            spacing: root.s(1)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(6)

                                Text {
                                    Layout.fillWidth: true
                                    text: NotesManager.noteTitle({ content: model.content, title: model.title })
                                    font.family: ThemeBackend.fontFamily
                                    font.bold: true
                                    font.pixelSize: root.s(12)
                                    color: noteWrapper.isSelected ? root.cCrust : root.cText
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.fmtDate(model.updatedAt)
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(8)
                                    color: noteWrapper.isSelected ? root.alpha(root.cCrust, 0.65) : root.alpha(root.cSubtext0, 0.75)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: noteWrapper.canExpand
                                    text: noteWrapper.expanded ? "󰅁" : "󰅀"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(11)
                                    color: noteWrapper.isSelected ? root.alpha(root.cCrust, 0.8) : root.cSubtext0
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: NotesManager.notePreview({ title: model.title, content: model.content })
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                color: noteWrapper.isSelected ? root.alpha(root.cCrust, 0.85) : root.cSubtext0
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        Flickable {
                            id: expandView
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: headerCol.bottom
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: root.s(12)
                            anchors.rightMargin: root.s(12)
                            anchors.topMargin: root.s(6)
                            anchors.bottomMargin: root.s(8)
                            visible: noteWrapper.expandProgress > 0.01
                            opacity: Math.max(0.0, Math.min(1.0, (noteWrapper.expandProgress - 0.15) * 1.6))
                            clip: true
                            contentWidth: width
                            contentHeight: expandedText.paintedHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: expandedText
                                width: parent.width
                                text: {
                                    let body = NotesManager.bodyMarkdown({ title: model.title, content: model.content });
                                    return body !== "" ? body : I18n.t("quickactions.notepad.tap_to_write");
                                }
                                color: noteWrapper.isSelected ? root.alpha(root.cCrust, 0.9) : root.cText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !noteWrapper.isDismissing
                            cursorShape: Qt.PointingHandCursor

                            property real startRootX: 0
                            property real startRootY: 0
                            property bool draggingH: false
                            property bool draggingV: false

                            onPressed: (mouse) => {
                                let pt = mapToItem(notesList, mouse.x, mouse.y);
                                startRootX = pt.x;
                                startRootY = pt.y;
                                draggingH = false;
                                draggingV = false;
                                resetAnim.stop();
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                let pt = mapToItem(notesList, mouse.x, mouse.y);
                                let dx = pt.x - startRootX;
                                let dy = pt.y - startRootY;

                                if (!draggingH && !draggingV) {
                                    if (Math.abs(dx) > root.s(6) && Math.abs(dx) > Math.abs(dy)) {
                                        draggingH = true;
                                        cardMa.preventStealing = true;
                                    } else if (noteWrapper.canExpand && Math.abs(dy) > root.s(6) && Math.abs(dy) >= Math.abs(dx)) {
                                        draggingV = true;
                                        cardMa.preventStealing = true;
                                    }
                                }

                                if (draggingH) {
                                    noteWrapper.dragX = dx;
                                } else if (draggingV && noteWrapper.canExpand) {
                                    let dragDist = root.s(120);
                                    let target = noteWrapper.expanded
                                        ? Math.max(0.0, Math.min(1.0, 1.0 + (dy / dragDist)))
                                        : Math.max(0.0, Math.min(1.0, dy / dragDist));
                                    noteWrapper.expandProgress = target;
                                }
                            }

                            onReleased: (mouse) => {
                                cardMa.preventStealing = false;
                                if (draggingH) {
                                    let threshold = card.width * 0.25;
                                    if (Math.abs(noteWrapper.dragX) > threshold) {
                                        noteWrapper.isDismissing = true;
                                        dismissAnim.dismissId = model.id;
                                        dismissAnim.from = noteWrapper.dragX;
                                        dismissAnim.to = noteWrapper.dragX > 0 ? card.width * 1.2 : -card.width * 1.2;
                                        dismissAnim.start();
                                    } else {
                                        resetAnim.from = noteWrapper.dragX;
                                        resetAnim.start();
                                    }
                                    draggingH = false;
                                } else if (draggingV && noteWrapper.canExpand) {
                                    if (!noteWrapper.expanded && noteWrapper.expandProgress > 0.35) {
                                        noteWrapper.expanded = true;
                                        notesList.positionViewAtIndex(index, ListView.Contain);
                                    } else if (noteWrapper.expanded && noteWrapper.expandProgress < 0.65) {
                                        noteWrapper.expanded = false;
                                    }
                                    noteWrapper.expandProgress = Qt.binding(() => noteWrapper.expanded ? 1.0 : 0.0);
                                    draggingV = false;
                                } else {
                                    root.noteActivated(model.id);
                                }
                            }

                            onCanceled: {
                                cardMa.preventStealing = false;
                                if (draggingH) {
                                    resetAnim.from = noteWrapper.dragX;
                                    resetAnim.start();
                                    draggingH = false;
                                }
                                if (draggingV && noteWrapper.canExpand) {
                                    noteWrapper.expandProgress = Qt.binding(() => noteWrapper.expanded ? 1.0 : 0.0);
                                    draggingV = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
