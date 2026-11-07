import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: confirmPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(520)) : 520
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
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

    Connections {
        target: confirmPopup.rootObj ? confirmPopup.rootObj : null
        function onVisibleChanged() {
            if (confirmPopup.rootObj && !confirmPopup.rootObj.visible) {
                confirmPopup.close();
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
                text: I18n.t("guide.general.presets.confirm.title", "Apply preset?")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            CloseButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: rootObj ? rootObj.s(8) : 8
                iconFontSize: rootObj ? rootObj.s(14) : 14
                onClicked: confirmPopup.close()
            }
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("guide.general.presets.confirm.desc", "Are you sure you want to apply this preset without saving your own settings first? It will override your existing settings, and you won't be able to recover them.")
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj ? rootObj.s(13) : 13
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(8) : 8

            Checkbox {
                id: dontShowCheck
                size: rootObj ? rootObj.s(24) : 24
                text: I18n.t("guide.general.presets.confirm.dont_show", "Do not show me this again")
                textFontSize: rootObj ? rootObj.s(12) : 12
                textColor: ThemeBackend.subtext0
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            ClickButton {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: rootObj ? rootObj.s(34) : 34
                buttonText: I18n.t("guide.general.presets.confirm.cancel", "Cancel")
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: rootObj ? rootObj.s(14) : 14
                textFontSize: rootObj ? rootObj.s(12) : 12
                onTriggered: confirmPopup.close()
            }

            ClickButton {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: rootObj ? rootObj.s(34) : 34
                enabled: confirmPopup.remaining === 0
                opacity: enabled ? 1.0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 200 } }
                buttonText: I18n.t("guide.general.presets.confirm.apply", "Apply") + (confirmPopup.remaining > 0 ? " (" + confirmPopup.remaining + ")" : "")
                buttonIcon: "󰄬"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: rootObj ? rootObj.s(14) : 14
                iconFontSize: rootObj ? rootObj.s(15) : 15
                textFontSize: rootObj ? rootObj.s(12) : 12
                onTriggered: {
                    let p = confirmPopup.preset;
                    let skip = dontShowCheck.checked;
                    confirmPopup.close();
                    confirmPopup.confirmed(p, skip);
                }
            }
        }
    }
}
