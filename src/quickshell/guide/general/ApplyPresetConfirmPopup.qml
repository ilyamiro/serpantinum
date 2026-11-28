import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

GuideModal {
    id: confirmPopup

    title: I18n.t("guide.general.presets.confirm.title", "Apply preset?")
    preferredWidth: s(520)
    padding: s(20)
    cornerRadius: ThemeBackend.clampedBorderRadius
    contentSpacing: s(16)

    property var preset: null
    property int remaining: 0

    signal confirmed(var preset, bool dontShowAgain)

    function openFor(p) {
        preset = p;
        dontShowCheck.checked = false;
        remaining = 3;
        countdown.restart();
        open();
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            confirmPopup.remaining = Math.max(0, confirmPopup.remaining - 1);
            if (confirmPopup.remaining === 0) stop();
        }
    }

    onClosed: countdown.stop()

    Text {
        Layout.fillWidth: true
        text: I18n.t("guide.general.presets.confirm.desc", "Are you sure you want to apply this preset without saving your own settings first? It will override your existing settings, and you won't be able to recover them.")
        color: ThemeBackend.subtext0
        font.family: ThemeBackend.fontFamily
        font.pixelSize: confirmPopup.s(13)
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: confirmPopup.s(8)

        Checkbox {
            id: dontShowCheck
            size: confirmPopup.s(24)
            text: I18n.t("guide.general.presets.confirm.dont_show", "Do not show me this again")
            textFontSize: confirmPopup.s(12)
            textColor: ThemeBackend.subtext0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        ClickButton {
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: confirmPopup.s(34)
            buttonText: I18n.t("guide.general.presets.confirm.cancel", "Cancel")
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: confirmPopup.s(14)
            textFontSize: confirmPopup.s(12)
            onTriggered: confirmPopup.close()
        }

        ClickButton {
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: confirmPopup.s(34)
            enabled: confirmPopup.remaining === 0
            opacity: enabled ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: 200 } }
            buttonText: I18n.t("guide.general.presets.confirm.apply", "Apply") + (confirmPopup.remaining > 0 ? " (" + confirmPopup.remaining + ")" : "")
            buttonIcon: "󰄬"
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: confirmPopup.s(14)
            iconFontSize: confirmPopup.s(15)
            textFontSize: confirmPopup.s(12)
            onTriggered: {
                let p = confirmPopup.preset;
                let skip = dontShowCheck.checked;
                confirmPopup.close();
                confirmPopup.confirmed(p, skip);
            }
        }
    }
}
