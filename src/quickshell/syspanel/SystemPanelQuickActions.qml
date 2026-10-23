import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    required property var panel
    property alias nightLight: nightLightBtn
    property alias coffee: coffeeBtn

    component QuickActionBtn : Rectangle {
        id: qaBtn
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: view.panel.cardRadius

        property bool isActive: false
        property string iconText: ""
        property color activeColor: ThemeBackend.blue
        readonly property bool isHovered: qaMa.containsMouse
        property real customFontSize: 0
        property string customFontFamily: ""

        property real togglePulse: 0.0

        onIsActiveChanged: {
            if (qaGlass.active) togglePulseAnim.restart();
        }

        SequentialAnimation {
            id: togglePulseAnim
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 0.0; duration: 560; easing.type: Easing.OutCubic }
        }

        signal leftClicked()
        signal rightClicked()

        color: qaGlass.active ? "transparent" : (isActive ? activeColor : ThemeBackend.faded(qaMa.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04)))

        GlassFill {
            id: qaGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: qaBtn.isActive ? qaBtn.activeColor : (qaMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
            tintAmount: qaBtn.isActive ? 0.6 : 0.3
            shadow: 1
            press: qaMa.pressed ? 1 : (qaMa.containsMouse ? 0.25 : 0)
            pulse: qaBtn.togglePulse
            Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on tintAmount { NumberAnimation { duration: 180 } }
        }
        Behavior on color {
            enabled: view.panel.visible
            ColorAnimation { duration: 150 }
        }

        scale: qaMa.pressed ? 0.95 : (qaMa.containsMouse ? 1.01 : 1.0)
        Behavior on scale {
            enabled: view.panel.visible
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        Text {
            anchors.centerIn: parent
            font.family: qaBtn.customFontFamily !== "" ? qaBtn.customFontFamily : ThemeBackend.iconFont
            font.pixelSize: qaBtn.customFontSize > 0 ? qaBtn.customFontSize : view.panel.s(18)
            font.weight: qaBtn.customFontSize > 0 ? Font.Bold : Font.Normal
            color: (qaBtn.isActive && !qaGlass.active) ? ThemeBackend.crust : ((qaBtn.isActive || qaMa.containsMouse) ? ThemeBackend.text : ThemeBackend.subtext0)
            text: qaBtn.iconText
            Behavior on color {
                enabled: view.panel.visible
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

    id: view
    z: 5
    Layout.fillWidth: true
    Layout.preferredHeight: view.panel.s(73)
    Layout.maximumHeight: view.panel.s(73)
    opacity: view.panel.introQuickActions
    transform: Translate { x: (view.panel.isLeftAnchored ? -view.panel.rowSlideDistance : view.panel.rowSlideDistance) * (1.0 - view.panel.introQuickActions) }

    RowLayout {
        anchors.fill: parent
        spacing: view.panel.s(6)

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
                enabled: view.panel.visible
                ignoreUnknownSignals: true
                function onSettingsLoaded() {
                    nightLightBtn.updateState();
                }
            }

            Connections {
                target: typeof BlueLight !== "undefined" ? BlueLight : null
                enabled: view.panel.visible
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
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "open", "settings", "display"]);
            }
        }

        QuickActionBtn {
            id: coffeeBtn
            activeColor: Qt.tint(ThemeBackend.peach, "#5c3016")

            property double coffeeStartTime: 0
            property double coffeeEndTime: 0
            property int remainingSeconds: 0

            readonly property string remainingTimeString: {
                if (isActive && coffeeEndTime <= 0) return "∞";
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
            customFontSize: (isActive && isHovered) ? view.panel.s(12) : 0
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
                syncConfig(true);
            }

            function increaseCaffeine(addMs) {
                let now = Date.now();
                if (!isActive || coffeeEndTime <= now) {
                    enableCaffeine(addMs);
                } else {
                    coffeeEndTime += addMs;
                    updateRemaining();
                    syncConfig(true);
                }
            }

            function disableCaffeine() {
                isActive = false;
                coffeeStartTime = 0;
                coffeeEndTime = 0;
                remainingSeconds = 0;
                syncConfig(false);
            }

            function updateState() {
                if (typeof Config === "undefined") return;
                let idleObj = Config.getSetting("idle", {}) || {};
                let endTime = Number(idleObj.caffeineEndTime) || 0;

                if (!idleObj.manualInhibit) {
                    isActive = false;
                    coffeeStartTime = 0;
                    coffeeEndTime = 0;
                    remainingSeconds = 0;
                } else if (endTime > 0 && endTime <= Date.now()) {
                    disableCaffeine();
                } else {
                    coffeeStartTime = Number(idleObj.caffeineStartTime) || 0;
                    coffeeEndTime = endTime;
                    isActive = true;
                    updateRemaining();
                }
            }

            Timer {
                id: coffeeTicker
                interval: view.panel.visible ? 1000 : 15000
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
            isActive: view.panel.wifiRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Networking.wifiEnabled = !Networking.wifiEnabled;
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "network", "wifi"]);
            }
        }

        QuickActionBtn {
            iconText: isActive ? "󰂯" : "󰂲"
            activeColor: ThemeBackend.mauve
            isActive: view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (Bluetooth.defaultAdapter) {
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                }
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "network", "bt"]);
            }
        }

        QuickActionBtn {
            iconText: "󰀝"
            activeColor: ThemeBackend.red
            isActive: !view.panel.wifiRadioEnabled && !view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let enableAirplane = !isActive;
                if (enableAirplane) {
                    view.panel.btStateBeforeAirplane = view.panel.btRadioEnabled;
                    view.panel.wifiStateBeforeAirplane = view.panel.wifiRadioEnabled;
                    Networking.wifiEnabled = false;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                } else {
                    let restoreWifi = view.panel.wifiStateBeforeAirplane;
                    let restoreBt = view.panel.btStateBeforeAirplane;
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
