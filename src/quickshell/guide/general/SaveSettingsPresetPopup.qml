import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    property var tab
    property string imagePath: ""

    signal saveRequested(string presetName, string imagePath)

    function openPopup() {
        presetNameInput.text = "";
        imagePath = "";
        open();
        presetNameInput.forceInputFocus();
    }

    function commitSave() {
        let name = presetNameInput.text.trim();
        if (!name) {
            presetNameInput.triggerShake();
            return;
        }
        savePresetPopup.saveRequested(name, imagePath);
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

        Rectangle {
            id: imageSlot
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 10 / 16)
            radius: ThemeBackend.borderRadius
            color: slotMouse.containsMouse ? Qt.darker(ThemeBackend.surface0, 1.05) : Qt.darker(ThemeBackend.surface0, 1.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            layer.enabled: slotImage.status === Image.Ready
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: slotMask
            }

            Item {
                id: slotMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: "white"
                }
            }

            BoundedImage {
                id: slotImage
                anchors.fill: parent
                source: savePresetPopup.tab ? savePresetPopup.tab.imageSource(savePresetPopup.imagePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Column {
                anchors.centerIn: parent
                spacing: rootObj ? rootObj.s(6) : 6
                visible: slotImage.status !== Image.Ready

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰋩"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: rootObj ? rootObj.s(36) : 36
                    color: ThemeBackend.subtext0
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("guide.general.presets.image.choose", "Choose an image (optional)")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj ? rootObj.s(12) : 12
                    color: ThemeBackend.subtext0
                }
            }

            MouseArea {
                id: slotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: savePresetPopup.tab.pickImage("new", savePresetPopup.imagePath)
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
