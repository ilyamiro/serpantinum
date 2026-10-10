pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import "AudioCache.js" as AudioCache

Singleton {
    id: root

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function isSerpantinumStream(node) {
        if (!node || !node.properties) return false;
        let p = node.properties;
        let appId = p["application.id"] || "";
        let appName = p["application.name"] || "";
        if (appId === "serpantinum-sfx" || appId === "serpantinum" || appId === "org.serpantinum.sfx") return true;
        if (appName === "serpantinum-sfx" || appName === "serpantinum") return true;
        let mediaFile = p["media.filename"] || p["media.name"] || "";
        if (mediaFile.indexOf("assets/sounds/") !== -1) return true;
        return false;
    }

    readonly property var outputs: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (!n.isStream && n.isSink && n.audio) arr.push(n);
        }
        return AudioCache.updateOutputs(arr);
    }

    readonly property var inputs: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
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
        for (const n of Pipewire.nodes.values) {
            if (n.isStream && n.audio
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol"
                && !isSerpantinumStream(n)) {
                arr.push(n);
            }
        }
        return AudioCache.updateApps(arr);
    }

    readonly property bool hasActiveStream: {
        for (const n of Pipewire.nodes.values) {
            if (!n || !n.isStream || !n.audio || isSerpantinumStream(n)) continue;
            let p = n.properties;
            if (!p) continue;
            if (p["media.class"] && p["media.class"] !== "Stream/Output/Audio") continue;
            let appId = p["application.id"] || p["application.name"] || p["node.name"] || "";
            if (appId === "org.PulseAudio.pavucontrol" || appId === "cava") continue;
            let corked = p["pulse.corked"];
            if (corked === "true" || corked === true) continue;
            if (n.audio && n.audio.muted) continue;
            return true;
        }
        return false;
    }

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

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
