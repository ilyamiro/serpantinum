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
import "../mc"

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
        if (root.visible && slidersBox.volumeSlider && !root.isDraggingVol && slidersBox.volumeSlider.value !== sysVolume) {
            slidersBox.volumeSlider.value = sysVolume;
        }
    }

    onSysBrightnessChanged: {
        if (root.visible && slidersBox.brightnessSlider && !root.isDraggingBri && slidersBox.brightnessSlider.value !== sysBrightness) {
            slidersBox.brightnessSlider.value = sysBrightness;
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

            if (slidersBox.volumeSlider && !root.isDraggingVol) {
                slidersBox.volumeSlider.value = root.sysVolume;
            }

            if (slidersBox.brightnessSlider && !root.isDraggingBri) {
                slidersBox.brightnessSlider.value = root.sysBrightness;
            }

            if (quickActionsBox.nightLight) quickActionsBox.nightLight.updateState();
            if (quickActionsBox.coffee) quickActionsBox.coffee.updateState();

            briPollerTimer.interval = 150;
            briPollerTimer.restart();
        } else {
            briPollerTimer.stop();
            briPoller.running = false;
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        hibernateCheck.running = true;
        if (visible) {
            NotificationManager.sysPanelOpen = true;
            if (quickActionsBox.nightLight) quickActionsBox.nightLight.updateState();
            if (quickActionsBox.coffee) quickActionsBox.coffee.updateState();
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

    property alias closeAnim: closeSequence

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

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: "#151515"
        radius: 0
        border.width: 0
        clip: true
        opacity: root.introContent
        transform: Translate { x: (root.isLeftAnchored ? -root.slideDistance : root.slideDistance) * (1.0 - root.introContent) }

        McPanel {
            anchors.fill: parent
            bevel: Math.max(2, Math.round(root.s(3)))
            fill: "#151515"
            light: "#3a3a3a"
            dark: "#070707"
        }

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
                    radius: 0
                    color: "transparent"
                    opacity: root.introTop

                    McPanel {
                        anchors.fill: parent
                        fill: "#2a2a2a"
                        light: "#4e4e4e"
                        dark: "#101010"
                    }
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
                            mcStyle: true
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

                SystemPanelSliders {
                    id: slidersBox
                    panel: root
                }

                SystemPanelQuickActions {
                    id: quickActionsBox
                    panel: root
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

                SystemPanelPowerActions {
                    panel: root
                }

                Rectangle {
                    id: batteryBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.isDesktop ? root.s(52) : root.s(72)
                    Layout.maximumHeight: Layout.preferredHeight
                    radius: 0
                    color: "transparent"
                    clip: true

                    McPanel {
                        anchors.fill: parent
                        visible: !root.isDesktop
                        fill: "#2a2a2a"
                        light: "#4e4e4e"
                        dark: "#101010"
                    }
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
                        // Durability colors: green, then yellow, then red as it drains.
                        color1: root.batCapacity > 50 ? "#3faf3f" : (root.batCapacity > 20 ? "#d8b020" : "#d03030")
                        color2: root.batCapacity > 50 ? "#2f8f2f" : (root.batCapacity > 20 ? "#b08a10" : "#a02020")
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
                            contentTextColor: "#ffffff"
                            iconColor: "#ffffff"
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

                        // Power profiles as stone buttons; the active one gets the white hotbar frame.
                        Item {
                            id: profileSwitch
                            anchors.fill: parent
                            property real spacing: root.s(4)
                            implicitWidth: root.isDesktop ? parent.width : (PowerProfiles.hasPerformanceProfile ? root.s(240) : root.s(162))
                            implicitHeight: root.isDesktop ? root.s(48) : root.s(52)
                            property real cornerRadius: 0
                            readonly property var profiles: PowerProfiles.hasPerformanceProfile
                                ? [["󰌪", "power-saver", I18n.t("syspanel.profiles.power_saver")], ["󰗑", "balanced", I18n.t("syspanel.profiles.balanced")], ["󰓅", "performance", I18n.t("syspanel.profiles.performance")]]
                                : [["󰌪", "power-saver", I18n.t("syspanel.profiles.power_saver")], ["󰗑", "balanced", I18n.t("syspanel.profiles.balanced")]]

                            Repeater {
                                model: profileSwitch.profiles
                                McButton {
                                    x: index * (width + profileSwitch.spacing)
                                    width: (profileSwitch.width - profileSwitch.spacing * (profileSwitch.profiles.length - 1)) / profileSwitch.profiles.length
                                    height: profileSwitch.height
                                    bevel: 2
                                    icon: modelData[0]
                                    label: root.isDesktop ? modelData[2] : ""
                                    iconSize: root.isDesktop ? root.s(14) : root.s(20)
                                    fontSize: root.s(12)
                                    selected: root.powerProfile === modelData[1]
                                    onClicked: {
                                        if (modelData[1] === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
                                        else if (modelData[1] === "balanced") PowerProfiles.profile = PowerProfile.Balanced;
                                        else PowerProfiles.profile = PowerProfile.Performance;
                                    }
                                }
                            }
                        }

                        Item {
                            visible: false
                            implicitWidth: 0
                            implicitHeight: 0
                            property real fontPixelSize: 0
                        }
                    }
                }
            }
        }
    }

    // Steve falls in from an End portal and hangs out on the battery card.
    SteveVisitor {
        anchors.fill: parent
        z: 100
        active: root.visible
        style: "end"
        target: batteryBox
        homeFrac: 0.3
        px: Math.max(3, Math.round(Scaler.s(3)))
        tired: !root.isDesktop && root.batCapacity <= 20 && !root.isCharging
        phrases: ["Привіт!", "Батарея — мій дім", "Не вимикай мене!", "Що робимо?", "Кріпер позаду!", "Ой!"]
        onArrivedSignal: {
            if (root.isCharging) say("Заряджаюсь ⚡");
            else if (tired) say("Їсти хочу... " + root.batCapacity + "%");
            else say("Привіт, " + (typeof SystemInfo !== "undefined" && SystemInfo.username ? SystemInfo.username : "друже") + "!");
        }
    }
}
