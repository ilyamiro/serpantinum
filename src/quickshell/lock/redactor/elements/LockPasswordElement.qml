import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "filled"
    property var ctx: null
    property alias input: field

    readonly property var sr: el.ctx
    readonly property bool glass: el.variant === "glass"
    readonly property color fieldColor: el.glass
        ? Qt.alpha(Qt.lighter(ThemeBackend.surface0, 1.28), 0.45)
        : Qt.lighter(ThemeBackend.surface0, 1.28)

    PasswordInput {
        id: field
        anchors.fill: parent
        lockBoxColor: Qt.lighter(ThemeBackend.surface0, 1.55)
        baseColor: el.fieldColor
        hoverColor: el.fieldColor
        focusColor: el.fieldColor
        activeColor: el.fieldColor
        accentColor: ThemeBackend.mauve
        textColor: ThemeBackend.text
        subTextColor: ThemeBackend.subtext0
        errorColor: ThemeBackend.red
        busyColor: ThemeBackend.peach
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: Scaler.s(12)
        fontFamily: ThemeBackend.fontFamily
        fontPixelSize: Scaler.s(14)
        horizontalAlignment: TextInput.AlignHCenter
        placeholderText: I18n.t("lock.status.enter_pin")
        showCaret: el.sr !== null
        enabled: el.sr ? (!el.sr.isPlayingIntro && !el.sr.isUnlocking) : true
        hasError: el.sr ? el.sr.lockUI.failed : false
        isBusy: el.sr ? el.sr.lockUI.authenticating : false
        isWidgetVisible: el.sr ? (el.sr.rootLock.locked && el.sr.inputActive) : true

        onActiveFocusChanged: {
            if (el.sr && !activeFocus && el.sr.rootLock.locked && !el.sr.isUnlocking && el.sr.inputActive) {
                Qt.callLater(el.sr.restoreFocus);
            }
        }

        onAccepted: (finalText) => {
            if (!el.sr) return;
            if (finalText.length > 0 && el.sr.pam.responseRequired && !el.sr.lockUI.authenticating) {
                el.sr.lockUI.authenticating = true;
                el.sr.lockUI.statusText = I18n.t("lock.status.authenticating");
                el.sr.lockUI.failed = false;
                el.sr.pam.respond(finalText);
            }
        }

        onTextEdited: (newText) => {
            if (!el.sr) return;
            if (el.sr.lockUI.authenticating || el.sr.isUnlocking || el.sr.lockUI.lockedOut) return;
            if (newText.length > 0 && !el.sr.inputActive) {
                el.sr.inputActive = true;
            }
            el.sr.idleTimer.restart();
            if (newText.length > 0) {
                el.sr.lockUI.failed = false;
                el.sr.lockUI.statusText = I18n.t("lock.status.enter_pin");
            } else {
                if (!el.sr.lockUI.failed) el.sr.lockUI.statusText = I18n.t("lock.status.locked");
            }
        }

        Keys.onPressed: (event) => {
            if (!el.sr) return;
            if (event.key === Qt.Key_Escape) {
                if (el.sr.powerMenuOpen) {
                    el.sr.powerMenuOpen = false;
                } else {
                    el.sr.inputActive = false;
                }
                field.clear();
                el.sr.restoreFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = true;
                el.sr.restoreFocus();
            }
        }
    }
}
