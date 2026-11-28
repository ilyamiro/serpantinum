import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"

Scope {
    id: polkitScope

    Dim {
        active: PolkitService.isActive
        opacity: 0.55
        blockInput: true
        namespace: "serpantinum-polkit-dim"
        onClicked: PolkitService.cancel()
    }

    ShellOverlayWindow {
        id: polkitWindow

        property var _resolvedScreen: null

        WlrLayershell.namespace: "serpantinum-polkit"
        screen: _resolvedScreen
        overlayOpen: PolkitService.isActive
        visible: PolkitService.isActive
        exclusiveKeyboardFocus: true
        dismissOnOutsideClick: true
        focusTarget: passwordInput
        onOutsideClicked: PolkitService.cancel()
        onEscapeDismissed: PolkitService.cancel()
        onOverlayOpenChanged: {
            if (overlayOpen) {
                polkitWindow._resolvedScreen = Compositor.focusedScreen();
            }
        }

        property real crLarge: ThemeBackend.borderRadius
        property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
        property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

        property real toolbarHeight: s(32)
        property real actionHeight: s(42)
        property bool isAuthenticating: false
        property bool pendingSubmit: false

        readonly property string resolvedIconPath: {
            if (!PolkitService.flow || !PolkitService.flow.iconName) return "";
            let p = Quickshell.iconPath(PolkitService.flow.iconName, true);
            return p ? String(p) : "";
        }

        onVisibleChanged: {
            if (visible) {
                polkitWindow.isAuthenticating = false;
                polkitWindow.pendingSubmit = false;
                passwordInput.clear();
                polkitWindow.acquireFocus();
            } else {
                polkitWindow.pendingSubmit = false;
            }
        }

        Component.onCompleted: {
            polkitWindow._resolvedScreen = Compositor.focusedScreen();
            if (visible) {
                polkitWindow.isAuthenticating = false;
                polkitWindow.pendingSubmit = false;
                passwordInput.clear();
                Qt.callLater(polkitWindow.acquireFocus);
            }
        }

        Shortcut {
            sequences: ["Return", "Enter"]
            enabled: polkitWindow.visible && passwordInput.text.length > 0
            onActivated: polkitWindow.submitPassword()
        }

        function submitPassword() {
            if (!PolkitService.flow || polkitWindow.isAuthenticating) return;
            if (PolkitService.flow.isResponseRequired === false) {
                polkitWindow.pendingSubmit = true;
                return;
            }
            polkitWindow.pendingSubmit = false;
            polkitWindow.isAuthenticating = true;
            PolkitService.submit(passwordInput.text);
        }

        Connections {
            target: PolkitService

            function onRequestStarted() {
                polkitWindow.isAuthenticating = false;
                polkitWindow.pendingSubmit = false;
                passwordInput.clear();
                polkitWindow.acquireFocus();
            }

            function onAuthenticationFailed() {
                polkitWindow.isAuthenticating = false;
                polkitWindow.pendingSubmit = false;
                passwordInput.clear();
                passwordInput.markError();
                polkitWindow.acquireFocus();
            }
        }

        Connections {
            target: PolkitService.flow
            ignoreUnknownSignals: true

            function onIsResponseRequiredChanged() {
                if (PolkitService.flow && PolkitService.flow.isResponseRequired) {
                    if (polkitWindow.pendingSubmit && passwordInput.text.length > 0 && !polkitWindow.isAuthenticating) {
                        polkitWindow.submitPassword();
                    } else if (polkitWindow.visible) {
                        polkitWindow.acquireFocus();
                    }
                }
            }
        }

        Rectangle {
            id: dialogCard
            anchors.centerIn: parent
            width: polkitWindow.s(520)
            implicitHeight: cardLayout.implicitHeight + (polkitWindow.s(18) * 2)
            height: implicitHeight
            color: ThemeBackend.base
            radius: polkitWindow.crLarge

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowVerticalOffset: polkitWindow.s(4)
                shadowBlur: 0.5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: polkitWindow.s(18)
                spacing: polkitWindow.s(14)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: polkitWindow.s(12)
                    layoutDirection: I18n.layoutDirection

                    Rectangle {
                        Layout.preferredWidth: polkitWindow.s(44)
                        Layout.preferredHeight: polkitWindow.s(44)
                        Layout.alignment: Qt.AlignTop
                        radius: polkitWindow.crMedium
                        color: ThemeBackend.surface0

                        Image {
                            id: polkitIconImage
                            anchors.fill: parent
                            anchors.margins: polkitWindow.s(8)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            mipmap: true
                            source: polkitWindow.resolvedIconPath
                            visible: source !== "" && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !polkitIconImage.visible
                            text: {
                                if (!PolkitService.flow || !PolkitService.flow.iconName) return "󰌾";
                                let name = PolkitService.flow.iconName.toLowerCase();
                                if (name.indexOf("lock") !== -1 || name.indexOf("auth") !== -1) return "󰌾";
                                if (name.indexOf("system") !== -1 || name.indexOf("package") !== -1) return "󰏗";
                                if (name.indexOf("drive") !== -1 || name.indexOf("disk") !== -1) return "󰋊";
                                if (name.indexOf("network") !== -1) return "󰖩";
                                return "󰌾";
                            }
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: polkitWindow.s(22)
                            color: ThemeBackend.mauve
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: polkitWindow.s(3)

                        Text {
                            text: {
                                if (PolkitService.flow && PolkitService.flow.message) return PolkitService.flow.message;
                                return typeof I18n !== "undefined" ? I18n.t("polkit.default_message") : "An application is requesting administrative rights.";
                            }
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: polkitWindow.s(14)
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                            horizontalAlignment: I18n.textAlignment
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (PolkitService.flow && PolkitService.flow.actionId) return PolkitService.flow.actionId;
                                return typeof I18n !== "undefined" ? I18n.t("polkit.default_description") : "Authentication is needed to run this action as superuser.";
                            }
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: polkitWindow.s(12)
                            wrapMode: Text.Wrap
                            horizontalAlignment: I18n.textAlignment
                            Layout.fillWidth: true
                        }
                    }

                    CloseButton {
                        Layout.preferredWidth: polkitWindow.toolbarHeight
                        Layout.preferredHeight: polkitWindow.toolbarHeight
                        Layout.alignment: Qt.AlignTop
                        cornerRadius: polkitWindow.crSmall
                        iconFontSize: polkitWindow.s(14)
                        accentColor: ThemeBackend.surface1
                        onClicked: PolkitService.cancel()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: errorText.implicitHeight + polkitWindow.s(12)
                    radius: polkitWindow.crSmall
                    color: Qt.alpha(ThemeBackend.red, 0.12)
                    visible: PolkitService.errorMessage !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: polkitWindow.s(6)
                        spacing: polkitWindow.s(8)
                        layoutDirection: I18n.layoutDirection

                        Text {
                            text: "󰅚"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: polkitWindow.s(14)
                            color: ThemeBackend.red
                        }

                        Text {
                            id: errorText
                            text: PolkitService.errorMessage
                            color: ThemeBackend.red
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: polkitWindow.s(12)
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
                    Layout.preferredHeight: polkitWindow.toolbarHeight + polkitWindow.s(6)
                    visible: true

                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    errorColor: ThemeBackend.red
                    busyColor: ThemeBackend.peach

                    cornerRadius: polkitWindow.crSmall
                    horizontalPadding: polkitWindow.s(10)
                    verticalPadding: polkitWindow.s(4)

                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: polkitWindow.s(13)

                    showLockIcon: true
                    showSubmitButton: true
                    lockButtonSize: polkitWindow.toolbarHeight + polkitWindow.s(2)

                    hasError: PolkitService.errorMessage !== ""
                    isBusy: polkitWindow.isAuthenticating

                    placeholderText: {
                        if (PolkitService.flow && PolkitService.flow.inputPrompt) {
                            let p = PolkitService.flow.inputPrompt.trim();
                            if (p.endsWith(":")) p = p.slice(0, -1);
                            return p;
                        }
                        return typeof I18n !== "undefined" ? I18n.t("polkit.password_placeholder") : "Password";
                    }

                    onAccepted: polkitWindow.submitPassword()
                }
            }
        }
    }
}
