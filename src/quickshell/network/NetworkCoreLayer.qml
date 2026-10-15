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
    property alias repeater: coreRepeater
    id: orbitContainer
    anchors.fill: parent
    anchors.bottomMargin: window.s(65)
    z: 1

    Repeater {
        id: coreRepeater
        model: 5

        delegate: Item {
            id: coreContainer

            property var myDevice: window.currentCores[index]

            property bool isPrimary: index === 0
            property bool hasDevice: myDevice !== null
            property bool isReallyActive: window.currentPower && (hasDevice || (isPrimary && window.activeCoreCount === 0))

            property real activeTransition: isReallyActive ? 1.0 : 0.0
            property real coreIntroStart: 0.10 + (window.coreVisualIndices[index] * 0.04)
            property real coreIntroProg: window.easeBack(window.animWin(window.introState, coreIntroStart, coreIntroStart + 0.22))

            Behavior on activeTransition {
                enabled: window.visible && window.introState >= 0.3;
                NumberAnimation { duration: 1400; easing.type: Easing.OutExpo }
            }

            property real multiShift: window.activeMode === "wifi" || window.activeMode === "eth" ? 0.0 : window.multiTransitionState

            width: window.currentPower ? (window.s(170) - (window.s(25) * multiShift) - (window.s(12) * Math.max(0, window.smoothedActiveCoreCount - 2))) : window.s(140)
            height: width

            property real myBaseAngle: (window.coreVisualIndices[index] / Math.max(1, window.activeCoreCount)) * Math.PI * 2
            property real animatedBaseAngle: myBaseAngle
            Behavior on animatedBaseAngle { enabled: window.visible; NumberAnimation { duration: 1000; easing.type: Easing.InOutExpo } }

            property real coreOrbitAngle: window.globalOrbitAngle * 1.5 + animatedBaseAngle

            property real myOrbitRadiusX: window.s(150) + (window.activeCoreCount > 2 ? window.s(15) : 0)
            property real myOrbitRadiusY: window.s(90) + (window.activeCoreCount > 2 ? window.s(12) : 0)

            x: window.activeMode === "eth" ? (orbitContainer.width / 2 - width / 2) : ((orbitContainer.width / 2 - width / 2) + (Math.cos(coreOrbitAngle) * myOrbitRadiusX * multiShift * activeTransition))
            y: window.activeMode === "eth" ? (orbitContainer.height / 2 - height / 2) : ((orbitContainer.height / 2 - height / 2) + (Math.sin(coreOrbitAngle) * myOrbitRadiusY * multiShift * activeTransition))

            opacity: activeTransition * window.easeOut(window.animWin(window.introState, coreIntroStart, coreIntroStart + 0.22))
            scale: centralCore.bumpScale * (0.8 + 0.2 * activeTransition) * coreIntroProg
            visible: opacity > 0.01

            property string myId: myDevice ? (window.activeMode === "wifi" ? (myDevice.ssid || "") : (window.activeMode === "eth" ? (myDevice.id || "") : (myDevice.mac || ""))) : "unknown"
            property bool isMyDisconnecting: !!window.disconnectingDevices[myId]

            property bool showScanning: isPrimary && window.currentPower && !window.currentConn && window.pendingWifiId === "" && window.activeMode !== "eth"
            property bool showConnected: window.currentConn && hasDevice && window.pendingWifiId === ""
            property bool showPassword: isPrimary && window.pendingWifiId !== "" && window.activeMode === "wifi"
            property bool showEthDisconnected: isPrimary && window.currentPower && !window.currentConn && window.activeMode === "eth"

            MultiEffect {
                source: centralCore
                anchors.fill: centralCore
                shadowEnabled: window.visible && window.currentPower
                shadowColor: "#000000"
                shadowOpacity: window.currentPower ? 0.5 : 0.0
                shadowBlur: 1.2
                shadowVerticalOffset: window.s(5)
                z: -1
                Behavior on shadowOpacity { enabled: window.visible; NumberAnimation { duration: 600 } }
            }

            Rectangle {
                id: centralCore
                anchors.fill: parent
                radius: width / 2

                property real disconnectFill: 0.0
                property bool disconnectTriggered: false
                property real flashOpacity: 0.0
                property real bumpScale: 1.0
                property bool isDangerState: coreMa.containsMouse || disconnectFill > 0 || isMyDisconnecting

                SequentialAnimation on bumpScale {
                    id: coreBumpAnim
                    running: false
                    NumberAnimation { to: 1.15; duration: 200; easing.type: Easing.OutBack }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.OutQuint }
                }

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: {
                            if (!window.currentPower) return ThemeBackend.mantle;
                            if (isMyDisconnecting) return ThemeBackend.surface0;
                            if (centralCore.isDangerState && window.currentConn && !showPassword) return Qt.tint(Qt.lighter(window.activeColor, 1.15), Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.75));
                            return window.currentConn || showPassword ? Qt.lighter(window.activeColor, 1.15) : ThemeBackend.surface0;
                        }
                        Behavior on color { enabled: window.visible; ColorAnimation { duration: 300 } }
                    }
                    GradientStop {
                        position: 1.0
                        color: {
                            if (!window.currentPower) return ThemeBackend.crust;
                            if (isMyDisconnecting) return ThemeBackend.base;
                            if (centralCore.isDangerState && window.currentConn && !showPassword) return Qt.tint(window.activeColor, Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.75));
                            return window.currentConn || showPassword ? window.activeColor : ThemeBackend.base;
                        }
                        Behavior on color { enabled: window.visible; ColorAnimation { duration: 300 } }
                    }
                }

                border.color: {
                    if (!window.currentPower) return ThemeBackend.crust;
                    if (isMyDisconnecting) return ThemeBackend.surface0;
                    if (centralCore.isDangerState && window.currentConn && !showPassword) return Qt.tint(Qt.lighter(window.activeColor, 1.1), Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.45));
                    return window.currentConn || showPassword ? Qt.lighter(window.activeColor, 1.1) : ThemeBackend.surface1;
                }
                border.width: window.s(2)
                Behavior on border.color { enabled: window.visible; ColorAnimation { duration: 300 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "#ffffff"
                    opacity: centralCore.flashOpacity
                    PropertyAnimation on opacity { id: coreFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                }

                FluidWave {
                    id: coreWave
                    anchors.fill: parent
                    visible: window.visible && centralCore.disconnectFill > 0
                    opacity: 0.95

                    property real wavePhase: 0.0
                    NumberAnimation on wavePhase {
                        running: window.visible && centralCore.disconnectFill > 0.0 && centralCore.disconnectFill < 1.0
                        loops: Animation.Infinite
                        from: 0; to: Math.PI * 2; duration: 800
                    }

                    radius: width / 2
                    fillLevel: centralCore.disconnectFill
                    waveAmp: centralCore.disconnectFill < 0.99 ? (window.s(10) * Math.sin(centralCore.disconnectFill * Math.PI)) : 0
                    phase: wavePhase
                    vertical: 1.0
                    color1: ThemeBackend.surface2
                    color2: ThemeBackend.crust
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + window.s(30)
                    height: width
                    radius: width / 2
                    color: centralCore.isDangerState && window.currentConn && !showPassword ? ThemeBackend.red : window.activeColor
                    opacity: (window.currentConn || showPassword) && !isMyDisconnecting ? (centralCore.isDangerState && !showPassword ? 0.45 : 0.15) : 0.0
                    z: -1
                    Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 300 } }

                    SequentialAnimation on scale {
                        loops: Animation.Infinite; running: window.visible && (window.currentConn || showPassword)
                        NumberAnimation { to: 1.1; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + window.s(12)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: centralCore.isDangerState && !showPassword ? ThemeBackend.red : window.activeColor
                    border.width: window.s(2)
                    z: -2

                    property real pulseOp: 0.0
                    property real pulseSc: 1.0
                    opacity: ((window.currentConn || showPassword) && window.showInfoView && window.currentPower && !isMyDisconnecting) ? pulseOp : 0.0
                    scale: pulseSc

                    Timer {
                        interval: 45
                        running: window.visible && parent.opacity > 0.01
                        repeat: true
                        onTriggered: {
                            var time = Date.now() / 1000;
                            parent.pulseOp = 0.3 + Math.sin(time * 2.5) * 0.15;
                            parent.pulseSc = 1.02 + Math.cos(time * 3.0) * 0.02;
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: showScanning ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 400 } }

                    Repeater {
                        model: 3
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.4; height: width; radius: width / 2
                            color: "transparent"
                            border.color: window.activeColor; border.width: window.s(2)
                            SequentialAnimation on scale {
                                running: window.visible && showScanning; loops: Animation.Infinite
                                PauseAnimation { duration: index * 400 }
                                NumberAnimation { from: 1.0; to: 2.5; duration: 2000; easing.type: Easing.OutSine }
                            }
                            SequentialAnimation on opacity {
                                running: window.visible && showScanning; loops: Animation.Infinite
                                PauseAnimation { duration: index * 400 }
                                NumberAnimation { from: 0.8; to: 0.0; duration: 2000; easing.type: Easing.OutSine }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(40) - (window.s(12) * coreContainer.multiShift)
                        color: window.activeColor
                        text: window.activeMode === "wifi" ? "󰤨" : (window.activeMode === "eth" ? "󰈀" : "󰂯")
                        SequentialAnimation on opacity {
                            running: window.visible && showScanning; loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: window.s(8)
                    visible: showEthDisconnected
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 300 } }
                    Text { Layout.alignment: Qt.AlignHCenter; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(40); color: ThemeBackend.overlay0; text: "󰈂" }
                    Text { Layout.alignment: Qt.AlignHCenter; font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(13); color: ThemeBackend.overlay0; text: window.currentPowerPending ? (window.expectedEthPower === "on" ? (I18n.t("network.status.powering_on") || "Powering on...") : (I18n.t("network.status.powering_off") || "Powering off...")) : (I18n.t("network.status.disconnected") || "Disconnected") }
                }

                Item {
                    id: pwdLayer
                    anchors.fill: parent
                    opacity: showPassword ? 1.0 : 0.0
                    visible: opacity > 0.01
                    scale: showPassword ? 1.0 : 0.8
                    Behavior on scale { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutSine } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: window.s(6)

                        Text { Layout.alignment: Qt.AlignHCenter; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(28); color: ThemeBackend.crust; text: "󰤨" }

                        Text {
                            Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: pwdLayer.width - window.s(30)
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(12)
                            color: ThemeBackend.crust; text: window.pendingWifiSsid; elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: pwdLayer.width - window.s(30); height: window.s(32)
                            radius: ThemeBackend.borderRadius
                            color: ThemeBackend.surface0
                            border.color: wifiPasswordField.activeFocus ? ThemeBackend.crust : "transparent"
                            border.width: 1
                            Behavior on border.color { enabled: window.visible; ColorAnimation { duration: 200 } }

                            TextInput {
                                id: wifiPasswordField
                                anchors.fill: parent
                                anchors.leftMargin: window.s(12); anchors.rightMargin: window.s(12)
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12); color: ThemeBackend.text
                                echoMode: TextInput.Password; clip: true
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        window.connectDevice(window.activeMode, window.pendingWifiId, window.pendingWifiSsid, text);
                                        window.pendingWifiId = ""; window.pendingWifiSsid = ""; text = "";
                                        window.forceActiveFocus();
                                    }
                                }
                                Keys.onEscapePressed: { window.pendingWifiId = ""; window.pendingWifiSsid = ""; text = ""; window.forceActiveFocus(); }
                            }
                        }
                    }

                    Timer { id: deferFocusTimer; interval: 50; onTriggered: wifiPasswordField.forceActiveFocus() }
                    onVisibleChanged: { if (visible) { wifiPasswordField.text = ""; deferFocusTimer.start(); } }
                }

                Item {
                    id: showConnectedItem
                    anchors.fill: parent
                    opacity: showConnected ? 1.0 : 0.0
                    visible: opacity > 0.01
                    scale: showConnected ? 1.0 : 0.95
                    Behavior on scale { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutSine } }

                    ColumnLayout {
                        id: baseCoreText
                        anchors.centerIn: parent
                        spacing: window.s(3)

                        Text {
                            id: coreIconText
                            Layout.alignment: Qt.AlignHCenter
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(40) - (window.s(12) * coreContainer.multiShift)
                            color: isMyDisconnecting ? ThemeBackend.overlay1 : ThemeBackend.crust
                            text: isMyDisconnecting ? "" : (coreMa.containsMouse ? (window.activeMode === "wifi" ? "󰖪" : (window.activeMode === "eth" ? "󰈂" : "󰂲")) : (coreContainer.myDevice ? (coreContainer.myDevice.icon || (window.activeMode === "wifi" ? "󰤨" : (window.activeMode === "eth" ? "󰈀" : "󰂯"))) : ""))
                            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                        }
                        LoadingDots { Layout.alignment: Qt.AlignHCenter; visible: isMyDisconnecting; dotCol: ThemeBackend.overlay1 }
                        Text {
                            id: coreNameText
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: window.s(130) - (window.s(40) * coreContainer.multiShift)
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Black
                            font.pixelSize: window.s(14) - (window.s(3) * coreContainer.multiShift)
                            color: isMyDisconnecting ? ThemeBackend.overlay1 : ThemeBackend.crust
                            text: coreContainer.myDevice ? (window.activeMode === "wifi" ? (coreContainer.myDevice.ssid || "") : (coreContainer.myDevice.name || "")) : ""
                            elide: Text.ElideRight
                            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                        }
                        Text {
                            id: coreStatusText
                            Layout.alignment: Qt.AlignHCenter
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(10)
                            color: isMyDisconnecting ? ThemeBackend.overlay1 : (coreMa.containsMouse ? ThemeBackend.crust : "#99000000")
                            text: isMyDisconnecting ? (I18n.t("network.status.disconnecting") || "Disconnecting...") : (centralCore.disconnectFill > 0.01 ? (I18n.t("network.status.hold") || "Hold to Disconnect") : (I18n.t("network.status.connected") || "Connected"))
                            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                        }
                    }

                    Item {
                        id: waveClipItem
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        property real clipWaveAmp: window.s(10) * Math.sin(centralCore.disconnectFill * Math.PI)
                        property real clipPhaseOffset: Math.sin(coreWave.wavePhase) - Math.cos(coreWave.wavePhase)
                        property real clipCenterOffset: centralCore.disconnectFill > 0.01 && centralCore.disconnectFill < 0.99 ? 0.375 * clipWaveAmp * clipPhaseOffset : 0
                        height: Math.max(0, Math.min(parent.height, (parent.height * centralCore.disconnectFill) + clipCenterOffset))
                        clip: true
                        visible: centralCore.disconnectFill > 0

                        ColumnLayout {
                            spacing: window.s(3)
                            x: waveClipItem.width / 2 - width / 2
                            y: (centralCore.height / 2) - (height / 2) - (centralCore.height - waveClipItem.height)

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: window.s(40) - (window.s(12) * coreContainer.multiShift)
                                color: ThemeBackend.text
                                text: isMyDisconnecting ? "" : (coreMa.containsMouse ? (window.activeMode === "wifi" ? "󰖪" : (window.activeMode === "eth" ? "󰈂" : "󰂲")) : (coreContainer.myDevice ? (coreContainer.myDevice.icon || (window.activeMode === "wifi" ? "󰤨" : (window.activeMode === "eth" ? "󰈀" : "󰂯"))) : ""))
                            }
                            LoadingDots { Layout.alignment: Qt.AlignHCenter; visible: isMyDisconnecting; dotCol: ThemeBackend.text }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: window.s(130) - (window.s(40) * coreContainer.multiShift)
                                horizontalAlignment: Text.AlignHCenter
                                font.family: ThemeBackend.fontFamily; font.weight: Font.Black
                                font.pixelSize: window.s(14) - (window.s(3) * coreContainer.multiShift)
                                color: ThemeBackend.text
                                text: coreContainer.myDevice ? (window.activeMode === "wifi" ? (coreContainer.myDevice.ssid || "") : (coreContainer.myDevice.name || "")) : ""
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(10)
                                color: ThemeBackend.text
                                text: isMyDisconnecting ? (I18n.t("network.status.disconnecting") || "Disconnecting...") : (centralCore.disconnectFill > 0.01 ? (I18n.t("network.status.hold") || "Hold to Disconnect") : (I18n.t("network.status.connected") || "Connected"))
                            }
                        }
                    }
                }

                MouseArea {
                    id: coreMa
                    anchors.fill: parent
                    enabled: window.visible
                    hoverEnabled: window.visible
                    cursorShape: window.currentConn && !isMyDisconnecting && !showPassword ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onEntered: {
                        if (window.currentConn && !showPassword) {
                            window.disconnectHoverCount++;
                        }
                    }
                    onExited: {
                        if (window.currentConn && !showPassword) {
                            window.disconnectHoverCount = Math.max(0, window.disconnectHoverCount - 1);
                        }
                    }

                    onPressed: {
                        if (window.currentConn && !isMyDisconnecting && !centralCore.disconnectTriggered && !showPassword) {
                            coreDrainAnim.stop();
                            coreFillAnim.start();
                        }
                    }
                    onReleased: {
                        if (!centralCore.disconnectTriggered && !isMyDisconnecting && !showPassword) {
                            coreFillAnim.stop();
                            coreDrainAnim.start();
                        }
                    }
                }

                NumberAnimation {
                    id: coreFillAnim
                    target: centralCore
                    property: "disconnectFill"
                    to: 1.0
                    duration: 800 * (1.0 - centralCore.disconnectFill)
                    easing.type: Easing.InSine
                    onFinished: {
                        if (!coreMa.pressed) {
                            centralCore.disconnectFill = 0.0;
                            return;
                        }

                        centralCore.disconnectTriggered = true;
                        centralCore.flashOpacity = 0.6;
                        coreFlashAnim.start();
                        coreBumpAnim.start();

                        Sounds.playSfx("network/disconnect.wav");

                        let dd = window.disconnectingDevices;
                        dd[coreContainer.myId] = true;
                        window.disconnectingDevices = Object.assign({}, dd);
                        window.busyTimeoutTimer.restart();

                        if (window.activeMode === "bt") {
                            let devList = window.getBtDevicesList();
                            let devToDisconnect = null;
                            for (let i = 0; i < devList.length; i++) {
                                if (devList[i] && devList[i].address === coreContainer.myId) { devToDisconnect = devList[i]; break; }
                            }
                            if (devToDisconnect) devToDisconnect.disconnect();
                        } else if (window.activeMode === "eth") {
                            if (window.ethDevice) window.ethDevice.disconnect();
                        } else if (window.activeMode === "wifi") {
                            if (window.wifiDevice) window.wifiDevice.disconnect();
                        }

                        centralCore.disconnectFill = 0.0;
                        centralCore.disconnectTriggered = false;
                    }
                }

                NumberAnimation {
                    id: coreDrainAnim
                    target: centralCore
                    property: "disconnectFill"
                    to: 0.0
                    duration: 1500 * centralCore.disconnectFill
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
