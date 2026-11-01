pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property bool isMango: Boolean(Quickshell.env("MANGO_INSTANCE_SIGNATURE")) || ((typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? (SystemInfo.desktopEnv.toLowerCase().indexOf("mango") !== -1) : false)

    property int activeIndex: 0
    property int tagCount: 0
    property var activeIndicesByOutput: ({})
    property var occupiedByOutput: ({})
    property var occupiedMap: ({})

    property var clients: []
    signal clientsUpdated()

    property int tagSubscribers: 0
    property int clientSubscribers: 0

    function subscribe() {
        tagSubscribers++;
        _syncStreams();
    }

    function unsubscribe() {
        tagSubscribers = Math.max(0, tagSubscribers - 1);
        _syncStreams();
    }

    function subscribeClients() {
        clientSubscribers++;
        _syncStreams();
    }

    function unsubscribeClients() {
        clientSubscribers = Math.max(0, clientSubscribers - 1);
        _syncStreams();
    }

    function _syncStreams() {
        let wantTags = isMango && tagSubscribers > 0;
        let wantClients = isMango && clientSubscribers > 0;
        if (tagStream.running !== wantTags) tagStream.running = wantTags;
        if (clientStream.running !== wantClients) clientStream.running = wantClients;
    }

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }

    function isOccupied(outputName, index) {
        let perOutput = (outputName && occupiedByOutput) ? occupiedByOutput[outputName] : null;
        if (perOutput) return Boolean(perOutput[index]);
        return Boolean(occupiedMap[index]);
    }

    function _applyTags(payload) {
        let monitors = (payload && Array.isArray(payload.all_tags)) ? payload.all_tags : [];
        let active = {};
        let occByOut = {};
        let occ = {};
        let maxTags = 0;
        let firstActive = -1;

        for (let i = 0; i < monitors.length; i++) {
            let mon = monitors[i];
            if (!mon || !Array.isArray(mon.tags)) continue;
            let name = mon.monitor || "";
            let occHere = {};
            let activeHere = -1;
            for (let j = 0; j < mon.tags.length; j++) {
                let tag = mon.tags[j];
                let idx = (tag.index !== undefined ? tag.index : j + 1) - 1;
                if (idx + 1 > maxTags) maxTags = idx + 1;
                if (tag.client_count > 0) {
                    occHere[idx] = true;
                    occ[idx] = true;
                }
                if (tag.is_active && activeHere < 0) activeHere = idx;
            }
            occByOut[name] = occHere;
            if (activeHere >= 0) {
                active[name] = activeHere;
                if (firstActive < 0) firstActive = activeHere;
            }
        }

        root.activeIndicesByOutput = active;
        root.occupiedByOutput = occByOut;
        root.occupiedMap = occ;
        root.tagCount = maxTags;
        root.activeIndex = firstActive >= 0 ? firstActive : 0;
    }

    function _applyClients(payload) {
        root.clients = (payload && Array.isArray(payload.clients)) ? payload.clients : [];
        root.clientsUpdated();
    }

    Process {
        id: tagStream
        running: false
        command: ["mmsg", "watch", "all-tags"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                let trimmed = line.trim();
                if (trimmed.length === 0) return;
                try {
                    root._applyTags(JSON.parse(trimmed));
                } catch (e) {}
            }
        }
        onExited: {
            if (root.isMango && root.tagSubscribers > 0) tagRestartTimer.restart();
        }
    }

    Process {
        id: clientStream
        running: false
        command: ["mmsg", "watch", "all-clients"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                let trimmed = line.trim();
                if (trimmed.length === 0) return;
                try {
                    root._applyClients(JSON.parse(trimmed));
                } catch (e) {}
            }
        }
        onExited: {
            if (root.isMango && root.clientSubscribers > 0) clientRestartTimer.restart();
        }
    }

    Timer {
        id: tagRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isMango && root.tagSubscribers > 0) {
                tagStream.running = false;
                tagStream.running = true;
            }
        }
    }

    Timer {
        id: clientRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isMango && root.clientSubscribers > 0) {
                clientStream.running = false;
                clientStream.running = true;
            }
        }
    }
}
