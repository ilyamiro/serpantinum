import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../reusables"
import "../mc"

RowLayout {
    required property var panel

    Layout.fillWidth: true
    Layout.preferredHeight: panel.s(73)
    Layout.maximumHeight: panel.s(73)
    spacing: panel.s(6)

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
            radius: 0
            clip: true

            property bool isHibernate: cmd === "hibernate"
            property bool isDisabled: isHibernate && !panel.canHibernate
            property bool showError: false
            property int chargingSoundHandle: -1

            opacity: panel.introActions
            transform: [
                Translate { id: shakeTranslate; x: 0 },
                Translate { x: (panel.isLeftAnchored ? -panel.rowSlideDistance : panel.rowSlideDistance) * (1.0 - panel.introActions) }
            ]

            color: "transparent"

            McPanel {
                z: -1
                anchors.fill: parent
                fill: (actionMa.containsMouse && !actionCapsule.isDisabled) ? "#6e6e6e" : "#575757"
                light: "#9a9a9a"
                dark: "#2a2a2a"
            }

            scale: (actionMa.pressed && !isDisabled) ? (0.98 - (0.01 * weight)) : ((actionMa.containsMouse && !isDisabled) ? 1.02 : 1.0)
            Behavior on scale {
                enabled: panel.visible
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
                NumberAnimation { target: shakeTranslate; property: "x"; to: -panel.s(3); duration: 50 }
                NumberAnimation { target: shakeTranslate; property: "x"; to: panel.s(3); duration: 50 }
                NumberAnimation { target: shakeTranslate; property: "x"; to: -panel.s(3); duration: 50 }
                NumberAnimation { target: shakeTranslate; property: "x"; to: panel.s(3); duration: 50 }
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
                visible: panel.visible && actionCapsule.fillLevel > 0.001

                property real wavePhase: 0.0
                NumberAnimation on wavePhase {
                    running: panel.visible && actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                    loops: Animation.Infinite
                    from: 0; to: Math.PI * 2; duration: 800
                }

                radius: actionCapsule.radius
                fillLevel: actionCapsule.fillLevel
                waveAmp: actionCapsule.fillLevel < 0.99 ? (panel.s(10) * Math.sin(actionCapsule.fillLevel * Math.PI)) : 0
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
                    enabled: panel.visible
                    NumberAnimation { duration: 200 }
                }
                z: 4
            }

            Text {
                anchors.centerIn: parent
                font.family: ThemeBackend.iconFont
                font.pixelSize: panel.s(19)
                color: isDisabled ? ThemeBackend.surface2 : (actionMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                text: icon
                Behavior on color {
                    enabled: panel.visible
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
                    font.pixelSize: panel.s(19)
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
                    panel.closeAnim.start();
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
