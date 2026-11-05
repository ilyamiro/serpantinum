import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: savePresetPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(480)) : 480
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj

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

    Connections {
        target: savePresetPopup.rootObj ? savePresetPopup.rootObj : null
        function onVisibleChanged() {
            if (savePresetPopup.rootObj && !savePresetPopup.rootObj.visible) {
                savePresetPopup.close();
            }
        }
    }

    background: Rectangle {
        radius: ThemeBackend.clampedBorderRadius
        color: gf1.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: 0.25
        }
    }

    contentItem: ColumnLayout {
        spacing: rootObj ? rootObj.s(16) : 16

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: I18n.t("guide.general.presets.save.button", "Save preset")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                Layout.fillWidth: true
            }

            CloseButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: rootObj ? rootObj.s(8) : 8
                iconFontSize: rootObj ? rootObj.s(14) : 14
                onClicked: savePresetPopup.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(10) : 10

            Input {
                id: presetNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj ? rootObj.s(38) : 38
                placeholderText: I18n.t("guide.display.widgets.preset_name_placeholder", "Enter preset name...")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj ? rootObj.s(13) : 13
                onAccepted: savePresetPopup.commitSave()
            }

            IconButton {
                size: rootObj ? rootObj.s(38) : 38
                Layout.preferredWidth: rootObj ? rootObj.s(38) : 38
                Layout.preferredHeight: rootObj ? rootObj.s(38) : 38
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰄬"
                iconFontSize: rootObj ? rootObj.s(18) : 18
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: savePresetPopup.commitSave()
            }
        }
    }
}
