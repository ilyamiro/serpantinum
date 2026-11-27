import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

Item {
    id: view
    required property var panel
    property alias nightLight: nightLightBtn
    property alias coffee: coffeeBtn

    readonly property var idleService: ShellRouter.idleService

    component QuickActionBtn : Rectangle {
        id: qaBtn
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: view.panel.cardRadius

        property bool isActive: false
        property string iconText: ""
        property color activeColor: ThemeBackend.blue
        readonly property bool isHovered: qaMa.containsMouse
        property real customFontSize: 0
        property string customFontFamily: ""

        property real togglePulse: 0.0

        onIsActiveChanged: {
            if (qaGlass.active) togglePulseAnim.restart();
        }

        SequentialAnimation {
            id: togglePulseAnim
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 0.0; duration: 560; easing.type: Easing.OutCubic }
        }

        signal leftClicked()
        signal rightClicked()

        color: qaGlass.active ? "transparent" : (isActive ? activeColor : ThemeBackend.faded(qaMa.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04)))

        GlassFill {
            id: qaGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: qaBtn.isActive ? qaBtn.activeColor : (qaMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
            tintAmount: qaBtn.isActive ? 0.6 : 0.3
            shadow: 1
            press: qaMa.pressed ? 1 : (qaMa.containsMouse ? 0.25 : 0)
            pulse: qaBtn.togglePulse
            Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on tintAmount { NumberAnimation { duration: 150 } }
        }
        Behavior on color {
            enabled: view.panel.visible
            ColorAnimation { duration: 150 }
        }

        scale: qaMa.pressed ? 0.95 : (qaMa.containsMouse ? 1.01 : 1.0)
        Behavior on scale {
            enabled: view.panel.visible
            NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
        }

        Text {
            anchors.centerIn: parent
            font.family: qaBtn.customFontFamily !== "" ? qaBtn.customFontFamily : ThemeBackend.iconFont
            font.pixelSize: qaBtn.customFontSize > 0 ? qaBtn.customFontSize : view.panel.s(18)
            font.weight: qaBtn.customFontSize > 0 ? Font.Bold : Font.Normal
            color: (qaBtn.isActive && !qaGlass.active) ? ThemeBackend.crust : ((qaBtn.isActive || qaMa.containsMouse) ? ThemeBackend.text : ThemeBackend.subtext0)
            text: qaBtn.iconText
            Behavior on color {
                enabled: view.panel.visible
                ColorAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: qaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) qaBtn.rightClicked();
                else qaBtn.leftClicked();
            }
        }
    }

    z: 5
    Layout.fillWidth: true
    Layout.preferredHeight: view.panel.s(73)
    Layout.maximumHeight: view.panel.s(73)
    opacity: view.panel.introQuickActions
    transform: Translate { x: (view.panel.isLeftAnchored ? -view.panel.rowSlideDistance : view.panel.rowSlideDistance) * (1.0 - view.panel.introQuickActions) }

    RowLayout {
        anchors.fill: parent
        spacing: view.panel.s(6)

        QuickActionBtn {
            id: nightLightBtn
            iconText: "󰖔"
            activeColor: ThemeBackend.peach
            isActive: Gamma.anyEnabled

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Gamma.toggleAll();
            }

            onRightClicked: {
                ShellRouter.toggle("settings", "display");
            }
        }

        QuickActionBtn {
            id: coffeeBtn
            activeColor: Qt.tint(ThemeBackend.peach, "#5c3016")

            isActive: view.idleService ? view.idleService.caffeineActive : false
            readonly property double coffeeEndTime: view.idleService ? view.idleService.caffeineEndTime : 0
            readonly property int remainingSeconds: view.idleService ? view.idleService.caffeineSecondsLeft : 0

            readonly property string remainingTimeString: {
                if (isActive && coffeeEndTime <= 0) return "∞";
                let secs = remainingSeconds;
                if (secs <= 0) return "< 1m";
                let h = Math.floor(secs / 3600);
                let m = Math.floor((secs % 3600) / 60);
                if (h > 0) {
                    return h + "h " + (m < 10 ? "0" + m : m) + "m";
                }
                return Math.max(1, m) + "m";
            }

            iconText: (isActive && isHovered) ? remainingTimeString : "󰅶"
            customFontSize: (isActive && isHovered) ? view.panel.s(12) : 0
            customFontFamily: (isActive && isHovered) ? ThemeBackend.fontFamily : ""

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (view.idleService) view.idleService.toggleCaffeine();
            }

            onRightClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (view.idleService) view.idleService.increaseCaffeine(60);
            }
        }

        QuickActionBtn {
            iconText: isActive ? "󰤨" : "󰤮"
            activeColor: ThemeBackend.blue
            isActive: Connectivity.wifiEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Connectivity.setWifiEnabled(!Connectivity.wifiEnabled);
            }
            onRightClicked: {
                ShellRouter.toggle("network", "wifi");
            }
        }

        QuickActionBtn {
            iconText: isActive ? "󰂯" : "󰂲"
            activeColor: ThemeBackend.mauve
            isActive: Connectivity.bluetoothEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Connectivity.setBluetoothEnabled(!Connectivity.bluetoothEnabled);
            }
            onRightClicked: {
                ShellRouter.toggle("network", "bt");
            }
        }

        QuickActionBtn {
            iconText: "󰀝"
            activeColor: ThemeBackend.red
            isActive: Connectivity.airplaneMode
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Connectivity.toggleAirplaneMode();
            }
        }
    }
}
