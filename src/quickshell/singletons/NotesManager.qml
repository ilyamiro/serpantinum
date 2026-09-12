pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    ListModel { id: notesModelInternal }
    property alias notesModel: notesModelInternal

    property string activeId: ""
    property bool loaded: false
    property bool suppressSave: false

    property string previewHtml: ""
    property bool useQtFallback: false
    property string pendingRenderId: ""

    readonly property string notesPath: Caching.getStateDir("notepad") + "/notes.json"
    readonly property string renderInputPath: Caching.getRunDir("notepad") + "/render_in.json"
    readonly property string mdRenderScript: Caching.serpantinumDir + "/scripts/notepad/md_render.py"

    signal renderFinished(string noteId, string html, bool useFallback)

    FileView {
        id: notesFile
        path: root.notesPath
        watchChanges: false
    }

    FileView {
        id: renderInputFile
        path: root.renderInputPath
    }

    Process {
        id: loadNotesProc
        command: ["cat", root.notesPath]
        stdout: StdioCollector {
            id: loadNotesCollector
            onStreamFinished: root.loadFromText(loadNotesCollector.text)
        }
        onExited: (exitCode) => {
            if (!root.loaded) root.markMissing();
        }
    }

    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.persistNotes()
    }

    Timer {
        id: renderTimer
        interval: 120
        repeat: false
        property string noteId: ""
        onTriggered: root.runPendingRender()
    }

    Process {
        id: renderProc
        command: ["python3", root.mdRenderScript, root.renderInputPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let noteId = root.pendingRenderId;
                if (!noteId) return;
                let html = this.text.trim();
                if (html !== "") {
                    root.previewHtml = html;
                    root.useQtFallback = false;
                    root.renderFinished(noteId, html, false);
                } else {
                    root.applyQtFallback(noteId);
                }
                root.pendingRenderId = "";
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.pendingRenderId)
                root.applyQtFallback(root.pendingRenderId);
        }
    }

    Component.onCompleted: {
        loadFromDisk();
        if (!renderInputFile.text() || renderInputFile.text().trim() === "")
            renderInputFile.setText("{}");
    }

    function newId() {
        return "n_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 1e6).toString(36);
    }

    function stripMarkdown(line) {
        if (!line) return "";
        line = line.replace(/^#+\s*/, "");
        line = line.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
        line = line.replace(/\*\*(.*?)\*\*/g, "$1");
        line = line.replace(/__(.*?)__/g, "$1");
        line = line.replace(/\*(.*?)\*/g, "$1");
        line = line.replace(/`(.*?)`/g, "$1");
        line = line.replace(/~~(.*?)~~/g, "$1");
        line = line.replace(/\[([ xX])\]\s*/g, "");
        line = line.replace(/(^|\s)[-*+]\s+/g, "$1");
        line = line.replace(/(^|\s)\d+\.\s+/g, "$1");
        return line.trim();
    }

    function derivedTitle(note) {
        if (!note || !note.content) return I18n.t("quickactions.notepad.untitled");
        let lines = note.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = root.stripMarkdown(lines[i]);
            if (line !== "") return line;
        }
        return I18n.t("quickactions.notepad.untitled");
    }

    function explicitTitle(note) {
        return (note && note.title) ? note.title : "";
    }

    function noteTitle(note) {
        if (note && note.title && note.title.trim() !== "") return note.title;
        return root.derivedTitle(note);
    }

    function titleLineIndex(note) {
        if (!note || !note.content) return -1;
        let lines = note.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            if (root.stripMarkdown(lines[i]) !== "") return i;
        }
        return -1;
    }

    function bodyMarkdown(note) {
        if (!note || !note.content) return "";
        let lines = note.content.split("\n");
        let idx = root.titleLineIndex(note);
        let start = 0;
        if (idx >= 0) {
            let hasExplicit = note.title && note.title.trim() !== "";
            let stripped = root.stripMarkdown(lines[idx]);
            if (!hasExplicit || stripped === note.title.trim()) start = idx + 1;
        }
        return lines.slice(start).join("\n").trim();
    }

    function notePreview(note) {
        let body = root.bodyMarkdown(note);
        if (!body || body.trim() === "") return I18n.t("quickactions.notepad.tap_to_write");
        let preview = root.stripMarkdown(body.replace(/\n/g, " ").replace(/\s+/g, " ").trim());
        return preview.length > 60 ? preview.substring(0, 60) + "…" : preview;
    }

    function getNoteById(id) {
        let idx = root.indexOfId(id);
        return idx >= 0 ? notesModelInternal.get(idx) : null;
    }

    function indexOfId(id) {
        for (let i = 0; i < notesModelInternal.count; i++) {
            if (notesModelInternal.get(i).id === id) return i;
        }
        return -1;
    }

    function activeNote() {
        return root.getNoteById(root.activeId);
    }

    function activeIndex() {
        return root.indexOfId(root.activeId);
    }

    function loadFromDisk() {
        if (!loadNotesProc.running) loadNotesProc.running = true;
    }

    function loadFromText(raw) {
        if (root.loaded) return;
        notesModelInternal.clear();
        if (!raw || raw.trim() === "") {
            root.activeId = "";
            root.loaded = true;
            return;
        }
        try {
            let data = JSON.parse(raw);
            let notes = Array.isArray(data.notes) ? data.notes : [];
            for (let i = 0; i < notes.length; i++)
                notesModelInternal.append(notes[i]);
            root.activeId = data.activeId || "";
            if (root.activeId && root.indexOfId(root.activeId) < 0)
                root.activeId = notesModelInternal.count > 0 ? notesModelInternal.get(0).id : "";
        } catch (e) {
            notesModelInternal.clear();
            root.activeId = "";
        }
        root.loaded = true;
    }

    function markMissing() {
        notesModelInternal.clear();
        root.activeId = "";
        root.loaded = true;
    }

    function isEmptyNote(note) {
        if (!note) return true;
        let title = (note.title || "").trim();
        let content = (note.content || "").trim();
        return title === "" && content === "";
    }

    function pruneEmptyNote(id) {
        let idx = root.indexOfId(id);
        if (idx < 0) return false;
        if (!root.isEmptyNote(notesModelInternal.get(idx))) return false;
        notesModelInternal.remove(idx);
        if (root.activeId === id) {
            if (notesModelInternal.count === 0)
                root.activeId = "";
            else
                root.activeId = notesModelInternal.get(Math.min(idx, notesModelInternal.count - 1)).id;
        }
        saveTimer.stop();
        root.persistNotes();
        return true;
    }

    function persistNotes() {
        if (!root.loaded || root.suppressSave) return;
        let notes = [];
        let activeExists = false;
        for (let i = 0; i < notesModelInternal.count; i++) {
            let note = notesModelInternal.get(i);
            if (root.isEmptyNote(note)) continue;
            notes.push(note);
            if (note.id === root.activeId) activeExists = true;
        }
        notesFile.setText(JSON.stringify({
            activeId: activeExists ? root.activeId : "",
            notes: notes
        }, null, 2));
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    function setActiveId(id) {
        root.activeId = id;
        root.scheduleSave();
    }

    function colorToHex(c) {
        if (!c) return "#ffffff";
        function channel(v) {
            let n = Math.round(Math.max(0, Math.min(1, v)) * 255);
            let h = n.toString(16);
            return h.length === 1 ? "0" + h : h;
        }
        return "#" + channel(c.r) + channel(c.g) + channel(c.b);
    }

    function themePayload() {
        return {
            text: colorToHex(ThemeBackend.text),
            base: colorToHex(ThemeBackend.base),
            mantle: colorToHex(ThemeBackend.mantle),
            mauve: colorToHex(ThemeBackend.mauve),
            surface0: colorToHex(ThemeBackend.surface0),
            subtext0: colorToHex(ThemeBackend.subtext0),
            fontFamily: ThemeBackend.fontFamily
        };
    }

    function scheduleRender(noteId) {
        if (!noteId) return;
        renderTimer.noteId = noteId;
        renderTimer.restart();
    }

    function runPendingRender() {
        let noteId = renderTimer.noteId;
        if (!noteId) return;
        let note = root.getNoteById(noteId);
        if (!note) return;
        root.pendingRenderId = noteId;
        renderInputFile.setText(JSON.stringify({
            markdown: note.content || "",
            theme: root.themePayload(),
            emptyHint: I18n.t("quickactions.notepad.tap_to_write")
        }));
        renderProc.running = false;
        renderProc.running = true;
    }

    function applyQtFallback(noteId) {
        let note = root.getNoteById(noteId);
        let content = note && note.content ? note.content : "";
        root.previewHtml = content;
        root.useQtFallback = true;
        root.renderFinished(noteId, content, true);
        root.pendingRenderId = "";
    }

    function updateNoteContent(id, text) {
        let idx = root.indexOfId(id);
        if (idx < 0) return;
        let note = notesModelInternal.get(idx);
        note.content = text;
        note.updatedAt = Date.now();
        notesModelInternal.set(idx, note);
        root.scheduleSave();
    }

    function updateNoteTitle(id, text) {
        let idx = root.indexOfId(id);
        if (idx < 0) return;
        let note = notesModelInternal.get(idx);
        note.title = text;
        note.updatedAt = Date.now();
        notesModelInternal.set(idx, note);
        root.scheduleSave();
    }

    function createNote() {
        let note = {
            id: root.newId(),
            title: "",
            content: "",
            updatedAt: Date.now()
        };
        notesModelInternal.insert(0, note);
        root.activeId = note.id;
        root.scheduleSave();
        return note.id;
    }

    function deleteNoteAtIndex(idx) {
        if (idx < 0 || idx >= notesModelInternal.count) return;
        let removedId = notesModelInternal.get(idx).id;
        notesModelInternal.remove(idx);
        if (root.activeId === removedId) {
            if (notesModelInternal.count === 0)
                root.activeId = "";
            else
                root.activeId = notesModelInternal.get(Math.min(idx, notesModelInternal.count - 1)).id;
        }
        root.persistNotes();
    }

    function deleteNoteById(id) {
        let idx = root.indexOfId(id);
        if (idx >= 0) root.deleteNoteAtIndex(idx);
    }

    function previewSnippet(content) {
        if (!content || content.trim() === "")
            return I18n.t("quickactions.notepad.tap_to_write");
        let preview = root.stripMarkdown(content.replace(/\n/g, " ").trim());
        return preview.length > 60 ? preview.substring(0, 60) + "…" : preview;
    }
}
