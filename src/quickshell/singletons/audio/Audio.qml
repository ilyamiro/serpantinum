pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../"

Singleton {
    id: root

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var outputs: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (!n.isStream && n.isSink && n.audio) arr.push(n);
        }
        return arr;
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
        return arr;
    }

    readonly property var apps: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (n.isStream && n.audio
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol") {
                arr.push(n);
            }
        }
        return arr;
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

    // ---------- name normalization ----------

    function profileDescription(node) {
        return (node && node.properties) ? (node.properties["device.profile.description"] || "") : "";
    }

    function regexEscape(s) {
        return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function stripProfile(text, profile) {
        if (!text) return "";
        let out = String(text);
        if (profile) out = out.replace(new RegExp(regexEscape(profile), "i"), " ");
        return out.trim();
    }

    function cleanNamePart(s) {
        if (!s) return "";
        let out = String(s);
        out = out.replace(/\s*\[[^\]]*\]\s*/g, " "); // [vendor/model] noise
        out = out.replace(/\bHD Audio Controller\b/gi, "HD Audio");
        out = out.replace(/\bAudio Controller\b/gi, "Audio");
        out = out.replace(/\s*[-–—·:]\s*$/g, "");
        out = out.replace(/\s{2,}/g, " ").trim();
        return out;
    }

    function looksLikeCode(s) {
        if (!s) return true;
        return !/[a-z]/.test(s);
    }

    function friendlyLabelFor(text, profile) {
        const prof = (profile || "").toLowerCase();
        const hay = (text || "").toLowerCase();
        if (/displayport|\bdp\b/.test(prof)) return "DisplayPort (GPU)";
        if (/hdmi/.test(prof)) return "HDMI (GPU)";
        if (/displayport|\bdp\b/.test(hay)) return "DisplayPort (GPU)";
        if (/hdmi/.test(hay)) return "HDMI (GPU)";
        if (/hd audio|audio controller|built-in audio|renoir|cezanne|family \w+/.test(hay))
            return I18n.t("volumepopup.internal_audio");
        return text;
    }

    function normalizedDeviceName(node) {
        const props = (node && node.properties) ? node.properties : {};
        const profile = profileDescription(node);
        const deviceDesc = props["device.description"] || "";
        const nodeDesc = node ? (node.description || "") : "";
        const nick = props["device.nick"] || (node ? (node.nick || "") : "");

        let base = cleanNamePart(stripProfile(deviceDesc, profile));
        if (!base) base = cleanNamePart(stripProfile(nodeDesc, profile));
        if (base) return friendlyLabelFor(base, profile);

        let short = cleanNamePart(nick);
        if (short && !looksLikeCode(short)) return friendlyLabelFor(short, profile);

        return cleanNamePart(nick || (node ? node.name : "") || "") || "Unknown Device";
    }

    function profileLabel(node) {
        const profile = profileDescription(node);
        if (!profile) return "";
        const hdmi = profile.match(/HDMI\s*(\d*)/i);
        if (hdmi) return "HDMI" + (hdmi[1] ? " " + hdmi[1] : "");
        if (/anal[oó]gic/i.test(profile)) return I18n.t("volumepopup.analog");
        if (/\bdigital\b/i.test(profile)) return "Digital";
        if (/\bmono\b/i.test(profile)) return "Mono";
        return profile;
    }

    function getNodeName(node) {
        if (!node) return "";
        // Handle virtual devices (easyeffects, pipewire, etc.) with cleaner names
        const nodeName = node.name || "";
        if (nodeName.startsWith("easyeffects_")) {
            return "Easy Effects";
        }
        if (nodeName.startsWith("pipewire_")) {
            return "PipeWire";
        }
        return normalizedDeviceName(node);
    }

    function getNodeSubDesc(node) {
        if (!node) return "";
        if (node.isStream) {
            return node.properties?.["media.name"] || node.properties?.["window.title"] || node.properties?.["media.role"] || "Audio Stream";
        }
        // For device nodes, show a cleaned-up profile/description
        const profile = profileDescription(node);
        const devName = node.properties?.["device.name"] || "";
        const api = node.properties?.["api.alsa.path"] || "";
        if (profile) return profileLabel(node);
        if (devName) return cleanNamePart(devName.replace(/^alsa_/, ""));
        if (api) return api;
        
        // For virtual nodes (easyeffects, etc.) show a clean type instead of internal name
        const nodeName = node.name || "";
        if (nodeName.startsWith("easyeffects_")) {
            return nodeName.includes("sink") ? "Saída virtual" : "Entrada virtual";
        }
        if (nodeName.startsWith("pipewire_")) {
            return "Virtual";
        }
        
        return cleanNamePart(node.nick || node.name || "") || "Unknown";
    }

    function getNodeAppName(node) {
        if (!node) return "";
        return node.properties?.["application.name"] || node.properties?.["application.process.binary"] || node.description || "Unknown App";
    }
}
