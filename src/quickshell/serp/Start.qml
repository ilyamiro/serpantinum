import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: window

    signal finished()
    signal closed()

    WlrLayershell.namespace: "welcome-guide"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Quickshell.primaryScreen || null

    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    color: "transparent"

    function s(val) {
        let res = Scaler.s(val);
        return res > 0 ? res : val;
    }

    readonly property color base:     ThemeBackend.base
    readonly property color mantle:   ThemeBackend.mantle   || ThemeBackend.base
    readonly property color crust:    ThemeBackend.crust
    readonly property color surface0: ThemeBackend.surface0
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface2: ThemeBackend.surface2
    readonly property color text:     ThemeBackend.text
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color green:    ThemeBackend.green
    readonly property color blue:     ThemeBackend.blue     || "#89b4fa"
    readonly property color mauve:    ThemeBackend.mauve    || "#cba6f7"
    readonly property color peach:    ThemeBackend.peach    || "#fab387"

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 120000; loops: Animation.Infinite; running: true
    }

    property real panelReveal: 0.0
    property real introPhase: 0.0
    NumberAnimation on introPhase {
        from: 0.0; to: 1.0; duration: 2500; easing.type: Easing.OutExpo; running: window.panelReveal > 0.5
    }

    property real orbBoost: 0.0

    property real welcomeReveal: 0.0
    property real welcomeOpacity: 1.0

    property real shellTextReveal: 0.0
    property real shellTextOpacity: 0.0
    property real shellTextScale: 0.94

    property real authorOpacity: 0.0
    property real authorScale: 0.94
    property real authorAnimX: 0
    property real authorAnimY: window.s(20)

    property bool authorAbsolute: false
    property real finalAuthorOpacity: 0.0

    property real toSerpReveal: 0.0
    property real toSerpOpacity: 0.0

    property real logoOpacity: 0.0
    property real logoScale: 0.94

    property bool colorizeActive: false
    property real logoFillLevel: 0.0
    property real btnOpacity: 0.0

    property real textGroupOffset: 0
    property real mainOpacity: 1.0

    property int bgSoundHandle: -1
    property int exitSoundHandle: -1

    property bool idleTextActive: false
    property real idlePhase: 0.0
    NumberAnimation on idlePhase {
        from: 0.0; to: Math.PI * 2; duration: 8000; loops: Animation.Infinite; running: window.idleTextActive
    }

    property real monitorZoomProgress: 0.0

    component TypewriterText : Row {
        id: twRoot
        property string text: ""
        property real reveal: 0.0
        property font font
        property color color: window.text
        property bool soundEnabled: true
        property string typeSfx: "start/type.wav"

        spacing: 0
        Repeater {
            model: Array.from(twRoot.text)
            Text {
                required property string modelData
                required property int index
                text: modelData === " " ? "\u00A0" : modelData
                font: twRoot.font
                color: twRoot.color

                property bool shown: (twRoot.reveal * (twRoot.text.length + 2)) > index

                onShownChanged: {
                    if (shown && twRoot.soundEnabled && modelData !== " ") {
                        if (typeof Sounds !== "undefined") Sounds.playSfx(twRoot.typeSfx);
                    }
                }

                opacity: shown ? 1.0 : 0.0
                scale: shown ? 1.0 : 0.94
                rotation: 0

                transform: Translate {
                    y: (shown ? 0 : window.s(10)) + (window.idleTextActive && shown ? Math.sin(window.idlePhase + (index * 0.3)) * window.s(1.2) : 0)
                    Behavior on y { NumberAnimation { duration: 550; easing.type: Easing.OutQuint } }
                }

                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    Timer {
        id: initStartTimer
        interval: 100
        repeat: false
        onTriggered: introChoreography.start()
    }

    Component.onCompleted: initStartTimer.start()

    SequentialAnimation {
        id: introChoreography
        ScriptAction { script: window.bgSoundHandle = Sounds.playUntilStopped("start/background.wav", 0.4, true) }
        ScriptAction { script: Sounds.playSfx("start/start.wav") }
        PauseAnimation { duration: 100 }

        NumberAnimation { target: window; property: "panelReveal"; from: 0.0; to: 1.0; duration: 2000; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 140 }

        NumberAnimation { target: window; property: "welcomeReveal"; to: 1.0; duration: 850; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 800 }
        NumberAnimation { target: window; property: "welcomeOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }

        ParallelAnimation {
            PropertyAction { target: window; property: "shellTextOpacity"; value: 1.0 }
            NumberAnimation { target: window; property: "shellTextReveal"; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { target: window; property: "shellTextScale"; from: 0.94; to: 1.0; duration: 1600; easing.type: Easing.OutExpo }
        }
        PauseAnimation { duration: 140 }
        ParallelAnimation {
            NumberAnimation { target: window; property: "authorOpacity"; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
            NumberAnimation { target: window; property: "authorScale"; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
            ScriptAction { script: Sounds.playSfx("start/pop_author.wav") }
        }

        PauseAnimation { duration: 1500 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "shellTextOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "authorOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        }
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }

        ParallelAnimation {
            SequentialAnimation {
                PropertyAction { target: window; property: "authorAbsolute"; value: true }
                PauseAnimation { duration: 800 }
                NumberAnimation { target: window; property: "finalAuthorOpacity"; to: 0.6; duration: 1000; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 210 }

                ParallelAnimation {
                    ParallelAnimation {
                        PropertyAction { target: window; property: "toSerpOpacity"; value: 1.0 }
                        NumberAnimation { target: window; property: "toSerpReveal"; to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { target: window; property: "logoOpacity"; to: 1.0; duration: 1500; easing.type: Easing.OutQuart }
                        NumberAnimation { target: window; property: "logoScale"; from: 0.94; to: 1.0; duration: 1800; easing.type: Easing.OutExpo }
                    }

                    SequentialAnimation {
                        PauseAnimation { duration: 1200 }
                        ParallelAnimation {
                            NumberAnimation { target: window; property: "btnOpacity"; to: 1.0; duration: 600; easing.type: Easing.OutQuint }
                            ScriptAction { script: window.idleTextActive = true }
                        }
                    }
                }
            }

            SequentialAnimation {
                ScriptAction { script: Sounds.playSfx("start/wave.wav", 0.2) }
                PauseAnimation { duration: 300 }

                ParallelAnimation {
                    NumberAnimation { target: window; property: "orbBoost"; to: 1.0; duration: 3200; easing.type: Easing.OutSine }
                    ScriptAction { script: window.colorizeActive = true }
                    NumberAnimation { target: window; property: "logoFillLevel"; to: 1.5; duration: 4500; easing.type: Easing.OutSine }
                    NumberAnimation { target: window; property: "monitorZoomProgress"; from: 0.0; to: 1.0; duration: 2800; easing.type: Easing.OutQuint }
                }
            }
        }
    }

    Canvas {
        id: bgCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        property real phase: 0.0
        NumberAnimation on phase {
            loops: Animation.Infinite
            running: window.panelReveal > 0.0 && window.panelReveal < 1.0
            from: 0; to: Math.PI * 2; duration: 3600
        }

        onPhaseChanged: requestPaint()

        Connections {
            target: window
            function onPanelRevealChanged() {
                if (window.panelReveal <= 0.0 || window.panelReveal >= 1.0) {
                    bgCanvas.requestPaint();
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (window.panelReveal <= 0.0) return;
            if (window.panelReveal >= 1.0) {
                ctx.fillStyle = window.base.toString();
                ctx.fillRect(0, 0, width, height);
                return;
            }

            function drawWipe(prog, color, ampMult, pOffset) {
                if (prog <= 0.0) return;
                if (prog >= 1.0) {
                    ctx.fillStyle = color;
                    ctx.fillRect(0, 0, width, height);
                    return;
                }

                var currentX = width * prog;
                var waveAmp = window.s(45) * Math.sin(prog * Math.PI) * ampMult;

                ctx.beginPath();
                ctx.moveTo(0, 0);

                var cp1x = currentX + Math.sin(phase + pOffset) * waveAmp;
                var cp1y = height * 0.33;
                var cp2x = currentX + Math.cos(phase + pOffset + Math.PI) * waveAmp;
                var cp2y = height * 0.66;

                ctx.lineTo(currentX, 0);
                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, currentX, height);
                ctx.lineTo(0, height);
                ctx.closePath();

                ctx.fillStyle = color;
                ctx.fill();
            }

            var speedFact = 2.5;
            var p1 = Math.max(0.0, Math.min(1.0, (window.panelReveal - 0.00) * speedFact));
            var p2 = Math.max(0.0, Math.min(1.0, (window.panelReveal - 0.05) * speedFact));
            var p3 = Math.max(0.0, Math.min(1.0, (window.panelReveal - 0.10) * speedFact));
            var p4 = Math.max(0.0, Math.min(1.0, (window.panelReveal - 0.15) * speedFact));
            var p5 = Math.max(0.0, Math.min(1.0, (window.panelReveal - 0.20) * speedFact));

            drawWipe(p1, window.crust.toString(), 1.8, 0.0);
            drawWipe(p2, window.surface1.toString(), 1.5, 0.5);
            drawWipe(p3, window.blue.toString(), 1.2, 1.0);
            drawWipe(p4, window.mauve.toString(), 0.9, 1.5);
            drawWipe(p5, window.base.toString(), 0.6, 2.0);
        }
    }

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        opacity: window.mainOpacity

        Shortcut {
            sequence: "Escape"
            onActivated: closeSequence.start()
        }

        Item {
            id: mauveOrbContainer
            width: window.s(1200); height: width
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            opacity: window.introPhase * 0.04 + window.orbBoost * 0.12
            z: 1

            transform: Translate {
                x: Math.cos(window.globalOrbitAngle * 2) * window.s(450)
                y: Math.sin(window.globalOrbitAngle * 2) * window.s(250)
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    id: mauveOrbSource
                    anchors.fill: parent
                    radius: width / 2
                    color: window.mauve
                    visible: false
                }

                MultiEffect {
                    source: mauveOrbSource
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 36
                }
            }
        }

        Item {
            id: blueOrbContainer
            width: window.s(1400); height: width
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            opacity: window.introPhase * 0.04 + window.orbBoost * 0.10
            z: 1

            transform: Translate {
                x: Math.sin(window.globalOrbitAngle * 1.5) * window.s(-450)
                y: Math.cos(window.globalOrbitAngle * 1.5) * window.s(-250)
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    id: blueOrbSource
                    anchors.fill: parent
                    radius: width / 2
                    color: window.blue
                    visible: false
                }

                MultiEffect {
                    source: blueOrbSource
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 36
                }
            }
        }

        Canvas {
            id: vignetteCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            z: 0
            onPaint: {
                var ctx = getContext("2d");
                var rad = Math.max(width, height) * 0.75;
                var grad = ctx.createRadialGradient(width/2, height/2, rad * 0.4, width/2, height/2, rad);
                grad.addColorStop(0, "rgba(0, 0, 0, 0)");
                grad.addColorStop(1, "rgba(0, 0, 0, 0.4)");
                ctx.fillStyle = grad;
                ctx.fillRect(0, 0, width, height);
            }
            Component.onCompleted: requestPaint()
            Connections { target: window; function onWidthChanged() { vignetteCanvas.requestPaint() } }
        }

        Item {
            id: monitorRig
            width: window.s(1200)
            height: window.s(900)
            anchors.centerIn: parent
            scale: 1.5 - (0.5 * window.monitorZoomProgress)
            opacity: window.monitorZoomProgress
            transformOrigin: Item.Center
            z: 2

            Item {
                id: finalMonitorContent
                anchors.fill: parent
                opacity: window.toSerpOpacity

                Item {
                    id: logoContainer
                    width: window.s(400)
                    height: window.s(400)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: window.s(-84)
                    scale: window.logoScale
                    transformOrigin: Item.Center

                    Item {
                        id: paddedMaskSource
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Image {
                            anchors.centerIn: parent
                            width: window.s(360)
                            height: window.s(360)
                            source: "file://" + Caching.serpantinumDir + "/assets/logo.svg"
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                        }
                    }

                    Item {
                        id: logoColorBlock
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle { anchors.fill: parent; color: window.text }

                        Canvas {
                            id: logoWaveCanvas
                            anchors.fill: parent
                            renderTarget: Canvas.FramebufferObject

                            property real wavePhase: 0.0
                            NumberAnimation on wavePhase {
                                running: window.logoFillLevel > 0.0 && window.logoFillLevel < 1.45
                                loops: Animation.Infinite
                                from: 0; to: Math.PI * 2; duration: 3500
                            }

                            onWavePhaseChanged: requestPaint()

                            Connections {
                                target: window
                                function onLogoFillLevelChanged() {
                                    if (window.logoFillLevel <= 0.0 || window.logoFillLevel >= 1.45) {
                                        logoWaveCanvas.requestPaint();
                                    }
                                }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (window.logoFillLevel <= 0.001) return;

                                var speedFact = 1.25;
                                var p1 = Math.max(0.0, Math.min(1.0, (window.logoFillLevel - 0.00) * speedFact));
                                var p2 = Math.max(0.0, Math.min(1.0, (window.logoFillLevel - 0.15) * speedFact));
                                var p3 = Math.max(0.0, Math.min(1.0, (window.logoFillLevel - 0.30) * speedFact));
                                var p4 = Math.max(0.0, Math.min(1.0, (window.logoFillLevel - 0.45) * speedFact));
                                var p5 = Math.max(0.0, Math.min(1.0, (window.logoFillLevel - 0.60) * speedFact));

                                function drawWaterWipe(prog, colorStr, ampMult, phaseOffset, waveCount) {
                                    if (prog <= 0.0) return;
                                    if (prog >= 1.0) {
                                        ctx.fillStyle = colorStr;
                                        ctx.fillRect(0, 0, width, height);
                                        return;
                                    }

                                    var fillY = height * (1.0 - prog);
                                    var baseAmp = window.s(16) * Math.sin(prog * Math.PI) * ampMult;
                                    var segments = 36;
                                    var localPhase = wavePhase + phaseOffset;

                                    ctx.beginPath();
                                    ctx.moveTo(0, height);
                                    ctx.lineTo(0, fillY);

                                    var prevX = 0;
                                    var prevY = fillY;

                                    for (var i = 0; i <= segments; i++) {
                                        var x = (i / segments) * width;
                                        var waveHeight = 0;

                                        for (var w = 1; w <= waveCount; w++) {
                                            var freq = w * 1.5;
                                            var amp = baseAmp * (1.0 - (w - 1) * 0.3);
                                            waveHeight += Math.sin(localPhase * freq + x * 0.01 * freq) * amp;
                                        }

                                        var y = fillY + waveHeight * 0.6;

                                        if (i === 0) {
                                            ctx.lineTo(x, y);
                                        } else {
                                            var cpx = (prevX + x) * 0.5;
                                            var cpy = (prevY + y) * 0.5 + (y - prevY) * 0.2;
                                            ctx.quadraticCurveTo(cpx, cpy, x, y);
                                        }
                                        prevX = x;
                                        prevY = y;
                                    }

                                    ctx.lineTo(width, height);
                                    ctx.closePath();
                                    ctx.fillStyle = colorStr;
                                    ctx.fill();
                                }

                                var baseColor = window.mauve;
                                drawWaterWipe(p1, Qt.darker(baseColor, 2.5).toString(), 1.8, 0.0, 3);
                                drawWaterWipe(p2, Qt.darker(baseColor, 2.0).toString(), 1.5, 0.5, 3);
                                drawWaterWipe(p3, Qt.darker(baseColor, 1.5).toString(), 1.2, 1.0, 3);
                                drawWaterWipe(p4, Qt.darker(baseColor, 1.1).toString(), 0.9, 1.5, 3);
                                drawWaterWipe(p5, baseColor.toString(), 0.6, 2.0, 3);
                            }
                        }
                    }

                    MultiEffect {
                        source: logoColorBlock
                        anchors.fill: parent
                        maskEnabled: true
                        maskSource: paddedMaskSource
                        autoPaddingEnabled: false
                        shadowEnabled: true

                        shadowColor: window.colorizeActive ? window.mauve : window.crust
                        shadowBlur: window.colorizeActive ? 1.0 : 0.6
                        shadowOpacity: window.colorizeActive ? 0.3 : 0.6
                        shadowVerticalOffset: window.colorizeActive ? 0 : window.s(6)

                        Behavior on shadowColor { ColorAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowBlur { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowOpacity { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowVerticalOffset { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                    }
                }

                TypewriterText {
                    id: serpText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: window.s(120)
                    text: I18n.t("start.title")
                    reveal: window.toSerpReveal
                    color: window.colorizeActive ? window.mauve : window.text
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: window.s(48)
                    soundEnabled: false
                }

                Text {
                    id: finalAuthorText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: serpText.bottom
                    anchors.topMargin: window.s(12)
                    text: I18n.t("start.made_by", { "author": "ilyamiro" })
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(15)
                    scale: 0.88
                    color: window.subtext0
                    opacity: window.finalAuthorOpacity
                }
            }
        }

        Item {
            id: textScene
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: window.textGroupOffset
            width: window.s(600)
            height: window.s(160)
            z: 5

            Item {
                anchors.centerIn: parent
                width: welcomeText.implicitWidth
                height: welcomeText.implicitHeight
                opacity: window.welcomeOpacity

                TypewriterText {
                    id: welcomeText
                    text: I18n.t("start.welcome")
                    reveal: window.welcomeReveal
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: window.s(48)
                }
            }

            Item {
                id: shellTextContainer
                anchors.centerIn: parent
                width: shellTextRow.implicitWidth
                height: shellTextRow.implicitHeight + window.s(40)
                opacity: window.shellTextOpacity
                scale: window.shellTextScale

                Row {
                    id: shellTextRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: window.s(8)

                    TypewriterText {
                        text: I18n.t("start.tagline")
                        reveal: window.shellTextReveal
                        color: window.text
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: window.s(28)
                        y: window.s(12)
                    }

                    TypewriterText {
                        id: youText
                        text: I18n.t("start.you")
                        reveal: Math.max(0.0, Math.min(1.0, (window.shellTextReveal - 0.70) * 3.33))
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: window.s(48)

                        property color blinkColor: window.mauve
                        SequentialAnimation on blinkColor {
                            loops: Animation.Infinite
                            running: window.shellTextOpacity > 0
                            ColorAnimation { to: window.blue; duration: 900; easing.type: Easing.InOutSine }
                            ColorAnimation { to: window.peach; duration: 900; easing.type: Easing.InOutSine }
                            ColorAnimation { to: window.mauve; duration: 900; easing.type: Easing.InOutSine }
                        }
                        color: blinkColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: youText.blinkColor
                            shadowBlur: 0.8
                            shadowOpacity: 0.85
                            shadowVerticalOffset: 0
                        }
                    }
                }

                Item {
                    id: introAuthorContainer
                    anchors.top: shellTextRow.bottom
                    anchors.topMargin: window.s(0)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: introAuthorText.implicitWidth
                    height: introAuthorText.implicitHeight
                    opacity: window.authorOpacity
                    scale: window.authorScale

                    Text {
                        id: introAuthorText
                        text: I18n.t("start.made_by", { "author": "ilyamiro" })
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(14)
                        color: window.subtext0
                    }
                }
            }
        }

        Item {
            id: btnSpacer
            anchors.top: parent.verticalCenter
            anchors.topMargin: window.s(180)
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            z: 10

            FillButton {
                id: startBtn
                anchors.top: parent.top
                anchors.topMargin: window.s(40)
                anchors.horizontalCenter: parent.horizontalCenter

                width: window.s(240)
                height: window.s(48)
                textFontSize: 16
                opacity: window.btnOpacity

                buttonText: I18n.t("start.start_preview")
                buttonIcon: "󰐊"
                accentColor: window.blue
                baseColor: window.surface0
                hoverColor: window.surface1
                textColor: window.text
                filledTextColor: window.crust
                fillDuration: 800

                Timer {
                    id: delayCloseTimer
                    interval: 800
                    onTriggered: closeSequence.start()
                }

                onTriggered: delayCloseTimer.start()
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }
        ScriptAction { script: window.exitSoundHandle = Sounds.playUntilStopped("start/exit.wav", 0.7, false) }
        PauseAnimation { duration: 350 }
        ParallelAnimation {
            NumberAnimation { target: window; property: "mainOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { target: window; property: "panelReveal"; to: 0.0; duration: 1760; easing.type: Easing.InOutCubic }
        }
        ScriptAction {
            script: {
                if (window.exitSoundHandle !== -1 ) {
                    Sounds.stopSfx(window.exitSoundHandle);
                    window.exitSoundHandle = -1;
                }
                if (startBtn.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(startBtn.chargingSoundHandle);
                    startBtn.chargingSoundHandle = -1;
                }
                if (window.bgSoundHandle !== -1) {
                    Sounds.stopSfx(window.bgSoundHandle);
                    window.bgSoundHandle = -1;
                }
            }
        }
        ScriptAction {
            script: {
                window.finished();
                window.closed();
                window.visible = false;
            }
        }
    }
}
