import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import "../"
import "../reusables"

Item {
    required property var window
    anchors.fill: parent
    z: 100

    Switch {
        id: bottomSwitch
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: window.s(18)
        implicitWidth: window.s(320)
        implicitHeight: window.s(42)
        opacity: window.easeOut(window.animWin(window.introState, 0.25, 0.50))
        scale: 0.9 + 0.1 * window.easeBack(window.animWin(window.introState, 0.25, 0.50))
        transform: Translate { y: (1 - window.easeOut(window.animWin(window.introState, 0.25, 0.50))) * window.s(26) }
        fontPixelSize: window.s(14)
        cornerRadius: ThemeBackend.borderRadius
        accentColor: window.activeColor
        baseColor: "#1affffff"
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        switchSound: "network/switch.wav"
        visible: window.visible && availableModes.length > 0
        enabled: window.visible
    
        readonly property var availableModes: {
            let m = [];
            if (window.ethPresent) m.push({ mode: "eth", label: "󰈀  " + (I18n.t("network.tabs.ethernet") || "Ethernet") });
            if (window.wifiPresent) m.push({ mode: "wifi", label: "󰤨  " + (I18n.t("network.tabs.wifi") || "Wi-Fi") });
            if (window.btPresent) m.push({ mode: "bt", label: "󰂯 " + (I18n.t("network.tabs.bluetooth") || "Bluetooth") });
            return m;
        }
    
        options: {
            let opts = [];
            for (let i = 0; i < availableModes.length; i++) {
                if (availableModes[i] && availableModes[i].label) {
                    opts.push(availableModes[i].label);
                }
            }
            return opts;
        }
    
        Binding on currentIndex {
            value: {
                let modes = bottomSwitch.availableModes;
                for (let i = 0; i < modes.length; i++) {
                    if (modes[i] && modes[i].mode === window.activeMode) return i;
                }
                return 0;
            }
        }
    
        onToggled: val => {
            if (window.pendingWifiId !== "") { window.pendingWifiId = ""; window.pendingWifiSsid = ""; }
            let modes = bottomSwitch.availableModes;
            if (!modes || modes.length === 0) return;
            let chosen = "";
            if (typeof val === "number") {
                if (val >= 0 && val < modes.length && modes[val]) {
                    chosen = modes[val].mode;
                }
            } else if (typeof val === "string") {
                for (let i = 0; i < modes.length; i++) {
                    if (modes[i] && (modes[i].label === val || modes[i].mode === val)) {
                        chosen = modes[i].mode;
                        break;
                    }
                }
            }
            if (chosen && chosen !== "" && window.activeMode !== chosen) {
                window.powerAnimAllowed = false;
                window.powerAnimBlockerTimer.restart();
                window.activeMode = chosen;
            }
        }
    }
    
    Item {
        id: powerToggleContainer
        z: 100
    
        property real pwrIntroProg: window.easeOut(window.animWin(window.introState, 0.10, 0.35))
        opacity: pwrIntroProg
        scale: window.easeBack(window.animWin(window.introState, 0.10, 0.35))
    
        property real pwrMorph: window.currentPower ? 1.0 : 0.0
        Behavior on pwrMorph {
            enabled: window.powerAnimAllowed && window.visible;
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuint }
        }
    
        width: window.s(140) + (window.s(42) - window.s(140)) * pwrMorph
        height: width
    
        x: ((parent.width / 2) - window.s(70)) + ((parent.width - window.s(24) - window.s(42)) - ((parent.width / 2) - window.s(70))) * pwrMorph
        y: (((parent.height - window.s(65)) / 2) - window.s(70)) + ((parent.height - window.s(24) - window.s(42)) - (((parent.height - window.s(65)) / 2) - window.s(70))) * pwrMorph
    
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: window.s(2)
            anchors.bottomMargin: -window.s(2)
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.16)
            z: -1
        }
    
        Rectangle {
            id: powerBtnRect
            anchors.fill: parent
            radius: width / 2
    
            scale: pwrMa.pressed ? 0.95 : (pwrMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    
            color: window.currentPower ? "transparent" : (pwrMa.containsMouse ? Qt.lighter(ThemeBackend.base, 1.6) : Qt.lighter(ThemeBackend.base, 1.3))
            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
    
            border.color: window.currentPowerPending ? window.activeColor : (window.currentPower ? "transparent" : (pwrMa.containsMouse ? Qt.lighter(ThemeBackend.base, 1.45) : Qt.lighter(ThemeBackend.base, 1.25)))
            border.width: 1
            Behavior on border.color { enabled: window.powerAnimAllowed && window.visible; ColorAnimation { duration: 800; easing.type: Easing.InOutQuint } }
    
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: window.currentPower ? 1.0 : 0.0
                Behavior on opacity { enabled: window.powerAnimAllowed && window.visible; NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.lighter(window.activeColor, 1.15) }
                    GradientStop { position: 1.0; color: window.activeColor }
                }
            }
    
            Text {
                id: pwrIcon
                anchors.centerIn: parent
                font.family: ThemeBackend.fontFamily
                font.pixelSize: window.s(54)
                scale: 1.0 + ((20.0 / 54.0) - 1.0) * powerToggleContainer.pwrMorph
                color: window.currentPower ? ThemeBackend.crust : ThemeBackend.subtext0
                text: window.currentPowerPending ? "󰑮" : ""
                Behavior on color { enabled: window.powerAnimAllowed && window.visible; ColorAnimation { duration: 800; easing.type: Easing.InOutQuint } }
    
                RotationAnimation {
                    target: pwrIcon
                    property: "rotation"
                    from: 0; to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: window.visible && window.currentPowerPending
                    onRunningChanged: {
                        if (!running) pwrIcon.rotation = 0;
                    }
                }
            }
    
            MouseArea {
                id: pwrMa
                anchors.fill: parent
                enabled: window.visible
                hoverEnabled: window.visible
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (window.pendingWifiId !== "") { window.pendingWifiId = ""; window.pendingWifiSsid = ""; }
    
                    if (window.activeMode === "eth") {
                        if (window.ethPowerPending) return;
                        window.expectedEthPower = window.ethPower === "on" ? "off" : "on";
                        window.ethPowerPending = true;
                        window.powerMinSpinTimerRef.restart();
                        if (window.expectedEthPower === "on") Sounds.playSfx("network/power_on.wav"); else Sounds.playSfx("network/power_off.wav");
                        window.ethPendingResetTimer.restart();
                        window.ethPower = window.expectedEthPower;
                        if (window.expectedEthPower === "off") {
                            if (window.ethDevice) window.ethDevice.disconnect();
                        } else {
                            if (window.ethDevice && window.ethDevice.network) window.ethDevice.network.connect();
                        }
                    } else if (window.activeMode === "wifi") {
                        if (window.wifiPowerPending) return;
                        window.expectedWifiPower = window.wifiPower === "on" ? "off" : "on";
                        window.wifiPowerPending = true;
                        window.powerMinSpinTimerRef.restart();
                        if (window.expectedWifiPower === "on") Sounds.playSfx("network/power_on.wav"); else Sounds.playSfx("network/power_off.wav");
                        window.wifiPendingResetTimer.restart();
                        window.wifiPower = window.expectedWifiPower;
                        Networking.wifiEnabled = (window.expectedWifiPower === "on");
                        if (window.expectedWifiPower === "on") window.startWifiScan(); else window.stopWifiScan();
                    } else {
                        if (window.btPowerPending) return;
                        window.expectedBtPower = window.btPower === "on" ? "off" : "on";
                        window.btPowerPending = true;
                        window.powerMinSpinTimerRef.restart();
                        if (window.expectedBtPower === "on") Sounds.playSfx("network/power_on.wav"); else Sounds.playSfx("network/power_off.wav");
                        window.btPendingResetTimer.restart();
                        window.btPower = window.expectedBtPower;
                        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = (window.expectedBtPower === "on");
                    }
                }
            }
        }
    }
}
