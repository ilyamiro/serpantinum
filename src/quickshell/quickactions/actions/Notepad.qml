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
    property bool keepAlive: inNoteView && (isEditing || titleInput.activeFocus)
    property bool isEditing: false
    property bool inNoteView: false
    property bool suppressSave: false
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"
    property string titleDraft: ""

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a);
    }

    property real baseW: s(360)
    property real baseL: s(400)
    property real preferredWidth: (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseL + 50 : baseW

    readonly property real panelChrome: (typeof panelChromeLength !== "undefined") ? panelChromeLength : root.s(120)
    readonly property int noteCount: NotesManager.notesModel.count
    readonly property int maxListRows: 6
    readonly property real rowUnit: root.s(58)
    readonly property real listChrome: root.s(24) + root.s(30) + root.s(8) + root.s(4)
    readonly property real listAreaHeight: noteCount === 0 ? root.s(84) : (Math.min(noteCount, maxListRows) * root.rowUnit - root.s(4))
    readonly property real listDesired: root.listChrome + root.listAreaHeight

    readonly property real noteChrome: root.s(12) * 2 + root.s(30) + root.s(8)
    readonly property real noteBodyContent: root.isEditing ? editorArea.paintedHeight : previewArea.paintedHeight
    readonly property real noteDesired: root.noteChrome + Math.max(root.s(80), root.noteBodyContent + root.s(40))

    property real preferredExtraLength: {
        if (root.inNoteView) {
            let cap = (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseW : baseL;
            let len = Math.max(root.s(120), root.noteDesired - root.panelChrome + root.s(8));
            return Math.min(len, cap);
        }
        return Math.max(root.s(40), root.listDesired - root.panelChrome + root.s(8));
    }

    property real counterRotation: {
        if (safeActiveEdge === "right") return 180;
        if (safeActiveEdge === "bottom") return 90;
        if (safeActiveEdge === "top") return -90;
        return 0;
    }

    readonly property color cBase: ThemeBackend.base
    readonly property color cMantle: ThemeBackend.mantle
    readonly property color cSurface0: ThemeBackend.surface0
    readonly property color cSurface1: ThemeBackend.surface1
    readonly property color cText: ThemeBackend.text
    readonly property color cSubtext0: ThemeBackend.subtext0
    readonly property color cMauve: ThemeBackend.mauve

    property var interceptedShortcuts: {
        let keys = [];
        if (inNoteView && titleInput.activeFocus)
            keys = keys.concat(["Return", "Enter", "Tab", "Shift+Tab"]);
        if (inNoteView && isEditing && editorArea.activeFocus)
            keys = keys.concat(["Return", "Enter", "Left", "Right", "Up", "Down", "Tab", "Shift+Tab", "Backspace"]);
        return keys;
    }

    function syncActiveNoteTitle() {
        root.titleDraft = NotesManager.explicitTitle(NotesManager.activeNote());
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
        if (NotesManager.pruneEmptyNote(NotesManager.activeId)) {
            root.inNoteView = false;
            return;
        }
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
        NotesManager.pruneEmptyNote(NotesManager.activeId);
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

    function deleteCurrentNote() {
        root.isEditing = false;
        NotesManager.deleteNoteById(NotesManager.activeId);
        root.closeNoteView();
    }

    onIsActiveTabChanged: {
        if (!isActiveTab) {
            root.finishEditing();
            if (NotesManager.pruneEmptyNote(NotesManager.activeId)) {
                root.isEditing = false;
                root.inNoteView = false;
            }
        }
    }

    Component.onCompleted: {
        if (!NotesManager.loaded)
            NotesManager.loadFromDisk();
        root.inNoteView = false;
        root.syncActiveNoteTitle();
    }

    Component.onDestruction: {
        NotesManager.pruneEmptyNote(NotesManager.activeId);
        NotesManager.persistNotes();
    }

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

                IconButton {
                    Layout.preferredWidth: root.s(30)
                    Layout.preferredHeight: root.s(30)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
                    buttonIcon: "󰁍"
                    iconFontSize: root.s(14)
                    accentColor: ThemeBackend.surface1
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0
                    onClicked: root.closeNoteView()
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(24)

                    TextInput {
                        id: titleInput
                        anchors.fill: parent
                        text: root.titleDraft
                        color: root.cText
                        font.family: ThemeBackend.fontFamily
                        font.bold: true
                        font.pixelSize: root.s(12)
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        selectionColor: root.alpha(root.cMauve, 0.35)
                        selectedTextColor: root.cText
                        clip: true
                        activeFocusOnTab: false
                        onTextEdited: {
                            root.titleDraft = text;
                            NotesManager.updateNoteTitle(NotesManager.activeId, text);
                        }
                        onAccepted: titleInput.focus = false
                        Keys.onEscapePressed: {
                            root.syncActiveNoteTitle();
                            titleInput.focus = false;
                            event.accepted = true;
                        }

                        Text {
                            anchors.fill: parent
                            visible: titleInput.text.length === 0 && !titleInput.activeFocus
                            text: NotesManager.derivedTitle(NotesManager.activeNote())
                            font.family: ThemeBackend.fontFamily
                            font.bold: true
                            font.pixelSize: root.s(12)
                            color: root.alpha(root.cSubtext0, 0.6)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                DeleteButton {
                    Layout.preferredWidth: root.s(30)
                    Layout.preferredHeight: root.s(30)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
                    iconFontSize: root.s(14)
                    textColor: isHoveredOrHighlighted ? ThemeBackend.crust : ThemeBackend.crust
                    onTriggered: root.deleteCurrentNote()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: root.isEditing ? root.cSurface0 : root.cBase
                    clip: true
                    Behavior on color { ColorAnimation { duration: 180 } }

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
                                    if (activeFocus || !root.isEditing) return;
                                    Qt.callLater(function() {
                                        if (root.isEditing && !editorArea.activeFocus && !titleInput.activeFocus)
                                            root.finishEditing();
                                    });
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
