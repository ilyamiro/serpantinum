import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../"

MusicPlayerState {
    id: root

    property var eqData: {
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false, "balance": 0,
        "mono": false, "swap": false, "dynamics": "off"
    }

    property var savedEqData: ({
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false, "balance": 0,
        "mono": false, "swap": false, "dynamics": "off"
    })

    property bool audioTestRunning: false

    Timer {
        id: audioTestTimer
        interval: 3200
        repeat: false
        onTriggered: root.audioTestRunning = false
    }

    function restoreLastSavedEqualizer() {
        if (!root.savedEqData) return;
        var wasPending = root.eqData && root.eqData.pending;
        var needsRestore = wasPending;
        if (!needsRestore && root.eqData) {
            for (var i = 1; i <= 10; i++) {
                if (root.eqData["b" + i] !== root.savedEqData["b" + i]) {
                    needsRestore = true;
                    break;
                }
            }
        }
        var restored = Object.assign({}, root.savedEqData);
        restored.pending = false;
        root.eqData = restored;
        if (needsRestore) {
            root.lastEqUpdate = Date.now();
            if (root.savedEqData.preset && root.savedEqData.preset !== "Custom") {
                root.execCmd(Caching.qsDir + `/media/equalizer.sh preset ${root.savedEqData.preset}`);
            } else {
                for (var b = 1; b <= 10; b++) {
                    if (root.savedEqData["b" + b] !== undefined) {
                        root.execCmd(Caching.qsDir + `/media/equalizer.sh set_band ${b} ${root.savedEqData["b" + b]}`);
                    }
                }
            }
        }
    }

    property color eqAccentColor: ThemeBackend.mauve || "#cba6f7"
    property string accumulatedEqOut: ""
    property real lastEqUpdate: 0

    property real eqLightningProgress: 0.0
    property real eqLightningFade: 1.0

    SequentialAnimation {
        id: eqLightningAnim
        running: false
        ScriptAction { script: { root.eqLightningFade = 0.0; root.eqLightningProgress = 0.0; } }
        NumberAnimation { 
            target: root; property: "eqLightningProgress"; 
            from: 0.0; to: 10.0; 
            duration: 650; 
            easing.type: Easing.OutSine 
        }
        PauseAnimation { duration: 150 }
        NumberAnimation { 
            target: root; property: "eqLightningFade"; 
            from: 0.0; to: 1.0; 
            duration: 800; 
            easing.type: Easing.OutQuad 
        }
        ScriptAction { script: { root.eqLightningProgress = 0.0; } }
    }

    function triggerEqLightning() {
        Sounds.playSfx("musicpopup/swoosh.wav", 0.75);
        eqLightningAnim.restart();
    }

    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        var p = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${safeCmd}\`]
                running: true
                onExited: (exitCode) => destroy()
            }
        `, root);
    }

    function applyPresetOptimistically(presetName) {
        var presets = {
            "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
            "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
            "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
            "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
            "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
            "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
            "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
        };
        if (presets[presetName]) {
            var temp = Object.assign({}, root.eqData);
            for (var i = 0; i < 10; i++) {
                temp["b" + (i + 1)] = presets[presetName][i];
            }
            temp.preset = presetName;
            temp.pending = false;
            root.eqData = temp;
            root.savedEqData = Object.assign({}, temp);
            
            root.lastEqUpdate = Date.now();
            
            root.triggerEqLightning();
            execCmd(Caching.qsDir + `/media/equalizer.sh preset ${presetName}`);
        }
    }

    function setBalance(value) {
        var clamped = Math.max(-1.0, Math.min(1.0, Number(value)));
        if (isNaN(clamped)) return;

        var temp = Object.assign({}, root.eqData);
        temp.balance = Math.round(clamped * 100) / 100;
        root.eqData = temp;
        root.savedEqData = Object.assign({}, temp);
        root.lastEqUpdate = Date.now();
        root.execCmd(Caching.qsDir + `/media/equalizer.sh set_balance ${temp.balance}`);
    }

    function setAudioFlag(name, value) {
        if (name !== "mono" && name !== "swap") return;
        var temp = Object.assign({}, root.eqData);
        temp[name] = value === true;
        root.eqData = temp;
        root.savedEqData = Object.assign({}, temp);
        root.lastEqUpdate = Date.now();
        root.execCmd(Caching.qsDir + `/media/equalizer.sh set_${name} ${temp[name]}`);
    }

    function setDynamics(value) {
        if (["off", "balanced", "night"].indexOf(value) < 0) return;
        var temp = Object.assign({}, root.eqData);
        temp.dynamics = value;
        root.eqData = temp;
        root.savedEqData = Object.assign({}, temp);
        root.lastEqUpdate = Date.now();
        root.execCmd(Caching.qsDir + `/media/equalizer.sh set_dynamics ${value}`);
    }

    function resetAudio() {
        var temp = Object.assign({}, root.eqData);
        temp.balance = 0;
        temp.mono = false;
        temp.swap = false;
        temp.dynamics = "off";
        root.eqData = temp;
        root.savedEqData = Object.assign({}, temp);
        root.audioTestRunning = false;
        audioTestTimer.stop();
        root.lastEqUpdate = Date.now();
        root.execCmd(Caching.qsDir + "/media/equalizer.sh reset_audio");
    }

    function toggleAudioTest() {
        if (root.audioTestRunning) {
            root.execCmd(Caching.qsDir + "/media/equalizer.sh stop_test");
            root.audioTestRunning = false;
            audioTestTimer.stop();
        } else {
            root.execCmd(Caching.qsDir + "/media/equalizer.sh test");
            root.audioTestRunning = true;
            audioTestTimer.restart();
        }
    }

    property bool eqInitDone: false

    function applyEqState(text) {
        var outStr = text ? text.trim() : "";
        if (outStr.length === 0) return;

        // Our own writes land here too; skip them for a moment and re-read once they settle.
        var sinceLocal = Date.now() - root.lastEqUpdate;
        if (sinceLocal < 2000) {
            eqResyncTimer.interval = 2000 - sinceLocal;
            eqResyncTimer.restart();
            return;
        }

        try {
            var parsed = JSON.parse(outStr);
            root.eqData = parsed;
            if (!parsed.pending) {
                root.savedEqData = Object.assign({}, parsed);
            }
        } catch(e) {}
    }

    // equalizer.sh keeps its state in this file; watch it instead of polling the script.
    FileView {
        id: eqStateFile
        path: Caching.runDir + "/music/eq_state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyEqState(text())
        // The script creates the file with defaults on first use.
        onLoadFailed: {
            if (!root.eqInitDone && !eqInitProc.running) {
                root.eqInitDone = true;
                eqInitProc.running = true;
            }
        }
    }

    Timer {
        id: eqResyncTimer
        repeat: false
        onTriggered: eqStateFile.reload()
    }

    Process {
        id: eqInitProc
        running: false
        command: ["bash", "-c", Caching.qsDir + "/media/equalizer.sh get"]
        onExited: eqStateFile.reload()
    }
}
