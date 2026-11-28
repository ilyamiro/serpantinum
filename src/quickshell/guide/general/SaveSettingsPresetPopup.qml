import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

GuideModal {
    id: savePresetPopup

    title: I18n.t("guide.general.presets.save.button", "Save preset")
    preferredWidth: s(480)
    padding: s(20)
    cornerRadius: ThemeBackend.clampedBorderRadius
    contentSpacing: s(16)

    signal saveRequested(string presetName)

    function openPopup() {
        presetNameInput.text = "";
        open();
        presetNameInput.forceInputFocus();
    }

    function commitSave() {
        let name = presetNameInput.text.trim();
        if (!name) {
            presetNameInput.triggerShake();
            return;
        }
        savePresetPopup.saveRequested(name);
        close();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: savePresetPopup.s(10)

        Input {
            id: presetNameInput
            Layout.fillWidth: true
            Layout.preferredHeight: savePresetPopup.s(38)
            placeholderText: I18n.t("guide.display.widgets.preset_name_placeholder", "Enter preset name...")
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: savePresetPopup.s(13)
            onAccepted: savePresetPopup.commitSave()
        }

        IconButton {
            size: savePresetPopup.s(38)
            Layout.preferredWidth: savePresetPopup.s(38)
            Layout.preferredHeight: savePresetPopup.s(38)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰄬"
            iconFontSize: savePresetPopup.s(18)
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            onClicked: savePresetPopup.commitSave()
        }
    }
}
