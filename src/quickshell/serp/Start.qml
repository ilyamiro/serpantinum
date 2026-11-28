import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: window

    signal finished()

    WlrLayershell.namespace: "welcome-guide"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Compositor.focusedScreen()

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

    component Wave : Shape {
        id: wave
        property string svgPath
        property real fillAlpha
        property int duration
        property bool reverse: false

        width: parent.width * 2
        height: parent.height
        z: 1
        opacity: window.introPhase * (0.6 + 0.4 * window.orbBoost)
        preferredRendererType: Shape.CurveRenderer

        NumberAnimation on x {
            from: wave.reverse ? -wave.width / 2 : 0
            to: wave.reverse ? 0 : -wave.width / 2
            duration: wave.duration
            loops: Animation.Infinite
            running: window.introPhase > 0
        }

        ShapePath {
            strokeWidth: -1
            fillColor: Qt.rgba(window.blue.r, window.blue.g, window.blue.b, wave.fillAlpha)
            scale: Qt.size(wave.width / 2880, wave.height / 1200)
            PathSvg { path: wave.svgPath }
        }
    }

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
        PauseAnimation { duration: 150 }

        NumberAnimation { target: window; property: "welcomeReveal"; to: 1.0; duration: 850; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 800 }
        NumberAnimation { target: window; property: "welcomeOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }

        ParallelAnimation {
            PropertyAction { target: window; property: "shellTextOpacity"; value: 1.0 }
            NumberAnimation { target: window; property: "shellTextReveal"; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { target: window; property: "shellTextScale"; from: 0.94; to: 1.0; duration: 1600; easing.type: Easing.OutExpo }
        }
        PauseAnimation { duration: 150 }
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
                PauseAnimation { duration: 250 }

                ParallelAnimation {
                    NumberAnimation { target: window; property: "orbBoost"; to: 1.0; duration: 3200; easing.type: Easing.OutSine }
                    ScriptAction { script: window.colorizeActive = true }
                    NumberAnimation { target: window; property: "logoFillLevel"; to: 1.5; duration: 4500; easing.type: Easing.OutSine }
                    NumberAnimation { target: window; property: "monitorZoomProgress"; from: 0.0; to: 1.0; duration: 2800; easing.type: Easing.OutQuint }
                }
            }
        }
    }

    ShaderEffect {
        id: bgCanvas
        anchors.fill: parent

        property real phase: 0.0
        NumberAnimation on phase {
            loops: Animation.Infinite
            running: window.panelReveal > 0.0 && window.panelReveal < 1.0
            from: 0; to: Math.PI * 2; duration: 3600
        }

        property vector2d itemSize: Qt.vector2d(width, height)
        property real reveal: window.panelReveal
        property color color0: window.crust
        property color color1: window.surface1
        property color color2: window.blue
        property color color3: window.mauve
        property color color4: window.base
        property vector4d params: Qt.vector4d(window.s(45), 0.0, 0.0, 0.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/screen_wipe.frag.qsb"
    }

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        opacity: window.mainOpacity

        Shortcut {
            sequence: "Escape"
            enabled: !introChoreography.running
            onActivated: closeSequence.start()
        }

        Wave {
            svgPath: "M0,160 C240,90 480,230 720,150 C960,90 1200,230 1440,160 C1680,90 1920,230 2160,150 C2400,90 2640,230 2880,160 L2880,1200 L0,1200 Z"
            fillAlpha: 0.03
            duration: 40000
        }

        Wave {
            svgPath: "M0,420 C240,340 480,500 720,410 C960,340 1200,500 1440,420 C1680,340 1920,500 2160,410 C2400,340 2640,500 2880,420 L2880,1200 L0,1200 Z"
            fillAlpha: 0.025
            duration: 30000
            reverse: true
        }

        Snake {
            anchors.fill: parent
            z: 1
            opacity: window.introPhase * 0.6
            running: window.introPhase > 0
            unit: window.s(100) / 100
            color: window.blue
            shadowStrength: (0.299 * window.base.r + 0.587 * window.base.g + 0.114 * window.base.b) < 0.5 ? 0.56 : 0.36
        }

        Wave {
            svgPath: "M0,700 C240,620 480,780 720,690 C960,620 1200,780 1440,700 C1680,620 1920,780 2160,690 C2400,620 2640,780 2880,700 L2880,1200 L0,1200 Z"
            fillAlpha: 0.02
            duration: 48000
        }

        Wave {
            svgPath: "M0,960 C240,880 480,1040 720,950 C960,880 1200,1040 1440,960 C1680,880 1920,1040 2160,950 C2400,880 2640,1040 2880,960 L2880,1200 L0,1200 Z"
            fillAlpha: 0.016
            duration: 36000
            reverse: true
        }

        ShaderEffect {
            id: vignetteCanvas
            anchors.fill: parent
            z: 0

            property vector2d itemSize: Qt.vector2d(width, height)
            property color vignetteColor: "#000000"
            property vector4d params: Qt.vector4d(0.4, 0.75, 0.4, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/vignette.frag.qsb"
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

                        ShaderEffect {
                            id: logoWaveCanvas
                            anchors.fill: parent

                            property real wavePhase: 0.0
                            NumberAnimation on wavePhase {
                                running: window.logoFillLevel > 0.0 && window.logoFillLevel < 1.45
                                loops: Animation.Infinite
                                from: 0; to: Math.PI * 2; duration: 3500
                            }

                            property vector2d itemSize: Qt.vector2d(width, height)
                            property real fillLevel: window.logoFillLevel
                            property color baseColor: window.mauve
                            property vector4d params: Qt.vector4d(window.s(16), 0.0, 0.0, 0.0)

                            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/fluid/logo_water_wave.frag.qsb"
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
                    font.pixelSize: window.s(60)
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
                    spacing: window.s(16)

                    TypewriterText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("start.tagline")
                        reveal: window.shellTextReveal
                        color: window.text
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: window.s(28)
                    }

                    Item {
                        id: youChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: youMetrics.tightBoundingRect.width + window.s(40)
                        height: youMetrics.tightBoundingRect.height + window.s(20)

                        TextMetrics {
                            id: youMetrics
                            font: youText.font
                            text: youText.text
                        }

                        FontMetrics {
                            id: youFontMetrics
                            font: youText.font
                        }

                        readonly property real reveal: Math.max(0.0, Math.min(1.0, (window.shellTextReveal - 0.70) * 3.33))
                        property real grow: reveal > 0 ? 1.0 : 0.0
                        Behavior on grow { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                        Rectangle {
                            id: youPill
                            anchors.centerIn: parent
                            height: parent.height
                            width: height + (parent.width - height) * youChip.grow
                            radius: height / 2
                            color: window.blue
                            opacity: Math.min(1.0, youChip.grow * 2)
                            scale: 0.7 + 0.3 * youChip.grow

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: window.crust
                                shadowBlur: 0.6
                                shadowOpacity: 0.45
                                shadowVerticalOffset: window.s(4)
                            }
                        }

                        TypewriterText {
                            id: youText
                            x: youChip.width / 2 - (youMetrics.tightBoundingRect.x + youMetrics.tightBoundingRect.width / 2)
                            y: youChip.height / 2 - (youFontMetrics.ascent + youMetrics.tightBoundingRect.y + youMetrics.tightBoundingRect.height / 2)
                            text: I18n.t("start.you")
                            reveal: youChip.reveal
                            color: window.crust
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: window.s(44)
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

                width: Math.max(window.s(300), implicitWidth)
                height: window.s(48)
                textFontSize: 16
                opacity: window.btnOpacity

                buttonText: I18n.t("start.hold_to_start")
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
        PauseAnimation { duration: 400 }
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
                window.visible = false;
            }
        }
    }
}
