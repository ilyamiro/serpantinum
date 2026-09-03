//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../singletons"
import "../../"
import "../../reusables"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property bool keepAlive: inNoteView && isEditing
    property bool isEditing: false
    property bool inNoteView: false
    property bool suppressSave: false
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"
    property string activeNoteTitle: ""

    function s(val) { return typeof scaleFunc === "function" ? scaleFunc(val) : val; }

    property real baseW: s(380)
    property real baseL: s(420)
    property real preferredWidth: (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (safeActiveEdge === "right") return 180;
        if (safeActiveEdge === "bottom") return 90;
        if (safeActiveEdge === "top") return -90;
        return 0;
    }

    property color cBase: ThemeBackend.base
    property color cMantle: ThemeBackend.mantle
    property color cSurface1: ThemeBackend.surface1
    property color cText: ThemeBackend.text
    property color cSubtext0: ThemeBackend.subtext0
    property color cMauve: ThemeBackend.mauve

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    property var interceptedShortcuts: {
        if (!inNoteView || !isEditing || !editorArea.activeFocus) return [];
        return ["Return", "Enter", "Left", "Right", "Up", "Down", "Tab", "Shift+Tab", "Backspace"];
    }

    function syncActiveNoteTitle() {
        root.activeNoteTitle = NotesManager.noteTitle(NotesManager.activeNote());
    }

    function scheduleRender() {
        if (!inNoteView || isEditing) return;
        NotesManager.scheduleRender(NotesManager.activeId);
    }

    function beginEditing() {
        root.isEditing = true;
        root.suppressSave = true;
        let note = NotesManager.activeNote();
        editorArea.text = note ? (note.content || "") : "";
        root.suppressSave = false;
        Qt.callLater(() => editorArea.forceActiveFocus());
    }

    function finishEditing() {
        if (!root.isEditing) return;
        NotesManager.updateNoteContent(NotesManager.activeId, editorArea.text);
        root.syncActiveNoteTitle();
        root.isEditing = false;
        root.scheduleRender();
    }

    function openNote(id) {
        NotesManager.setActiveId(id);
        root.inNoteView = true;
        root.isEditing = false;
        root.syncActiveNoteTitle();
        root.scheduleRender();
    }

    function closeNoteView() {
        root.finishEditing();
        NotesManager.persistNotes();
        root.inNoteView = false;
        root.isEditing = false;
    }

    function createNote() {
        let id = NotesManager.createNote();
        root.openNote(id);
        root.beginEditing();
    }

    function selectNote(id) {
        root.finishEditing();
        root.openNote(id);
    }

    onIsActiveTabChanged: {
        if (!isActiveTab && isEditing) root.finishEditing();
    }

    Component.onCompleted: {
        if (!NotesManager.loaded)
            NotesManager.loadFromDisk();
        root.inNoteView = false;
        root.syncActiveNoteTitle();
    }

    Component.onDestruction: NotesManager.persistNotes()

    Connections {
        target: NotesManager
        function onActiveIdChanged() {
            root.syncActiveNoteTitle();
        }
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.cMantle
            radius: ThemeBackend.borderRadius
            z: -1
        }

        NotesList {
            anchors.fill: parent
            anchors.margins: root.s(12)
            z: 0
            visible: !root.inNoteView
            opacity: root.inNoteView ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 180 } }
            scaleFunc: root.s
            selectedId: NotesManager.activeId
            onNoteActivated: (id) => root.selectNote(id)
            onCreateRequested: root.createNote()
        }

        ColumnLayout {
            id: noteViewLayer
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)
            z: 1
            visible: root.inNoteView
            opacity: root.inNoteView ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(6)
                z: 2

                ClickButton {
                    buttonText: I18n.t("quickactions.notepad.back_to_list")
                    onTriggered: root.closeNoteView()
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(20)

                    Text {
                        anchors.fill: parent
                        text: root.activeNoteTitle
                        font.family: ThemeBackend.fontFamily
                        font.bold: true
                        font.pixelSize: root.s(12)
                        color: root.cText
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: root.cBase
                    border.width: 1
                    border.color: root.isEditing ? root.cMauve : root.cSurface1
                    clip: true

                    Item {
                        anchors.fill: parent
                        visible: !root.isEditing
                        opacity: root.isEditing ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: root.s(8)
                            contentWidth: width
                            contentHeight: Math.max(height, previewArea.paintedHeight + root.s(48))
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: previewArea
                                width: parent.width
                                readOnly: true
                                selectByMouse: false
                                focus: false
                                textFormat: NotesManager.useQtFallback ? TextEdit.MarkdownText : TextEdit.RichText
                                text: NotesManager.useQtFallback
                                    ? ((NotesManager.activeNote() && NotesManager.activeNote().content)
                                        ? NotesManager.activeNote().content : "")
                                    : NotesManager.previewHtml
                                color: root.cText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                wrapMode: TextEdit.Wrap
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.isEditing
                            cursorShape: Qt.IBeamCursor

                            property real pressY: 0
                            property bool didDrag: false

                            onPressed: (mouse) => {
                                pressY = mouse.y;
                                didDrag = false;
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed || root.isEditing) return;
                                if (Math.abs(mouse.y - pressY) > root.s(4))
                                    didDrag = true;
                            }

                            onReleased: {
                                if (!didDrag)
                                    root.beginEditing();
                            }

                            onCanceled: {
                                didDrag = false;
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.isEditing
                        opacity: root.isEditing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: root.s(14)
                            visible: editorArea.text.length === 0
                            text: I18n.t("quickactions.notepad.placeholder")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            color: root.alpha(root.cSubtext0, 0.65)
                            z: 1
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: root.s(10)
                            contentWidth: width
                            contentHeight: Math.max(height, editorArea.paintedHeight + root.s(24))
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: editorArea
                                width: parent.width
                                color: root.cText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                selectionColor: root.alpha(root.cMauve, 0.35)
                                selectedTextColor: root.cText

                                onTextChanged: {
                                    if (root.suppressSave) return;
                                    NotesManager.updateNoteContent(NotesManager.activeId, text);
                                    root.syncActiveNoteTitle();
                                }

                                onActiveFocusChanged: {
                                    if (!activeFocus && root.isEditing)
                                        root.finishEditing();
                                }

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        root.finishEditing();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
