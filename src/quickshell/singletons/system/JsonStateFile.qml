import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property string path: ""
    property bool watchChanges: false
    property bool printErrors: false
    property bool preload: true
    property string lastWrittenText: ""

    signal loaded(var data)
    signal loadFailed()

    onPathChanged: {
        lastWrittenText = "";
    }

    function reload() {
        if (root.path) {
            fileView.reload();
        }
    }

    function save(obj) {
        if (!root.path) return;
        let payload = JSON.stringify(obj);
        root.lastWrittenText = payload.trim();
        fileView.setText(payload + "\n");
    }

    FileView {
        id: fileView
        path: root.path
        watchChanges: root.watchChanges
        printErrors: root.printErrors
        preload: root.preload
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            let raw = typeof text === "function" ? text() : text;
            let trimmed = raw ? String(raw).trim() : "";
            if (root.lastWrittenText !== "" && trimmed === root.lastWrittenText) {
                return;
            }
            if (trimmed === "") {
                root.loaded(null);
                return;
            }
            try {
                root.loaded(JSON.parse(trimmed));
            } catch (e) {
                root.loadFailed();
            }
        }
        onLoadFailed: root.loadFailed()
    }
}
