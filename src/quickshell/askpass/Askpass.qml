import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"

// Password dialog for `sudo -A` (bin/serpantinum-askpass), the polkit
// dialog's window with AskpassService as its source. Shell.qml loads it only
// while AskpassService.isActive.
Scope {
    id: askpassScope

    Dim {
        active: AskpassService.isActive
        opacity: 0.55
        blockInput: true
        namespace: "serpantinum-askpass-dim"
        onClicked: AskpassService.cancel()
    }

    ShellOverlayWindow {
        id: askWindow

        property var _resolvedScreen: null

        WlrLayershell.namespace: "serpantinum-askpass"
        screen: _resolvedScreen
        overlayOpen: AskpassService.isActive
        visible: AskpassService.isActive
        exclusiveKeyboardFocus: true
        dismissOnOutsideClick: true
        focusTarget: passwordInput
        onOutsideClicked: AskpassService.cancel()
        onEscapeDismissed: AskpassService.cancel()
        onOverlayOpenChanged: {
            if (overlayOpen) {
                askWindow._resolvedScreen = Compositor.focusedScreen();
            }
        }

        property real crLarge: ThemeBackend.borderRadius
        property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
        property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

        property real toolbarHeight: s(32)

        // A repeated request (the window stays loaded) starts clean too
        function startRequest() {
            passwordInput.clear();
            askWindow.acquireFocus();
            // sudo asks again after a wrong password
            if (AskpassService.retry) passwordInput.markError();
        }

        function submitPassword() {
            if (passwordInput.text.length > 0) AskpassService.answer(passwordInput.text);
        }

        Component.onCompleted: {
            askWindow._resolvedScreen = Compositor.focusedScreen();
            if (visible) Qt.callLater(askWindow.startRequest);
        }

        Connections {
            target: AskpassService

            function onRequestStarted() {
                askWindow.startRequest();
            }
        }

        Shortcut {
            sequences: ["Return", "Enter"]
            enabled: askWindow.visible && passwordInput.text.length > 0
            onActivated: askWindow.submitPassword()
        }

        Rectangle {
            id: dialogCard
            anchors.centerIn: parent
            width: askWindow.s(520)
            implicitHeight: cardLayout.implicitHeight + (askWindow.s(18) * 2)
            height: implicitHeight
            color: ThemeBackend.base
            radius: askWindow.crLarge

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowVerticalOffset: askWindow.s(4)
                shadowBlur: 0.5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: askWindow.s(18)
                spacing: askWindow.s(14)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: askWindow.s(12)
                    layoutDirection: I18n.layoutDirection

                    Rectangle {
                        Layout.preferredWidth: askWindow.s(44)
                        Layout.preferredHeight: askWindow.s(44)
                        Layout.alignment: Qt.AlignTop
                        radius: askWindow.crMedium
                        color: ThemeBackend.surface0

                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: askWindow.s(22)
                            color: ThemeBackend.mauve
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: askWindow.s(3)

                        Text {
                            text: AskpassService.title !== "" ? AskpassService.title
                                : (typeof I18n !== "undefined" ? I18n.t("polkit.title") : "Authentication required")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: askWindow.s(14)
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                            horizontalAlignment: I18n.textAlignment
                            Layout.fillWidth: true
                        }

                        Text {
                            text: AskpassService.message !== "" ? AskpassService.message
                                : (typeof I18n !== "undefined" ? I18n.t("polkit.default_description") : "Authentication is needed to run this action as superuser.")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: askWindow.s(12)
                            wrapMode: Text.Wrap
                            horizontalAlignment: I18n.textAlignment
                            Layout.fillWidth: true
                        }
                    }

                    CloseButton {
                        Layout.preferredWidth: askWindow.toolbarHeight
                        Layout.preferredHeight: askWindow.toolbarHeight
                        Layout.alignment: Qt.AlignTop
                        cornerRadius: askWindow.crSmall
                        iconFontSize: askWindow.s(14)
                        accentColor: ThemeBackend.surface1
                        onClicked: AskpassService.cancel()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: errorText.implicitHeight + askWindow.s(12)
                    radius: askWindow.crSmall
                    color: Qt.alpha(ThemeBackend.red, 0.12)
                    visible: AskpassService.retry

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: askWindow.s(6)
                        spacing: askWindow.s(8)
                        layoutDirection: I18n.layoutDirection

                        Text {
                            text: "󰅚"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: askWindow.s(14)
                            color: ThemeBackend.red
                        }

                        Text {
                            id: errorText
                            text: typeof I18n !== "undefined" ? I18n.t("polkit.error_failed") : "Authentication failed. Please try again."
                            color: ThemeBackend.red
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: askWindow.s(12)
                            font.weight: Font.Medium
                            wrapMode: Text.Wrap
                            horizontalAlignment: I18n.textAlignment
                            Layout.fillWidth: true
                        }
                    }
                }

                PasswordInput {
                    id: passwordInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: askWindow.toolbarHeight + askWindow.s(6)

                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    errorColor: ThemeBackend.red
                    busyColor: ThemeBackend.peach

                    cornerRadius: askWindow.crSmall
                    horizontalPadding: askWindow.s(10)
                    verticalPadding: askWindow.s(4)

                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: askWindow.s(13)

                    showLockIcon: true
                    showSubmitButton: true
                    lockButtonSize: askWindow.toolbarHeight + askWindow.s(2)

                    hasError: AskpassService.retry

                    placeholderText: {
                        let p = AskpassService.prompt.trim();
                        if (p.endsWith(":")) p = p.slice(0, -1).trim();
                        if (p !== "") return p;
                        return typeof I18n !== "undefined" ? I18n.t("polkit.password_placeholder") : "Password";
                    }

                    onAccepted: askWindow.submitPassword()
                }
            }
        }
    }
}
