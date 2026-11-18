import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

FocusScope {
    id: root
    width: 1920
    height: 1080

    property var appearance: ({})
    property string installedSnapshot: ""
    property date time: new Date()
    property bool signingIn: false
    property bool promptVisible: false
    property bool powerVisible: false
    property bool introPlaying: true
    property real panelReveal: 0
    property real contentReveal: 0
    property real centerReveal: 0
    property real wingsReveal: 0
    property bool loginComplete: false
    property real fold: 1
    property string status: ""
    property int failures: 0
    property var metrics: ({})
    readonly property string stateUrl: {
        const profile = String(config.profile || "")
        const state = "file:///var/lib/serpantinum-greeter/"
        return /^[0-9]{1,10}$/.test(profile) ? state + "profiles/" + profile + "/" : state
    }
    readonly property string mediaName: safeMedia(appearance.background)
    readonly property bool video: mediaName.endsWith(".mp4")
    readonly property string fontFamily: appearance.font || "Inter"
    readonly property bool dark: appearance.mode !== "light"
    readonly property color base: tint("base", dark ? "#14161b" : "#eff1f5")
    readonly property color crust: tint("crust", dark ? "#0d1016" : "#dce0e8")
    readonly property color foreground: effect === "glass" ? "white" : tint("text", dark ? "#e0e2e8" : "#4c4f69")
    readonly property color subtle: effect === "glass" ? "white" : tint("subtext0", dark ? "#c2c7cf" : "#6c6f85")
    readonly property color accent: tint("mauve", "#9ecafc")
    readonly property color surface: tint("surface0", dark ? "#242733" : "#ccd0da")
    readonly property color fieldColor: Qt.lighter(surface, 1.28)
    readonly property color cardColor: Qt.lighter(surface, 1.10)
    readonly property real opacitySetting: appearance.opacity === undefined ? 0.85 : appearance.opacity
    readonly property real corner: appearance.radius === undefined ? 10 : appearance.radius
    readonly property string effect: appearance.effect || "blur"
    readonly property var layoutData: appearance.layout || ({})
    readonly property var ref: layoutData.ref || ({w: 1920, h: 1080})
    readonly property var pane: layoutData.panel || ({x: -1, y: -1, w: 1280, h: 566, opacity: 1})
    readonly property real fit: Math.min(width / ref.w, height / ref.h)
    readonly property string timeFormat: appearance.clock || "h:mm:ss AP"

    property int userIndex: Math.max(0, userModel.lastIndex)
    readonly property string knownUser: config.user || users.objectAt(userIndex)?.name || userModel.lastUser || appearance.user || ""
    readonly property string primaryUser: knownUser || manualUser.text.trim()
    readonly property bool hasPowerActions: sddm.canSuspend || sddm.canReboot || sddm.canPowerOff
    readonly property var sounds: soundLoader.item
    readonly property var wallpaperSource: wallpaperTexture
    readonly property var palette: QtObject {
        readonly property color mauve: root.accent
        readonly property color primary: root.accent
        readonly property color base: root.base
        readonly property color mantle: root.tint("mantle", root.base)
        readonly property string iconFont: symbols.name
        readonly property color surface0: root.surface
        readonly property color surface1: root.tint("surface1", root.surface)
        readonly property color text: root.foreground
        readonly property color subtext0: root.subtle
        readonly property color blue: root.tint("blue", root.accent)
        readonly property color red: root.tint("red", "#ffb4ab")
        readonly property color green: root.tint("green", "#a6e3a1")
        readonly property color peach: root.tint("peach", "#ffbe98")
        readonly property color crust: root.crust
        readonly property real borderRadius: root.corner
        readonly property string fontFamily: root.fontFamily
    }

    Instantiator {
        id: users
        model: userModel
        delegate: QtObject { required property string name }
    }
    Loader {
        id: soundLoader
        active: !root.appearance.sfxMuted && (root.appearance.sfxVolume ?? 1) > 0
        source: "GreeterSounds.qml"
        onLoaded: item.volume = Qt.binding(() => root.appearance.sfxVolume ?? 1)
    }
    readonly property bool russian: appearance.language === "ru"
    readonly property bool rtl: /^(ar|fa|he|ur|ps|sd|yi)([_-]|$)/i.test(appearance.language || Qt.locale().name)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string batteryText: ""

    function trLabel(en, ru) { return russian ? ru : en }

    function s(value) { return value }
    function glassRect(item) {
        // Mapping depends on ancestor geometry throughout panel and focus animations.
        const dependency = root.wingsReveal + root.centerReveal + root.contentReveal + shell.y + item.width + item.height
        const origin = item.mapToItem(root, 0, 0)
        const edge = item.mapToItem(root, item.width, item.height)
        return Qt.rect(origin.x / root.width, origin.y / root.height,
                       (edge.x - origin.x) / root.width, (edge.y - origin.y) / root.height)
    }
    function tint(name, fallback) {
        const value = appearance.colors ? appearance.colors[name] : ""
        return typeof value === "string" && /^#[a-f0-9]{6}$/i.test(value) ? value : fallback
    }
    function safeMedia(value) {
        return typeof value === "string" && /^(wallpaper|avatar)-[a-f0-9]{20}\.(png|mp4)$/.test(value) ? value : ""
    }
    function loadState() {
        const file = new XMLHttpRequest()
        file.open("GET", stateUrl + "appearance.json")
        file.onreadystatechange = function() {
            if (file.readyState !== XMLHttpRequest.DONE || !file.responseText || file.responseText === installedSnapshot)
                return
            try {
                const snapshot = JSON.parse(file.responseText)
                if (snapshot.version === 1) {
                    appearance = snapshot
                    installedSnapshot = file.responseText
                    if (!mediaName || wallpaper.status === Image.Ready)
                        startIntro()
                }
            } catch (error) {}
        }
        file.send()
    }
    function startIntro() {
        if (introPlaying && !intro.running)
            intro.start()
    }
    function updateBattery() {
        const file = new XMLHttpRequest()
        file.open("GET", "file:///sys/class/power_supply/BAT0/capacity")
        file.onreadystatechange = function() {
            if (file.readyState === XMLHttpRequest.DONE && /^\d{1,3}\s*$/.test(file.responseText))
                batteryText = file.responseText.trim() + "%"
        }
        file.send()
    }
    function updateMetrics() {
        const file = new XMLHttpRequest()
        file.open("GET", "file:///run/serpantinum-greeter-system/metrics.json")
        file.onreadystatechange = function() {
            if (file.readyState === XMLHttpRequest.DONE) {
                try { metrics = JSON.parse(file.responseText) } catch (error) {}
            }
        }
        file.send()
    }
    function widgetValue(metric) {
        if (metric === "weather") {
            const weather = appearance.weather
            return weather && time.getTime() / 1000 - weather.fetched < 10800 ? weather.temp : ""
        }
        const value = metrics[metric]
        return typeof value === "number" ? String(value) + (metric === "temp" ? " °C" : "%") : ""
    }
    function focusCredentials() {
        if (knownUser)
            password.forceInputFocus()
        else
            manualUser.forceActiveFocus()
    }
    function openPrompt() {
        if (loginComplete)
            return
        promptVisible = true
        focusCredentials()
    }
    function closePrompt() {
        password.hideAll()
        sessions.close()
        accounts.close()
        powerVisible = false
        password.clear()
        if (!lockout.running)
            status = ""
        promptVisible = false
        root.forceActiveFocus()
    }
    function submit() {
        if (signingIn || lockout.running || !primaryUser || !password.text.length)
            return
        signingIn = true
        status = ""
        const entered = password.text
        password.clear()
        password.hideAll()
        sddm.login(primaryUser, entered, sessionIndex)
    }
    function itemFor(type, fallback, scope) {
        const models = scope === "screen" ? layoutData.screen : layoutData.items
        return (models || []).find(item => item.type === type) || fallback
    }

    Component.onCompleted: { loadState(); updateBattery(); updateMetrics(); root.forceActiveFocus() }
    FontLoader { id: symbols; source: "SymbolsNerdFontMono-Regular.ttf" }
    Timer { interval: 900; running: root.introPlaying && !intro.running; onTriggered: root.startIntro() }
    SequentialAnimation {
        id: intro
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelReveal"; from: 0; to: 1; duration: 600 }
            SequentialAnimation {
                PauseAnimation { duration: 460 }
                NumberAnimation { target: root; property: "contentReveal"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }
        }
        PropertyAction { target: root; property: "introPlaying"; value: false }
    }
    onPromptVisibleChanged: {
        if (loginComplete)
            return
        if (promptVisible) {
            collapse.stop()
            expand.restart()
        } else {
            expand.stop()
            collapse.restart()
        }
    }
    SequentialAnimation {
        id: expand
        NumberAnimation { target: root; property: "centerReveal"; to: 1; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: root; property: "wingsReveal"; to: 1; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
    }
    ParallelAnimation {
        id: collapse
        NumberAnimation { target: root; property: "centerReveal"; to: 0; duration: 100; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "wingsReveal"; to: 0; duration: 110; easing.type: Easing.InQuad }
    }
    SequentialAnimation {
        id: finish
        NumberAnimation { target: root; property: "wingsReveal"; to: 0; duration: 130; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: root; property: "fold"; to: 0; duration: 250; easing.type: Easing.InBack; easing.overshoot: 1.3 }
            NumberAnimation { target: root; property: "panelReveal"; to: 0; duration: 250; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "contentReveal"; to: 0; duration: 250; easing.type: Easing.InQuad }
        }
    }
    Timer {
        interval: 15000
        running: root.promptVisible && !password.text.length && !root.signingIn && !root.powerVisible && !lockout.running
        onTriggered: root.closePrompt()
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.time = new Date() }
    Timer { interval: 2500; repeat: true; running: true; onTriggered: root.loadState() }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.updateBattery() }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: root.updateMetrics() }
    Timer {
        id: lockout
        interval: 30000
        onTriggered: {
            root.failures = 0
            root.status = ""
            if (root.promptVisible) password.forceInputFocus()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.signingIn = false
            root.failures += 1
            if (root.appearance.passwordLimit > 0 && root.failures >= root.appearance.passwordLimit) {
                root.status = root.trLabel("Try again in 30 seconds.", "Попробуй снова через 30 секунд.")
                lockout.start()
            } else {
                root.status = root.trLabel("Incorrect password. Try again.", "Неверный пароль. Попробуй снова.")
                password.forceInputFocus()
            }
            password.markError()
        }
        function onLoginSucceeded() {
            root.status = ""
            root.powerVisible = false
            root.loginComplete = true
            expand.stop()
            collapse.stop()
            finish.start()
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && !signingIn) {
            if (sessions.opened) sessions.close()
            else if (accounts.opened) accounts.close()
            else if (powerVisible) powerVisible = false
            else if (promptVisible) closePrompt()
            event.accepted = true
        } else if (!promptVisible && !powerVisible) {
            openPrompt()
            if (!event.isAutoRepeat && event.text && event.text.length === 1
                && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter
                && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace
                && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0) {
                if (knownUser)
                    password.insertText(event.text)
                else
                    manualUser.insert(manualUser.cursorPosition, event.text)
            }
            event.accepted = true
        }
    }

    Rectangle { anchors.fill: parent; color: root.crust }

    Item {
        id: background
        anchors.fill: parent
        Image {
            anchors.fill: parent
            source: "fallback.jpg"
            fillMode: Image.PreserveAspectCrop
        }
        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.mediaName && !root.video ? root.stateUrl + root.mediaName : ""
            visible: status === Image.Ready
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
            onStatusChanged: {
                if (status === Image.Ready)
                    root.startIntro()
            }
        }
        Loader {
            anchors.fill: parent
            id: videoLayer
            Component.onCompleted: syncVideo()

            function syncVideo() {
                if (root.video)
                    setSource("VideoBackground.qml", { media: Qt.binding(() => root.stateUrl + root.mediaName) })
                else
                    source = ""
            }

            Connections {
                target: root
                function onVideoChanged() { videoLayer.syncVideo() }
            }
            Connections {
                target: videoLayer.item
                function onFirstFrame() { root.startIntro() }
            }
        }
    }

    ShaderEffectSource {
        id: wallpaperTexture
        sourceItem: background
        hideSource: false
        live: root.introPlaying || root.video || root.effect === "glass"
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: background
        autoPaddingEnabled: false
        blurEnabled: root.effect !== "off"
        blurMax: 64
        saturation: 0.25
        contrast: 0.06
        brightness: 0.02
        blur: root.promptVisible ? 1.0 : 0.72
        opacity: root.panelReveal
        visible: root.effect !== "off" && opacity > 0.01
        Behavior on blur { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        color: root.crust
        opacity: (root.effect === "off" ? 0.10 : (root.promptVisible ? 0.14 : 0.38)) * root.panelReveal
        Behavior on opacity {
            enabled: !root.introPlaying && !root.loginComplete
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.introPlaying
        property vector2d itemSize: Qt.vector2d(width, height)
        property real reveal: root.panelReveal
        property real s28: root.s(28)
        property color color0: root.crust
        property color color1: root.tint("surface1", root.surface)
        property color color2: root.tint("sapphire", root.accent)
        property color color3: root.tint("blue", root.accent)
        property color color4: root.accent
        property var source: wallpaperTexture
        fragmentShader: "curtain_wipe.frag.qsb"
    }

    MouseArea { anchors.fill: parent; onClicked: root.openPrompt() }

    component Caption: Text {
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: 17
        textFormat: Text.PlainText
    }
    component ActionButton: Button {
        id: control
        property string glyph: ""
        property color fill: root.fieldColor
        property color ink: root.foreground
        Accessible.name: text
        contentItem: Item {
            implicitWidth: buttonContent.implicitWidth
            implicitHeight: buttonContent.implicitHeight
            Row {
                id: buttonContent
                anchors.centerIn: parent
                spacing: 8
                Caption {
                    visible: control.glyph !== ""
                    text: control.glyph
                    color: control.ink
                    font.family: symbols.name
                    font.pixelSize: 17
                    anchors.verticalCenter: parent.verticalCenter
                }
                Caption {
                    visible: text !== ""
                    text: control.text
                    color: control.ink
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        background: Rectangle {
            radius: root.corner
            color: control.hovered || control.activeFocus ? Qt.lighter(control.fill, 1.16) : control.fill
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        padding: 12
    }
    component StatusCard: Rectangle {
        id: card
        property string glyph
        property string label
        property string detail
        property bool notificationCard: false
        color: root.cardColor
        radius: root.corner
        Caption {
            anchors { top: parent.top; left: parent.left; margins: 14 }
            visible: card.notificationCard
            text: card.label
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Column {
            anchors.centerIn: parent
            visible: card.notificationCard
            spacing: 8
            AnimatedImage {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(110, card.width * 0.6, card.height * 0.4)
                height: width
                visible: root.appearance.showEmptyGraphic !== false
                playing: visible && card.opacity > 0
                source: visible ? "pushy.gif" : ""
                fillMode: Image.PreserveAspectFit
            }
            Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.appearance.showEmptyGraphic === false
                text: card.glyph
                font.family: symbols.name
                font.pixelSize: 40
                color: root.subtle
            }
            Caption { anchors.horizontalCenter: parent.horizontalCenter; text: card.detail; font.pixelSize: 12; color: root.subtle }
        }
        Row {
            visible: !card.notificationCard
            anchors.centerIn: parent
            spacing: 12
            Caption {
                anchors.verticalCenter: parent.verticalCenter
                text: card.glyph
                font.family: symbols.name
                font.pixelSize: 24
                color: root.subtle
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Caption { text: card.label; font.pixelSize: 14; font.weight: Font.DemiBold }
                Caption { text: card.detail; font.pixelSize: 12; color: root.subtle }
            }
        }
    }

    Item {
        id: stage
        width: root.ref.w
        height: root.ref.h
        anchors.centerIn: parent
        scale: root.fit
        opacity: root.contentReveal
        transform: Translate { y: root.s(20) * (1 - root.contentReveal) }

        Item {
            id: clock
            readonly property var geometry: root.itemFor("clock", {x: stage.width/2 - 210, y: stage.height * 0.36 - 100, w: 420, h: 200, opacity: 1, rotation: 0, variant: "lockscreen"}, "screen")
            x: geometry.x
            y: geometry.y
            width: geometry.w || 420
            height: geometry.h || 200
            rotation: geometry.rotation
            opacity: root.promptVisible || root.centerReveal > 0.02 ? 0 : geometry.opacity
            scale: root.promptVisible || root.centerReveal > 0.02 ? 0.92 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            ClockFaceLockscreen { greeter: root }
        }

        Item {
            id: shell
            readonly property real fullWidth: Math.min(stage.width, root.pane.w)
            readonly property real coreWidth: Math.min(fullWidth, root.s(440))
            readonly property real panelLeft: root.pane.x >= 0
                ? Math.min(stage.width - fullWidth, root.pane.x) : (stage.width - fullWidth) / 2
            readonly property real panelTop: root.pane.y >= 0
                ? Math.min(stage.height - height, root.pane.y) : (stage.height - height) / 2
            width: coreWidth + root.wingsReveal * (fullWidth - coreWidth)
            height: Math.min(stage.height, root.pane.h)
            x: panelLeft + (fullWidth - width) / 2
            y: panelTop + (root.promptVisible ? 0 : root.s(90))
            scale: (0.92 + root.centerReveal * 0.08) * Math.max(0, root.fold)
            opacity: root.centerReveal
            visible: opacity > 0.005
            onVisibleChanged: if (visible && root.promptVisible) root.focusCredentials()
            enabled: root.promptVisible && !root.loginComplete
            clip: true
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: root.corner * 1.5
                color: Qt.alpha(root.surface, root.pane.opacity * (root.effect === "glass" ? 0.17 : root.opacitySetting))
            }
            Glass {
                anchors.fill: parent
                visible: root.effect === "glass"
                src: wallpaperTexture
                tintColor: root.surface
                tintAmount: root.pane.opacity * root.opacitySetting * 0.58
                radius: root.corner * 1.5
                sourceRect: {
                    const size = shell.scale * root.fit
                    const center = stage.mapToItem(root, shell.x + shell.width / 2, shell.y + shell.height / 2)
                    return Qt.rect((center.x - shell.width * size / 2) / root.width,
                                   (center.y - shell.height * size / 2) / root.height,
                                   shell.width * size / root.width, shell.height * size / root.height)
                }
            }
            MouseArea { anchors.fill: parent; onClicked: password.forceInputFocus() }
        }
        Item {
            id: panelViewport
            x: shell.x
            y: shell.y
            width: shell.width
            height: shell.height
            scale: shell.scale
            opacity: shell.opacity
            visible: shell.visible
            enabled: shell.enabled
            clip: true

            Item {
                id: panel
                x: (panelViewport.width - width) / 2
                width: shell.fullWidth
                height: parent.height

                function revealAt(centerX) {
                    return Math.abs(centerX - width / 2) <= shell.coreWidth / 2 ? 1
                        : Math.max(0, Math.min(1, root.wingsReveal))
                }

                Repeater {
                    model: [
                        {key: "weather", label: root.trLabel("Weather", "Погода"), glyph: "󰖐", x: 20, y: 20, w: 380, h: 190},
                        {key: "cpu", label: "CPU", glyph: "󰻠", x: 20, y: 218, w: 186, h: 160},
                        {key: "ram", label: "RAM", glyph: "󰍛", x: 214, y: 218, w: 186, h: 160},
                        {key: "temp", label: root.trLabel("Temperature", "Температура"), glyph: "󰔏", x: 20, y: 386, w: 186, h: 160},
                        {key: "disk", label: root.trLabel("Disk", "Диск"), glyph: "󰋊", x: 214, y: 386, w: 186, h: 160}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var box: root.itemFor("widget:" + modelData.key,
                            { x: modelData.x, y: modelData.y, w: modelData.w, h: modelData.h, opacity: 1, rotation: 0 })
                        readonly property string reading: root.widgetValue(modelData.key)
                        x: box.x; y: box.y; width: box.w; height: box.h
                        opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                        visible: (root.layoutData.items === undefined
                                 ? panel.width >= 1000 : root.layoutData.items.some(entry => entry.type === "widget:" + modelData.key))
                        radius: root.corner
                        color: root.cardColor
                        ShaderEffect {
                            anchors.fill: parent
                            visible: modelData.key !== "weather" && fillLevel > 0 && parent.opacity > 0
                            property real radius: parent.radius
                            property real fillLevel: Math.min(1, Math.max(0, (Number(root.metrics[modelData.key]) || 0) / 100))
                            property real waveAmp: 4
                            property vector2d itemSize: Qt.vector2d(width, height)
                            property real phase: 0
                            property real vertical: 1
                            property color color1: Qt.lighter(root.accent, 1.18)
                            property color color2: root.accent
                            property vector4d params: Qt.vector4d(0.94, 0, 0, 0)
                            opacity: root.effect === "glass" ? 0.5 : 0.75
                            fragmentShader: "fluid_wave.frag.qsb"
                            Behavior on fillLevel { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                            NumberAnimation on phase {
                                from: 0; to: Math.PI * 2; duration: 3200
                                loops: Animation.Infinite
                                running: parent.visible
                            }
                        }
                        Loader {
                            anchors.fill: parent
                            active: modelData.key === "weather"
                            sourceComponent: WeatherCard {
                                greeter: root
                                weather: root.appearance.weather || ({})
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: modelData.key !== "weather"
                            spacing: 9
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                Caption { text: modelData.glyph; color: root.subtle; font.family: symbols.name }
                                Caption {
                                    text: modelData.label
                                    color: root.subtle
                                    font.pixelSize: 14
                                }
                            }
                            Caption {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: reading || "—"
                                font.pixelSize: 35
                                font.weight: Font.DemiBold
                                color: root.foreground
                            }
                        }
                    }
                }
                Repeater {
                    model: [
                        {key: "notifications", label: root.trLabel("Notifications", "Уведомления"),
                         detail: root.trLabel("No notifications", "Нет уведомлений"), glyph: "󰂚", y: 20, h: 422},
                        {key: "widget:music", label: root.trLabel("Music", "Музыка"),
                         detail: root.trLabel("Nothing is playing", "Ничего не воспроизводится"), glyph: "󰝚", y: 450, h: 96}
                    ]
                    delegate: StatusCard {
                        required property var modelData
                        readonly property var box: root.itemFor(modelData.key,
                            {x: panel.width - 420, y: modelData.y, w: 400, h: modelData.h, opacity: 1, rotation: 0})
                        x: box.x; y: box.y; width: box.w; height: box.h
                        opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                        visible: (root.layoutData.items === undefined
                            ? panel.width >= 1000 : root.layoutData.items.some(entry => entry.type === modelData.key))
                        glyph: modelData.glyph
                        label: modelData.label
                        detail: modelData.detail
                        notificationCard: modelData.key === "notifications"
                        color: box.variant === "plain" ? "transparent" : root.cardColor
                    }
                }

                Rectangle {
                    id: avatar
                    readonly property var box: root.itemFor("avatar", {x: (panel.width - 200)/2, y: 89, w: 200, h: 200, opacity: 1, rotation: 0})
                    x: box.x; y: box.y; width: box.w; height: box.h
                    opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                    visible: root.layoutData.items === undefined || root.layoutData.items.some(entry => entry.type === "avatar")
                    radius: box.variant === "rounded" ? root.corner * 1.5 : width / 2
                    color: root.fieldColor
                    clip: true
                    Caption {
                        anchors.centerIn: parent
                        text: "󰀉"
                        font.family: symbols.name
                        font.pixelSize: Math.min(parent.width, parent.height) / 2
                    }
                    Image {
                        anchors.fill: parent
                        source: root.safeMedia(root.appearance.avatar) ? root.stateUrl + root.safeMedia(root.appearance.avatar) : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: status === Image.Ready
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle { width: avatar.width; height: avatar.height; radius: avatar.radius }
                            }
                        }
                    }
                }

                TextField {
                    id: manualUser
                    x: (panel.width - 380) / 2
                    y: 305
                    width: 185
                    height: 44
                    visible: !root.knownUser
                    placeholderText: root.trLabel("Username", "Имя пользователя")
                    color: root.foreground
                    placeholderTextColor: root.subtle
                    horizontalAlignment: TextInput.AlignHCenter
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    background: Rectangle { radius: root.corner; color: root.fieldColor }
                    onAccepted: if (text.trim()) password.forceInputFocus()
                }
                ActionButton {
                    readonly property var box: root.itemFor("user", {x: (panel.width - 380)/2, y: 305, w: 185, h: 44, opacity: 1, rotation: 0})
                    x: box.x; y: box.y; width: box.w; height: box.h
                    opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                    visible: !!root.knownUser && (root.layoutData.items === undefined || root.layoutData.items.some(entry => entry.type === "user"))
                    text: root.primaryUser
                    glyph: "󰀉"
                    fill: box.variant === "plain" ? "transparent" : root.fieldColor
                    onClicked: password.forceInputFocus()
                }
                ActionButton {
                    readonly property var box: root.itemFor("lockstatus", {x: (panel.width + 10)/2, y: 305, w: 185, h: 44, opacity: 1, rotation: 0})
                    x: box.x; y: box.y; width: box.w; height: box.h
                    opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                    visible: root.layoutData.items === undefined || root.layoutData.items.some(entry => entry.type === "lockstatus")
                    text: root.signingIn ? root.trLabel("Checking…", "Проверка…") : root.trLabel("Locked", "Заблокировано")
                    glyph: "󰌾"
                    fill: box.variant === "plain" ? "transparent" : root.fieldColor
                    ink: root.status ? root.tint("red", "#ffb4ab") : root.foreground
                    onClicked: password.forceInputFocus()
                }

                Item {
                    id: passwordBox
                    readonly property var box: root.itemFor("password", {x: (panel.width - 380)/2, y: 357, w: 380, h: 44, opacity: 1, rotation: 0})
                    x: Math.max(0, Math.min(panel.width - width, box.x))
                    y: Math.max(0, Math.min(panel.height - height, box.y))
                    width: Math.min(panel.width, Math.max(230, box.w))
                    height: Math.max(44, box.h)
                    rotation: box.rotation
                    opacity: Math.max(0.5, box.opacity) * panel.revealAt(x + width / 2)
                    PasswordInput {
                        id: password
                        anchors.fill: parent
                        greeter: root
                        enabled: !lockout.running
                        isBusy: root.signingIn
                        hasError: root.status !== ""
                        isWidgetVisible: root.promptVisible
                        horizontalAlignment: TextInput.AlignHCenter
                        placeholderText: root.trLabel("Password", "Пароль")
                        baseColor: passwordBox.box.variant === "glass" ? Qt.alpha(root.fieldColor, 0.45) : root.fieldColor
                        lockBoxColor: Qt.lighter(root.surface, 1.55)
                        accentColor: root.accent
                        fontPixelSize: 14
                        onAccepted: root.submit()
                        onTextEdited: {
                            if (!lockout.running)
                                root.status = ""
                        }
                    }
                }

                ActionButton {
                    readonly property var box: root.itemFor("keyboard", {x: panel.width/2 - 40, y: 433, w: 0, h: 0, rotation: 0, opacity: 1})
                    x: box.w > 0 ? box.x : box.x - width/2
                    y: box.h > 0 ? box.y : box.y - height/2
                    width: box.w > 0 ? box.w : 65
                    height: box.h > 0 ? box.h : 40
                    opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                    visible: keyboard.layouts.length > 1
                        && (root.layoutData.items === undefined || root.layoutData.items.some(entry => entry.type === "keyboard"))
                    text: keyboard.layouts[keyboard.currentLayout]?.shortName?.toUpperCase() || "EN"
                    glyph: "󰌌"
                    onClicked: { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; password.forceInputFocus() }
                }
                ActionButton {
                    readonly property var box: root.itemFor("battery", {x: panel.width/2 + 45, y: 433, w: 0, h: 0, rotation: 0, opacity: 1})
                    x: box.w > 0 ? box.x : box.x - width/2
                    y: box.h > 0 ? box.y : box.y - height/2
                    width: box.w > 0 ? box.w : 65
                    height: box.h > 0 ? box.h : 40
                    opacity: box.opacity * panel.revealAt(x + width / 2); rotation: box.rotation
                    visible: root.batteryText !== ""
                        && (root.layoutData.items === undefined || root.layoutData.items.some(entry => entry.type === "battery"))
                    text: root.batteryText
                    glyph: "󰁹"
                    enabled: false
                }
                Caption {
                    anchors.horizontalCenter: passwordBox.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 23
                    color: root.tint("red", "#ffb4ab")
                    text: root.status
                }
            }
        }

        ActionButton {
            id: power
            anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 16; rightMargin: 20 }
            width: 48; height: 48
            opacity: root.promptVisible && root.hasPowerActions ? 1 : 0
            visible: opacity > 0.01
            enabled: root.promptVisible && root.hasPowerActions
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            glyph: root.powerVisible ? "󰅖" : "󰐥"
            ink: root.powerVisible ? root.foreground : root.tint("red", "#ffb4ab")
            Accessible.name: root.trLabel("Power", "Питание")
            onClicked: {
                root.sounds?.play("reusables/iconbutton/click.wav")
                root.powerVisible = !root.powerVisible
            }
        }
        Rectangle {
            anchors { right: power.right; bottom: power.top; bottomMargin: 16 }
            width: 320
            height: root.powerVisible ? actions.implicitHeight + 24 : 0
            opacity: root.powerVisible ? 1 : 0
            visible: height > 0 || opacity > 0
            enabled: root.powerVisible
            clip: true
            color: Qt.alpha(root.surface, Math.max(0.5, root.opacitySetting))
            radius: root.corner
            Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Column {
                id: actions
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Repeater {
                    model: [
                        {available: sddm.canSuspend, icon: "󰒲", label: root.trLabel("Suspend", "Сон"), tint: root.accent,
                         trigger: () => sddm.suspend()},
                        {available: sddm.canReboot, icon: "󰑓", label: root.trLabel("Restart", "Перезагрузка"), tint: root.palette.blue,
                         trigger: () => sddm.reboot()},
                        {available: sddm.canPowerOff, icon: "󰐥", label: root.trLabel("Shut down", "Выключить"), tint: root.palette.red,
                         trigger: () => sddm.powerOff()}
                    ]
                    FillButton {
                        required property var modelData
                        greeter: root
                        width: actions.width
                        visible: modelData.available
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        baseColor: root.surface
                        hoverColor: root.palette.surface1
                        accentColor: modelData.tint
                        cornerRadius: root.corner
                        fillDuration: 1200
                        onTriggered: {
                            root.powerVisible = false
                            modelData.trigger()
                        }
                    }
                }
            }
        }
        SessionChooser {
            id: sessions
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 20; bottomMargin: 16 }
            width: implicitWidth
            height: implicitHeight
            greeter: root
            sessions: sessionModel
            selectedIndex: root.sessionIndex
            active: root.promptVisible && !root.loginComplete && !root.signingIn
            iconFont: symbols.name
            backdrop: wallpaperTexture
            onChosen: index => root.sessionIndex = index
            onDismissed: if (root.promptVisible) root.focusCredentials()
        }
        SessionChooser {
            id: accounts
            anchors { left: sessions.right; bottom: sessions.bottom; leftMargin: 10 }
            width: implicitWidth
            height: implicitHeight
            greeter: root
            sessions: userModel
            selectedIndex: root.userIndex
            title: root.trLabel("Account", "Пользователь")
            glyph: "󰀉"
            active: root.promptVisible && !root.loginComplete && !root.signingIn && !config.user && users.count > 1
            iconFont: symbols.name
            backdrop: wallpaperTexture
            onChosen: index => {
                password.clear()
                password.hideAll()
                root.status = ""
                root.userIndex = index
            }
            onDismissed: if (root.promptVisible) root.focusCredentials()
        }
    }
}
