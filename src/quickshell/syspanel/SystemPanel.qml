import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    id: root
    visible: false
    focus: true
    enabled: visible

    function s(val) {
        return Scaler.s(val);
    }

    readonly property string barPosition: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) {
            return Config.rawSettings.bar.position;
        }
        return "top";
    }

    readonly property bool isLeftAnchored: barPosition === "right"
    readonly property real slideDistance: sidebarPanel.width > 0 ? sidebarPanel.width : root.s(420)
    readonly property real rowSlideDistance: root.s(36)

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop

    readonly property real boxRadius: Math.min(ThemeBackend.borderRadius, root.s(20))
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, root.s(14))

    readonly property color briColor: Qt.lighter(ThemeBackend.mauve, 1.1)
    readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.5)
    readonly property color profileColor: Qt.lighter(ThemeBackend.blue, 1.55)
    readonly property int batCapacity: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0

    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    readonly property string batStatus: {
        if (!UPower.displayDevice.ready) return "Unknown";
        switch (UPower.displayDevice.state) {
            case UPowerDeviceState.FullyCharged: return "Fully Charged";
            case UPowerDeviceState.Charging: return "Charging";
            case UPowerDeviceState.Discharging: return "Discharging";
            default: return "Unknown";
        }
    }

    readonly property int batHours: {
        if (!UPower.displayDevice.ready) return 0;
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        return Math.floor(secs / 3600);
    }

    readonly property int batMins: {
        if (!UPower.displayDevice.ready) return 0;
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        return Math.round((secs % 3600) / 60);
    }

    readonly property string batTimeLabel: {
        if (!UPower.displayDevice.ready || (batHours === 0 && batMins === 0) || batCapacity === 100) return "";
        if (UPower.displayDevice.state === UPowerDeviceState.Charging) return I18n.t("syspanel.battery.until_full");
        if (UPower.displayDevice.state === UPowerDeviceState.Discharging) return I18n.t("syspanel.battery.remaining");
        return "";
    }

    readonly property string powerProfile: {
        switch (PowerProfiles.profile) {
            case PowerProfile.Performance: return "performance";
            case PowerProfile.PowerSaver: return "power-saver";
            default: return "balanced";
        }
    }

    readonly property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    readonly property bool sysMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

    property real sysBrightness: 0

    property bool wifiRadioEnabled: Networking.wifiEnabled
    property bool btRadioEnabled: Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onDefaultAdapterChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    Connections {
        target: Bluetooth.defaultAdapter || null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    property bool isDraggingVol: false
    property bool isDraggingBri: false
    property bool usesDdcBrightness: false

    property bool btStateBeforeAirplane: false
    property bool wifiStateBeforeAirplane: true

    property bool canHibernate: false

    readonly property color batColorFlat: {
        if (!UPower.displayDevice.ready) return ThemeBackend.blue;
        if (isCharging) return ThemeBackend.green;
        if (batCapacity <= 20) return ThemeBackend.red;
        return ThemeBackend.blue;
    }

    property real animCapacity: 0
    Behavior on animCapacity {
        enabled: root.visible
        NumberAnimation { duration: 1200; easing.type: Easing.OutQuint }
    }

    onBatCapacityChanged: {
        if (root.visible) {
            animCapacity = batCapacity;
        }
    }

    onSysVolumeChanged: {
        if (root.visible && typeof volSlider !== "undefined" && volSlider && !root.isDraggingVol && volSlider.value !== sysVolume) {
            volSlider.value = sysVolume;
        }
    }

    onSysBrightnessChanged: {
        if (root.visible && typeof briSlider !== "undefined" && briSlider && !root.isDraggingBri && briSlider.value !== sysBrightness) {
            briSlider.value = sysBrightness;
        }
    }

    Process {
        id: hibernateCheck
        running: false
        command: ["bash", Caching.serpantinumDir + "/scripts/system/can_hibernate.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                root.canHibernate = (out === "yes");
            }
        }
    }

    property real introContent: 0.0
    property real introTop: 0.0
    property real introSliders: 0.0
    property real introQuickActions: 0.0
    property real introNotifs: 0.0
    property real introActions: 0.0
    property real introCore: 0.0

    function resetAndPlayIntro() {
        introContent = 0.0;
        introTop = 0.0;
        introSliders = 0.0;
        introQuickActions = 0.0;
        introNotifs = 0.0;
        introActions = 0.0;
        introCore = 0.0;
        closeSequence.stop();
        startupSequence.restart();
    }

    onVisibleChanged: {
        NotificationManager.sysPanelOpen = visible;
        if (visible) {
            forceActiveFocus();
            resetAndPlayIntro();

            animCapacity = batCapacity;

            if (typeof volSlider !== "undefined" && volSlider && !root.isDraggingVol) {
                volSlider.value = root.sysVolume;
            }

            if (typeof briSlider !== "undefined" && briSlider && !root.isDraggingBri) {
                briSlider.value = root.sysBrightness;
            }

            if (nightLightBtn) nightLightBtn.updateState();
            if (coffeeBtn) coffeeBtn.updateState();

            briPollerTimer.interval = 150;
            briPollerTimer.restart();
        } else {
            briPollerTimer.stop();
            briPoller.running = false;
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Timer {
        id: volSyncDelay
        interval: 800
        repeat: false
        onTriggered: root.isDraggingVol = false
    }

    Timer {
        id: briSyncDelay
        interval: 800
        repeat: false
        onTriggered: root.isDraggingBri = false
    }

    Component.onCompleted: {
        hibernateCheck.running = true;
        if (visible) {
            NotificationManager.sysPanelOpen = true;
            if (nightLightBtn) nightLightBtn.updateState();
            if (coffeeBtn) coffeeBtn.updateState();
            resetAndPlayIntro();
            forceActiveFocus();
            briPollerTimer.interval = 150;
            briPollerTimer.restart();
            animCapacity = batCapacity;
        }
    }

    Component.onDestruction: {
        NotificationManager.sysPanelOpen = false;
        briPollerTimer.stop();
    }

    Timer {
        id: briPollerTimer
        interval: root.usesDdcBrightness ? 10000 : 1500
        repeat: false
        onTriggered: {
            if (root.visible) {
                briPoller.running = true;
                interval = root.usesDdcBrightness ? 10000 : 1500;
            }
        }
    }

    Process {
        id: briBackend
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "backend"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.usesDdcBrightness = this.text.trim() === "ddc"
        }
    }

    Process {
        id: briPoller
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "" && !root.isDraggingBri) {
                    root.sysBrightness = parseInt(out) || 0;
                }
                if (root.visible) briPollerTimer.start();
            }
        }
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "introTop"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }

        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation { target: root; property: "introSliders"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 55 }
            NumberAnimation { target: root; property: "introQuickActions"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: root; property: "introNotifs"; from: 0; to: 1.0; duration: 330; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 105 }
            NumberAnimation { target: root; property: "introActions"; from: 0; to: 1.0; duration: 330; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 130 }
            NumberAnimation { target: root; property: "introCore"; from: 0; to: 1.0; duration: 340; easing.type: Easing.OutCubic }
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introTop"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introSliders"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introQuickActions"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introNotifs"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introActions"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introCore"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    component BatteryContent : Item {
        id: bRoot
        property color contentTextColor: ThemeBackend.text
        property color iconColor: root.batColorFlat

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.s(20)
            anchors.rightMargin: root.s(20)
            spacing: root.s(16)

            Text {
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.s(32)
                color: bRoot.iconColor
                text: root.isCharging ? "󰂄" : (root.batCapacity > 20 ? "󰁹" : "󰂃")
                Behavior on color {
                    enabled: root.visible
                    ColorAnimation { duration: 400 }
                }
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: root.s(2)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(20)
                    color: bRoot.contentTextColor
                    text: Math.round(root.animCapacity) + "%"
                    Behavior on color {
                        enabled: root.visible
                        ColorAnimation { duration: 400 }
                    }
                }

                Text {
                    property string timeString: {
                        if (root.batStatus === "Fully Charged") return I18n.t("syspanel.battery.fully_charged");
                        if (root.batStatus === "Charging") {
                            if (root.batHours === 0 && root.batMins === 0) return I18n.t("syspanel.battery.charging");
                            return I18n.t("syspanel.battery.charging_time", { hours: root.batHours, mins: root.batMins });
                        }
                        if (root.batHours === 0 && root.batMins === 0) return I18n.t("syspanel.battery.discharging");
                        return I18n.t("syspanel.battery.left_time", { hours: root.batHours, mins: root.batMins });
                    }

                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(10)
                    color: bRoot.contentTextColor === ThemeBackend.crust ? Qt.alpha(ThemeBackend.crust, 0.85) : (root.isCharging ? ThemeBackend.green : ThemeBackend.subtext0)
                    text: timeString
                    Behavior on color {
                        enabled: root.visible
                        ColorAnimation { duration: 300 }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }

    component QuickActionBtn : Rectangle {
        id: qaBtn
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: root.cardRadius

        property bool isActive: false
        property string iconText: ""
        property color activeColor: ThemeBackend.blue
        readonly property bool isHovered: qaMa.containsMouse
        property real customFontSize: 0
        property string customFontFamily: ""

        signal leftClicked()
        signal rightClicked()

        color: isActive ? activeColor : (qaMa.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04))
        Behavior on color {
            enabled: root.visible
            ColorAnimation { duration: 150 }
        }

        scale: qaMa.pressed ? 0.95 : (qaMa.containsMouse ? 1.01 : 1.0)
        Behavior on scale {
            enabled: root.visible
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        Text {
            anchors.centerIn: parent
            font.family: qaBtn.customFontFamily !== "" ? qaBtn.customFontFamily : ThemeBackend.iconFont
            font.pixelSize: qaBtn.customFontSize > 0 ? qaBtn.customFontSize : root.s(18)
            font.weight: qaBtn.customFontSize > 0 ? Font.Bold : Font.Normal
            color: qaBtn.isActive ? ThemeBackend.crust : (qaMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
            text: qaBtn.iconText
            Behavior on color {
                enabled: root.visible
                ColorAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: qaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) qaBtn.rightClicked();
                else qaBtn.leftClicked();
            }
        }
    }

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.97)
        radius: Math.min(ThemeBackend.borderRadius, root.s(28))
        border.width: 0
        clip: true
        opacity: root.introContent
        transform: Translate { x: (root.isLeftAnchored ? -root.slideDistance : root.slideDistance) * (1.0 - root.introContent) }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: root.isLeftAnchored ? parent.left : undefined
            anchors.right: root.isLeftAnchored ? undefined : parent.right
            width: sidebarPanel.radius + root.s(2)
            color: sidebarPanel.color
            visible: sidebarPanel.radius > 0
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(8)
                spacing: root.s(5)

                Rectangle {
                    id: userBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(54)
                    Layout.maximumHeight: root.s(54)
                    radius: root.boxRadius
                    color: Qt.darker(ThemeBackend.surface0, 1.04)
                    opacity: root.introTop
                    transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introTop) }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(10)
                        spacing: root.s(10)

                        ImageBox {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: root.s(34)
                            Layout.preferredHeight: root.s(34)
                            size: root.s(34)
                            cornerRadius: root.s(8)
                            imageRadius: root.s(8)
                            source: SystemInfo.avatarPath !== "" ? "file://" + SystemInfo.avatarPath : ""
                            backgroundColor: SystemInfo.avatarPath === "" ? ThemeBackend.surface1 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(18)
                                color: ThemeBackend.text
                                visible: SystemInfo.avatarPath === ""
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 0

                            Text {
                                text: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("syspanel.user.default_name")
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: root.s(15)
                                color: ThemeBackend.text
                            }

                            Text {
                                text: SystemInfo.osName !== "" ? SystemInfo.osName : I18n.t("syspanel.user.default_os")
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Medium
                                font.pixelSize: root.s(10)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ClickButton {
                            id: logoutBtn
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            Layout.preferredWidth: root.s(92)
                            Layout.preferredHeight: root.s(34)
                            horizontalPadding: root.s(10)
                            cornerRadius: root.s(12)
                            buttonText: I18n.t("syspanel.user.logout")
                            textFontSize: root.s(11)
                            buttonIcon: "󰍃"
                            iconFontSize: root.s(14)
                            accentColor: ThemeBackend.surface2
                            textColor: ThemeBackend.text

                            Timer {
                                id: logoutOpenTimer
                                interval: 150
                                onTriggered: {
                                    closeSequence.start();
                                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/system/exit.sh"]);
                                    Quickshell.execDetached(["sh", "-c", "echo 'close' > " + Caching.runDir + "/widget_state"]);
                                }
                            }

                            onTriggered: {
                                logoutOpenTimer.start();
                            }
                        }
                    }
                }

                Rectangle {
                    id: slidersBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: slidersCol.implicitHeight + root.s(20)
                    Layout.maximumHeight: slidersCol.implicitHeight + root.s(20)
                    radius: root.boxRadius
                    color: Qt.darker(ThemeBackend.surface0, 1.04)
                    opacity: root.introSliders
                    transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introSliders) }

                    ColumnLayout {
                        id: slidersCol
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)

                            IconButton {
                                Layout.alignment: Qt.AlignVCenter
                                size: root.s(26)
                                cornerRadius: root.s(8)
                                buttonIcon: root.sysMuted || root.sysVolume === 0 ? "󰖁" : (root.sysVolume > 50 ? "󰕾" : "󰖀")
                                iconFontSize: root.s(15)
                                accentColor: ThemeBackend.surface1
                                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.sysMuted ? ThemeBackend.overlay0 : root.volColor)
                                onClicked: {
                                    if (Audio.defaultSink) {
                                        Audio.toggleMute(Audio.defaultSink);
                                    }
                                }
                            }

                            Timer {
                                id: volCmdThrottle
                                interval: 50
                                property int targetPct: -1
                                onTriggered: {
                                    if (targetPct >= 0) {
                                        if (targetPct > 0 && root.sysMuted) {
                                            if (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) {
                                                Audio.toggleMute(Audio.defaultSink);
                                            }
                                        }
                                        if (Audio.defaultSink) {
                                            Audio.setVolume(Audio.defaultSink, targetPct);
                                        }
                                        targetPct = -1;
                                    }
                                }
                            }

                            Draggable {
                                id: volSlider
                                Layout.fillWidth: true
                                implicitHeight: root.s(18)
                                from: 0.0
                                to: Audio.maxVolume
                                stepSize: 1.0
                                showValueBubble: true
                                valueFormatter: function(v) { return Math.round(v) }
                                value: root.sysVolume
                                backgroundColor: ThemeBackend.surface1
                                accentColor: root.sysMuted ? ThemeBackend.surface2 : root.volColor
                                gradColor1: root.sysMuted ? ThemeBackend.surface2 : root.volColor
                                gradColor2: root.sysMuted ? ThemeBackend.surface2 : Qt.lighter(root.volColor, 1.05)
                                gradColor3: root.sysMuted ? ThemeBackend.surface2 : Qt.lighter(root.volColor, 1.10)
                                cornerRadius: root.s(6)
                                handleSize: root.s(22)

                                handleColor: root.sysMuted ? ThemeBackend.overlay0 : Qt.lighter(root.volColor, 1.15)
                                handleHoverColor: root.sysMuted ? ThemeBackend.subtext0 : Qt.lighter(root.volColor, 1.5)
                                handleDragColor: root.sysMuted ? ThemeBackend.text : Qt.lighter(root.volColor, 1.45)
                                handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

                                onDragStarted: {
                                    volSyncDelay.stop();
                                    root.isDraggingVol = true;
                                }
                                onDragFinished: {
                                    if (volCmdThrottle.running && volCmdThrottle.targetPct >= 0) {
                                        volCmdThrottle.stop();
                                        if (volCmdThrottle.targetPct > 0 && root.sysMuted) {
                                            if (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) {
                                                Audio.toggleMute(Audio.defaultSink);
                                            }
                                        }
                                        if (Audio.defaultSink) {
                                            Audio.setVolume(Audio.defaultSink, volCmdThrottle.targetPct);
                                        }
                                        volCmdThrottle.targetPct = -1;
                                    }
                                    volSyncDelay.restart();
                                }
                                onMoved: (val) => {
                                    let pct = Math.max(0, Math.min(Audio.maxVolume, Math.round(val)));
                                    volSlider.value = pct;
                                    volCmdThrottle.targetPct = pct;
                                    if (!volCmdThrottle.running) volCmdThrottle.start();
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)

                            IconButton {
                                Layout.alignment: Qt.AlignVCenter
                                size: root.s(26)
                                cornerRadius: root.s(8)
                                buttonIcon: root.sysBrightness > 66 ? "󰃠" : (root.sysBrightness > 33 ? "󰃟" : "󰃞")
                                iconFontSize: root.s(15)
                                accentColor: ThemeBackend.surface1
                                textColor: isHoveredOrHighlighted ? ThemeBackend.text : root.briColor
                                onClicked: {
                                    briCmdThrottle.stop();
                                    briCmdThrottle.targetPct = -1;
                                    let target = root.sysBrightness > 0 ? 0 : 100;
                                    root.sysBrightness = target;
                                    Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", target.toString()]);
                                }
                            }

                            Timer {
                                id: briCmdThrottle
                                interval: 400
                                property int targetPct: -1
                                onTriggered: {
                                    if (targetPct >= 0) {
                                        Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", targetPct.toString()]);
                                        targetPct = -1;
                                    }
                                }
                            }

                            Draggable {
                                id: briSlider
                                Layout.fillWidth: true
                                implicitHeight: root.s(18)
                                from: 0.0
                                to: 100.0
                                stepSize: 1.0
                                showValueBubble: true
                                valueFormatter: function(v) { return Math.round(v) }
                                value: root.sysBrightness
                                backgroundColor: ThemeBackend.surface1
                                accentColor: root.briColor
                                gradColor1: root.briColor
                                gradColor2: Qt.lighter(root.briColor, 1.05)
                                gradColor3: Qt.lighter(root.briColor, 1.10)
                                cornerRadius: root.s(6)
                                handleSize: root.s(22)

                                handleColor: Qt.lighter(root.briColor, 1.15)
                                handleHoverColor: Qt.lighter(root.briColor, 1.3)
                                handleDragColor: Qt.lighter(root.briColor, 1.45)
                                handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

                                onDragStarted: {
                                    briSyncDelay.stop();
                                    root.isDraggingBri = true;
                                }
                                onDragFinished: {
                                    if (briCmdThrottle.targetPct >= 0) {
                                        briCmdThrottle.stop();
                                        Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", briCmdThrottle.targetPct.toString()]);
                                        briCmdThrottle.targetPct = -1;
                                    }
                                    briSyncDelay.restart();
                                }
                                onMoved: (val) => {
                                    let pct = Math.max(0, Math.min(100, Math.round(val)));
                                    root.sysBrightness = pct;
                                    briSlider.value = pct;
                                    briCmdThrottle.targetPct = pct;
                                    if (!briSlider.isDragging) briCmdThrottle.restart();
                                }
                            }
                        }
                    }
                }

                Item {
                    id: quickActionsBox
                    z: 5
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(73)
                    Layout.maximumHeight: root.s(73)
                    opacity: root.introQuickActions
                    transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introQuickActions) }

                    RowLayout {
                        anchors.fill: parent
                        spacing: root.s(6)

                        QuickActionBtn {
                            id: nightLightBtn
                            iconText: "󰖔"
                            activeColor: ThemeBackend.peach

                            function updateState() {
                                let anyEnabled = false;
                                if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
                                    anyEnabled = BlueLight.isAnyEnabled();
                                } else if (typeof Config !== "undefined") {
                                    let ds = Config.getSetting("display", {"monitors": {}});
                                    let mons = (ds && ds.monitors) ? ds.monitors : {};
                                    for (let mName in mons) {
                                        if (mons[mName] && mons[mName].enabled) {
                                            anyEnabled = true;
                                            break;
                                        }
                                    }
                                }
                                isActive = anyEnabled;
                            }

                            Component.onCompleted: updateState()

                            Connections {
                                target: typeof Config !== "undefined" ? Config : null
                                enabled: root.visible
                                ignoreUnknownSignals: true
                                function onSettingsLoaded() {
                                    nightLightBtn.updateState();
                                }
                            }

                            Connections {
                                target: typeof BlueLight !== "undefined" ? BlueLight : null
                                enabled: root.visible
                                ignoreUnknownSignals: true
                                function onSettingsChanged() {
                                    nightLightBtn.updateState();
                                }
                            }

                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                let target = !nightLightBtn.isActive;
                                nightLightBtn.isActive = target;

                                let monNames = [];
                                let ds = typeof Config !== "undefined" ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
                                let mons = (ds && ds.monitors) ? ds.monitors : {};
                                for (let m in mons) {
                                    if (monNames.indexOf(m) === -1) {
                                        monNames.push(m);
                                    }
                                }
                                if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                                    for (let i = 0; i < Quickshell.screens.length; i++) {
                                        let scr = Quickshell.screens[i];
                                        if (scr && scr.name && monNames.indexOf(scr.name) === -1) {
                                            monNames.push(scr.name);
                                        }
                                    }
                                }

                                if (monNames.length > 0) {
                                    for (let i = 0; i < monNames.length; i++) {
                                        BlueLight.setEnabled(monNames[i], target);
                                    }
                                } else {
                                    BlueLight.setEnabled("", target);
                                }
                                nightLightBtn.updateState();
                            }

                            onRightClicked: {
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "guide", "display"]);
                            }
                        }

                        QuickActionBtn {
                            id: coffeeBtn
                            activeColor: Qt.tint(ThemeBackend.peach, "#5c3016")

                            readonly property string stateFilePath: Caching.runDir + "/caffeine_state.json"
                            property double coffeeStartTime: 0
                            property double coffeeEndTime: 0
                            property int remainingSeconds: 0

                            readonly property string remainingTimeString: {
                                let secs = remainingSeconds;
                                if (secs <= 0) return "< 1m";
                                let h = Math.floor(secs / 3600);
                                let m = Math.floor((secs % 3600) / 60);
                                if (h > 0) {
                                    return h + "h " + (m < 10 ? "0" + m : m) + "m";
                                }
                                return Math.max(1, m) + "m";
                            }

                            iconText: (isActive && isHovered) ? remainingTimeString : "󰅶"
                            customFontSize: (isActive && isHovered) ? root.s(12) : 0
                            customFontFamily: (isActive && isHovered) ? ThemeBackend.fontFamily : ""

                            function updateRemaining() {
                                if (!isActive || coffeeEndTime <= 0) {
                                    remainingSeconds = 0;
                                    return;
                                }
                                let now = Date.now();
                                let diff = Math.round((coffeeEndTime - now) / 1000);
                                if (diff <= 0) {
                                    remainingSeconds = 0;
                                    disableCaffeine();
                                } else {
                                    remainingSeconds = diff;
                                }
                            }

                            function saveState() {
                                let data = {
                                    "enabled": isActive,
                                    "startTime": coffeeStartTime,
                                    "enabledAt": coffeeStartTime > 0 ? new Date(coffeeStartTime).toISOString() : "",
                                    "endTime": coffeeEndTime,
                                    "durationSeconds": (coffeeEndTime > coffeeStartTime) ? Math.round((coffeeEndTime - coffeeStartTime) / 1000) : 0
                                };
                                let jsonStr = JSON.stringify(data);
                                Quickshell.execDetached(["sh", "-c", "mkdir -p '" + Caching.runDir + "' && echo '" + jsonStr + "' > '" + stateFilePath + "'"]);
                            }

                            function syncConfig(enabled) {
                                if (typeof Config === "undefined") return;
                                let idleObj = Object.assign({}, Config.getSetting("idle", {}));
                                idleObj.manualInhibit = enabled;
                                idleObj.caffeineStartTime = enabled ? coffeeStartTime : 0;
                                idleObj.caffeineEndTime = enabled ? coffeeEndTime : 0;
                                Config.setSetting("idle", idleObj);
                            }

                            function enableCaffeine(durationMs) {
                                let now = Date.now();
                                coffeeStartTime = now;
                                coffeeEndTime = now + durationMs;
                                isActive = true;
                                updateRemaining();
                                saveState();
                                syncConfig(true);
                            }

                            function increaseCaffeine(addMs) {
                                let now = Date.now();
                                if (!isActive || coffeeEndTime <= now) {
                                    enableCaffeine(addMs);
                                } else {
                                    coffeeEndTime += addMs;
                                    updateRemaining();
                                    saveState();
                                    syncConfig(true);
                                }
                            }

                            function disableCaffeine() {
                                isActive = false;
                                coffeeStartTime = 0;
                                coffeeEndTime = 0;
                                remainingSeconds = 0;
                                saveState();
                                syncConfig(false);
                            }

                            function applyLoadedState(rawText) {
                                if (!rawText || rawText.trim() === "") return;
                                try {
                                    let data = JSON.parse(rawText.trim());
                                    if (data && data.enabled && data.endTime) {
                                        let now = Date.now();
                                        if (now < data.endTime) {
                                            coffeeStartTime = data.startTime || now;
                                            coffeeEndTime = data.endTime;
                                            isActive = true;
                                            updateRemaining();
                                            syncConfig(true);
                                            return;
                                        }
                                    }
                                } catch (e) {}

                                if (isActive) {
                                    disableCaffeine();
                                }
                            }

                            function updateState() {
                                let now = Date.now();
                                if (typeof Config !== "undefined") {
                                    let idleObj = Config.getSetting("idle", {"manualInhibit": false});
                                    if (idleObj && idleObj.manualInhibit && idleObj.caffeineEndTime && idleObj.caffeineEndTime > now) {
                                        coffeeStartTime = idleObj.caffeineStartTime || now;
                                        coffeeEndTime = idleObj.caffeineEndTime;
                                        isActive = true;
                                        updateRemaining();
                                    } else if (idleObj && !idleObj.manualInhibit) {
                                        isActive = false;
                                        coffeeEndTime = 0;
                                        coffeeStartTime = 0;
                                        remainingSeconds = 0;
                                    }
                                }
                                coffeeStateReader.running = true;
                            }

                            Process {
                                id: coffeeStateReader
                                command: ["sh", "-c", "cat '" + coffeeBtn.stateFilePath + "' 2>/dev/null || true"]
                                running: false
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        coffeeBtn.applyLoadedState(this.text.trim());
                                    }
                                }
                            }

                            Timer {
                                id: coffeeTicker
                                interval: root.visible ? 1000 : 15000
                                repeat: true
                                running: coffeeBtn.isActive
                                triggeredOnStart: true
                                onTriggered: {
                                    coffeeBtn.updateRemaining();
                                }
                            }

                            Component.onCompleted: updateState()

                            Connections {
                                target: typeof Config !== "undefined" ? Config : null
                                enabled: true
                                ignoreUnknownSignals: true
                                function onSettingsLoaded() {
                                    coffeeBtn.updateState();
                                }
                            }

                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                if (isActive) {
                                    disableCaffeine();
                                } else {
                                    enableCaffeine(3600 * 1000);
                                }
                            }

                            onRightClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                increaseCaffeine(3600 * 1000);
                            }
                        }

                        QuickActionBtn {
                            iconText: isActive ? "󰤨" : "󰤮"
                            activeColor: ThemeBackend.blue
                            isActive: root.wifiRadioEnabled
                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                            }
                            onRightClicked: {
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "network", "wifi"]);
                            }
                        }

                        QuickActionBtn {
                            iconText: isActive ? "󰂯" : "󰂲"
                            activeColor: ThemeBackend.mauve
                            isActive: root.btRadioEnabled
                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                if (Bluetooth.defaultAdapter) {
                                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                }
                            }
                            onRightClicked: {
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "network", "bt"]);
                            }
                        }

                        QuickActionBtn {
                            iconText: "󰀝"
                            activeColor: ThemeBackend.red
                            isActive: !root.wifiRadioEnabled && !root.btRadioEnabled
                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                let enableAirplane = !isActive;
                                if (enableAirplane) {
                                    root.btStateBeforeAirplane = root.btRadioEnabled;
                                    root.wifiStateBeforeAirplane = root.wifiRadioEnabled;
                                    Networking.wifiEnabled = false;
                                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                                } else {
                                    let restoreWifi = root.wifiStateBeforeAirplane;
                                    let restoreBt = root.btStateBeforeAirplane;
                                    if (!restoreWifi && !restoreBt) {
                                        restoreWifi = true;
                                    }
                                    Networking.wifiEnabled = restoreWifi;
                                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = restoreBt;
                                }
                            }
                        }
                    }
                }

                NotificationBox {
                    id: notifsBox
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.s(68)
                    cornerRadius: root.boxRadius
                    cardRadius: root.cardRadius
                    baseColor: Qt.darker(ThemeBackend.surface0, 1.04)
                    rootContext: root
                    opacity: root.introNotifs
                    transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introNotifs) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(73)
                    Layout.maximumHeight: root.s(73)
                    spacing: root.s(6)

                    Repeater {
                        model: ListModel {
                            ListElement { cmd: "lock"; icon: ""; weight: 1.0 }
                            ListElement { cmd: "sleep"; icon: "ᶻ 𝗓 𝗓"; weight: 1.0 }
                            ListElement { cmd: "hibernate"; icon: "󰤄"; weight: 1.5 }
                            ListElement { cmd: "reboot"; icon: "󰑓"; weight: 2.5 }
                            ListElement { cmd: "poweroff"; icon: ""; weight: 3.5 }
                        }

                        delegate: Rectangle {
                            id: actionCapsule
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: root.boxRadius
                            clip: true

                            property bool isHibernate: cmd === "hibernate"
                            property bool isDisabled: isHibernate && !root.canHibernate
                            property bool showError: false
                            property int chargingSoundHandle: -1

                            opacity: root.introActions
                            transform: [
                                Translate { id: shakeTranslate; x: 0 },
                                Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introActions) }
                            ]

                            color: (actionMa.containsMouse && !isDisabled) ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04)
                            Behavior on color {
                                enabled: root.visible
                                ColorAnimation { duration: 200 }
                            }

                            scale: (actionMa.pressed && !isDisabled) ? (0.98 - (0.01 * weight)) : ((actionMa.containsMouse && !isDisabled) ? 1.02 : 1.0)
                            Behavior on scale {
                                enabled: root.visible
                                NumberAnimation { duration: 400; easing.type: Easing.OutQuart }
                            }

                            property real fillLevel: 0.0
                            property bool triggered: false
                            property real flashOpacity: 0.0

                            Connections {
                                target: root
                                function onVisibleChanged() {
                                    if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                        Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    actionCapsule.fillLevel = 0.0;
                                    actionCapsule.triggered = false;
                                    actionCapsule.flashOpacity = 0.0;
                                    fillAnim.stop();
                                    drainAnim.stop();
                                }
                            }

                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shakeTranslate; property: "x"; to: -root.s(3); duration: 50 }
                                NumberAnimation { target: shakeTranslate; property: "x"; to: root.s(3); duration: 50 }
                                NumberAnimation { target: shakeTranslate; property: "x"; to: -root.s(3); duration: 50 }
                                NumberAnimation { target: shakeTranslate; property: "x"; to: root.s(3); duration: 50 }
                                NumberAnimation { target: shakeTranslate; property: "x"; to: 0; duration: 50 }
                                onStarted: actionCapsule.showError = true
                                onStopped: actionCapsule.showError = false
                            }

                            function triggerError() {
                                shakeAnim.stop();
                                shakeAnim.start();
                            }

                            FluidWave {
                                id: actionWaveCanvas
                                anchors.fill: parent
                                visible: root.visible && actionCapsule.fillLevel > 0.001

                                property real wavePhase: 0.0
                                NumberAnimation on wavePhase {
                                    running: root.visible && actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                                    loops: Animation.Infinite
                                    from: 0; to: Math.PI * 2; duration: 800
                                }

                                radius: actionCapsule.radius
                                fillLevel: actionCapsule.fillLevel
                                waveAmp: actionCapsule.fillLevel < 0.99 ? (root.s(10) * Math.sin(actionCapsule.fillLevel * Math.PI)) : 0
                                phase: wavePhase
                                vertical: 1.0
                                color1: (cmd === "poweroff" || cmd === "hibernate" ? ThemeBackend.red : ThemeBackend.blue)
                                color2: color1
                            }

                            Rectangle {
                                anchors.fill: parent; radius: actionCapsule.radius; color: "#ffffff"
                                opacity: actionCapsule.flashOpacity
                                PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: ThemeBackend.red
                                opacity: actionCapsule.showError ? 0.15 : 0.0
                                radius: actionCapsule.radius
                                Behavior on opacity {
                                    enabled: root.visible
                                    NumberAnimation { duration: 200 }
                                }
                                z: 4
                            }

                            Text {
                                anchors.centerIn: parent
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(19)
                                color: isDisabled ? ThemeBackend.surface2 : (actionMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                text: icon
                                Behavior on color {
                                    enabled: root.visible
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            Item {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: actionCapsule.height * actionCapsule.fillLevel
                                clip: true

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(19)
                                    color: ThemeBackend.crust
                                    text: icon
                                }
                            }

                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: isDisabled ? Qt.ForbiddenCursor : (actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor)

                                onPressed: {
                                    if (isDisabled) {
                                        actionCapsule.triggerError();
                                        Quickshell.execDetached([
                                            "notify-send",
                                            "-a", I18n.t("syspanel.actions.system_name"),
                                            "-u", "normal",
                                            "-i", "dialog-warning",
                                            I18n.t("syspanel.actions.hibernate_error_title"),
                                            I18n.t("syspanel.actions.hibernate_error_body")
                                        ]);
                                    } else if (!actionCapsule.triggered) {
                                        if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                            Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                            actionCapsule.chargingSoundHandle = -1;
                                        }
                                        if (typeof Sounds !== "undefined") {
                                            actionCapsule.chargingSoundHandle = Sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                                        }
                                        drainAnim.stop();
                                        fillAnim.start();
                                    }
                                }
                                onReleased: {
                                    if (!isDisabled && !actionCapsule.triggered && actionCapsule.fillLevel < 1.0) {
                                        if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                            Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                            actionCapsule.chargingSoundHandle = -1;
                                        }
                                        fillAnim.stop();
                                        drainAnim.start();
                                    }
                                }
                                onCanceled: {
                                    if (!isDisabled && !actionCapsule.triggered) {
                                        if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                            Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                            actionCapsule.chargingSoundHandle = -1;
                                        }
                                        fillAnim.stop();
                                        drainAnim.start();
                                    }
                                }
                            }

                            NumberAnimation {
                                id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                duration: (550 * weight) * (1.0 - actionCapsule.fillLevel); easing.type: Easing.InSine
                                onFinished: {
                                    actionCapsule.triggered = true;
                                    actionCapsule.flashOpacity = 0.6;
                                    if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                        Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    if (typeof Sounds !== "undefined") {
                                        Sounds.playSfx("reusables/fillbutton/button.wav");
                                    }
                                    cardFlashAnim.start();
                                    drainAnim.start();
                                    closeSequence.start();
                                    exitTimer.start();
                                }
                            }

                            NumberAnimation {
                                id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                duration: 1500 * actionCapsule.fillLevel; easing.type: Easing.OutQuad
                            }

                            Timer {
                                id: exitTimer; interval: 500
                                onTriggered: {
                                    if (actionCapsule.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                                        Sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    let scriptPath = cmd === "lock" ? Caching.serpantinumDir + "/scripts/lock.sh" : Caching.serpantinumDir + "/scripts/system/" + (cmd === "sleep" ? "suspend.sh" : cmd + ".sh");
                                    Quickshell.execDetached(["bash", scriptPath]);
                                    Quickshell.execDetached(["sh", "-c", "echo 'close' > " + Caching.runDir + "/widget_state"]);

                                    actionCapsule.fillLevel = 0.0;
                                    actionCapsule.triggered = false;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: batteryBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.isDesktop ? root.s(52) : root.s(72)
                    Layout.maximumHeight: Layout.preferredHeight
                    radius: root.isDesktop ? root.s(15) : root.boxRadius
                    color: root.isDesktop ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04)
                    clip: true
                    opacity: root.introCore
                    transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introCore) }

                    property real fillLevel: root.animCapacity / 100
                    property real maxWaveAmp: root.isCharging ? root.s(10) : root.s(6.5)
                    property real waveAmp: (fillLevel < 0.99 && fillLevel > 0.01) ? maxWaveAmp * Math.sin(fillLevel * Math.PI) : 0

                    FluidWave {
                        id: waveCanvas
                        anchors.fill: parent
                        visible: root.visible && !root.isDesktop && batteryBox.fillLevel > 0.001

                        property real wavePhase: 0.0
                        NumberAnimation on wavePhase {
                            running: root.visible && !root.isDesktop && batteryBox.fillLevel > 0.0 && batteryBox.fillLevel < 1.0
                            loops: Animation.Infinite
                            from: 0; to: Math.PI * 2; duration: root.isCharging ? 1200 : 2200
                        }

                        radius: batteryBox.radius
                        fillLevel: batteryBox.fillLevel
                        waveAmp: (batteryBox.fillLevel < 0.99 && batteryBox.waveAmp > 0) ? Math.min(batteryBox.waveAmp, Math.min(width * batteryBox.fillLevel, width * (1.0 - batteryBox.fillLevel))) : 0
                        phase: wavePhase
                        vertical: 0.0
                        color1: root.batColorFlat
                        color2: root.batColorFlat
                    }

                    BatteryContent {
                        anchors.fill: parent
                        contentTextColor: ThemeBackend.text
                        iconColor: root.batColorFlat
                        visible: !root.isDesktop
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        visible: !root.isDesktop

                        property real phaseOffset: Math.sin(waveCanvas.wavePhase) - Math.cos(waveCanvas.wavePhase)
                        property real centerOffset: batteryBox.fillLevel > 0.01 && batteryBox.fillLevel < 0.99 ? 0.375 * batteryBox.waveAmp * phaseOffset : 0

                        width: Math.max(0, Math.min(parent.width, (parent.width * batteryBox.fillLevel) + centerOffset))
                        clip: true

                        BatteryContent {
                            width: batteryBox.width
                            height: batteryBox.height
                            contentTextColor: ThemeBackend.crust
                            iconColor: ThemeBackend.crust
                        }
                    }

                    Item {
                        id: profileSwitchWrapper
                        anchors.fill: root.isDesktop ? parent : undefined
                        anchors.right: root.isDesktop ? undefined : parent.right
                        anchors.verticalCenter: root.isDesktop ? undefined : parent.verticalCenter
                        anchors.rightMargin: root.isDesktop ? 0 : root.s(12)
                        implicitWidth: root.isDesktop ? parent.width : profileSwitch.implicitWidth
                        implicitHeight: profileSwitch.implicitHeight

                        Rectangle {
                            id: profileSwitchShadow
                            visible: !root.isDesktop
                            anchors.fill: parent
                            anchors.topMargin: root.s(1.5)
                            anchors.bottomMargin: -root.s(1.5)
                            radius: profileSwitch.cornerRadius
                            color: Qt.rgba(0, 0, 0, 0.25)
                        }

                        Switch {
                            id: profileSwitch
                            anchors.fill: parent
                            implicitWidth: root.isDesktop ? parent.width : (PowerProfiles.hasPerformanceProfile ? root.s(240) : root.s(162))
                            implicitHeight: root.isDesktop ? root.s(48) : root.s(52)
                            cornerRadius: root.s(15)
                            fontPixelSize: root.isDesktop ? root.s(14) : root.s(22)
                            options: {
                                if (root.isDesktop) {
                                    return PowerProfiles.hasPerformanceProfile
                                        ? ["󰌪 " + I18n.t("syspanel.profiles.power_saver"), "󰗑 " + I18n.t("syspanel.profiles.balanced"), "󰓅 " + I18n.t("syspanel.profiles.performance")]
                                        : ["󰌪 " + I18n.t("syspanel.profiles.power_saver"), "󰗑 " + I18n.t("syspanel.profiles.balanced")];
                                } else {
                                    return PowerProfiles.hasPerformanceProfile
                                        ? ["󰌪", "󰗑", "󰓅"]
                                        : ["󰌪", "󰗑"];
                                }
                            }
                            accentColor: root.profileColor
                            baseColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            activeTextColor: ThemeBackend.crust
                            currentIndex: {
                                if (PowerProfiles.hasPerformanceProfile) {
                                    if (root.powerProfile === "power-saver") return 0;
                                    if (root.powerProfile === "balanced") return 1;
                                    return 2;
                                } else {
                                    if (root.powerProfile === "power-saver") return 0;
                                    return 1;
                                }
                            }

                            onValueChanged: (idx, val) => {
                                if (PowerProfiles.hasPerformanceProfile) {
                                    if (idx === 0) PowerProfiles.profile = PowerProfile.PowerSaver;
                                    else if (idx === 1) PowerProfiles.profile = PowerProfile.Balanced;
                                    else PowerProfiles.profile = PowerProfile.Performance;
                                } else {
                                    if (idx === 0) PowerProfiles.profile = PowerProfile.PowerSaver;
                                    else PowerProfiles.profile = PowerProfile.Balanced;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
