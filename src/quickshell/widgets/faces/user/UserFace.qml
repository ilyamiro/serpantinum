import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool previewMode: false

    property real minWidth: 220
    property real minHeight: 130
    property real maxWidth: 500
    property real maxHeight: 300
    property real minAspect: 1.2
    property real maxAspect: 2.8
    property bool isRound: false

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.clampedBorderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Scaler.s(10)
            spacing: Scaler.s(8)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Scaler.s(10)

                ImageBox {
                    id: avatarBox
                    Layout.preferredWidth: Scaler.s(70)
                    Layout.preferredHeight: Scaler.s(70)
                    size: Scaler.s(70)
                    cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(12)) : Scaler.s(12)
                    imageRadius: cornerRadius
                    source: SystemInfo.avatarPath !== "" ? "file://" + SystemInfo.avatarPath : ""
                    backgroundColor: SystemInfo.avatarPath === "" ? ThemeBackend.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: Scaler.s(30)
                        color: ThemeBackend.text
                        visible: SystemInfo.avatarPath === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Scaler.s(6)

                    ClickButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Scaler.s(32)
                        cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(8)) : Scaler.s(8)
                        horizontalPadding: Scaler.s(10)
                        contentAlignment: Qt.AlignLeft
                        buttonIcon: ""
                        iconFontSize: Scaler.s(15)
                        buttonText: SystemInfo.username !== "" ? SystemInfo.username : "User"
                        textFontSize: Scaler.s(12)
                        accentColor: ThemeBackend.surface1
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        onClicked: ShellRouter.toggle("settings")
                    }

                    ClickButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Scaler.s(32)
                        cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(8)) : Scaler.s(8)
                        horizontalPadding: Scaler.s(10)
                        contentAlignment: Qt.AlignLeft
                        buttonIcon: ""
                        iconFontSize: Scaler.s(15)
                        buttonText: "Lock"
                        textFontSize: Scaler.s(12)
                        accentColor: ThemeBackend.surface1
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.mauve

                        onClicked: {
                            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/lock.sh"]);
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Scaler.s(36)
                spacing: Scaler.s(6)

                Repeater {
                    model: [
                        { cmd: "sleep", icon: "󰒲", weight: 1.0, color: ThemeBackend.blue },
                        { cmd: "reboot", icon: "󰑓", weight: 2.0, color: ThemeBackend.peach },
                        { cmd: "poweroff", icon: "", weight: 3.0, color: ThemeBackend.red }
                    ]

                    delegate: FillButton {
                        id: actionCapsule
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        vertical: true
                        horizontalPadding: 0
                        cornerRadius: ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Scaler.s(8)) : Scaler.s(8)
                        buttonIcon: modelData.icon
                        buttonText: ""
                        iconFontSize: Scaler.s(16)
                        accentColor: modelData.color
                        baseColor: ThemeBackend.surface1
                        hoverColor: ThemeBackend.surface2 !== undefined ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.surface1, 1.12)
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        restTextColor: ThemeBackend.subtext0
                        filledTextColor: ThemeBackend.crust
                        fillDuration: Math.round(550 * modelData.weight)
                        autoResetTimeout: 450

                        onTriggered: exitTimer.restart()

                        Timer {
                            id: exitTimer
                            interval: 450
                            repeat: false
                            onTriggered: {
                                let cmd = actionCapsule.modelData.cmd;
                                let scriptPath = Caching.serpantinumDir + "/scripts/system/" + (cmd === "sleep" ? "suspend.sh" : cmd + ".sh");
                                Quickshell.execDetached(["bash", scriptPath]);
                            }
                        }
                    }
                }
            }
        }
    }
}
