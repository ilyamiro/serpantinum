import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"
import "../reusables"
import "../reusables/media"
import "../mc"

Item {
    id: root
    visible: false
    focus: true

    readonly property bool active: root.visible

    property bool cavaRegistered: false

    function registerCava() {
        if (!cavaRegistered) {
            cavaRegistered = true;
            Cava.registerConsumer();
        }
    }

    function unregisterCava() {
        if (cavaRegistered) {
            cavaRegistered = false;
            Cava.unregisterConsumer();
        }
    }

    function s(val) { 
        return Scaler.s(val); 
    }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        chargeAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        introMain = 0;
        introCover = 0;
        introText = 0;
        introControls = 0;
        introSeparator = 0;
        introEqHeader = 0;
        introEqSliders = 0;
        introPresets = 0;
        maskRectOuter.drawProgress = 0;
        introAnim.restart();
        chargeAnim.restart();
    }

    property bool lyricsSubscribed: false

    function updateLyricsSubscription() {
        let shouldSub = root.active && (bottomSectionSwitch.currentIndex === 1);
        if (shouldSub && !lyricsSubscribed) {
            lyricsSubscribed = true;
            Lyrics.customPlayer = root.targetPlayer;
            Lyrics.subscribe();
        } else if (!shouldSub && lyricsSubscribed) {
            lyricsSubscribed = false;
            Lyrics.customPlayer = null;
            Lyrics.unsubscribe();
        } else if (shouldSub && lyricsSubscribed) {
            Lyrics.customPlayer = root.targetPlayer;
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: root.active
        onActivated: {
            bottomSectionSwitch.currentIndex = (bottomSectionSwitch.currentIndex === 0 ? 1 : 0);
            root.updateLyricsSubscription();
        }
    }

    Shortcut {
        sequence: "Backtab"
        enabled: root.active
        onActivated: {
            bottomSectionSwitch.currentIndex = (bottomSectionSwitch.currentIndex === 0 ? 1 : 0);
            root.updateLyricsSubscription();
        }
    }

    onActiveChanged: {
        updateLyricsSubscription();
        if (active) {
            forceActiveFocus();
            resetAndPlayIntro();
            registerCava();
            triggerLocalArtFetch();
        } else {
            exitAnim.stop();
            unregisterCava();
            if (lyricsPickerPopup.visible || lyricsPickerPopup.opened) {
                lyricsPickerPopup.closePicker();
            }
            if (root.eqData && root.eqData.pending) {
                root.restoreLastSavedEqualizer();
            }
        }
    }

    Component.onCompleted: {
        if (root.eqData) {
            root.savedEqData = Object.assign({}, root.eqData);
        }
        if (active) {
            forceActiveFocus();
            resetAndPlayIntro();
            registerCava();
            triggerLocalArtFetch();
            updateLyricsSubscription();
        }
    }

    Component.onDestruction: {
        unregisterCava();
        if (lyricsSubscribed) {
            lyricsSubscribed = false;
            Lyrics.unsubscribe();
        }
    }

    Text {
        id: eqMeasureText
        visible: false
        text: root.eqData && root.eqData.pending ? (typeof I18n !== "undefined" ? I18n.t("music.eq.apply") : "Apply") : (typeof I18n !== "undefined" ? I18n.t("music.eq.saved") : "Saved")
        font.family: "Monocraft"
        font.pixelSize: root.s(11)
    }

    Text {
        id: lyricsMeasureText
        visible: false
        text: typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file"
        font.family: "Monocraft"
        font.pixelSize: root.s(11)
    }

    property real actionBtnMorph: 0.0
    property real presetSlideProgress: 0.0

    readonly property real eqActionBtnWidth: Math.max(root.s(68), eqMeasureText.implicitWidth + root.s(26))
    readonly property real lyricsActionBtnWidth: Math.max(root.s(116), lyricsMeasureText.implicitWidth + root.s(44))
    readonly property real actionBtnCurrentWidth: eqActionBtnWidth + (lyricsActionBtnWidth - eqActionBtnWidth) * actionBtnMorph

    ParallelAnimation {
        id: toLyricsAnim
        running: false
        NumberAnimation {
            target: root
            property: "actionBtnMorph"
            to: 1.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "presetSlideProgress"
            to: 1.0
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: toEqAnim
        running: false
        NumberAnimation {
            target: root
            property: "actionBtnMorph"
            to: 0.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "presetSlideProgress"
            to: 0.0
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    property int barCount: 60
    property var rawBarLevels: []

    Binding {
        target: root
        property: "rawBarLevels"
        value: Cava.barLevels
        when: root.active
    }

    // Sub-bass and kick strength for the glow and the disc bounce
    property var beat: {
        let source = rawBarLevels;
        if (!source || source.length === 0) return { bass: 0.0, kick: 0.0 };

        let subBass = (source[0] || 0.0) * 0.50 + (source[1] || 0.0) * 0.35 + (source[2] || 0.0) * 0.15;
        let kickPunch = (source[1] || 0.0) * 0.30 + (source[2] || 0.0) * 0.45 + (source[3] || 0.0) * 0.25;
        let rawKick = Math.max(subBass, kickPunch);

        let kick = rawKick > 0.10 ? Math.min(1.0, Math.pow((rawKick - 0.10) / 0.90, 1.8) * 1.4) : 0.0;
        let bass = Math.max(0.0, Math.min(1.0, subBass * 0.6 + kickPunch * 0.4));

        return { bass: bass, kick: kick };
    }

    property real bassLevel: beat.bass
    property real kickLevel: beat.kick

    property var playerList: {
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    property var targetPlayer: {
        if (manualPlayer) {
            for (let i = 0; i < playerList.length; i++) {
                if (playerList[i] === manualPlayer) return manualPlayer;
            }
        }
        return MprisController.activePlayer;
    }

    property bool hasTargetPlayer: targetPlayer !== null

    property var playerOptions: {
        let list = playerList;
        let names = [];
        let counts = {};
        for (let i = 0; i < list.length; i++) {
            let base = list[i].identity || list[i].desktopEntry || ("Player " + (i + 1));
            counts[base] = (counts[base] || 0) + 1;
        }
        for (let i = 0; i < list.length; i++) {
            let p = list[i];
            let base = p.identity || p.desktopEntry || ("Player " + (i + 1));
            if (counts[base] > 1 && p.trackTitle) {
                names.push(base + " (" + p.trackTitle + ")");
            } else {
                names.push(base);
            }
        }
        return names;
    }

    property int currentPlayerIndex: {
        if (!targetPlayer) return 0;
        for (let i = 0; i < playerList.length; i++) {
            if (playerList[i] === targetPlayer) return i;
        }
        return 0;
    }

    function selectPlayerByIndex(idx) {
        if (idx >= 0 && idx < playerList.length) {
            manualPlayer = playerList[idx];
            triggerLocalArtFetch();
        }
    }

    property real currentLivePosition: targetPlayer ? targetPlayer.position : 0

    Connections {
        target: root.targetPlayer
        function onPositionChanged() {
            if (!root.active) return;
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
        }
        function onPostTrackChanged() {
            if (!root.active) return;
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
            root.triggerLocalArtFetch();
        }
        function onTrackArtUrlChanged() {
            if (!root.active) return;
            root.triggerLocalArtFetch();
        }
        function onTrackTitleChanged() {
            if (!root.active) return;
            root.triggerLocalArtFetch();
        }
    }

    onTargetPlayerChanged: {
        if (targetPlayer) currentLivePosition = targetPlayer.position;
        triggerLocalArtFetch();
        updateLyricsSubscription();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.hasTargetPlayer && root.targetPlayer.isPlaying
        onTriggered: {
            if (root.targetPlayer) {
                if (typeof root.targetPlayer.positionChanged === "function") {
                    root.targetPlayer.positionChanged();
                }
                root.currentLivePosition = root.targetPlayer.position;
            }
        }
    }

    property string localArtUrl: ""
    property string localBlur: ""
    property string localGrad: ""
    property string localTextColor: ""
    property string localDeviceIcon: "󰓃"
    property string localDeviceName: "Speaker"

    Process {
        id: customArtFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.targetPlayer ? (root.targetPlayer.trackArtUrl || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackTitle || "") : "",
            root.targetPlayer ? (root.targetPlayer.trackArtist || "") : ""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.localArtUrl = d.artUrl || "";
                        root.localBlur = d.blur || "";
                        root.localGrad = d.grad || "";
                        root.localTextColor = d.textColor || "#cdd6f4";
                        root.localDeviceIcon = d.deviceIcon || "󰓃";
                        root.localDeviceName = d.deviceName || "Speaker";
                    } catch(e) {}
                }
            }
        }
    }

    function triggerLocalArtFetch() {
        if (root.targetPlayer && root.targetPlayer !== MprisController.activePlayer) {
            customArtFetchProc.running = false;
            customArtFetchProc.running = true;
        } else if (root.targetPlayer && root.targetPlayer === MprisController.activePlayer) {
            if (!MprisController.artUrl) {
                MprisController.queueFetch();
            }
        }
    }

    property string activeArtUrl: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.artUrl : localArtUrl
    property string activeBlur: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.blur : localBlur
    property string activeGrad: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.grad : localGrad
    property string activeTextColor: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.textColor : (localTextColor || "#cdd6f4")
    property string activeDeviceIcon: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.deviceIcon : localDeviceIcon
    property string activeDeviceName: (targetPlayer && targetPlayer === MprisController.activePlayer) ? MprisController.deviceName : localDeviceName

    property var eqData: {
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false
    }

    property var savedEqData: ({
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false
    })

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

    property color eqAccentColor: "#ffffff"
    property string accumulatedEqOut: ""
    property real lastEqUpdate: 0

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: root.active
    }

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

    property real introMain: 0
    property real introCover: 0
    property real introText: 0
    property real introControls: 0
    property real introSeparator: 0
    property real introEqHeader: 0
    property real introEqSliders: 0
    property real introPresets: 0

    ParallelAnimation {
        id: introAnim
        running: false

        NumberAnimation { target: root; property: "introMain"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutQuart }

        SequentialAnimation {
            PauseAnimation { duration: 70 }
            NumberAnimation { target: root; property: "introCover"; from: 0; to: 1.0; duration: 810; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }

        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: root; property: "introText"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 230 }
            NumberAnimation { target: root; property: "introControls"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }

        SequentialAnimation {
            PauseAnimation { duration: 310 }
            NumberAnimation { target: root; property: "introSeparator"; from: 0; to: 1.0; duration: 660; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 370 }
            NumberAnimation { target: root; property: "introEqHeader"; from: 0; to: 1.0; duration: 710; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 430 }
            NumberAnimation { target: root; property: "introEqSliders"; from: 0; to: 1.0; duration: 860; easing.type: Easing.OutExpo }
        }

        SequentialAnimation {
            PauseAnimation { duration: 550 }
            NumberAnimation { target: root; property: "introPresets"; from: 0; to: 1.0; duration: 810; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: root; property: "introPresets"; to: 0.0; duration: 130; easing.type: Easing.InBack }
            NumberAnimation { target: root; property: "introEqSliders"; to: 0.0; duration: 140; easing.type: Easing.InExpo }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: root; property: "introEqHeader"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "introSeparator"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: root; property: "introControls"; to: 0.0; duration: 140; easing.type: Easing.InBack }
                NumberAnimation { target: root; property: "introText"; to: 0.0; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "introCover"; to: 0.0; duration: 150; easing.type: Easing.InBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation { target: root; property: "introMain"; to: 0.0; duration: 170; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                }
            }
        }
    }

    property var borderColors: {
        var defaultColors = [ThemeBackend.mauve || "#cba6f7", ThemeBackend.blue || "#89b4fa", ThemeBackend.red || "#f38ba8", ThemeBackend.mauve || "#cba6f7"];
        var gradSource = root.activeGrad || (typeof MprisController !== "undefined" ? MprisController.grad : "");
        if (!gradSource) return defaultColors;
        
        var hexRegex = /#[0-9a-fA-F]{6}/g;
        var matches = gradSource.match(hexRegex);
        
        if (matches && matches.length >= 3) {
            return [matches[0], matches[1], matches[2], matches[0]];
        }
        return defaultColors;
    }

    property color bc1: borderColors[0] || ThemeBackend.mauve || "#cba6f7"
    property color bc2: borderColors[1] || ThemeBackend.blue || "#89b4fa"
    property color bc3: borderColors[2] || ThemeBackend.red || "#f38ba8"
    property color bc4: borderColors[3] || ThemeBackend.mauve || "#cba6f7"

    property color dynamicTextColor: "#ffffff"
    property color artTextColor: {
        var rawCol = root.activeTextColor || (typeof MprisController !== "undefined" ? MprisController.textColor : "");
        if (rawCol) {
            var c = String(rawCol).trim();
            var match = c.match(/^(#[0-9a-fA-F]{6})/);
            if (match) return match[1];
        }
        return ThemeBackend.text || "#cdd6f4";
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

    LyricsPicker {
        id: lyricsPickerPopup
        targetScreen: (root.Window && root.Window.window) ? root.Window.window.screen : null
        onLyricsSelected: function(filePath, fileName) {
            Lyrics.loadLocalLyricsFile(filePath);
        }
    }

    Item {
        id: mainWrapper
        anchors.fill: parent
        
        scale: 0.92 + (0.08 * root.introMain)
        opacity: root.introMain
        transform: Translate { y: root.s(12) * (1 - root.introMain) }

        Item {
            anchors.fill: parent

            Shape {
                id: maskRectOuter
                anchors.fill: parent
                visible: false
                layer.enabled: true
                preferredRendererType: Shape.GeometryRenderer

                property real sw: root.s(6)
                property real inset: (sw / 2) + root.s(0.5)
                property real w: width
                property real h: height
                property real r: ThemeBackend.borderRadius - inset
                
                property real straightLines: 2 * (w - 2 * inset - 2 * r) + 2 * (h - 2 * inset - 2 * r)
                property real arcLines: 2 * Math.PI * r
                property real perimeter: straightLines + arcLines

                property real drawProgress: 0

                NumberAnimation on drawProgress {
                    id: chargeAnim
                    from: 0
                    to: maskRectOuter.perimeter
                    duration: 1200
                    easing.type: Easing.OutCubic
                    running: false
                }

                ShapePath {
                    strokeWidth: maskRectOuter.sw
                    strokeColor: "black"
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap

                    dashPattern: [maskRectOuter.perimeter / maskRectOuter.sw, maskRectOuter.perimeter / maskRectOuter.sw]
                    dashOffset: (maskRectOuter.perimeter - maskRectOuter.drawProgress) / maskRectOuter.sw

                    startX: maskRectOuter.inset
                    startY: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r

                    PathLine { x: maskRectOuter.inset; y: maskRectOuter.inset + maskRectOuter.r }
                    PathArc { 
                        x: maskRectOuter.inset + maskRectOuter.r; y: maskRectOuter.inset 
                        radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
                    }
                    PathLine { x: maskRectOuter.w - maskRectOuter.inset - maskRectOuter.r; y: maskRectOuter.inset }
                    PathArc { 
                        x: maskRectOuter.w - maskRectOuter.inset; y: maskRectOuter.inset + maskRectOuter.r 
                        radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
                    }
                    PathLine { x: maskRectOuter.w - maskRectOuter.inset; y: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r }
                    PathArc { 
                        x: maskRectOuter.w - maskRectOuter.inset - maskRectOuter.r; y: maskRectOuter.h - maskRectOuter.inset 
                        radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
                    }
                    PathLine { x: maskRectOuter.inset + maskRectOuter.r; y: maskRectOuter.h - maskRectOuter.inset }
                    PathArc { 
                        x: maskRectOuter.inset; y: maskRectOuter.h - maskRectOuter.inset - maskRectOuter.r 
                        radiusX: maskRectOuter.r; radiusY: maskRectOuter.r; direction: PathArc.Clockwise 
                    }
                }
            }

            Item {
                id: gradContainer
                anchors.fill: parent
                visible: false
                clip: true

                Rectangle {
                    width: Math.max(parent.width, parent.height) * 2
                    height: width
                    anchors.centerIn: parent
                    
                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 5000
                        loops: Animation.Infinite
                        running: root.active
                    }

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.bc1; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                        GradientStop { position: 0.33; color: root.bc2; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                        GradientStop { position: 0.66; color: root.bc3; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                        GradientStop { position: 1.0; color: root.bc4; Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } } }
                    }
                }
            }

            MultiEffect {
                visible: false
                source: gradContainer
                anchors.fill: parent
                maskEnabled: true
                maskSource: maskRectOuter
            }
        }

        Rectangle {
            id: innerBg
            anchors.fill: parent
            anchors.margins: 0
            color: "#151515"
            radius: 0

            McPanel {
                anchors.fill: parent
                bevel: Math.max(2, Math.round(root.s(3)))
                fill: "#151515"
                light: "#3a3a3a"
                dark: "#070707"
            }

            Rectangle {
                id: innerBgMask
                anchors.fill: parent
                anchors.margins: Math.max(2, Math.round(root.s(3))) + 1
                radius: 0
                visible: false
                layer.enabled: true 
            }

            Item {
                id: bgEffectsLayer
                anchors.fill: parent
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: innerBgMask
                }

                Item {
                    id: blurCrossfader
                    anchors.fill: parent
                    property string blurUrl: root.activeBlur ? (root.activeBlur.startsWith("file://") || root.activeBlur.startsWith("http") ? root.activeBlur : "file://" + root.activeBlur) : ""
                    property bool showingA: true

                    Image {
                        id: blurA
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        opacity: blurCrossfader.showingA && status === Image.Ready && root.hasTargetPlayer ? 0.9 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                    }

                    Image {
                        id: blurB
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        opacity: !blurCrossfader.showingA && status === Image.Ready && root.hasTargetPlayer ? 0.9 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        opacity: (root.hasTargetPlayer && root.activeBlur) ? 1.0 : 0.0
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.base, 0.55); Behavior on color { ColorAnimation { duration: 600 } } }
                            GradientStop { position: 0.5; color: Qt.alpha(ThemeBackend.base, 0.72); Behavior on color { ColorAnimation { duration: 600 } } }
                            GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.base, 0.90); Behavior on color { ColorAnimation { duration: 600 } } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                    }

                    onBlurUrlChanged: {
                        if (!blurUrl) {
                            blurA.source = "";
                            blurB.source = "";
                            return;
                        }
                        if (showingA) {
                            blurB.source = blurUrl;
                            showingA = false;
                        } else {
                            blurA.source = blurUrl;
                            showingA = true;
                        }
                    }

                    Component.onCompleted: {
                        if (blurUrl) {
                            blurA.source = blurUrl;
                            showingA = true;
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.8; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * root.s(150)
                    y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * root.s(100)
                    
                    opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? 0.025 : (root.hasTargetPlayer ? 0.01 : 0.0)
                    color: (root.targetPlayer && root.targetPlayer.isPlaying) ? "#ffffff" : "#808080"
                    Behavior on color { ColorAnimation { duration: 1000 } }
                    Behavior on opacity { NumberAnimation { duration: 1000 } }
                }
                
                Rectangle {
                    width: parent.width * 0.9; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * root.s(-150)
                    y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * root.s(-100)
                    
                    opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? 0.025 : (root.hasTargetPlayer ? 0.01 : 0.0)
                    color: (root.targetPlayer && root.targetPlayer.isPlaying) ? "#bdbdbd" : "#606060"
                    Behavior on color { ColorAnimation { duration: 1000 } }
                    Behavior on opacity { NumberAnimation { duration: 1000 } }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(18)
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(224)
                    spacing: root.s(16)

                    Item {
                        id: coverHost
                        Layout.preferredWidth: root.s(224)
                        Layout.preferredHeight: root.s(224)
                        Layout.alignment: Qt.AlignVCenter

                        opacity: root.introCover
                        transform: Translate { x: root.s(-35) * (1 - root.introCover); y: root.s(9) * (1 - root.introCover) }

                        property real availableRadius: width / 2
                        property real dynMargin: 0
                        property real artRadius: availableRadius * 0.86
                        property real maxBarHeight: availableRadius - artRadius
                        property real barWidth: Math.max(root.s(2), (2 * Math.PI * artRadius) / root.barCount * 0.65)

                        Repeater {
                            model: 4
                            delegate: McText {
                                id: noteParticle
                                z: 10
                                text: "♪"
                                font.pixelSize: root.s(20)
                                color: ["#5cff5c", "#ff5ca8", "#5cc8ff", "#ffd75c"][index % 4]
                                property real t: 0
                                property bool playing: root.active && root.targetPlayer && root.targetPlayer.isPlaying
                                x: coverHost.width * (0.18 + 0.2 * index) + Math.sin(t * Math.PI * 2 + index) * root.s(6)
                                y: coverHost.height * 0.2 - t * root.s(70)
                                opacity: playing ? Math.sin(t * Math.PI) : 0.0
                                SequentialAnimation on t {
                                    loops: Animation.Infinite
                                    running: noteParticle.playing
                                    PauseAnimation { duration: index * 420 }
                                    NumberAnimation { from: 0; to: 1; duration: 1700; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        Item {
                            id: discAndVisGroup
                            anchors.centerIn: parent
                            width: coverHost.artRadius * 2
                            height: coverHost.artRadius * 2

                            property real targetScale: (root.targetPlayer && root.targetPlayer.isPlaying) ? (1.0 + (root.bassLevel * 0.0135) + (root.kickLevel * 0.027)) : 0.90
                            property real targetBounceY: (root.targetPlayer && root.targetPlayer.isPlaying) ? -(root.kickLevel * coverHost.artRadius * 0.02025) : 0
                            property real targetTilt: (root.targetPlayer && root.targetPlayer.isPlaying) ? (root.bassLevel - 0.3) * 0.9 : 0

                            anchors.verticalCenterOffset: targetBounceY
                            rotation: targetTilt
                            scale: targetScale

                            Behavior on anchors.verticalCenterOffset {
                                SpringAnimation {
                                    spring: 4.8
                                    damping: 0.38
                                    mass: 0.85
                                }
                            }

                            Behavior on rotation {
                                SpringAnimation {
                                    spring: 2.8
                                    damping: 0.52
                                    mass: 0.95
                                }
                            }

                            Behavior on scale {
                                SpringAnimation {
                                    spring: 5.2
                                    damping: 0.35
                                    mass: 0.75
                                }
                            }

                            Item {
                                id: discContainer
                                anchors.fill: parent

                                // Minecraft music disc item, drawn pixel by pixel.
                                Canvas {
                                    id: fallbackPlaceholder
                                    anchors.centerIn: parent
                                    // 32x32 pixel grid: still blocky, but reads as a round disc.
                                    property int px: Math.max(1, Math.floor(parent.width / 32))
                                    width: px * 32
                                    height: px * 32
                                    antialiasing: false

                                    // Spins continuously while playing; nearest sampling keeps the pixels hard-edged.
                                    smooth: false
                                    NumberAnimation on rotation {
                                        from: 0; to: 360
                                        duration: 2400
                                        loops: Animation.Infinite
                                        running: root.active
                                        paused: root.active && !(root.targetPlayer && root.targetPlayer.isPlaying)
                                    }

                                    // Cover art of the current track, printed on the disc like a picture disc.
                                    // Browsers often expose the same track twice (e.g. firefox + plasma-browser-integration)
                                    // and only one of them carries art; fall back to that, then to the YouTube thumbnail.
                                    property string fallbackArt: {
                                        let tp = root.targetPlayer;
                                        if (!tp) return "";
                                        let t = tp.trackTitle || "";
                                        let players = Mpris.players.values;
                                        for (let i = 0; i < players.length; i++) {
                                            let p = players[i];
                                            if (p === tp || !p.trackArtUrl || !p.trackTitle || !t) continue;
                                            if (t.indexOf(p.trackTitle) === 0 || p.trackTitle.indexOf(t) === 0) return p.trackArtUrl;
                                        }
                                        let url = tp.metadata ? (tp.metadata["xesam:url"] || "") : "";
                                        let m = String(url).match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/);
                                        return m ? "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg" : "";
                                    }
                                    property string rawArt: root.activeArtUrl || (root.targetPlayer && root.targetPlayer.trackArtUrl) || fallbackArt
                                    property string artUrl: root.hasTargetPlayer && rawArt ? (rawArt.startsWith("file://") || rawArt.startsWith("http") ? rawArt : "file://" + rawArt) : ""
                                    onArtUrlChanged: {
                                        if (artUrl !== "") loadImage(artUrl);
                                        requestPaint();
                                    }
                                    onImageLoaded: requestPaint()

                                    // Only used to learn the art's real size for a centered square crop.
                                    Image {
                                        id: artProbe
                                        visible: false
                                        asynchronous: true
                                        source: fallbackPlaceholder.artUrl
                                        onStatusChanged: fallbackPlaceholder.requestPaint()
                                    }

                                    onPxChanged: requestPaint()
                                    Component.onCompleted: {
                                        if (artUrl !== "") loadImage(artUrl);
                                        requestPaint();
                                    }
                                    onPaint: {
                                        let ctx = getContext("2d");
                                        ctx.reset();

                                        let art = null;
                                        if (artUrl !== "" && isImageLoaded(artUrl) && artProbe.status === Image.Ready) {
                                            let iw = artProbe.implicitWidth, ih = artProbe.implicitHeight;
                                            let side = Math.min(iw, ih);
                                            if (side > 0) {
                                                ctx.drawImage(artUrl, (iw - side) / 2, (ih - side) / 2, side, side, 0, 0, 32, 32);
                                                art = ctx.getImageData(0, 0, 32, 32).data;
                                                ctx.reset();
                                            }
                                        }
                                        function ch(v) { return Math.max(0, Math.min(255, Math.round(v))) / 255; }

                                        for (let y = 0; y < 32; y++) {
                                            for (let x = 0; x < 32; x++) {
                                                let dx = x + 0.5 - 16, dy = y + 0.5 - 16;
                                                let d = Math.sqrt(dx * dx + dy * dy);
                                                if (d > 15.6) continue;
                                                let ang = Math.atan2(dy, dx) * 180 / Math.PI;
                                                let groove = (d > 8.6 && d <= 9.4) || (d > 11.4 && d <= 12.2);
                                                let shine = d > 6.4 && d <= 13.8 && ((ang > -70 && ang < -35) || (ang > 115 && ang < 140));
                                                let c;
                                                if (art && d <= 14.4 && d > 2.6) {
                                                    let i = (y * 32 + x) * 4;
                                                    let k = groove ? 0.6 : 1.0, add = shine ? 45 : 0;
                                                    ctx.fillStyle = Qt.rgba(ch(art[i] * k + add), ch(art[i + 1] * k + add), ch(art[i + 2] * k + add), 1);
                                                    ctx.fillRect(x * px, y * px, px, px);
                                                    continue;
                                                }
                                                if (art && d > 1.8 && d <= 2.6) c = "#111111";
                                                else if (d > 14.4) c = "#000000";
                                                else if (d <= 1.8) c = "#000000";
                                                else if (d <= 4.6) c = "#dcdcdc";
                                                else if (d <= 5.6) c = "#9a9a9a";
                                                else if (d <= 6.4) c = "#111111";
                                                else if (groove) c = "#3a3a3a";
                                                else c = "#232323";
                                                // Glossy highlights top-right and bottom-left, like the item texture.
                                                if (shine) c = groove ? "#7a7a7a" : "#5a5a5a";
                                                ctx.fillStyle = c;
                                                ctx.fillRect(x * px, y * px, px, px);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -root.s(14)
                        spacing: root.s(12)

                        ColumnLayout {
                            z: 1
                            spacing: root.s(6)
                            opacity: root.introText
                            transform: Translate { x: root.s(25) * (1 - root.introText) }
                            
                            MarqueeText {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(25)
                                text: (root.targetPlayer && root.targetPlayer.trackTitle !== "") ? root.targetPlayer.trackTitle : I18n.t("music.nothing_playing")
                                color: root.dynamicTextColor
                                font.family: "Monocraft"
                                font.pixelSize: root.s(18)
                                font.bold: true
                                marqueeSpacing: root.s(50)
                                speed: 25
                                active: root.active

                                Behavior on color { ColorAnimation { duration: 600 } }
                            }

                            McText {
                                text: root.targetPlayer && root.targetPlayer.trackArtist ? I18n.t("music.by_artist", { "artist": root.targetPlayer.trackArtist }) : I18n.t("music.by_artist", { "artist": I18n.t("music.unknown_artist") })
                                color: "#a8a8a8"
                                font.pixelSize: root.s(12.5)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(18)
                            }
                            RowLayout {
                                spacing: root.s(9)
                                McButton {
                                    id: devicePill
                                    Layout.preferredHeight: root.s(22)
                                    horizontalPadding: root.s(8)
                                    interactive: false
                                    icon: root.activeDeviceIcon || "󰓃"
                                    label: root.activeDeviceName || I18n.t("music.speaker")
                                    fontSize: root.s(10.5)
                                }
                                Dropdown {
                                    id: sourceDropdown
                                    visible: root.playerList.length >= 2
                                    Layout.preferredHeight: root.s(22)
                                    implicitHeight: root.s(22)
                                    implicitWidth: root.s(140)
                                    cornerRadius: 0
                                    options: root.playerOptions
                                    currentIndex: root.currentPlayerIndex
                                    fontPixelSize: root.s(11.5)
                                    iconSize: root.s(12)
                                    accentColor: "#d0d0d0"
                                    baseColor: "#5e5e5e"
                                    hoverColor: "#7c7c7c"
                                    dropdownColor: "#3a3a3a"
                                    borderColor: "#000000"
                                    textColor: "#e0e0e0"
                                    activeTextColor: "#101010"
                                    onValueChanged: (index, value) => {
                                        root.selectPlayerByIndex(index);
                                    }
                                }
                                McButton {
                                    id: sourcePill
                                    visible: root.playerList.length < 2
                                    Layout.preferredHeight: root.s(22)
                                    horizontalPadding: root.s(8)
                                    interactive: false
                                    label: I18n.t("music.via_source", { "source": root.targetPlayer ? (root.targetPlayer.identity || root.targetPlayer.desktopEntry || "Media") : I18n.t("music.offline") })
                                    fontSize: root.s(10.5)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: -root.s(6)
                            spacing: root.s(2)
                            opacity: root.introControls
                            transform: Translate { x: root.s(18) * (1 - root.introControls); y: root.s(9) * (1 - root.introControls) }

                            Item {
                                id: progBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(24)
                                Layout.topMargin: root.s(4)
                                Layout.bottomMargin: root.s(2)
                                Layout.alignment: Qt.AlignVCenter
                                property real from: 0.0
                                property real to: root.targetPlayer ? root.targetPlayer.length : 100.0
                                property real value: root.currentLivePosition
                                property bool isDragging: seekMa.pressed
                                property real dragFrac: 0
                                readonly property real frac: isDragging ? dragFrac : (to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0)
                                signal moved(real val)

                                McPanel {
                                    id: seekFrame
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: Math.round(root.s(12))
                                    inset: true
                                    fill: "#101010"
                                }
                                Item {
                                    id: seekFill
                                    readonly property int pad: seekFrame.bevel + 1
                                    x: seekFrame.x + pad
                                    y: seekFrame.y + pad
                                    width: (seekFrame.width - pad * 2) * progBar.frac
                                    height: seekFrame.height - pad * 2
                                    clip: true
                                    Rectangle { anchors.fill: parent; color: "#cfcfcf" }
                                    Rectangle { width: parent.width; height: Math.max(1, Math.round(parent.height / 3)); color: "#ffffff" }
                                    Repeater {
                                        model: 17
                                        Rectangle {
                                            x: (index + 1) * (seekFrame.width - seekFill.pad * 2) / 18
                                            width: Math.max(1, Math.round(root.s(2)))
                                            height: seekFill.height
                                            color: "#101010"
                                        }
                                    }
                                }
                                McPanel {
                                    width: Math.round(root.s(10))
                                    height: parent.height
                                    x: Math.max(0, Math.min(parent.width - width, progBar.frac * parent.width - width / 2))
                                    bevel: Math.max(1, Math.round(root.s(2)))
                                    fill: seekMa.containsMouse || seekMa.pressed ? "#9a9a9a" : "#7a7a7a"
                                    light: "#d0d0d0"
                                    dark: "#3a3a3a"
                                }
                                MouseArea {
                                    id: seekMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    function fracAt(mx) { return Math.max(0, Math.min(1, mx / width)); }
                                    onPressed: mouse => { progBar.dragFrac = fracAt(mouse.x); }
                                    onPositionChanged: mouse => { if (pressed) progBar.dragFrac = fracAt(mouse.x); }
                                    onReleased: mouse => {
                                        progBar.moved(progBar.from + fracAt(mouse.x) * (progBar.to - progBar.from));
                                    }
                                }

                                property bool seekPending: false

                                Timer {
                                    id: seekTimer
                                    interval: 1000
                                    onTriggered: progBar.seekPending = false
                                }

                                Connections {
                                    target: root.targetPlayer
                                    function onPositionChanged() {
                                        if (!root.active) return;
                                        if (!progBar.isDragging && !progBar.seekPending && root.targetPlayer) {
                                            progBar.value = root.targetPlayer.position;
                                        }
                                    }
                                }

                                onMoved: val => {
                                    if (root.targetPlayer && root.targetPlayer.canSeek) {
                                        progBar.seekPending = true;
                                        seekTimer.restart();
                                        progBar.value = val;
                                        root.targetPlayer.position = val;
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                McText {
                                    text: root.formatTime(root.currentLivePosition)
                                    color: "#c8c8c8"
                                    font.pixelSize: root.s(11)
                                }
                                Item { Layout.fillWidth: true }
                                McText {
                                    text: root.formatTime(root.targetPlayer ? root.targetPlayer.length : 0)
                                    color: "#c8c8c8"
                                    font.pixelSize: root.s(11)
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.s(18)
                            opacity: root.introControls
                            transform: Translate { y: root.s(18) * (1 - root.introControls) }

                            McButton {
                                id: prevMediaBtn
                                Layout.preferredWidth: root.s(32)
                                Layout.preferredHeight: root.s(32)
                                Layout.alignment: Qt.AlignVCenter
                                bevel: Math.max(2, Math.round(root.s(2)))
                                icon: "󰒮"
                                fontSize: root.s(11)
                                onClicked: if (root.targetPlayer && root.targetPlayer.canGoPrevious) root.targetPlayer.previous()
                            }

                            McButton {
                                id: playPauseBtn
                                Layout.preferredWidth: root.s(43)
                                Layout.preferredHeight: root.s(43)
                                Layout.alignment: Qt.AlignVCenter
                                bevel: Math.max(2, Math.round(root.s(2)))
                                icon: (root.targetPlayer && root.targetPlayer.isPlaying) ? "󰏤" : "󰐊"
                                fontSize: root.s(15)
                                onClicked: if (root.targetPlayer && root.targetPlayer.canTogglePlaying) root.targetPlayer.togglePlaying()
                            }

                            McButton {
                                id: nextMediaBtn
                                Layout.preferredWidth: root.s(32)
                                Layout.preferredHeight: root.s(32)
                                Layout.alignment: Qt.AlignVCenter
                                bevel: Math.max(2, Math.round(root.s(2)))
                                icon: "󰒭"
                                fontSize: root.s(11)
                                onClicked: if (root.targetPlayer && root.targetPlayer.canGoNext) root.targetPlayer.next()
                            }
                        }
                    }
                }

                SteveStage {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.topMargin: 0
                    Layout.bottomMargin: root.s(4)
                    px: Math.max(3, Math.round(root.s(3)))
                    active: root.active
                    playing: !!(root.targetPlayer && root.targetPlayer.isPlaying)
                    beat: root.kickLevel
                    trackId: root.targetPlayer ? (root.targetPlayer.trackTitle || "") : ""

                    opacity: root.introSeparator
                    transform: Translate { y: root.s(12) * (1 - root.introSeparator) }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(12)

                    RowLayout {
                        Layout.fillWidth: true
                        opacity: root.introEqHeader
                        transform: Translate { y: root.s(12) * (1 - root.introEqHeader) }

                        Row {
                            id: bottomSectionSwitch
                            Layout.preferredHeight: root.s(26)
                            spacing: root.s(4)
                            property int currentIndex: 0
                            property var options: [
                                typeof I18n !== "undefined" ? I18n.t("music.equalizer", "Equalizer") : "Equalizer",
                                typeof I18n !== "undefined" ? I18n.t("music.lyrics", "Lyrics") : "Lyrics"
                            ]
                            Repeater {
                                model: bottomSectionSwitch.options
                                McButton {
                                    height: root.s(26)
                                    width: Math.max(root.s(84), implicitWidth)
                                    horizontalPadding: root.s(10)
                                    label: modelData
                                    fontSize: root.s(10.5)
                                    selected: index === bottomSectionSwitch.currentIndex
                                    onClicked: bottomSectionSwitch.currentIndex = index
                                }
                            }
                            onCurrentIndexChanged: {
                                root.updateLyricsSubscription();
                                if (currentIndex === 1) {
                                    toEqAnim.stop();
                                    toLyricsAnim.restart();
                                    root.restoreLastSavedEqualizer();
                                } else {
                                    toLyricsAnim.stop();
                                    root.restoreLastSavedEqualizer();
                                    toEqAnim.restart();
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        McButton {
                            id: actionBtn
                            Layout.preferredHeight: root.s(26)
                            Layout.preferredWidth: root.actionBtnCurrentWidth
                            implicitWidth: root.actionBtnCurrentWidth
                            horizontalPadding: root.s(10)
                            icon: bottomSectionSwitch.currentIndex === 1 && root.actionBtnMorph > 0.45 ? "󰈔" : ""
                            label: {
                                if (bottomSectionSwitch.currentIndex === 1 && root.actionBtnMorph > 0.35) {
                                    return typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file";
                                }
                                return root.eqData && root.eqData.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved");
                            }
                            fontSize: root.s(10.5)
                            iconSize: root.s(13)
                            selected: root.actionBtnMorph < 0.5 && root.eqData && root.eqData.pending
                            enabled: bottomSectionSwitch.currentIndex === 1 ? (root.hasTargetPlayer && !Lyrics.loading) : true
                            opacity: bottomSectionSwitch.currentIndex === 1 ? (root.hasTargetPlayer && !Lyrics.loading ? 1.0 : 0.45) : 1.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            onClicked: {
                                if (bottomSectionSwitch.currentIndex === 1) {
                                    lyricsPickerPopup.targetScreen = (root.Window && root.Window.window) ? root.Window.window.screen : null;
                                    lyricsPickerPopup.openPicker();
                                } else if (root.eqData && root.eqData.pending) {
                                    var temp = Object.assign({}, root.eqData);
                                    temp.pending = false;
                                    root.eqData = temp;
                                    root.savedEqData = Object.assign({}, temp);
                                    root.lastEqUpdate = Date.now();
                                    root.triggerEqLightning();
                                    root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
                                }
                            }
                        }

                        Item {
                            id: presetTextContainer
                            Layout.preferredHeight: root.s(26)
                            Layout.preferredWidth: (presetLabelText.implicitWidth + root.s(12)) * Math.max(0.0, 1.0 - root.presetSlideProgress)
                            implicitWidth: Layout.preferredWidth
                            visible: root.presetSlideProgress < 0.99
                            opacity: Math.max(0.0, 1.0 - root.presetSlideProgress)
                            clip: true

                            McText {
                                id: presetLabelText
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.s(12) + (root.s(24) * root.presetSlideProgress)
                                text: root.eqData && root.eqData.preset ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat")
                                color: "#a8a8a8"
                                font.pixelSize: root.s(12)
                            }
                        }
                    }

                    Item {
                        id: bottomViewsContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(235)

                        Item {
                            id: eqView
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width
                            x: bottomSectionSwitch.currentIndex === 0 ? 0 : -parent.width - root.s(24)
                            opacity: bottomSectionSwitch.currentIndex === 0 ? 1.0 : 0.0
                            visible: opacity > 0.0

                            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuart } }
                            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: root.s(12)

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(140)

                                    Row {
                                        id: eqSliderRow
                                        anchors.fill: parent
                                        z: 1

                                        Repeater {
                                            model: [
                                                {"idx": 1, "lbl": "31"}, {"idx": 2, "lbl": "63"}, {"idx": 3, "lbl": "125"},
                                                {"idx": 4, "lbl": "250"}, {"idx": 5, "lbl": "500"}, {"idx": 6, "lbl": "1k"},
                                                {"idx": 7, "lbl": "2k"}, {"idx": 8, "lbl": "4k"}, {"idx": 9, "lbl": "8k"},
                                                {"idx": 10, "lbl": "16k"}
                                            ]
                                            delegate: Item {
                                                id: sliderDelegate
                                                width: eqSliderRow.width / 10
                                                height: eqSliderRow.height

                                                opacity: root.introEqSliders
                                                transform: Translate {
                                                    y: root.s(25) * (1 - root.introEqSliders) + (index * root.s(7) * (1 - root.introEqSliders))
                                                }

                                                property real dist: root.eqLightningProgress - (modelData.idx - 1)
                                                property real hitPulse: dist >= 0 && dist < 1.0 ? Math.sin((dist) * Math.PI) : 0.0
                                                
                                                property real trackPulse: 0.0
                                                property real ringPulse: 0.0
                                                property real flashFade: 0.0
                                                property bool hasFired: false

                                                onDistChanged: {
                                                    if (dist <= 0.05) {
                                                        hasFired = false;
                                                    } else if (dist > 0.4 && !hasFired) {
                                                        hasFired = true;
                                                        trackPulseAnim.restart();
                                                        ringPulseAnim.restart();
                                                        flashFadeAnim.restart();
                                                    }
                                                }

                                                SequentialAnimation {
                                                    id: trackPulseAnim
                                                    NumberAnimation { target: sliderDelegate; property: "trackPulse"; from: 0.0; to: 1.0; duration: 1000; easing.type: Easing.OutQuart }
                                                }
                                                SequentialAnimation {
                                                    id: ringPulseAnim
                                                    NumberAnimation { target: sliderDelegate; property: "ringPulse"; from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.OutExpo }
                                                }
                                                SequentialAnimation {
                                                    id: flashFadeAnim
                                                    NumberAnimation { target: sliderDelegate; property: "flashFade"; from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.OutSine }
                                                }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    spacing: root.s(4)
                                                    Slider {
                                                        id: eqSlider
                                                        Layout.fillHeight: true
                                                        Layout.alignment: Qt.AlignHCenter
                                                        orientation: Qt.Vertical
                                                        from: -12; to: 12
                                                        stepSize: 1
                                                        hoverEnabled: true

                                                        Connections {
                                                            target: root
                                                            function onEqDataChanged() {
                                                                if (!eqSlider.pressed) {
                                                                    if (root.eqData && root.eqData["b" + modelData.idx] !== undefined) {
                                                                        var p = Number(root.eqData["b" + modelData.idx]);
                                                                        if (!isNaN(p)) eqSlider.value = p;
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Behavior on value {
                                                            enabled: !eqSlider.pressed
                                                            NumberAnimation {
                                                                duration: 350
                                                                easing.type: Easing.OutQuart
                                                            }
                                                        }

                                                        onPressedChanged: {
                                                            if (!pressed) {
                                                                var temp = Object.assign({}, root.eqData);
                                                                temp["b" + modelData.idx] = Math.round(value);
                                                                temp.preset = "Custom";
                                                                temp.pending = true;
                                                                root.eqData = temp;
                                                                
                                                                root.lastEqUpdate = Date.now();
                                                                
                                                                root.execCmd(Caching.qsDir + `/media/equalizer.sh set_band ${modelData.idx} ${Math.round(value)}`);
                                                            }
                                                        }

                                                        background: Rectangle {
                                                            id: trackBg
                                                            x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                            y: eqSlider.topPadding
                                                            implicitWidth: root.s(14)
                                                            implicitHeight: root.s(130)
                                                            width: root.s(14); height: eqSlider.availableHeight
                                                            radius: 0
                                                            color: "transparent"

                                                            McPanel {
                                                                anchors.fill: parent
                                                                inset: true
                                                                fill: "#101010"
                                                            }

                                                            Rectangle {
                                                                z: -1
                                                                anchors.centerIn: parent
                                                                width: parent.width + root.s(17) + sliderDelegate.ringPulse * root.s(34)
                                                                height: parent.height + root.s(17) + sliderDelegate.ringPulse * root.s(51)
                                                                radius: 0
                                                                color: "transparent"
                                                                border.color: root.eqAccentColor
                                                                border.width: root.s(2) + sliderDelegate.ringPulse * root.s(4)
                                                                opacity: sliderDelegate.ringPulse * 0.8 * (1.0 - root.eqLightningFade)
                                                                
                                                                layer.enabled: true
                                                                layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                                                            }

                                                            Item {
                                                                width: parent.width
                                                                height: (1 - eqSlider.visualPosition) * parent.height
                                                                y: eqSlider.visualPosition * parent.height
                                                                
                                                                layer.enabled: true
                                                                layer.effect: MultiEffect {
                                                                    maskEnabled: true
                                                                    maskSource: eqFillMask
                                                                }

                                                                Rectangle {
                                                                    id: eqFillMask
                                                                    anchors.fill: parent
                                                                    radius: 0
                                                                    visible: false
                                                                    layer.enabled: true 
                                                                }

                                                                Rectangle {
                                                                    anchors.fill: parent
                                                                    anchors.margins: Math.max(2, Math.round(root.s(3)))
                                                                    color: "#cfcfcf"

                                                                    Rectangle {
                                                                        anchors.fill: parent
                                                                        opacity: sliderDelegate.flashFade
                                                                        gradient: Gradient {
                                                                            orientation: Gradient.Vertical
                                                                            GradientStop { position: 0.0; color: Qt.lighter(root.eqAccentColor, 1.3) }
                                                                            GradientStop { position: 0.5; color: root.eqAccentColor }
                                                                            GradientStop { position: 1.0; color: "transparent" }
                                                                        }
                                                                    }

                                                                    Rectangle {
                                                                        width: parent.width
                                                                        height: root.s(70)
                                                                        y: (sliderDelegate.trackPulse * (parent.height + height)) - height
                                                                        opacity: Math.sin(sliderDelegate.trackPulse * Math.PI) * 2.0 * (1.0 - root.eqLightningFade)
                                                                        
                                                                        gradient: Gradient {
                                                                            orientation: Gradient.Vertical
                                                                            GradientStop { position: 0.0; color: "transparent" }
                                                                            GradientStop { position: 0.2; color: root.eqAccentColor }
                                                                            GradientStop { position: 0.5; color: ThemeBackend.text || "#ffffff" }
                                                                            GradientStop { position: 0.8; color: Qt.lighter(root.eqAccentColor, 1.2) }
                                                                            GradientStop { position: 1.0; color: "transparent" }
                                                                        }
                                                                        
                                                                        layer.enabled: true
                                                                        layer.effect: MultiEffect {
                                                                            shadowEnabled: true; shadowColor: root.eqAccentColor; shadowBlur: 1.0; shadowOpacity: 1.0
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        handle: Rectangle {
                                                            id: eqHandle
                                                            x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                            y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                                            implicitWidth: root.s(24)
                                                            implicitHeight: root.s(12)
                                                            width: root.s(24); height: root.s(12)
                                                            radius: 0

                                                            property color handleColor: "#7a7a7a"
                                                            property color handleHoverColor: "#9a9a9a"
                                                            property color handleDragColor: "#b0b0b0"

                                                            McPanel {
                                                                anchors.fill: parent
                                                                bevel: Math.max(1, Math.round(root.s(2)))
                                                                fill: parent.color
                                                                light: "#d0d0d0"
                                                                dark: "#3a3a3a"
                                                            }

                                                            color: eqSlider.pressed ? handleDragColor : (eqSlider.hovered ? handleHoverColor : handleColor)
                                                            Behavior on color { ColorAnimation { duration: 150 } }

                                                            property real targetScale: {
                                                                if (eqSlider.pressed) return 1.25;
                                                                if (eqSlider.hovered) return 1.08;
                                                                return 1.0;
                                                            }

                                                            Behavior on targetScale {
                                                                NumberAnimation {
                                                                    duration: 150
                                                                    easing.type: Easing.OutBack
                                                                }
                                                            }

                                                            property real popScale: 1.0
                                                            property real flashOpacity: 0.0

                                                            SequentialAnimation {
                                                                id: eqHandlePopAnim
                                                                NumberAnimation { target: eqHandle; property: "popScale"; to: 1.12; duration: 100; easing.type: Easing.OutQuad }
                                                                NumberAnimation { target: eqHandle; property: "popScale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                                                            }

                                                            Connections {
                                                                target: eqSlider
                                                                function onMoved() {
                                                                    eqHandlePopAnim.restart();
                                                                }
                                                                function onPressedChanged() {
                                                                    if (!eqSlider.pressed) {
                                                                        eqHandle.flashOpacity = 0.35;
                                                                        eqHandleFlashAnim.restart();
                                                                    }
                                                                }
                                                            }

                                                            property var catColors: ["#ffffff"]

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: parent.width + root.s(31) * sliderDelegate.hitPulse
                                                                height: width
                                                                radius: 0
                                                                color: (parent.catColors && parent.catColors.length > 0) ? (parent.catColors[(typeof index !== "undefined" ? index : 0) % parent.catColors.length] || root.eqAccentColor) : root.eqAccentColor
                                                                opacity: sliderDelegate.hitPulse * (1.0 - root.eqLightningFade)
                                                                layer.enabled: true
                                                                layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                radius: parent.radius
                                                                color: "#ffffff"
                                                                opacity: eqHandle.flashOpacity
                                                                PropertyAnimation on opacity { id: eqHandleFlashAnim; to: 0; duration: 300; easing.type: Easing.OutCubic }
                                                            }

                                                            scale: (targetScale * popScale) + (sliderDelegate.hitPulse * 0.4 * (1.0 - root.eqLightningFade))
                                                        }
                                                    }
                                                    McText {
                                                        text: modelData.lbl
                                                        color: "#8a8a8a"
                                                        font.pixelSize: root.s(9)
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ShaderEffect {
                                        id: lightningCanvas
                                        anchors.fill: parent
                                        opacity: 1.0 - root.eqLightningFade
                                        z: 0

                                        property real animTime: 0.0
                                        NumberAnimation on animTime {
                                            running: root.active
                                            loops: Animation.Infinite
                                            from: 0; to: 1000
                                            duration: 1000000
                                        }

                                        property vector2d itemSize: Qt.vector2d(width, height)
                                        property real time: animTime
                                        property real progress: root.eqLightningProgress
                                        property real fade: root.eqLightningFade
                                        property real scale: root.s(1.0)
                                        property color accentColor: root.eqAccentColor

                                        property vector4d bands0: Qt.vector4d(
                                            root.eqData.b1 !== undefined ? Number(root.eqData.b1) : 0,
                                            root.eqData.b2 !== undefined ? Number(root.eqData.b2) : 0,
                                            root.eqData.b3 !== undefined ? Number(root.eqData.b3) : 0,
                                            root.eqData.b4 !== undefined ? Number(root.eqData.b4) : 0
                                        )
                                        property vector4d bands1: Qt.vector4d(
                                            root.eqData.b5 !== undefined ? Number(root.eqData.b5) : 0,
                                            root.eqData.b6 !== undefined ? Number(root.eqData.b6) : 0,
                                            root.eqData.b7 !== undefined ? Number(root.eqData.b7) : 0,
                                            root.eqData.b8 !== undefined ? Number(root.eqData.b8) : 0
                                        )
                                        property vector4d bands2: Qt.vector4d(
                                            root.eqData.b9 !== undefined ? Number(root.eqData.b9) : 0,
                                            root.eqData.b10 !== undefined ? Number(root.eqData.b10) : 0,
                                            root.s(10),
                                            root.s(30)
                                        )

                                        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/vfx/eq_lightning.frag.qsb"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(7)
                                    
                                    opacity: root.introPresets
                                    transform: Translate { y: root.s(18) * (1 - root.introPresets) }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Repeater {
                                            model: ["Flat", "Bass", "Treble", "Vocal"]
                                            delegate: PresetButton { name: modelData }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Repeater {
                                            model: ["Pop", "Rock", "Jazz", "Classic"]
                                            delegate: PresetButton { name: modelData }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: lyricsView
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width
                            x: bottomSectionSwitch.currentIndex === 1 ? 0 : parent.width + root.s(24)
                            opacity: bottomSectionSwitch.currentIndex === 1 ? 1.0 : 0.0
                            visible: opacity > 0.0
                            clip: true

                            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuart } }
                            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                            LyricsView {
                                id: popupLyricsViewport
                                anchors.fill: parent
                                visible: Lyrics.hasLyrics
                                sideMargin: root.s(4)
                                baseActiveFont: root.s(18)
                                lineHeight: Math.max(root.s(30), baseActiveFont * 1.4)
                                lineSpacing: Math.max(root.s(6), baseActiveFont * 0.25)
                                activeLineColor: "#ffffff"
                                inactiveLineColor: "#6a6a6a"
                                fontFamily: "Monocraft"
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: root.s(6)
                                visible: !Lyrics.hasLyrics
                                z: 5

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "󰎈"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(28)
                                    color: root.dynamicTextColor
                                    opacity: 0.75
                                }

                                McText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: {
                                        if (!root.hasTargetPlayer || !root.targetPlayer.trackTitle) return I18n.t("music.nothing_playing");
                                        if (Lyrics.loading) return I18n.t("music.searching_lyrics");
                                        return I18n.t("music.no_lyrics");
                                    }
                                    font.pixelSize: root.s(11)
                                    color: "#9a9a9a"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PresetButton : McButton {
        property string name: ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: root.s(28)
        implicitHeight: root.s(28)
        bevel: Math.max(2, Math.round(root.s(2)))
        label: I18n.t("music.presets." + name.toLowerCase())
        fontSize: root.s(10.5)
        horizontalPadding: 0
        property bool isActivePreset: root.eqData && root.eqData.preset === name
        selected: isActivePreset
        onClicked: root.applyPresetOptimistically(name)
    }
}
