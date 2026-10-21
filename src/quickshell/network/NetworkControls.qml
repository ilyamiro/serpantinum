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
import "../mc"

Item {
    required property var window
    anchors.fill: parent
    z: 100

    // Minecraft-style tab buttons (replaces the shared Switch, which can't take the pixel font).
    Row {
        id: bottomSwitch
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: window.s(18)
        spacing: window.s(6)
        height: window.s(36)
        opacity: window.easeOut(window.animWin(window.introState, 0.25, 0.50))
        scale: 0.9 + 0.1 * window.easeBack(window.animWin(window.introState, 0.25, 0.50))
        transform: Translate { y: (1 - window.easeOut(window.animWin(window.introState, 0.25, 0.50))) * window.s(26) }
        visible: window.visible && availableModes.length > 0
        enabled: window.visible
    
        readonly property var availableModes: {
            let m = [];
            if (window.ethPresent) m.push({ mode: "eth", icon: "󰈀", label: (I18n.t("network.tabs.ethernet") || "Ethernet") });
            if (window.wifiPresent) m.push({ mode: "wifi", icon: "󰤨", label: (I18n.t("network.tabs.wifi") || "Wi-Fi") });
            if (window.btPresent) m.push({ mode: "bt", icon: "󰂯", label: (I18n.t("network.tabs.bluetooth") || "Bluetooth") });
            return m;
        }
    
        Repeater {
            model: bottomSwitch.availableModes
            McButton {
                height: bottomSwitch.height
                width: Math.max(window.s(104), implicitWidth)
                horizontalPadding: window.s(12)
                bevel: Math.max(2, Math.round(window.s(2)))
                icon: modelData.icon
                label: modelData.label
                fontSize: window.s(12)
                iconSize: window.s(14)
                selected: modelData.mode === window.activeMode
                onClicked: bottomSwitch.choose(index)
            }
        }

        function choose(val) {
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
            anchors.topMargin: window.s(3)
            anchors.bottomMargin: -window.s(3)
            radius: 0
            color: Qt.rgba(0, 0, 0, 0.3)
            z: -1
        }
    
        Rectangle {
            id: powerBtnRect
            anchors.fill: parent
            radius: 0
    
            scale: pwrMa.pressed ? 0.95 : (pwrMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    
            color: window.currentPower ? "transparent" : (pwrMa.containsMouse ? "#6e6e6e" : "#575757")
            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
    
            border.color: pwrMa.containsMouse || window.currentPowerPending ? "#ffffff" : "#000000"
            border.width: pwrMa.containsMouse ? 2 : 1
            Behavior on border.color { enabled: window.powerAnimAllowed && window.visible; ColorAnimation { duration: 800; easing.type: Easing.InOutQuint } }
    
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 0
                opacity: window.currentPower ? 1.0 : 0.0
                Behavior on opacity { enabled: window.powerAnimAllowed && window.visible; NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }
                color: pwrMa.containsMouse ? "#3fa83f" : "#2f8f2f"
            }

            // Stone bevel on top of either state.
            Item {
                anchors.fill: parent
                anchors.margins: 1
                readonly property int b: Math.max(2, Math.round(parent.width / 18))
                Rectangle { x: 0; y: 0; width: parent.width; height: parent.b; color: Qt.rgba(1, 1, 1, 0.3) }
                Rectangle { x: 0; y: 0; width: parent.b; height: parent.height; color: Qt.rgba(1, 1, 1, 0.3) }
                Rectangle { x: 0; y: parent.height - parent.b; width: parent.width; height: parent.b; color: Qt.rgba(0, 0, 0, 0.45) }
                Rectangle { x: parent.width - parent.b; y: 0; width: parent.b; height: parent.height; color: Qt.rgba(0, 0, 0, 0.45) }
            }
    
            Text {
                id: pwrIcon
                anchors.centerIn: parent
                font.family: ThemeBackend.fontFamily
                font.pixelSize: window.s(54)
                scale: 1.0 + ((20.0 / 54.0) - 1.0) * powerToggleContainer.pwrMorph
                color: window.currentPower ? "#ffffff" : "#d0d0d0"
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
