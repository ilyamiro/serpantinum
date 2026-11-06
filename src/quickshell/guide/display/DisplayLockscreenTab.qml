import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"
import "../../reusables/guide"

DisplayLockscreenState {
    id: displayLockscreenRoot

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: lockscreenCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: lockscreenCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            LockBackgroundPreview {
                tab: displayLockscreenRoot
            }

            SettingsRow {
                rootObj: displayLockscreenRoot.rootObj
                settingId: "lockscreen_edit"
                icon: "󰌾"
                title: I18n.t("guide.display.lockscreen.edit.title", "Lock screen")
                description: I18n.t("guide.display.lockscreen.edit.desc", "Customize the layout of your lock screen")
                searchKeywords: "lockscreen lock screen redactor edit layout"

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    maxWidth: rootObj.s(160)
                    implicitHeight: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("guide.display.lockscreen.edit.button", "Edit lock screen")
                    buttonIcon: "󰏫"
                    iconFontSize: rootObj.s(14)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: displayLockscreenRoot.openRedactor()
                }
            }

            SettingsRow {
                visible: displayLockscreenRoot.fingerprintSupported
                rootObj: displayLockscreenRoot.rootObj
                settingId: "lockscreen_fingerprint"
                icon: "󰈷"
                title: I18n.t("guide.display.lockscreen.fingerprint.title", "Enable fingerprint login")
                description: I18n.t("guide.display.lockscreen.fingerprint.desc", "Allow unlocking the lock screen with a fingerprint")
                searchKeywords: "lockscreen lock screen fingerprint fprintd biometric login"

                Toggle {
                    id: fingerprintToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayLockscreenRoot.currentFingerprintEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        displayLockscreenRoot.currentFingerprintEnabled = c;
                        displayLockscreenRoot.updateLockscreenSetting("fingerprintEnabled", c);
                    }
                }
            }

            SettingsGroup {
                rootObj: displayLockscreenRoot.rootObj
                icon: "󰦝"
                title: I18n.t("guide.display.lockscreen.limits.title", "Attempt limits")
                description: I18n.t("guide.display.lockscreen.limits.desc", "Temporarily block password entry and disable the fingerprint reader after too many failed attempts")
                expanded: displayLockscreenRoot.currentAttemptLimitEnabled

                Toggle {
                    id: attemptLimitToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayLockscreenRoot.currentAttemptLimitEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        displayLockscreenRoot.currentAttemptLimitEnabled = c;
                        displayLockscreenRoot.updateLockscreenSetting("attemptLimitEnabled", c);
                    }
                }

                subSettings: [
                    SettingsRow {
                        rootObj: displayLockscreenRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰌆"
                        title: I18n.t("guide.display.lockscreen.password_attempts.title", "Password attempts")
                        description: I18n.t("guide.display.lockscreen.password_attempts.desc", "Failed attempts before password entry is blocked for 30 seconds")

                        NumberSelector {
                            id: passwordAttemptsSelector
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(120)
                            implicitHeight: rootObj.s(32)
                            from: 1
                            to: 20
                            stepSize: 1
                            decimals: 0
                            value: displayLockscreenRoot.currentPasswordMaxAttempts
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(11)
                            onValueChanged: {
                                let v = Math.round(passwordAttemptsSelector.value);
                                if (!isNaN(v) && v > 0 && displayLockscreenRoot.currentPasswordMaxAttempts !== v) {
                                    displayLockscreenRoot.currentPasswordMaxAttempts = v;
                                    displayLockscreenRoot.updateLockscreenSetting("passwordMaxAttempts", v);
                                }
                            }
                        }
                    },

                    SettingsRow {
                        visible: displayLockscreenRoot.fingerprintSupported
                        rootObj: displayLockscreenRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰈷"
                        title: I18n.t("guide.display.lockscreen.fingerprint_attempts.title", "Fingerprint attempts")
                        description: I18n.t("guide.display.lockscreen.fingerprint_attempts.desc", "Failed scans before the fingerprint reader is disabled until the next unlock")

                        NumberSelector {
                            id: fingerprintAttemptsSelector
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(120)
                            implicitHeight: rootObj.s(32)
                            from: 1
                            to: 20
                            stepSize: 1
                            decimals: 0
                            value: displayLockscreenRoot.currentFingerprintMaxAttempts
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(11)
                            onValueChanged: {
                                let v = Math.round(fingerprintAttemptsSelector.value);
                                if (!isNaN(v) && v > 0 && displayLockscreenRoot.currentFingerprintMaxAttempts !== v) {
                                    displayLockscreenRoot.currentFingerprintMaxAttempts = v;
                                    displayLockscreenRoot.updateLockscreenSetting("fingerprintMaxAttempts", v);
                                }
                            }
                        }
                    }
                ]
            }
        }
    }
}
