import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: dashboard
    required property var screenRoot
    property alias passwordInput: passwordInput

    anchors.fill: parent

    Rectangle {
        id: mainDashboardShellShadow
        anchors.fill: mainDashboardShell
        anchors.topMargin: screenRoot.s(1.5)
        anchors.bottomMargin: -screenRoot.s(1.5)
        radius: mainDashboardShell.radius
        color: Qt.rgba(0, 0, 0, 0.14)
        opacity: mainDashboardShell.opacity
        scale: mainDashboardShell.scale
        visible: mainDashboardShell.visible
        transform: Scale {
            origin.x: mainDashboardShell.width / 2
            origin.y: mainDashboardShell.height / 2
            xScale: screenRoot.isUnlocking ? screenRoot.foldScaleX : 1.0
            yScale: screenRoot.isUnlocking ? screenRoot.foldScaleY : 1.0
        }
    }

    Rectangle {
        id: mainDashboardShell
        anchors.centerIn: parent
        anchors.verticalCenterOffset: screenRoot.inputActive ? screenRoot.s(0) : screenRoot.s(90)
        width: Math.min(parent.width - screenRoot.s(48), screenRoot.s(440) + (screenRoot.wingsReveal * screenRoot.s(780)))
        height: screenRoot.s(580)
        radius: ThemeBackend.borderRadius * 1.5
        color: ThemeBackend.faded(ThemeBackend.surface0)
        clip: true

        opacity: screenRoot.centerReveal
        scale: 0.92 + (screenRoot.centerReveal * 0.08)
        visible: opacity > 0.01

        transform: Scale {
            origin.x: mainDashboardShell.width / 2
            origin.y: mainDashboardShell.height / 2
            xScale: screenRoot.isUnlocking ? screenRoot.foldScaleX : 1.0
            yScale: screenRoot.isUnlocking ? screenRoot.foldScaleY : 1.0
        }

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: mainDashboardShell.radius
            screenOverride: screenRoot.surface.screen
            useSnapshot: true
        }

        readonly property real leftWingWidth: screenRoot.wingsReveal * screenRoot.s(390)
        readonly property real centerWidth: screenRoot.s(440)
        readonly property real rightWingWidth: screenRoot.wingsReveal * screenRoot.s(390)

        Item {
            id: leftWingContainer
            x: 0
            y: 0
            width: mainDashboardShell.leftWingWidth
            height: parent.height
            clip: true
            opacity: screenRoot.wingsReveal
            visible: width > 0.5

            Loader {
                id: leftWingLoader
                width: screenRoot.s(390)
                height: leftWingContainer.height
                active: screenRoot.wingsEverNeeded
                asynchronous: true
                sourceComponent: Component { LockLeftWing { screenRoot: dashboard.screenRoot } }
            }
        }

        Item {
            id: centerUserPanel
            x: mainDashboardShell.leftWingWidth
            y: 0
            width: mainDashboardShell.centerWidth
            height: parent.height

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: screenRoot.s(24)
                spacing: 0

                Item { Layout.fillHeight: true; Layout.preferredHeight: screenRoot.s(16) }

                ImageBox {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: screenRoot.s(214)
                    Layout.preferredHeight: screenRoot.s(214)
                    size: screenRoot.s(214)
                    cornerRadius: screenRoot.s(107)
                    imageRadius: screenRoot.s(107)
                    source: screenRoot.faceIconPath !== "" ? screenRoot.faceIconPath : (SystemInfo.avatarPath !== "" ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : "")
                    backgroundColor: (screenRoot.faceIconPath === "" && SystemInfo.avatarPath === "") ? ThemeBackend.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: screenRoot.s(107)
                        color: ThemeBackend.text
                        visible: screenRoot.faceIconPath === "" && SystemInfo.avatarPath === ""
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: screenRoot.s(16) }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: screenRoot.s(14)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: screenRoot.s(10)

                        ClickButton {
                            Layout.preferredHeight: screenRoot.s(38)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: screenRoot.s(16)
                            buttonIcon: "󰀉"
                            iconFontSize: screenRoot.s(15)
                            buttonText: screenRoot.currentUser
                            textFontSize: screenRoot.s(13)
                            accentColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                            textColor: ThemeBackend.text
                            onClicked: screenRoot.restoreFocus()
                        }

                        ClickButton {
                            Layout.preferredHeight: screenRoot.s(38)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: screenRoot.s(16)
                            buttonIcon: ""
                            iconFontSize: screenRoot.s(15)
                            buttonText: screenRoot.lockUI.statusText
                            textFontSize: screenRoot.s(13)
                            accentColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                            textColor: screenRoot.lockUI.failed ? ThemeBackend.red : (screenRoot.lockUI.authenticating ? ThemeBackend.peach : ThemeBackend.text)
                            onClicked: screenRoot.restoreFocus()
                        }
                    }

                    PasswordInput {
                        id: passwordInput
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: screenRoot.s(44)
                        lockBoxColor: Qt.lighter(ThemeBackend.surface0, 1.55)
                        baseColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                        hoverColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                        focusColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                        activeColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        errorColor: ThemeBackend.red
                        busyColor: ThemeBackend.peach
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: screenRoot.s(12)
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: screenRoot.s(14)
                        horizontalAlignment: TextInput.AlignHCenter
                        placeholderText: I18n.t("lock.status.enter_pin")
                        enabled: !screenRoot.isPlayingIntro && !screenRoot.isUnlocking
                        hasError: screenRoot.lockUI.failed
                        isBusy: screenRoot.lockUI.authenticating
                        isWidgetVisible: screenRoot.rootLock.locked && screenRoot.inputActive

                        onActiveFocusChanged: {
                            if (!activeFocus && screenRoot.rootLock.locked && !screenRoot.isUnlocking && screenRoot.inputActive) {
                                Qt.callLater(screenRoot.restoreFocus);
                            }
                        }

                        onAccepted: (finalText) => {
                            if (finalText.length > 0 && screenRoot.pam.responseRequired && !screenRoot.lockUI.authenticating) {
                                screenRoot.lockUI.authenticating = true;
                                screenRoot.lockUI.statusText = I18n.t("lock.status.authenticating");
                                screenRoot.lockUI.failed = false;
                                screenRoot.pam.respond(finalText);
                            }
                        }

                        onTextEdited: (newText) => {
                            if (screenRoot.lockUI.authenticating || screenRoot.isUnlocking) return;
                            if (newText.length > 0 && !screenRoot.inputActive) {
                                screenRoot.inputActive = true;
                            }
                            screenRoot.idleTimer.restart();
                            if (newText.length > 0) {
                                screenRoot.lockUI.failed = false;
                                screenRoot.lockUI.statusText = I18n.t("lock.status.enter_pin");
                            } else {
                                if (!screenRoot.lockUI.failed) screenRoot.lockUI.statusText = I18n.t("lock.status.locked");
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (screenRoot.powerMenuOpen) {
                                    screenRoot.powerMenuOpen = false;
                                } else {
                                    screenRoot.inputActive = false;
                                }
                                passwordInput.clear();
                                screenRoot.restoreFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                event.accepted = true;
                                screenRoot.restoreFocus();
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: screenRoot.s(10)

                        ClickButton {
                            id: kbPill
                            Layout.preferredHeight: screenRoot.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: screenRoot.s(12)
                            buttonIcon: "󰌌"
                            iconFontSize: screenRoot.s(14)
                            buttonText: screenRoot.root.kbLayout
                            textFontSize: screenRoot.s(12)
                            accentColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                            textColor: ThemeBackend.text
                            onClicked: screenRoot.root.switchKbLayout()
                        }

                        ClickButton {
                            id: batPill
                            visible: !screenRoot.root.isDesktop
                            Layout.preferredHeight: screenRoot.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: screenRoot.s(12)
                            buttonIcon: screenRoot.root.batIcon
                            iconFontSize: screenRoot.s(14)
                            buttonText: screenRoot.root.batPercent
                            textFontSize: screenRoot.s(12)
                            accentColor: Qt.lighter(ThemeBackend.surface0, 1.28)
                            textColor: screenRoot.root.batDynamicColor
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: screenRoot.s(8) }

                FingerprintIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    visible: screenRoot.root.fingerprintAvailable
                    status: screenRoot.lockUI.fpState
                    label: screenRoot.lockUI.fpLabel
                    attempts: screenRoot.lockUI.fpFailures
                    maxAttempts: screenRoot.root.fingerprintMaxAttempts
                    glyphSize: screenRoot.s(44)
                    labelPixelSize: screenRoot.s(12)
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: screenRoot.s(8) }
            }
        }

        Item {
            id: rightWingContainer
            x: mainDashboardShell.leftWingWidth + mainDashboardShell.centerWidth
            y: 0
            width: mainDashboardShell.rightWingWidth
            height: parent.height
            clip: true
            opacity: screenRoot.wingsReveal
            visible: width > 0.5

            Loader {
                id: rightWingLoader
                width: screenRoot.s(390)
                height: rightWingContainer.height
                active: screenRoot.wingsEverNeeded
                asynchronous: true
                sourceComponent: Component { LockRightWing { screenRoot: dashboard.screenRoot } }
            }
        }
    }

    Connections {
        target: screenRoot.lockUI
        function onFailedChanged() {
            if (screenRoot.lockUI.failed) {
                passwordInput.triggerShake();
                passwordInput.clear();
                screenRoot.restoreFocus();
            }
        }
    }
}
