pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../../"
import "AudioCache.js" as AudioCache

Singleton {
    id: root

    function pipewireNodes() {
        try {
            const model = Pipewire.nodes;
            const list = model ? model.values : null;
            return list ? list : [];
        } catch (e) {
            return [];
        }
    }

    property var trackedNodes: []

    function refreshTrackedNodes() {
        const list = root.pipewireNodes();
        root.trackedNodes = list ? list : [];
    }

    Connections {
        target: Pipewire.nodes ?? null
        ignoreUnknownSignals: true
        function onValuesChanged() {
            root.refreshTrackedNodes();
        }
    }

    Component.onCompleted: {
        root.refreshTrackedNodes();
        root.refreshActiveStream();
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    function isSerpantinumStream(node) {
        if (!node || !node.properties) return false;
        let p = node.properties;
        let appId = p["application.id"] || "";
        let appName = p["application.name"] || "";
        if (appId === "serpantinum-sfx" || appId === "serpantinum" || appId === "org.serpantinum.sfx") return true;
        if (appName === "serpantinum-sfx" || appName === "serpantinum") return true;
        if (p["node.group"] === "serpantinum-audio" || p["node.link-group"] === "serpantinum-audio") return true;
        let mediaFile = p["media.filename"] || p["media.name"] || "";
        if (mediaFile.indexOf("assets/sounds/") !== -1) return true;
        return false;
    }

    readonly property var outputs: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (!n.isStream && n.isSink && n.audio) arr.push(n);
        }
        return AudioCache.updateOutputs(arr);
    }

    readonly property var inputs: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (!n.isStream && !n.isSink && n.audio
                && n.properties?.["device.class"] !== "monitor"
                && !n.name?.endsWith(".monitor")) {
                arr.push(n);
            }
        }
        return AudioCache.updateInputs(arr);
    }

    readonly property var apps: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (n.isStream && n.audio
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol"
                && !isSerpantinumStream(n)) {
                arr.push(n);
            }
        }
        return AudioCache.updateApps(arr);
    }

    function computeHasActiveStream(list) {
        try {
            for (const n of list ?? []) {
                if (!n || !n.audio) continue;
                let p = n.properties;
                if (!p || p["media.class"] !== "Stream/Output/Audio") continue;
                let corked = p["pulse.corked"];
                if (corked === "true" || corked === true) continue;
                if (n.audio.muted || (n.audio.volume !== undefined && n.audio.volume <= 0.001)) continue;
                return true;
            }
        } catch (e) {
        }
        return false;
    }

    property bool hasActiveStream: false

    function refreshActiveStream() {
        const active = root.computeHasActiveStream(root.apps) === true;
        if (root.hasActiveStream !== active) root.hasActiveStream = active;
    }

    onAppsChanged: root.refreshActiveStream()

    Instantiator {
        model: root.apps

        delegate: QtObject {
            id: streamWatch
            required property var modelData

            property Connections nodeConnections: Connections {
                target: streamWatch.modelData
                ignoreUnknownSignals: true
                function onPropertiesChanged() { root.refreshActiveStream(); }
            }

            property Connections audioConnections: Connections {
                target: streamWatch.modelData ? streamWatch.modelData.audio : null
                ignoreUnknownSignals: true
                function onMutedChanged() { root.refreshActiveStream(); }
                function onVolumesChanged() { root.refreshActiveStream(); }
            }
        }
    }

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink

    readonly property string activeOutputName: root.defaultSink && root.defaultSink.name ? root.defaultSink.name : ""
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    // Some codecs report a fixed hardware level when the machine boots. The
    // session manager restores the route, the codec overrides it and the sink
    // ends up at that fixed level (41% on the ALC245), so the volume the user
    // left is lost. Keep the last level of each output in the state directory
    // and put it back once the sink is ready. The value is saved again only
    // after the restore, so the boot-time level never replaces it.
    readonly property string volumeStatePath: {
        if (typeof Caching === "undefined" || typeof Caching.getStateDir !== "function") return "";
        return Caching.getStateDir("volume") + "/levels.json";
    }
    property var savedVolumes: ({})
    property bool savedVolumesReady: false
    property var restoredVolumes: ({})
    property bool restoringVolume: false

    FileView {
        id: volumeStateFile
        path: root.volumeStatePath
        blockWrites: true
        onLoaded: root.loadSavedVolumes(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) root.loadSavedVolumes("");
        }
    }

    Timer {
        id: volumeRestoreTimer
        interval: 2500
        repeat: false
        onTriggered: root.restoreSavedVolume(root.defaultSink)
    }

    Timer {
        id: volumeSaveTimer
        interval: 500
        repeat: false
        onTriggered: root.writeSavedVolumes()
    }

    Connections {
        target: root.defaultSink && root.defaultSink.audio ? root.defaultSink.audio : null
        ignoreUnknownSignals: true
        function onVolumesChanged() { root.rememberVolume(root.defaultSink); }
        function onMutedChanged() { root.rememberVolume(root.defaultSink); }
    }

    onDefaultSinkChanged: root.scheduleVolumeRestore()

    function loadSavedVolumes(content) {
        let data = {};
        try {
            let parsed = content && content.trim() !== "" ? JSON.parse(content) : {};
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) data = parsed;
        } catch (e) {
        }
        root.savedVolumes = data;
        root.savedVolumesReady = true;
        root.scheduleVolumeRestore();
    }

    function scheduleVolumeRestore() {
        if (!root.savedVolumesReady || !root.defaultSink || !root.defaultSink.audio) return;
        volumeRestoreTimer.restart();
    }

    function restoreSavedVolume(node) {
        if (!root.savedVolumesReady || !node || !node.audio) return;
        let name = node.name ? String(node.name) : "";
        if (name === "" || root.restoredVolumes[name] === true) return;

        root.restoredVolumes[name] = true;
        let saved = root.savedVolumes[name];
        if (saved === undefined || saved === null || !isFinite(Number(saved))) {
            root.rememberVolume(node);
            return;
        }

        let target = Math.max(0, Math.min(1.5, Number(saved)));
        if (Math.abs((node.audio.volume || 0) - target) <= 0.005) {
            root.rememberVolume(node);
            return;
        }

        root.restoringVolume = true;
        node.audio.volume = target;
        root.restoringVolume = false;
        volumeSaveTimer.restart();
    }

    function rememberVolume(node) {
        if (root.restoringVolume || !root.savedVolumesReady || !node || !node.audio) return;
        let name = node.name ? String(node.name) : "";
        let value = node.audio.volume;
        if (name === "" || value === undefined || value === null || !isFinite(Number(value))) return;
        // Ignore changes until the restore attempt has run for this sink.
        if (root.restoredVolumes[name] !== true) return;
        let next = Object.assign({}, root.savedVolumes);
        next[name] = Math.round(Number(value) * 10000) / 10000;
        root.savedVolumes = next;
        volumeSaveTimer.restart();
    }

    function writeSavedVolumes() {
        if (volumeStateFile.path === "") return;
        volumeStateFile.setText(JSON.stringify(root.savedVolumes) + "\n");
    }

    function setDefaultOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted;
    }

    function setVolume(node, pct) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.5, pct / 100.0));
    }

    function getNodeName(node) {
        if (!node) return "";
        return node.properties?.["device.description"] || node.description || node.name || "Unknown Device";
    }

    function getNodeSubDesc(node) {
        if (!node) return "";
        if (node.isStream) {
            return node.properties?.["media.name"] || node.properties?.["window.title"] || node.properties?.["media.role"] || "Audio Stream";
        }
        return node.name || "Unknown";
    }

    function getNodeAppName(node) {
        if (!node) return "";
        return node.properties?.["application.name"] || node.properties?.["application.process.binary"] || node.description || "Unknown App";
    }
}
