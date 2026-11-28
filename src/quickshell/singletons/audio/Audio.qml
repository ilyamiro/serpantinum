pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.Pipewire

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

    readonly property PwNode effectiveSink: defaultSink || (outputs && outputs.length > 0 ? outputs[0] : null)
    readonly property PwNode effectiveSource: defaultSource || (inputs && inputs.length > 0 ? inputs[0] : null)

    readonly property int sinkVolumePercent: effectiveSink && effectiveSink.audio ? Math.round(effectiveSink.audio.volume * 100) : 0
    readonly property bool sinkMuted: effectiveSink && effectiveSink.audio ? effectiveSink.audio.muted : false
    readonly property int sourceVolumePercent: effectiveSource && effectiveSource.audio ? Math.round(effectiveSource.audio.volume * 100) : 0
    readonly property bool sourceMuted: effectiveSource && effectiveSource.audio ? effectiveSource.audio.muted : false

    property var _pendingVolumeNode: null
    property int _pendingVolumePercent: -1

    Timer {
        id: volumeThrottleTimer
        interval: 50
        repeat: false
        onTriggered: root.flushVolume()
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

    function _applyVolumeAndUnmute(node, percent) {
        if (!node || !node.audio) return;
        let pct = Math.max(0, Math.min(150, Math.round(Number(percent) || 0)));
        if (pct > 0 && node.audio.muted) node.audio.muted = false;
        root.setVolume(node, pct);
    }

    function setVolumeAndUnmute(node, percent, throttled) {
        if (!node || !node.audio) return;
        let pct = Math.max(0, Math.min(150, Math.round(Number(percent) || 0)));
        if (throttled) {
            if (root._pendingVolumeNode && root._pendingVolumeNode !== node && root._pendingVolumePercent >= 0) {
                root._applyVolumeAndUnmute(root._pendingVolumeNode, root._pendingVolumePercent);
            }
            root._pendingVolumeNode = node;
            root._pendingVolumePercent = pct;
            if (!volumeThrottleTimer.running) volumeThrottleTimer.start();
        } else {
            if (root._pendingVolumeNode === node) {
                volumeThrottleTimer.stop();
                root._pendingVolumeNode = null;
                root._pendingVolumePercent = -1;
            }
            root._applyVolumeAndUnmute(node, pct);
        }
    }

    function flushVolume() {
        volumeThrottleTimer.stop();
        if (root._pendingVolumeNode && root._pendingVolumePercent >= 0) {
            let n = root._pendingVolumeNode;
            let pct = root._pendingVolumePercent;
            root._pendingVolumeNode = null;
            root._pendingVolumePercent = -1;
            root._applyVolumeAndUnmute(n, pct);
        }
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
