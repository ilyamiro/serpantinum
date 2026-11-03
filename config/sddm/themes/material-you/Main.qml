import QtQuick
import QtQuick.Window
import QtQuick.Effects
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height

    component Ico: Item {
        id: ico
        property string name: "power"
        property color tint: root.cDark
        property real size: 20
        width: size
        height: size
        Image {
            id: icoImg
            anchors.fill: parent
            source: root.iconSource(ico.name)
            sourceSize.width: ico.size * 2
            sourceSize.height: ico.size * 2
            visible: false
        }
        MultiEffect {
            anchors.fill: icoImg
            source: icoImg
            brightness: 1.0
            colorization: 1.0
            colorizationColor: ico.tint
        }
    }

    component MenuContent: Item {
        id: bRoot
        property string iconName: "power"
        property string label: ""
        property color contentColor: root.cMid
        property real currentFill: 0.0

        Row {
            id: contentRow
            x: Math.round((bRoot.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.s

            Ico {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                name: bRoot.iconName
                tint: bRoot.contentColor
                size: 18 * root.s
                readonly property real norm: bRoot.width > 0 ? (contentRow.x + x + width / 2) / bRoot.width : 0
                readonly property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999 ? Math.exp(-Math.pow((bRoot.currentFill - norm) * 9, 2)) : 0.0
                transform: [
                    Translate { y: -icon.bump * root.s },
                    Scale {
                        origin.x: icon.width / 2
                        origin.y: icon.height / 2
                        xScale: 1.0 + icon.bump * 0.03
                        yScale: 1.0 + icon.bump * 0.03
                    }
                ]
            }

            Row {
                id: charRow
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: Array.from(bRoot.label)

                    Item {
                        id: slot
                        required property string modelData
                        required property int index
                        width: ct.implicitWidth
                        height: ct.implicitHeight
                        readonly property real norm: bRoot.width > 0 ? (contentRow.x + charRow.x + x + width / 2) / bRoot.width : 0
                        readonly property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999 ? Math.exp(-Math.pow((bRoot.currentFill - norm) * 9, 2)) : 0.0

                        Text {
                            id: ct
                            anchors.centerIn: parent
                            text: slot.modelData === " " ? "\u00A0" : slot.modelData
                            font.family: root.sansFont
                            font.pixelSize: 14 * root.s
                            font.weight: Font.Bold
                            color: bRoot.contentColor
                        }

                        transform: [
                            Translate { y: -slot.bump * 3.5 * root.s },
                            Scale {
                                origin.x: slot.width / 2
                                origin.y: slot.height / 2
                                xScale: 1.0 + slot.bump * 0.12
                                yScale: 1.0 + slot.bump * 0.12
                            },
                            Rotation {
                                origin.x: slot.width / 2
                                origin.y: slot.height / 2
                                angle: slot.bump * (slot.index % 2 === 0 ? -7 : 7)
                            }
                        ]
                    }
                }
            }
        }
    }

    component MenuButton: Item {
        id: btn
        property string iconName: "power"
        property string label: ""
        property color accent: root.cMid
        property int fillDuration: 800
        property real fillLevel: 0.0
        property bool isTriggered: false
        property real flashOpacity: 0.0
        property real popScale: 1.0
        readonly property bool hot: ma.containsMouse && !isTriggered
        signal triggered()

        height: 48 * root.s

        Timer {
            id: resetTimer
            interval: 1200
            onTriggered: {
                btn.isTriggered = false;
                fillAnim.stop();
                drainAnim.start();
            }
        }

        Rectangle {
            id: shape
            anchors.fill: parent
            radius: root.radius
            clip: true
            color: btn.hot ? root.cSurfaceHover : root.cSurfaceSolid
            scale: (ma.pressed && !btn.isTriggered ? 0.96 : (btn.hot ? 1.02 : 1.0)) * btn.popScale
            Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: btn; property: "popScale"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: btn; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
            }

            ShaderEffect {
                id: wave
                anchors.fill: parent
                property real radius: root.radius
                property real fillLevel: btn.fillLevel
                property real waveAmp: btn.fillLevel < 0.99 ? Math.min(10 * root.s, Math.min(width * btn.fillLevel, width - width * btn.fillLevel)) * Math.sin(btn.fillLevel * Math.PI) : 0
                property vector2d itemSize: Qt.vector2d(width, height)
                property real phase: 0.0
                property real vertical: 0.0
                property color color1: Qt.darker(btn.accent, 1.15)
                property color color2: btn.accent
                property vector4d params: Qt.vector4d(1.0, 0.0, 0.0, 0.0)
                visible: btn.fillLevel > 0.001
                fragmentShader: Qt.resolvedUrl("shaders/fluid_wave.frag.qsb")

                NumberAnimation on phase {
                    running: btn.fillLevel > 0.0 && btn.fillLevel < 1.0
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 800
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "#ffffff"
                opacity: btn.flashOpacity
                PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
            }

            MenuContent {
                width: shape.width
                height: shape.height
                iconName: btn.iconName
                label: btn.label
                contentColor: btn.hot ? root.cText : btn.accent
                currentFill: btn.fillLevel
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                readonly property real maxAmp: Math.min(10 * root.s, Math.min(parent.width * btn.fillLevel, parent.width * (1.0 - btn.fillLevel)))
                readonly property real waveAmp: maxAmp * Math.sin(btn.fillLevel * Math.PI)
                readonly property real phaseOffset: Math.sin(wave.phase) - Math.cos(wave.phase)
                readonly property real centerOffset: btn.fillLevel > 0.01 && btn.fillLevel < 0.99 ? 0.375 * waveAmp * phaseOffset : 0
                width: Math.max(0, Math.min(parent.width, parent.width * btn.fillLevel + centerOffset))
                clip: true

                MenuContent {
                    width: shape.width
                    height: shape.height
                    iconName: btn.iconName
                    label: btn.label
                    contentColor: root.cOnAccent
                    currentFill: btn.fillLevel
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                enabled: !btn.isTriggered
                cursorShape: btn.isTriggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                onPressed: {
                    drainAnim.stop();
                    fillAnim.start();
                }
                onReleased: {
                    if (!btn.isTriggered && btn.fillLevel < 1.0) {
                        fillAnim.stop();
                        drainAnim.start();
                    }
                }
                onCanceled: {
                    if (!btn.isTriggered && btn.fillLevel < 1.0) {
                        fillAnim.stop();
                        drainAnim.start();
                    }
                }
            }
        }

        NumberAnimation {
            id: fillAnim
            target: btn
            property: "fillLevel"
            to: 1.0
            duration: btn.fillDuration * (1.0 - btn.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                btn.isTriggered = true;
                btn.flashOpacity = 0.5;
                popAnim.start();
                flashAnim.start();
                btn.triggered();
                resetTimer.restart();
            }
        }

        NumberAnimation {
            id: drainAnim
            target: btn
            property: "fillLevel"
            to: 0.0
            duration: btn.fillDuration * 1.875 * btn.fillLevel
            easing.type: Easing.OutQuad
        }
    }

    readonly property real s: Screen.height / 768
    readonly property real radius: 10 * s
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0

    readonly property string themeMode: (typeof config !== "undefined" && config.mode) ? String(config.mode).toLowerCase() : "dark"
    property int modeOverride: -1
    readonly property bool isDark: modeOverride >= 0 ? modeOverride === 1 : (themeMode === "dark" || (themeMode === "auto" && (now.getHours() >= 19 || now.getHours() < 7)))
    property bool themeGrabPending: false
    property bool themeSwitching: false
    property bool themeBusy: false
    property bool themeForward: true
    property bool themePrevDark: false
    property real themeProgress: 0
    property real themeOriginX: 1
    property real themeOriginY: 1
    property var snapResult: null

    function setMode(v) {
        themeSwitching = true;
        modeOverride = v;
        switchTimer.restart();
    }

    Timer {
        id: switchTimer
        interval: 80
        onTriggered: root.themeSwitching = false
    }

    function toggleTheme() {
        if (themeBusy) {
            themeAnim.stop();
            themeForward = !themeForward;
            let to = themeForward ? 1 : 0;
            themeAnim.from = themeProgress;
            themeAnim.to = to;
            themeAnim.duration = Math.max(150, 750 * Math.abs(to - themeProgress));
            themeAnim.restart();
            return;
        }
        if (themeGrabPending) return;
        themeGrabPending = true;
        let p = themeButton.mapToItem(root, themeButton.width / 2, themeButton.height / 2);
        scene.grabToImage(function(result) {
            root.snapResult = result;
            themeOverlay.source = result.url;
            root.themeOriginX = p.x / root.width;
            root.themeOriginY = p.y / root.height;
            root.themePrevDark = root.isDark;
            root.themeProgress = 0;
            root.setMode(root.isDark ? 0 : 1);
            root.themeForward = true;
            root.themeBusy = true;
            root.themeGrabPending = false;
            themeOverlay.visible = true;
            themeAnim.from = 0;
            themeAnim.to = 1;
            themeAnim.duration = 750;
            themeAnim.restart();
        });
    }

    function finishTheme() {
        if (!themeForward) setMode(themePrevDark ? 1 : 0);
        themeOverlay.visible = false;
        themeOverlay.source = "";
        snapResult = null;
        themeBusy = false;
    }

    readonly property color cText: isDark ? "#EEE3FD" : "#3A2656"
    readonly property color cDark: isDark ? "#CBA6F7" : "#4A2C72"
    readonly property color cMid: isDark ? "#B392E6" : "#6B4A99"
    readonly property color cSurface: isDark ? Qt.rgba(0.125, 0.082, 0.2, 0.9) : Qt.rgba(0.953, 0.922, 0.988, 0.92)
    readonly property color cSurfaceHover: isDark ? "#33214F" : "#E4D4F9"
    readonly property color cField: isDark ? "#33214F" : "#E4D4F9"
    readonly property color cFieldBox: isDark ? "#46306C" : "#D6BFF8"
    readonly property color cSurfaceSolid: isDark ? "#241636" : "#F3EBFC"
    readonly property color cOnAccent: isDark ? "#1E1233" : "#F3EBFC"
    readonly property color cRed: isDark ? "#ff6b7a" : "#ea1821"
    readonly property color cBusy: isDark ? "#CBA6F7" : "#8A67BD"
    readonly property color cMenu1: isDark ? "#B392E6" : "#6B4A99"
    readonly property color cMenu2: isDark ? "#CBA6F7" : "#8A67BD"
    readonly property color cMenuDanger: isDark ? "#ff6b7a" : "#ea1821"

    property real ui1: 0
    property bool powerMenuOpen: false
    property var now: new Date()

    FontLoader {
        id: customFont
        source: "font/GoogleSans-VariableFont_GRAD,opsz,wght.ttf"
    }
    FontLoader {
        id: flexFont
        source: "font/GoogleSansFlex.ttf"
    }

    readonly property string sansFont: customFont.name !== "" ? customFont.name : "Roboto, Inter, sans-serif"
    readonly property string flexName: flexFont.status === FontLoader.Ready && flexFont.name !== "" ? flexFont.name : sansFont

    readonly property var icons: ({
        "power": "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/>",
        "close": "<line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/>",
        "session": "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'/>",
        "reboot": "<polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/>",
        "user": "<path d='M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>",
        "moon": "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>",
        "sun": "<circle cx='12' cy='12' r='4'/><line x1='12' y1='2' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='22'/><line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/><line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/><line x1='2' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='22' y2='12'/><line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/><line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/>",
        "sleep": "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>"
    })

    function iconSource(name) {
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'>" + icons[name] + "</svg>";
    }

    function sessionName() {
        return (sessionHelper.currentItem && sessionHelper.currentItem.sName) ? sessionHelper.currentItem.sName : "Plasma";
    }

    function userName() {
        return (userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : (userModel.lastUser || "User");
    }

    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string sName: model.name || ""
        }
    }

    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string uName: model.realName || model.name || ""
            property string uLogin: model.name || ""
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: focusTimer
        interval: 300
        running: true
        onTriggered: pw.forceInputFocus()
    }

    Timer {
        id: busyGuard
        interval: 15000
        onTriggered: pw.isBusy = false
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            busyGuard.stop();
            pw.isBusy = false;
            pw.clear();
            pw.markError();
            errTimer.restart();
        }
    }

    Timer {
        id: errTimer
        interval: 3000
        onTriggered: pw.resetVerification()
    }

    Component.onCompleted: {
        fadeAnim.start();
        if (typeof keyboard !== "undefined") keyboard.numLock = true;
    }

    SequentialAnimation {
        id: fadeAnim
        PauseAnimation { duration: 300 }
        NumberAnimation { target: root; property: "ui1"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    }

    Item {
        id: scene
        anchors.fill: parent

    Image {
        anchors.fill: parent
        source: root.isDark ? "bg_dark.jpg" : "bg.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.powerMenuOpen = false;
            pw.forceInputFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.powerMenuOpen
        onActivated: {
            root.powerMenuOpen = false;
            pw.forceInputFocus();
        }
    }

    Column {
        id: mainLayout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -15 * s
        spacing: 16 * s
        opacity: root.ui1
        scale: 0.96 + (0.04 * root.ui1)
        transform: Translate { y: (1 - root.ui1) * 30 * s }

        Rectangle {
            id: clockCard
            anchors.horizontalCenter: parent.horizontalCenter
            width: digits.width
            height: digits.height
            color: "transparent"

            Item {
                id: digits
                anchors.centerIn: parent
                readonly property real fitSize: 230 * s
                readonly property var inkRects: {
                    var rects = [];
                    for (var i = 0; i < 10; i++) rects.push(ref.tightBoundingRect(String(i)));
                    return rects;
                }
                readonly property real refCellW: {
                    var m = 1;
                    for (var i = 0; i < inkRects.length; i++) m = Math.max(m, inkRects[i].width);
                    return m;
                }
                readonly property real refCellH: {
                    var m = 1;
                    for (var i = 0; i < inkRects.length; i++) m = Math.max(m, inkRects[i].height);
                    return m;
                }
                readonly property real pixelSize: Math.min(fitSize / (2 * refCellW), fitSize / (2 * refCellH)) * 100
                readonly property real sf: pixelSize / 100
                readonly property real cellW: refCellW * sf
                readonly property real cellH: refCellH * sf
                readonly property string h: Qt.formatTime(root.now, "hh")
                readonly property string m: Qt.formatTime(root.now, "mm")

                width: cellW * 2
                height: cellH * 2

                FontMetrics {
                    id: ref
                    font.family: root.flexName
                    font.pixelSize: 100
                    font.weight: Font.Black
                    font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
                }

                Repeater {
                    model: 4

                    delegate: Item {
                        id: cell
                        readonly property int col: index % 2
                        readonly property int row: Math.floor(index / 2)
                        readonly property string digit: (row === 0 ? digits.h : digits.m).charAt(col)
                        readonly property var ink: digits.inkRects[digit >= "0" && digit <= "9" ? Number(digit) : 0]
                        readonly property real textX: (digits.cellW - ink.width * digits.sf) / 2 - ink.x * digits.sf
                        readonly property color tint: (row + col) % 2 === 0 ? root.cText : root.cMid

                        x: col * digits.cellW
                        y: row * digits.cellH
                        width: digits.cellW
                        height: digits.cellH

                        Repeater {
                            model: [
                                { dy: 0.045, alpha: 0.10 },
                                { dy: 0.022, alpha: 0.18 }
                            ]
                            delegate: Text {
                                x: cell.textX
                                y: cell.height - baselineOffset + digits.pixelSize * modelData.dy
                                text: cell.digit
                                font.family: root.flexName
                                font.pixelSize: digits.pixelSize
                                font.weight: Font.Black
                                font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
                                renderType: Text.NativeRendering
                                color: root.isDark ? Qt.rgba(0, 0, 0, modelData.alpha * 1.6) : Qt.rgba(0.18, 0.1, 0.29, modelData.alpha)
                            }
                        }

                        Text {
                            x: cell.textX
                            y: cell.height - baselineOffset
                            text: cell.digit
                            font.family: root.flexName
                            font.pixelSize: digits.pixelSize
                            font.weight: Font.Black
                            font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
                            renderType: Text.NativeRendering
                            color: cell.tint
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: dateText.implicitWidth + 32 * s
            height: 32 * s
            radius: root.radius
            color: root.cSurface

            Text {
                id: dateText
                anchors.centerIn: parent
                text: Qt.formatDate(root.now, "dddd, MMM d")
                font.family: root.sansFont
                font.pixelSize: 13 * s
                font.weight: Font.Medium
                color: root.cText
            }
        }

        Item {
            width: 1
            height: 94 * s
        }

        Item {
            id: pw
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380 * s
            height: 40 * s

            property string text: ""
            property bool isRevealed: false
            property bool hasError: false
            property bool isBusy: false
            property real focusPop: 1.0
            property real scrollOffset: 0
            property real typePulse: 0
            readonly property bool hasFocus: innerInput.activeFocus
            readonly property real fontSize: 14 * s
            readonly property real dotSize: Math.round(height * 0.44)
            readonly property int charSpacing: Math.round(2 * s)
            readonly property real charSlotStep: (revealProgress > 0.5 ? charMetrics.width : dotSize) + charSpacing
            readonly property real btnSize: height - 8 * s
            readonly property real btnRadius: Math.max(4 * s, root.radius - 4 * s)
            property real revealProgress: isRevealed ? 1.0 : 0.0
            readonly property color signalColor: hasError ? root.cRed : (isBusy ? root.cBusy : root.cDark)

            Behavior on revealProgress {
                NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
            }

            function forceInputFocus() { innerInput.forceActiveFocus(); }
            function toggleReveal() { isRevealed = !isRevealed; submitBtn.triggerSpin(); }
            function resetVerification() { hasError = false; }
            function markError() {
                hasError = true;
                shakeAnim.restart();
            }

            function clear() {
                innerInput.text = "";
                text = "";
                charModel.clear();
                scrollOffset = 0;
            }

            function submit() {
                if (isBusy || innerInput.text === "") return;
                if (!root.isQuickshell) {
                    isBusy = true;
                    busyGuard.restart();
                    let currentUser = userHelper.currentItem ? userHelper.currentItem.uLogin : userModel.lastUser;
                    sddm.login(currentUser, innerInput.text, root.sessionIndex);
                }
            }

            function syncModel() {
                let str = innerInput.text;
                let minLen = Math.min(str.length, charModel.count);
                let matchLen = 0;
                while (matchLen < minLen && str[matchLen] === charModel.get(matchLen).glyph) matchLen++;
                while (charModel.count > matchLen) charModel.remove(charModel.count - 1);
                for (let i = matchLen; i < str.length; i++) charModel.append({ glyph: str[i] });
                updateScroll();
            }

            function updateScroll() {
                let totalW = charRow.contentWidth;
                let visibleW = fieldArea.width;
                if (visibleW <= 0) return;
                if (totalW <= visibleW) {
                    scrollOffset = (visibleW - totalW) / 2;
                    return;
                }
                let curX = innerInput.cursorPosition * charSlotStep;
                let minOffset = visibleW - totalW;
                let margin = 4;
                let curScreenX = curX + scrollOffset;
                if (curScreenX < margin) {
                    scrollOffset = Math.min(0, Math.max(minOffset, margin - curX));
                } else if (curScreenX > visibleW - margin - 2) {
                    scrollOffset = Math.min(0, Math.max(minOffset, visibleW - margin - 2 - curX));
                } else {
                    scrollOffset = Math.min(0, Math.max(minOffset, scrollOffset));
                }
            }

            onRevealProgressChanged: { updateScroll(); lockButton.canvas.requestPaint(); }
            onHasErrorChanged: lockButton.canvas.requestPaint()
            onIsBusyChanged: {
                if (!isBusy) lockButton.busyRotation = 0;
                lockButton.canvas.requestPaint();
            }
            onHasFocusChanged: {
                if (hasFocus) focusPopAnim.restart();
                lockButton.canvas.requestPaint();
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; from: 0; to: -6 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: -6 * s; to: 6 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: 6 * s; to: -4 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: -4 * s; to: 4 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: 4 * s; to: 0; duration: 50 }
            }

            SequentialAnimation {
                id: focusPopAnim
                NumberAnimation { target: pw; property: "focusPop"; to: 1.02; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: pw; property: "focusPop"; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
            }

            TextMetrics {
                id: charMetrics
                font.family: root.sansFont
                font.pixelSize: pw.fontSize
                text: "0"
            }

            ListModel { id: charModel }

            TapHandler {
                onTapped: pw.forceInputFocus()
            }

            Item {
                id: contentContainer
                anchors.fill: parent
                scale: (pw.hasError ? 1.02 : (pw.isBusy ? 0.98 : 1.0)) * pw.focusPop
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                transform: Translate { id: shakeT; x: 0 }

                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: root.cField
                    Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
                }

                Item {
                    id: lockButton
                    x: 4 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: pw.btnSize
                    height: pw.btnSize
                    property real busyRotation: 0
                    property alias canvas: lockCanvas
                    readonly property color iconColor: pw.hasError ? root.cRed : (pw.isBusy ? root.cBusy : root.cMid)
                    onIconColorChanged: lockCanvas.requestPaint()
                    onBusyRotationChanged: lockCanvas.requestPaint()

                    Rectangle {
                        anchors.fill: parent
                        radius: pw.btnRadius
                        color: lockMa.containsMouse ? Qt.lighter(root.cFieldBox, 1.06) : root.cFieldBox
                        Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
                    }

                    SequentialAnimation {
                        running: pw.isBusy
                        loops: Animation.Infinite
                        NumberAnimation { target: lockButton; property: "busyRotation"; from: 0; to: 360; duration: 540; easing.type: Easing.InOutCubic }
                        PauseAnimation { duration: 480 }
                    }

                    Canvas {
                        id: lockCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            var w = width;
                            var h = height;
                            ctx.clearRect(0, 0, w, h);
                            var color = lockButton.iconColor;
                            var bodyW = Math.round(w * 0.52);
                            var bodyH = Math.round(bodyW * 0.76);
                            var stroke = Math.max(1.8, bodyW * 0.14);
                            var outerW = Math.round(bodyW * 0.62);
                            var rad = (outerW - stroke) / 2;
                            var shackleH = Math.round(rad + bodyH * 0.30);
                            var top = Math.round((h - (shackleH + bodyH)) / 2);
                            var bodyY = top + shackleH;
                            var topY = top + stroke / 2;
                            var cx = Math.round(w / 2);
                            var cy = Math.round(h / 2);
                            var bodyX = Math.round((w - bodyW) / 2);
                            var prog = pw.revealProgress;
                            var pivotX = cx - rad;
                            var pivotY = bodyY + stroke / 2;
                            var lift = Math.round(shackleH * 0.28 * prog);
                            var swing = -0.38 * prog;
                            var rightBottom = bodyY + 1.0 - Math.round(shackleH * 0.32 * prog);
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.rotate(lockButton.busyRotation * Math.PI / 180);
                            ctx.translate(-cx, -cy);
                            ctx.save();
                            ctx.strokeStyle = color;
                            ctx.lineWidth = stroke;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.translate(pivotX, pivotY);
                            ctx.translate(0, -lift);
                            ctx.rotate(swing);
                            ctx.translate(-pivotX, -pivotY);
                            ctx.beginPath();
                            ctx.arc(cx, topY + rad, rad, Math.PI, 0, false);
                            ctx.lineTo(cx + rad, rightBottom);
                            ctx.moveTo(cx - rad, topY + rad);
                            ctx.lineTo(cx - rad, bodyY + 1.5 + lift);
                            ctx.stroke();
                            ctx.restore();
                            ctx.fillStyle = color;
                            var r = Math.max(2, Math.round(bodyW * 0.16));
                            ctx.beginPath();
                            ctx.moveTo(bodyX + r, bodyY);
                            ctx.lineTo(bodyX + bodyW - r, bodyY);
                            ctx.arcTo(bodyX + bodyW, bodyY, bodyX + bodyW, bodyY + r, r);
                            ctx.lineTo(bodyX + bodyW, bodyY + bodyH - r);
                            ctx.arcTo(bodyX + bodyW, bodyY + bodyH, bodyX + bodyW - r, bodyY + bodyH, r);
                            ctx.lineTo(bodyX + r, bodyY + bodyH);
                            ctx.arcTo(bodyX, bodyY + bodyH, bodyX, bodyY + bodyH - r, r);
                            ctx.lineTo(bodyX, bodyY + r);
                            ctx.arcTo(bodyX, bodyY, bodyX + r, bodyY, r);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = root.cField;
                            var kr = Math.max(1.4, bodyH * 0.16);
                            var ky = bodyY + Math.round(bodyH * 0.42);
                            ctx.beginPath();
                            ctx.arc(cx, ky, kr, 0, Math.PI * 2);
                            ctx.fill();
                            var slotW = Math.max(1.4, kr * 0.85);
                            ctx.beginPath();
                            ctx.rect(cx - slotW / 2, ky, slotW, Math.round(bodyH * 0.28));
                            ctx.fill();
                            ctx.restore();
                        }
                    }

                    MouseArea {
                        id: lockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pw.forceInputFocus();
                            pw.toggleReveal();
                        }
                    }
                }

                Item {
                    id: submitBtn
                    x: parent.width - width - 4 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: pw.btnSize
                    height: pw.btnSize
                    property real popScale: 1.0
                    property real flashOpacity: 0.0
                    readonly property bool hot: submitMa.containsMouse && !pw.isBusy
                    readonly property color accent: pw.hasError ? root.cRed : (pw.isBusy ? root.cBusy : root.cDark)

                    function triggerSpin() {
                        submitPop.restart();
                        flashOpacity = 0.4;
                        flashAnim.restart();
                        chevronSpin.restart();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: pw.btnRadius
                        clip: true
                        color: pw.isBusy ? submitBtn.accent : (submitMa.pressed ? Qt.darker(submitBtn.accent, 1.12) : (submitBtn.hot ? Qt.lighter(submitBtn.accent, 1.12) : submitBtn.accent))
                        opacity: pw.isBusy ? 0.5 : 1.0
                        scale: (pw.isBusy ? 1.0 : (submitMa.pressed ? 1.08 : (submitBtn.hot ? 1.04 : 1.0))) * submitBtn.popScale
                        Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                        SequentialAnimation {
                            id: submitPop
                            NumberAnimation { target: submitBtn; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
                            NumberAnimation { target: submitBtn; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
                        }

                        Item {
                            id: chevron
                            anchors.centerIn: parent
                            width: submitBtn.width * 0.38
                            height: width
                            rotation: 180
                            property real armT: Math.max(1.5, submitBtn.width * 0.048)
                            property real armL: Math.max(5, submitBtn.width * 0.19)

                            NumberAnimation {
                                id: chevronSpin
                                target: chevron
                                property: "rotation"
                                from: 180
                                to: 540
                                duration: 400
                                easing.type: Easing.OutCubic
                            }

                            Item {
                                x: (chevron.width - chevron.armL * 0.766) / 2
                                y: chevron.height / 2
                                width: 0
                                height: 0
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: chevron.armT
                                    height: width
                                    radius: width / 2
                                    color: root.cField
                                    antialiasing: true
                                }
                                Rectangle {
                                    y: -chevron.armT / 2
                                    width: chevron.armL
                                    height: chevron.armT
                                    radius: height / 2
                                    transformOrigin: Item.Left
                                    rotation: 40
                                    color: root.cField
                                    antialiasing: true
                                }
                                Rectangle {
                                    y: -chevron.armT / 2
                                    width: chevron.armL
                                    height: chevron.armT
                                    radius: height / 2
                                    transformOrigin: Item.Left
                                    rotation: -40
                                    color: root.cField
                                    antialiasing: true
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: pw.btnRadius
                            color: "#ffffff"
                            opacity: submitBtn.flashOpacity
                            PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
                        }

                        MouseArea {
                            id: submitMa
                            anchors.fill: parent
                            hoverEnabled: !pw.isBusy
                            enabled: !pw.isBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                submitBtn.triggerSpin();
                                pw.forceInputFocus();
                                pw.submit();
                            }
                        }
                    }
                }

                Item {
                    id: fieldArea
                    anchors.left: lockButton.right
                    anchors.leftMargin: 6 * s
                    anchors.right: submitBtn.left
                    anchors.rightMargin: 6 * s
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4 * s
                    anchors.bottomMargin: 4 * s
                    clip: true
                    onWidthChanged: pw.updateScroll()

                    Text {
                        text: pw.hasError ? "Wrong password" : "Enter password"
                        font.family: root.sansFont
                        font.pixelSize: pw.fontSize
                        color: pw.hasError ? root.cRed : root.cMid
                        opacity: pw.hasError ? 1.0 : ((innerInput.text.length === 0 && !pw.hasFocus && charModel.count === 0) ? 0.55 : 0.0)
                        x: (fieldArea.width - implicitWidth) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Rectangle {
                        readonly property int selMin: Math.min(innerInput.selectionStart, innerInput.selectionEnd)
                        readonly property int selMax: Math.max(innerInput.selectionStart, innerInput.selectionEnd)
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.min(parent.height - 6 * s, pw.fontSize * 1.6)
                        radius: 4 * s
                        color: pw.signalColor
                        opacity: selMax > selMin ? 0.28 : 0.0
                        x: pw.scrollOffset + selMin * pw.charSlotStep - 2
                        width: selMax > selMin ? ((selMax - selMin) * pw.charSlotStep - pw.charSpacing + 4) : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                        Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    }

                    ListView {
                        id: charRow
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: pw.charSpacing
                        width: contentWidth
                        x: pw.scrollOffset
                        model: charModel
                        onContentWidthChanged: pw.updateScroll()
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "scale"; from: 0.60; to: 1.0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
                                NumberAnimation { property: "y"; from: 3.5; to: 0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                NumberAnimation { property: "rotation"; from: -9; to: 0; duration: 250; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutQuad }
                            }
                        }
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "scale"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "y"; to: 2; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "rotation"; to: 6; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
                            }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: charSlot
                            required property int index
                            required property string glyph
                            width: pw.revealProgress > 0.5 ? charMetrics.width : pw.dotSize
                            height: charRow.height
                            transformOrigin: Item.Center

                            Rectangle {
                                id: charShape
                                anchors.centerIn: parent
                                width: pw.dotSize
                                height: width
                                radius: Math.round(width * 0.24)
                                color: root.cText
                                antialiasing: true
                                property real dotPop: 1.0
                                opacity: 1.0 - pw.revealProgress
                                scale: (1.0 - pw.revealProgress) * dotPop
                                rotation: pw.revealProgress * -12
                                visible: opacity > 0.01
                                Component.onCompleted: {
                                    dotPop = 0.82;
                                    dotPopAnim.restart();
                                }
                                SequentialAnimation {
                                    id: dotPopAnim
                                    NumberAnimation { target: charShape; property: "dotPop"; to: 1.11; duration: 110; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                    NumberAnimation { target: charShape; property: "dotPop"; to: 1.0; duration: 170; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: charSlot.glyph
                                color: root.cText
                                font.family: root.sansFont
                                font.pixelSize: pw.fontSize
                                opacity: pw.revealProgress
                                scale: 0.88 + 0.12 * pw.revealProgress
                                rotation: (1.0 - pw.revealProgress) * 12
                                visible: opacity > 0.01
                            }
                        }
                    }

                    Rectangle {
                        id: caretRect
                        width: 2
                        height: pw.fontSize * 1.3
                        color: pw.signalColor
                        visible: pw.hasFocus && (pw.isRevealed || pw.revealProgress > 0.01)
                        anchors.verticalCenter: parent.verticalCenter
                        x: pw.scrollOffset + innerInput.cursorPosition * pw.charSlotStep
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        SequentialAnimation on opacity {
                            running: caretRect.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 120; easing.type: Easing.InQuad }
                            PauseAnimation { duration: 380 }
                            NumberAnimation { to: 1; duration: 120; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 380 }
                        }
                    }

                    TextInput {
                        id: innerInput
                        anchors.fill: parent
                        focus: true
                        opacity: 0
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        selectByMouse: true
                        horizontalAlignment: TextInput.AlignHCenter
                        font.family: root.sansFont
                        font.pixelSize: pw.fontSize
                        enabled: !pw.isBusy
                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        onCursorPositionChanged: pw.updateScroll()
                        onSelectionStartChanged: pw.updateScroll()
                        onSelectionEndChanged: pw.updateScroll()
                        Keys.onPressed: function(event) {
                            if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) {
                                event.accepted = true;
                                return;
                            }
                            if (event.matches(StandardKey.Copy) || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)) {
                                event.accepted = true;
                            }
                        }
                        onTextEdited: {
                            pw.hasError = false;
                            pw.text = text;
                            pw.syncModel();
                        }
                        onAccepted: pw.submit()
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * s

            Rectangle {
                id: userChip
                width: userRow.implicitWidth + 36 * s
                height: 36 * s
                radius: root.radius
                color: userMa.pressed ? root.cFieldBox : (userMa.containsMouse ? root.cField : root.cSurface)
                scale: userMa.pressed ? 0.96 : 1.0
                Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Row {
                    id: userRow
                    anchors.centerIn: parent
                    spacing: 8 * s
                    Ico {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "user"
                        tint: root.cMid
                        size: 16 * s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.userName()
                        font.family: root.sansFont
                        font.pixelSize: 14 * s
                        font.weight: Font.Medium
                        color: root.cText
                    }
                }

                MouseArea {
                    id: userMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isQuickshell && typeof userModel !== "undefined" && userModel.rowCount() > 0) {
                            root.userIndex = (root.userIndex + 1) % userModel.rowCount();
                        }
                        pw.forceInputFocus();
                    }
                }
            }

            Rectangle {
                id: sessionChip
                width: sessionRow.implicitWidth + 36 * s
                height: 36 * s
                radius: root.radius
                color: sessionMa.pressed ? root.cFieldBox : (sessionMa.containsMouse ? root.cField : root.cSurface)
                scale: sessionMa.pressed ? 0.96 : 1.0
                Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Row {
                    id: sessionRow
                    anchors.centerIn: parent
                    spacing: 8 * s
                    Ico {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "session"
                        tint: root.cMid
                        size: 16 * s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sessionName()
                        font.family: root.sansFont
                        font.pixelSize: 14 * s
                        font.weight: Font.Medium
                        color: root.cText
                    }
                }

                MouseArea {
                    id: sessionMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isQuickshell && typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0) {
                            root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount();
                        }
                        pw.forceInputFocus();
                    }
                }
            }
        }
    }

    Item {
        id: powerDock
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20 * s
        anchors.bottomMargin: 16 * s
        width: 280 * s
        height: 36 * s
        opacity: root.ui1

        Rectangle {
            id: menu
            anchors.right: parent.right
            anchors.bottom: toggle.top
            anchors.bottomMargin: 12 * s
            width: parent.width
            height: root.powerMenuOpen ? menuCol.implicitHeight + 24 * s : 0
            radius: root.radius
            clip: true
            visible: height > 0 || opacity > 0
            opacity: root.powerMenuOpen ? 1.0 : 0.0
            color: root.cSurface
            transformOrigin: Item.BottomRight
            scale: 0.92
            Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Column {
                id: menuCol
                x: 12 * s
                y: 12 * s
                width: parent.width - 24 * s
                spacing: 8 * s

                MenuButton {
                    width: parent.width
                    iconName: "sleep"
                    label: "Suspend"
                    accent: root.cMenu1
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.suspend();
                    }
                }
                MenuButton {
                    width: parent.width
                    iconName: "reboot"
                    label: "Reboot"
                    accent: root.cMenu2
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.reboot();
                    }
                }
                MenuButton {
                    width: parent.width
                    iconName: "power"
                    label: "Power off"
                    accent: root.cMenuDanger
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.powerOff();
                    }
                }
            }
        }

        Rectangle {
            id: themeButton
            anchors.right: toggle.left
            anchors.rightMargin: 8 * s
            anchors.bottom: parent.bottom
            width: 36 * s
            height: 36 * s
            radius: root.radius
            color: themeMa.containsMouse ? root.cField : root.cSurface
            scale: themeMa.pressed ? 0.94 : 1.0
            Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            Ico {
                anchors.centerIn: parent
                name: root.isDark ? "sun" : "moon"
                tint: root.cMid
                size: 16 * s
            }

            MouseArea {
                id: themeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTheme()
            }
        }

        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 36 * s
            height: 36 * s
            radius: root.radius
            color: root.powerMenuOpen ? root.cFieldBox : (toggleMa.containsMouse ? root.cField : root.cSurface)
            scale: toggleMa.pressed ? 0.94 : 1.0
            Behavior on color { enabled: !root.themeSwitching; ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            Ico {
                anchors.centerIn: parent
                name: root.powerMenuOpen ? "close" : "power"
                tint: root.powerMenuOpen ? root.cText : root.cRed
                size: 16 * s
            }

            MouseArea {
                id: toggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.powerMenuOpen = !root.powerMenuOpen;
                    if (!root.powerMenuOpen) pw.forceInputFocus();
                }
            }
        }
    }
    }

    ShaderEffect {
        id: themeMask
        anchors.fill: parent
        visible: false
        layer.enabled: themeOverlay.visible
        property vector2d itemSize: Qt.vector2d(width, height)
        property real progress: root.themeProgress
        property real transitionType: 2.0
        property vector2d origin: Qt.vector2d(root.themeOriginX, root.themeOriginY)
        property vector4d params: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        fragmentShader: Qt.resolvedUrl("shaders/wallpaper_transition.frag.qsb")
    }

    Image {
        id: themeOverlay
        anchors.fill: parent
        z: 1000
        visible: false
        cache: false
        fillMode: Image.Stretch
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: themeMask
            maskInverted: true
            maskThresholdMin: 0.0
            maskSpreadAtMin: 0.0
        }
    }

    NumberAnimation {
        id: themeAnim
        target: root
        property: "themeProgress"
        easing.type: Easing.InOutCubic
        onFinished: root.finishTheme()
    }
}
