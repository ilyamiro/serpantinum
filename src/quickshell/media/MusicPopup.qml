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

Item {
    id: root

    focus: true

    function s(val) { 
        return Scaler.s(val); 
    }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function resetAndPlayIntro() {
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

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            resetAndPlayIntro();
            Cava.registerConsumer();
            if (!eqProc.running) eqProc.running = true;
            if (titleTextMain.implicitWidth > titleClipRect.width) {
                marqueeContainer.x = 0;
                titleAnim.restart();
            }
        } else {
            Cava.unregisterConsumer();
            titleAnim.stop();
            marqueeContainer.x = 0;
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            resetAndPlayIntro();
            Cava.registerConsumer();
        }
    }

    Component.onDestruction: {
        Cava.unregisterConsumer();
    }

    property int barCount: 60
    property var rawBarLevels: Cava.barLevels

    property var processedBars: {
        let source = rawBarLevels;
        let count = barCount;
        let out = [];

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return { levels: out, bass: 0.0, kick: 0.0 };
        }

        let subBass = (source[0] || 0.0) * 0.50 + (source[1] || 0.0) * 0.35 + (source[2] || 0.0) * 0.15;
        let kickPunch = (source[1] || 0.0) * 0.30 + (source[2] || 0.0) * 0.45 + (source[3] || 0.0) * 0.25;
        let rawKick = Math.max(subBass, kickPunch);

        let kick = rawKick > 0.10 ? Math.min(1.0, Math.pow((rawKick - 0.10) / 0.90, 1.8) * 1.4) : 0.0;
        let bass = Math.max(0.0, Math.min(1.0, subBass * 0.6 + kickPunch * 0.4));

        let srcLen = source.length;
        for (let i = 0; i < count; i++) {
            let norm = i / (count - 1);
            let pos = Math.pow(norm, 1.15) * (srcLen - 1);
            let idx0 = Math.floor(pos);
            let idx1 = Math.min(srcLen - 1, idx0 + 1);
            let frac = pos - idx0;

            let v0 = source[idx0] || 0.0;
            let v1 = source[idx1] || 0.0;
            let val = v0 + (v1 - v0) * frac;

            val = Math.max(0.0, Math.min(1.0, val));
            val = Math.pow(val, 1.08);

            out.push(val);
        }

        return { levels: out, bass: bass, kick: kick };
    }

    property var barLevels: processedBars.levels
    property real bassLevel: processedBars.bass
    property real kickLevel: processedBars.kick

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
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
        }
        function onPostTrackChanged() {
            if (root.targetPlayer) root.currentLivePosition = root.targetPlayer.position;
            root.triggerLocalArtFetch();
        }
        function onTrackArtUrlChanged() {
            root.triggerLocalArtFetch();
        }
        function onTrackTitleChanged() {
            root.triggerLocalArtFetch();
        }
    }

    onTargetPlayerChanged: {
        if (targetPlayer) currentLivePosition = targetPlayer.position;
        triggerLocalArtFetch();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.hasTargetPlayer && root.targetPlayer.isPlaying
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

    property color eqAccentColor: ThemeBackend.mauve || "#cba6f7"
    property string accumulatedEqOut: ""
    property real lastEqUpdate: 0

    property real catppuccinFlowOffset: 0
    NumberAnimation on catppuccinFlowOffset {
        from: 0; to: 1.0
        duration: 8000
        loops: Animation.Infinite
        running: true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
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

    property color dynamicTextColor: {
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
            
            root.lastEqUpdate = Date.now();
            
            root.triggerEqLightning();
            execCmd(Caching.qsDir + `/media/equalizer.sh preset ${presetName}`);
        }
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!eqProc.running) eqProc.running = true;
        }
    }

    Process {
        id: eqProc
        running: true
        command: ["bash", "-c", Caching.qsDir + "/media/equalizer.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    if (Date.now() - root.lastEqUpdate < 2000) return;

                    var outStr = this.text.trim();
                    if (outStr.length > 0) {
                        try { root.eqData = JSON.parse(outStr); } catch(e) {}
                    }
                }
            }
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
                        running: true
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
                source: gradContainer
                anchors.fill: parent
                maskEnabled: true
                maskSource: maskRectOuter
            }
        }

        Rectangle {
            id: innerBg
            anchors.fill: parent
            anchors.margins: root.s(3)
            color: ThemeBackend.base
            radius: ThemeBackend.borderRadius

            layer.enabled: true

            Rectangle {
                id: innerBgMask
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
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
                    property string blurUrl: root.activeBlur ? "file://" + root.activeBlur : ""
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
                    color: (root.targetPlayer && root.targetPlayer.isPlaying) ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface2 || "#585b70")
                    Behavior on color { ColorAnimation { duration: 1000 } }
                    Behavior on opacity { NumberAnimation { duration: 1000 } }
                }
                
                Rectangle {
                    width: parent.width * 0.9; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * root.s(-150)
                    y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * root.s(-100)
                    
                    opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? 0.025 : (root.hasTargetPlayer ? 0.01 : 0.0)
                    color: (root.targetPlayer && root.targetPlayer.isPlaying) ? (ThemeBackend.blue || "#89b4fa") : (ThemeBackend.surface1 || "#45475a")
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

                            Rectangle {
                                anchors.centerIn: parent
                                width: (coverHost.artRadius * 2) + (coverHost.maxBarHeight * 2.2)
                                height: width
                                radius: width / 2
                                color: ThemeBackend.mauve || "#cba6f7"
                                opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.005 + (root.bassLevel * 0.035)) : 0.0
                                scale: 0.985 + (root.bassLevel * 0.0375)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                Behavior on scale {
                                    SpringAnimation {
                                        spring: 4.2
                                        damping: 0.38
                                        mass: 0.8
                                    }
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: (coverHost.artRadius * 2) + (coverHost.maxBarHeight * 1.5)
                                height: width
                                radius: width / 2
                                color: ThemeBackend.mauve || "#cba6f7"
                                opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.01 + (root.kickLevel * 0.055)) : 0.0
                                scale: 0.992 + (root.kickLevel * 0.02625)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 40
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on scale {
                                    SpringAnimation {
                                        spring: 5.2
                                        damping: 0.34
                                        mass: 0.6
                                    }
                                }
                            }

                            Repeater {
                                model: root.barCount
                                delegate: Item {
                                    anchors.centerIn: parent
                                    width: 0
                                    height: 0
                                    rotation: index * (360 / root.barCount)

                                    property real level: {
                                        if (!root.barLevels || root.barLevels.length === 0) return 0.0;
                                        return root.barLevels[index] || 0.0;
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: coverHost.artRadius
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: coverHost.barWidth
                                        height: Math.max(root.s(2), parent.level * coverHost.maxBarHeight * 1.4)
                                        topLeftRadius: width / 2
                                        topRightRadius: width / 2
                                        bottomLeftRadius: 0
                                        bottomRightRadius: 0
                                        antialiasing: true
                                        color: {
                                            let mixRatio = (index / root.barCount) * 0.4 + (parent.level * 0.6);
                                            let baseColor = ThemeBackend.mauve || "#cba6f7";
                                            return Qt.tint(baseColor, Qt.rgba(1, 1, 1, mixRatio * 0.45));
                                        }
                                        opacity: 0.40 + (parent.level * 0.60)

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 70
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: discContainer
                                anchors.fill: parent

                                property real borderWidth: 0

                                Rectangle {
                                    z: -1
                                    anchors.centerIn: parent
                                    width: parent.width + root.s(12)
                                    height: parent.height + root.s(12)
                                    radius: width / 2
                                    color: ThemeBackend.mauve || "#cba6f7"
                                    opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.35 + root.kickLevel * 0.25) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 500 } }
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        blurEnabled: true
                                        blurMax: 32
                                        blur: 1.0
                                    }
                                }

                                Rectangle {
                                    id: vinylBase
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: ThemeBackend.surface1 || "#45475a"
                                    border.width: discContainer.borderWidth
                                    border.color: (root.targetPlayer && root.targetPlayer.isPlaying) ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.overlay0 || "#6c7086")
                                    Behavior on border.color { ColorAnimation { duration: 500 } }

                                    NumberAnimation on rotation {
                                        from: 0; to: 360; duration: 25000
                                        loops: Animation.Infinite
                                        running: true
                                        paused: !(root.targetPlayer && root.targetPlayer.isPlaying)
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: vinylBase.border.width

                                        Rectangle {
                                            id: maskRect
                                            anchors.fill: parent
                                            radius: width / 2
                                            visible: false
                                            layer.enabled: true 
                                        }

                                        Item {
                                            id: artMaskedContainer
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: maskRect
                                            }

                                            Item {
                                                id: artCrossfader
                                                anchors.fill: parent
                                                property string artSource: root.activeArtUrl ? (root.activeArtUrl.startsWith("file://") || root.activeArtUrl.startsWith("http") ? root.activeArtUrl : "file://" + root.activeArtUrl) : ""
                                                property bool showingA: true

                                                Image {
                                                    id: artImgA
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectCrop
                                                    opacity: artCrossfader.showingA && status === Image.Ready ? 1.0 : 0.0
                                                    Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
                                                }

                                                Image {
                                                    id: artImgB
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectCrop
                                                    opacity: !artCrossfader.showingA && status === Image.Ready ? 1.0 : 0.0
                                                    Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
                                                }

                                                onArtSourceChanged: {
                                                    if (!artSource) {
                                                        artImgA.source = "";
                                                        artImgB.source = "";
                                                        return;
                                                    }
                                                    if (showingA) {
                                                        artImgB.source = artSource;
                                                        showingA = false;
                                                    } else {
                                                        artImgA.source = artSource;
                                                        showingA = true;
                                                    }
                                                }

                                                Component.onCompleted: {
                                                    if (artSource) {
                                                        artImgA.source = artSource;
                                                        showingA = true;
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: fallbackPlaceholder
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: ThemeBackend.mantle || "#1e1e2e"
                                            opacity: (root.hasTargetPlayer && root.activeArtUrl) ? 0.0 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: 400 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰝚"
                                                font.pixelSize: parent.width * 0.26
                                                color: ThemeBackend.overlay1 || "#7f849c"
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: {
                                                let m = ThemeBackend.mauve || Qt.rgba(0.8, 0.6, 0.9, 1);
                                                return Qt.rgba(m.r, m.g, m.b, 0.08 + (root.kickLevel * 0.08));
                                            }
                                            opacity: (root.hasTargetPlayer && root.activeArtUrl) ? 1.0 : 0.0
                                            Behavior on opacity { NumberAnimation { duration: 600 } }
                                        }

                                        Repeater {
                                            model: [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44]
                                            delegate: Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width * modelData
                                                height: width
                                                radius: width / 2
                                                color: "transparent"
                                                border.color: index % 2 === 0 ? "#ffffff" : "#000000"
                                                border.width: 1
                                                opacity: (index % 2 === 0 ? 0.035 : 0.06) + (root.bassLevel * 0.02)
                                                antialiasing: true
                                            }
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.28
                                            height: width
                                            radius: width / 2
                                            color: ThemeBackend.crust || "#11111b"
                                            opacity: 0.96
                                            scale: 1.0 + (root.kickLevel * 0.0135)
                                            border.width: 1.5
                                            border.color: {
                                                let m = ThemeBackend.mauve || Qt.rgba(0.8, 0.6, 0.9, 1);
                                                return Qt.rgba(m.r, m.g, m.b, 0.45 + (root.kickLevel * 0.4));
                                            }

                                            Behavior on scale {
                                                SpringAnimation {
                                                    spring: 6.0
                                                    damping: 0.32
                                                    mass: 0.5
                                                }
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width * 0.68
                                                height: width
                                                radius: width / 2
                                                color: ThemeBackend.surface2 || "#585b70"
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.18)

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: parent.width * 0.38
                                                    height: width
                                                    radius: width / 2
                                                    color: "#0d0e15"
                                                }
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
                            spacing: root.s(6)
                            opacity: root.introText
                            transform: Translate { x: root.s(25) * (1 - root.introText) }
                            
                            Item {
                                id: titleClipRect
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(25) 
                                clip: true

                                property int marqueeSpacing: root.s(50)

                                Item {
                                    id: marqueeContainer
                                    height: parent.height

                                    Row {
                                        spacing: titleClipRect.marqueeSpacing
                                        Text {
                                            id: titleTextMain
                                            text: (root.targetPlayer && root.targetPlayer.trackTitle !== "") ? root.targetPlayer.trackTitle : I18n.t("music.nothing_playing")
                                            color: root.dynamicTextColor
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(19)
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: 600 } }

                                            onTextChanged: {
                                                marqueeContainer.x = 0;
                                                if (implicitWidth > titleClipRect.width && root.visible) {
                                                    titleAnim.restart();
                                                } else {
                                                    titleAnim.stop();
                                                }
                                            }
                                        }
                                        Text {
                                            id: titleTextClone
                                            text: titleTextMain.text
                                            color: root.dynamicTextColor
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(19)
                                            font.bold: true
                                            visible: titleTextMain.implicitWidth > titleClipRect.width
                                        }
                                    }

                                    SequentialAnimation on x {
                                        id: titleAnim
                                        loops: Animation.Infinite
                                        running: root.visible && titleTextMain.implicitWidth > titleClipRect.width

                                        PauseAnimation { duration: 3000 }
                                        
                                        NumberAnimation {
                                            from: 0
                                            to: -(titleTextMain.implicitWidth + titleClipRect.marqueeSpacing)
                                            duration: (titleTextMain.implicitWidth + titleClipRect.marqueeSpacing) * 25
                                        }
                                        
                                        PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                                    }
                                }
                            }

                            Text {
                                text: root.targetPlayer && root.targetPlayer.trackArtist ? I18n.t("music.by_artist", { "artist": root.targetPlayer.trackArtist }) : I18n.t("music.by_artist", { "artist": I18n.t("music.unknown_artist") })
                                color: root.dynamicTextColor
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13.5)
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(18)
                            }
                            RowLayout {
                                spacing: root.s(9)
                                ClickButton {
                                    id: devicePill
                                    Layout.preferredHeight: root.s(22)
                                    cornerRadius: ThemeBackend.borderRadius
                                    horizontalPadding: root.s(10)
                                    buttonText: (root.activeDeviceIcon || "󰓃") + " " + (root.activeDeviceName || I18n.t("music.speaker"))
                                    textFontSize: root.s(11.5)
                                    accentColor: ThemeBackend.surface0 || "#313244"
                                    textColor: ThemeBackend.text || "#cdd6f4"
                                }
                                Dropdown {
                                    id: sourceDropdown
                                    visible: root.playerList.length >= 2
                                    Layout.preferredHeight: root.s(22)
                                    implicitHeight: root.s(22)
                                    implicitWidth: root.s(140)
                                    cornerRadius: ThemeBackend.borderRadius
                                    options: root.playerOptions
                                    currentIndex: root.currentPlayerIndex
                                    fontPixelSize: root.s(11.5)
                                    iconSize: root.s(12)
                                    accentColor: ThemeBackend.mauve || "#cba6f7"
                                    baseColor: ThemeBackend.surface0 || "#313244"
                                    hoverColor: ThemeBackend.surface1 || "#45475a"
                                    dropdownColor: ThemeBackend.surface0
                                    borderColor: Qt.alpha(ThemeBackend.surface2 || "#585b70", 0.6)
                                    textColor: ThemeBackend.text || "#cdd6f4"
                                    activeTextColor: ThemeBackend.crust || "#11111b"
                                    onValueChanged: (index, value) => {
                                        root.selectPlayerByIndex(index);
                                    }
                                }
                                ClickButton {
                                    id: sourcePill
                                    visible: root.playerList.length < 2
                                    Layout.preferredHeight: root.s(22)
                                    cornerRadius: ThemeBackend.borderRadius
                                    horizontalPadding: root.s(10)
                                    buttonText: I18n.t("music.via_source", { "source": root.targetPlayer ? (root.targetPlayer.identity || root.targetPlayer.desktopEntry || "Media") : I18n.t("music.offline") })
                                    textFontSize: root.s(11.5)
                                    accentColor: ThemeBackend.surface0 || "#313244"
                                    textColor: ThemeBackend.subtext0 || "#9399b2"
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.s(4)
                            opacity: root.introControls
                            transform: Translate { x: root.s(18) * (1 - root.introControls); y: root.s(9) * (1 - root.introControls) }

                            Draggable {
                                id: progBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(15)
                                Layout.alignment: Qt.AlignVCenter
                                from: 0.0
                                to: root.targetPlayer ? root.targetPlayer.length : 100.0
                                value: root.currentLivePosition
                                showValueBubble: false
                                showTooltip: false
                                valueFormatter: function(v) { return "" }
                                backgroundColor: ThemeBackend.surface0 || "#313244"
                                accentColor: ThemeBackend.mauve || "#cba6f7"
                                gradColor1: Qt.lighter(ThemeBackend.blue || "#89b4fa", 1.2)
                                gradColor2: Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.15)
                                gradColor3: Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.15)
                                cornerRadius: ThemeBackend.borderRadius
                                handleSize: root.s(15)

                                handleColor: Qt.lighter(ThemeBackend.blue || "#89b4fa", 1.15)
                                handleHoverColor: Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.65)
                                handleDragColor: Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.65)
                                handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

                                property bool seekPending: false
                                
                                Timer {
                                    id: seekTimer
                                    interval: 1000
                                    onTriggered: progBar.seekPending = false
                                }

                                Connections {
                                    target: root.targetPlayer
                                    function onPositionChanged() {
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
                                Text { 
                                    text: root.formatTime(root.currentLivePosition); 
                                    color: root.dynamicTextColor; 
                                    font.family: ThemeBackend.fontFamily; 
                                    font.bold: true; 
                                    font.pixelSize: root.s(12);
                                    Behavior on color { ColorAnimation { duration: 600 } }
                                }
                                Item { Layout.fillWidth: true }
                                Text { 
                                    text: root.formatTime(root.targetPlayer ? root.targetPlayer.length : 0); 
                                    color: root.dynamicTextColor; 
                                    font.family: ThemeBackend.fontFamily; 
                                    font.bold: true; 
                                    font.pixelSize: root.s(12);
                                    Behavior on color { ColorAnimation { duration: 600 } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.s(18)
                            opacity: root.introControls
                            transform: Translate { y: root.s(18) * (1 - root.introControls) }

                            IconButton {
                                id: prevMediaBtn
                                Layout.preferredWidth: root.s(32)
                                Layout.preferredHeight: root.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰒮"
                                iconFontSize: root.s(21)
                                accentColor: ThemeBackend.surface0 || "#313244"
                                textColor: isHoveredOrHighlighted ? (ThemeBackend.text || "#cdd6f4") : (ThemeBackend.subtext0 || "#a6adc8")
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (root.targetPlayer && root.targetPlayer.canGoPrevious) root.targetPlayer.previous()
                            }

                            IconButton {
                                id: playPauseBtn
                                iconOffsetY: -2
                                Layout.preferredWidth: root.s(43)
                                Layout.preferredHeight: root.s(43)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: (root.targetPlayer && root.targetPlayer.isPlaying) ? "󰏤" : "󰐊"
                                iconFontSize: root.s(32)
                                accentColor: ThemeBackend.surface0 || "#313244"
                                textColor: isHoveredOrHighlighted ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.text || "#cdd6f4")
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (root.targetPlayer && root.targetPlayer.canTogglePlaying) root.targetPlayer.togglePlaying()
                            }

                            IconButton {
                                id: nextMediaBtn
                                Layout.preferredWidth: root.s(32)
                                Layout.preferredHeight: root.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰒭"
                                iconFontSize: root.s(21)
                                accentColor: ThemeBackend.surface0 || "#313244"
                                textColor: isHoveredOrHighlighted ? (ThemeBackend.text || "#cdd6f4") : (ThemeBackend.subtext0 || "#a6adc8")
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (root.targetPlayer && root.targetPlayer.canGoNext) root.targetPlayer.next()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(2)
                    Layout.topMargin: root.s(16)
                    Layout.bottomMargin: root.s(16)
                    color: "#1AFFFFFF"
                    radius: root.s(1)

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

                        Text { text: I18n.t("music.equalizer"); color: ThemeBackend.mauve || "#cba6f7"; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(15); font.bold: true; Layout.fillWidth: true }
                        
                        ClickButton {
                            id: applyBtn
                            Layout.preferredHeight: root.s(26)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: root.s(12)
                            buttonText: root.eqData.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved")
                            textFontSize: root.s(11.5)
                            accentColor: root.eqData.pending ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface1 || "#45475a")
                            textColor: root.eqData.pending ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.subtext0 || "#a6adc8")
                            enabled: root.eqData.pending
                            onClicked: {
                                if (root.eqData.pending) {
                                    var temp = Object.assign({}, root.eqData);
                                    temp.pending = false;
                                    root.eqData = temp;
                                    
                                    root.lastEqUpdate = Date.now();
                                    
                                    root.triggerEqLightning();
                                    root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
                                }
                            }
                        }
                        Text { text: root.eqData.preset ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat"); color: ThemeBackend.subtext0 || "#a6adc8"; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(13); font.bold: true; Layout.leftMargin: root.s(12) }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(155)

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
                                                implicitWidth: root.s(12)
                                                implicitHeight: root.s(130)
                                                width: root.s(12); height: eqSlider.availableHeight
                                                radius: ThemeBackend.borderRadius
                                                
                                                color: Qt.rgba((ThemeBackend.surface0 ? ThemeBackend.surface0.r : 0.2), (ThemeBackend.surface0 ? ThemeBackend.surface0.g : 0.2), (ThemeBackend.surface0 ? ThemeBackend.surface0.b : 0.3), 0.7)

                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    id: trackEffect
                                                    shadowEnabled: true
                                                    shadowColor: "#000000"
                                                    shadowOpacity: 0.9
                                                    shadowBlur: 0.5
                                                    shadowVerticalOffset: 1
                                                }

                                                Rectangle {
                                                    z: -1
                                                    anchors.centerIn: parent
                                                    width: parent.width + root.s(17) + sliderDelegate.ringPulse * root.s(34)
                                                    height: parent.height + root.s(17) + sliderDelegate.ringPulse * root.s(51)
                                                    radius: parent.radius + root.s(8) + sliderDelegate.ringPulse * root.s(17)
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
                                                        radius: ThemeBackend.borderRadius
                                                        visible: false
                                                        layer.enabled: true 
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: root.eqAccentColor

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
                                                implicitWidth: root.s(16)
                                                implicitHeight: root.s(16)
                                                width: root.s(16); height: root.s(16)
                                                radius: root.s(8)

                                                property color handleColor: ThemeBackend.text || "#cdd6f4"
                                                property color handleHoverColor: Qt.lighter(root.eqAccentColor, 1.15)
                                                property color handleDragColor: Qt.lighter(root.eqAccentColor, 1.30)

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

                                                property var catColors: [
                                                    root.eqAccentColor,
                                                    ThemeBackend.pink || "#f5c2e7",
                                                    ThemeBackend.lavender || "#b4befe",
                                                    root.eqAccentColor,
                                                    ThemeBackend.blue || "#89b4fa"
                                                ]

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: parent.width + root.s(31) * sliderDelegate.hitPulse
                                                    height: width
                                                    radius: width / 2
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
                                        Text {
                                            text: modelData.lbl
                                            color: ThemeBackend.overlay1 || "#7f849c"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(9.5)
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }

                        Canvas {
                            id: lightningCanvas
                            anchors.fill: parent
                            opacity: 1.0 - root.eqLightningFade
                            z: 0

                            renderTarget: Canvas.FramebufferObject

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: root.eqAccentColor
                                shadowBlur: 1.0
                                shadowOpacity: 0.8
                                shadowVerticalOffset: 0
                                shadowHorizontalOffset: 0
                            }

                            Timer {
                                interval: 16
                                running: root.eqLightningFade < 1.0 && root.eqLightningProgress > 0.0
                                repeat: true
                                onTriggered: lightningCanvas.requestPaint()
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                if (root.eqLightningProgress <= 0.0 || root.eqLightningFade >= 1.0) return;

                                var time = Date.now() / 1000;
                                var maxIdx = root.eqLightningProgress;

                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";

                                var pts = [];
                                for (var i = 1; i <= 10; i++) {
                                    var val = root.eqData["b" + i] !== undefined ? Number(root.eqData["b" + i]) : 0;
                                    var norm = 1.0 - ((val + 12) / 24);
                                    
                                    var py = root.s(10) + norm * (height - root.s(30));
                                    var px = (i - 0.5) * (width / 10);
                                    pts.push({ x: px, y: py });
                                }

                                for (var s = 0; s < 4; s++) {
                                    ctx.beginPath();
                                    ctx.moveTo(pts[0].x, pts[0].y);

                                    for (var i = 0; i < pts.length - 1; i++) {
                                        if (i > maxIdx) break;

                                        var p1 = pts[i];
                                        var p2 = pts[i+1];

                                        var fraction = 1.0;
                                        if (maxIdx < i + 1) {
                                            fraction = maxIdx - i;
                                        }

                                        var steps = s === 3 ? 6 : 8;
                                        for (var j = 1; j <= steps; j++) {
                                            var t = j / steps;
                                            if (t > fraction) t = fraction;

                                            var cx = p1.x + (p2.x - p1.x) * t;
                                            var cy = p1.y + (p2.y - p1.y) * t;

                                            var envelope = Math.sin(t * Math.PI);

                                            var noiseAmpX = s === 3 ? 1.0 : (4 - s) * 4;
                                            var noiseAmpY = s === 3 ? 1.0 : (4 - s) * 5;
                                            
                                            var sepWaveX = (s < 2) ? Math.sin(time * 3 + i + j + s) * root.s(9) * envelope : 0;
                                            var sepWaveY = (s < 2) ? Math.cos(time * 2.5 + i - j - s) * root.s(13.5) * envelope : 0;

                                            var noiseX = Math.sin(time * (10+s) + i + j) * Math.cos(time * 8 - i + j) * noiseAmpX * envelope * (1 - root.eqLightningFade);
                                            var noiseY = Math.cos(time * (9-s) + i - j) * Math.sin(time * 7 + i - j) * noiseAmpY * envelope * (1 - root.eqLightningFade);

                                            ctx.lineTo(cx + sepWaveX + noiseX, cy + sepWaveY + noiseY);

                                            if (t === fraction) break;
                                        }
                                    }

                                    if (s === 0) {
                                        ctx.lineWidth = root.s(18);
                                        ctx.strokeStyle = root.eqAccentColor;
                                        ctx.globalAlpha = 0.35;
                                    } else if (s === 1) {
                                        ctx.lineWidth = root.s(9);
                                        ctx.strokeStyle = Qt.lighter(root.eqAccentColor, 1.25);
                                        ctx.globalAlpha = 0.65;
                                    } else if (s === 2) {
                                        ctx.lineWidth = root.s(4.5);
                                        ctx.strokeStyle = Qt.lighter(root.eqAccentColor, 1.5);
                                        ctx.globalAlpha = 0.9;
                                    } else if (s === 3) {
                                        ctx.lineWidth = root.s(2.2);
                                        ctx.strokeStyle = "#ffffff";
                                        ctx.globalAlpha = 1.0;
                                    }

                                    ctx.stroke();
                                }
                            }
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
        }
    }

    component PresetButton : ClickButton {
        property string name: ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: root.s(28)
        cornerRadius: ThemeBackend.borderRadius
        buttonText: I18n.t("music.presets." + name.toLowerCase())
        textFontSize: root.s(11.5)
        horizontalPadding: 0
        property bool isActivePreset: root.eqData && root.eqData.preset === name
        accentColor: isActivePreset ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface0 || "#313244")
        textColor: isActivePreset ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.subtext0 || "#a6adc8")
        onClicked: root.applyPresetOptimistically(name)
    }
}
