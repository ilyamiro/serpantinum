pragma Singleton
import QtQuick
import QtQml
import Quickshell
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
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    // Upper limit for every volume surface (popup sliders, OSD, bar widget) and
    // for scripts/volume.sh. Percentage; 100 keeps the classic behaviour.
    property var generalSettings: Config.getSetting("general", { "maxVolume": 100 })
    readonly property int maxVolume: {
        let v = (generalSettings && generalSettings.maxVolume !== undefined) ? Number(generalSettings.maxVolume) : 100;
        if (isNaN(v)) return 100;
        return Math.max(100, Math.min(200, Math.round(v)));
    }
    readonly property real maxVolumeFactor: maxVolume / 100.0

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.generalSettings = Config.getSetting("general", { "maxVolume": 100 });
        }
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
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(root.maxVolumeFactor, pct / 100.0));
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
