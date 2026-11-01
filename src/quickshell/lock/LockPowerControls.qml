import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: controls
    required property var screenRoot

    anchors.fill: parent

    Item {
        id: bottomInfoTray
        anchors.bottom: parent.bottom
        anchors.bottomMargin: screenRoot.s(16)
        anchors.left: parent.left
        anchors.leftMargin: screenRoot.s(20)
        anchors.right: parent.right
        anchors.rightMargin: screenRoot.s(20)
        height: screenRoot.s(48)

        opacity: screenRoot.inputActive ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        WallpaperBlur {
            z: -1
            anchors.fill: powerControlToggle
            radius: ThemeBackend.borderRadius
            screenOverride: screenRoot.surface.screen
            useSnapshot: true
            standalone: true
            surfaceEnabled: ThemeBackend.liquidGlass
        }

        IconButton {
            id: powerControlToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: screenRoot.s(48)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: screenRoot.powerMenuOpen ? "󰅖" : "󰐥"
            iconFontSize: screenRoot.s(20)
            accentColor: screenRoot.powerMenuOpen ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.surface0, 1.28)
            textColor: screenRoot.powerMenuOpen ? ThemeBackend.text : ThemeBackend.red
            onClicked: screenRoot.powerMenuOpen = !screenRoot.powerMenuOpen
        }
    }

    Rectangle {
        id: powerContainer
        z: 100

        Shortcut {
            sequence: "Escape"
            enabled: screenRoot.powerMenuOpen
            onActivated: {
                screenRoot.powerMenuOpen = false;
                screenRoot.restoreFocus();
            }
        }

        anchors.bottom: bottomInfoTray.top
        anchors.bottomMargin: screenRoot.s(16)
        anchors.right: bottomInfoTray.right

        width: screenRoot.s(320)
        height: screenRoot.powerMenuOpen ? (menuLayout.implicitHeight + screenRoot.s(24)) : 0
        radius: ThemeBackend.borderRadius

        clip: true
        visible: height > 0 || opacity > 0
        opacity: screenRoot.powerMenuOpen ? 1.0 : 0.0

        color: Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.45 * ThemeBackend.elementOpacity)

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            screenOverride: screenRoot.surface.screen
            useSnapshot: true
        }

        Behavior on height {
            NumberAnimation {
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: menuLayout
            anchors.top: parent.top
            anchors.topMargin: screenRoot.s(12)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: screenRoot.s(12)
            anchors.rightMargin: screenRoot.s(12)
            spacing: screenRoot.s(8)

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰒲"
                buttonText: I18n.t("lock.power.suspend")
                accentColor: ThemeBackend.accent
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.suspendProcess.running = true; }
            }

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰑓"
                buttonText: I18n.t("lock.power.reboot")
                accentColor: ThemeBackend.accent
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.reloadProcess.running = true; }
            }

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰐥"
                buttonText: I18n.t("lock.power.power_off")
                accentColor: ThemeBackend.red
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.poweroffProcess.running = true; }
            }
        }
    }
}
