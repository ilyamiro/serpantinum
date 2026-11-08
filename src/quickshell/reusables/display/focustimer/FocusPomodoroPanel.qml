import QtQuick
import QtQuick.Layouts
import "../../"
import "../../../"

FocusPanel {
    id: root

    property bool showSettings: false

    readonly property bool isRunning: FocusTimer.isPomoRunning
    readonly property var interceptedShortcuts: ["Return", "Enter"]

    function toggle() {
        FocusTimer.toggleMode(2);
    }

    function phaseColor() {
        if (FocusTimer.pomoState === 0) return ThemeBackend.mauve;
        if (FocusTimer.pomoState === 1) return Qt.rgba(166/255, 227/255, 161/255, 1.0);
        return ThemeBackend.surface1;
    }

    function phaseLabel() {
        if (FocusTimer.pomoState === 0) return I18n.t("quickactions.timer.pomodoro.phases.focus");
        if (FocusTimer.pomoState === 1) return I18n.t("quickactions.timer.pomodoro.phases.short_break");
        return I18n.t("quickactions.timer.pomodoro.phases.long_break");
    }

    Shortcut { enabled: root.visible && root.isActiveTab; sequence: "Return"; onActivated: root.toggle() }
    Shortcut { enabled: root.visible && root.isActiveTab; sequence: "Enter"; onActivated: root.toggle() }

    Item {
        anchors.fill: parent
        anchors.margins: root.padding

        Item {
            id: contentArea
            anchors.top: parent.top
            anchors.bottom: controls.top
            anchors.left: parent.left
            anchors.right: parent.right

            FocusTimeCard {
                padX: root.s(26)
                padY: root.s(14)
                visible: !root.showSettings
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: root.contentGap < 0 ? parent.verticalCenter : undefined
                anchors.bottom: root.contentGap >= 0 ? parent.bottom : undefined
                anchors.bottomMargin: Math.max(0, root.contentGap)

                ColumnLayout {
                    spacing: root.s(6)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.phaseLabel() + " (" + FocusTimer.pomoSessionsCount + "/" + FocusTimer.pomoTargetSessions + ")"
                        font.family: ThemeBackend.fontFamily; font.bold: true; font.pixelSize: root.s(14)
                        color: root.phaseColor()
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: FocusTimer.formatTime(FocusTimer.pomoRemainingMs, false)
                        font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: root.s(68)
                        color: ThemeBackend.text
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.s(270)
                height: root.s(160)
                radius: ThemeBackend.borderRadius
                color: settingsGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                visible: root.showSettings

                GlassFill {
                    id: settingsGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.3
                }

                Column {
                    anchors.centerIn: parent
                    spacing: root.s(12)

                    Repeater {
                        model: [
                            { label: I18n.t("quickactions.timer.pomodoro.settings.work"), target: "pomoWorkLimit", step: 5, min: 5, max: 60 },
                            { label: I18n.t("quickactions.timer.pomodoro.settings.short_break"), target: "pomoShortBreakLimit", step: 1, min: 1, max: 15 },
                            { label: I18n.t("quickactions.timer.pomodoro.settings.long_break"), target: "pomoLongBreakLimit", step: 5, min: 5, max: 45 },
                            { label: I18n.t("quickactions.timer.pomodoro.settings.sessions"), target: "pomoTargetSessions", step: 1, min: 1, max: 10 }
                        ]
                        RowLayout {
                            width: root.s(230)
                            Text { text: modelData.label; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); Layout.fillWidth: true }
                            IconButton {
                                size: root.s(24)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "-"
                                iconFontSize: root.s(14)
                                accentColor: ThemeBackend.surface1
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                onClicked: FocusTimer.adjustPomoSetting(modelData.target, -modelData.step, modelData.min, modelData.max)
                            }
                            Text { text: FocusTimer[modelData.target]; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; font.pixelSize: root.s(14); Layout.minimumWidth: root.s(24); horizontalAlignment: Text.AlignHCenter }
                            IconButton {
                                size: root.s(24)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "+"
                                iconFontSize: root.s(14)
                                accentColor: ThemeBackend.surface1
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                onClicked: FocusTimer.adjustPomoSetting(modelData.target, modelData.step, modelData.min, modelData.max)
                            }
                        }
                    }
                }
            }
        }

        FocusTimerControls {
            id: controls
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.s(10)
            anchors.left: parent.left
            anchors.right: parent.right
            scaleFn: root.scaleFn
            leftIcon: ""
            leftTextColor: root.showSettings ? ThemeBackend.mauve : ThemeBackend.text
            playIcon: root.isRunning ? "" : ""
            playAccent: root.phaseColor()
            showRight: true
            rightIcon: ""
            onLeftClicked: root.showSettings = !root.showSettings
            onPlayClicked: {
                if (root.showSettings) root.showSettings = false;
                root.toggle();
            }
            onRightClicked: FocusTimer.skipPomoPhase()
        }
    }
}
