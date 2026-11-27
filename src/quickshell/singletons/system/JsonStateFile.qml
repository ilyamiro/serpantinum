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
    property bool _inCallback: false
    property string _pendingWriteText: ""
    property bool _hasPendingWrite: false
    property bool _pendingReload: false

    signal loaded(var data)
    signal loadFailed()

    onPathChanged: {
        lastWrittenText = "";
        _pendingWriteText = "";
        _hasPendingWrite = false;
        _pendingReload = false;
    }

    function _flushPending() {
        if (!root.path) {
            _pendingWriteText = "";
            _hasPendingWrite = false;
            _pendingReload = false;
            return;
        }
        if (_hasPendingWrite) {
            let textOut = _pendingWriteText;
            _pendingWriteText = "";
            _hasPendingWrite = false;
            _pendingReload = false;
            fileView.setText(textOut);
            return;
        }
        if (_pendingReload) {
            _pendingReload = false;
            fileView.reload();
        }
    }

    function reload() {
        if (!root.path) return;
        if (_inCallback) {
            _pendingReload = true;
            Qt.callLater(root._flushPending);
            return;
        }
        fileView.reload();
    }

    function save(obj) {
        if (!root.path) return;
        let payload = JSON.stringify(obj);
        root.lastWrittenText = payload.trim();
        let textOut = payload + "\n";
        if (_inCallback) {
            _pendingWriteText = textOut;
            _hasPendingWrite = true;
            Qt.callLater(root._flushPending);
            return;
        }
        fileView.setText(textOut);
    }

    FileView {
        id: fileView
        path: root.path
        watchChanges: root.watchChanges
        printErrors: root.printErrors
        preload: root.preload
        atomicWrites: true
        onFileChanged: {
            if (!root.path) return;
            root._pendingReload = true;
            Qt.callLater(root._flushPending);
        }
        onLoaded: {
            let raw = typeof text === "function" ? text() : text;
            let trimmed = raw ? String(raw).trim() : "";
            if (root.lastWrittenText !== "" && trimmed === root.lastWrittenText) {
                return;
            }
            root._inCallback = true;
            try {
                if (trimmed === "") {
                    root.loaded(null);
                } else {
                    let parsed;
                    let ok = true;
                    try {
                        parsed = JSON.parse(trimmed);
                    } catch (e) {
                        ok = false;
                    }
                    if (ok) root.loaded(parsed);
                    else root.loadFailed();
                }
            } finally {
                root._inCallback = false;
            }
        }
        onLoadFailed: {
            root._inCallback = true;
            try {
                root.loadFailed();
            } finally {
                root._inCallback = false;
            }
        }
    }
}
