import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../../reusables"
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 160
    property real minHeight: 60
    property real maxWidth: 600
    property real maxHeight: 200
    property real minAspect: 1.5
    property real maxAspect: 4.5
    property bool isRound: false

    readonly property bool hasBattery: UPower.displayDevice.ready ? UPower.displayDevice.isLaptopBattery : !SystemInfo.isDesktop
    readonly property int batCapacity: (UPower.displayDevice.ready && hasBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: hasBattery && UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    readonly property color batColorFlat: {
        if (!hasBattery) return ThemeBackend.subtext0;
        if (isCharging) return ThemeBackend.green;
        if (batCapacity <= 20) return ThemeBackend.red;
        return ThemeBackend.blue;
    }

    property real animCapacity: 0
    Behavior on animCapacity {
        enabled: root.visible
        NumberAnimation { duration: 1200; easing.type: Easing.OutQuint }
    }

    onBatCapacityChanged: {
        if (root.visible && hasBattery) animCapacity = batCapacity;
    }

    Component.onCompleted: {
        if (hasBattery) animCapacity = batCapacity;
    }

    readonly property real fillLevel: hasBattery ? animCapacity / 100 : 0
    readonly property real maxWaveAmp: isCharging ? Scaler.s(8) : Scaler.s(2.5)
    readonly property real waveAmp: (fillLevel < 0.99 && fillLevel > 0.01) ? maxWaveAmp * Math.sin(fillLevel * Math.PI) : 0

    property real wavePhase: 0.0
    NumberAnimation on wavePhase {
        running: root.visible && root.hasBattery && root.fillLevel > 0.0 && root.fillLevel < 1.0
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: root.isCharging ? 1200 : 3400
    }

    onWavePhaseChanged: waveCanvas.requestPaint()

    readonly property string timeString: {
        if (!hasBattery) return "No battery found";
        if (!UPower.displayDevice.ready) return "Unknown";
        if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return I18n.t("syspanel.battery.fully_charged");
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        let h = Math.floor(secs / 3600);
        let m = Math.round((secs % 3600) / 60);
        if (UPower.displayDevice.state === UPowerDeviceState.Charging) {
            if (h === 0 && m === 0) return I18n.t("syspanel.battery.charging");
            return I18n.t("syspanel.battery.charging_time", { hours: h, mins: m });
        }
        if (h === 0 && m === 0) return I18n.t("syspanel.battery.discharging");
        return I18n.t("syspanel.battery.left_time", { hours: h, mins: m });
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.width: 1
        border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)
        clip: true

        Canvas {
            id: waveCanvas
            anchors.fill: parent
            visible: root.visible && root.hasBattery && root.fillLevel > 0.001
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            Connections {
                target: root
                function onFillLevelChanged() { waveCanvas.requestPaint() }
                function onWaveAmpChanged() { waveCanvas.requestPaint() }
                function onBatColorFlatChanged() { waveCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root.fillLevel <= 0.001) return;

                var r = ThemeBackend.borderRadius > 0 ? Math.min(ThemeBackend.borderRadius, Math.min(width, height) / 2) : Scaler.s(14);
                var currentW = width * root.fillLevel;

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(0, 0);
                if (root.fillLevel < 0.99 && root.waveAmp > 0) {
                    var wAmp = root.waveAmp;
                    if (currentW - wAmp < 0) wAmp = currentW;
                    var cp1x = currentW + Math.sin(root.wavePhase) * wAmp;
                    var cp2x = currentW + Math.cos(root.wavePhase + Math.PI) * wAmp;

                    ctx.lineTo(currentW, 0);
                    ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                    ctx.lineTo(0, height);
                } else {
                    ctx.lineTo(currentW, 0);
                    ctx.lineTo(currentW, height);
                    ctx.lineTo(0, height);
                }
                ctx.closePath();
                ctx.clip();

                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(width - r, 0);
                ctx.arcTo(width, 0, width, r, r);
                ctx.lineTo(width, height - r);
                ctx.arcTo(width, height, width - r, height, r);
                ctx.lineTo(r, height);
                ctx.arcTo(0, height, 0, height - r, r);
                ctx.lineTo(0, r);
                ctx.arcTo(0, 0, r, 0, r);
                ctx.closePath();

                ctx.fillStyle = root.batColorFlat.toString();
                ctx.fill();
                ctx.restore();
            }
        }

        component BatteryContent : Item {
            id: bRoot
            property color contentTextColor: ThemeBackend.text
            property color iconColor: root.batColorFlat

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Scaler.s(16)
                anchors.rightMargin: Scaler.s(16)
                spacing: Scaler.s(14)

                Text {
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: Math.max(Scaler.s(22), Math.min(Scaler.s(36), root.height * 0.36))
                    color: bRoot.iconColor
                    text: {
                        if (!root.hasBattery) return "󰂎";
                        if (root.isCharging) return "󰂄";
                        if (root.batCapacity > 80) return "󰁹";
                        if (root.batCapacity > 60) return "󰂀";
                        if (root.batCapacity > 40) return "󰁾";
                        if (root.batCapacity > 20) return "󰁼";
                        return "󰂃";
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: Scaler.s(2)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: Math.max(Scaler.s(14), Math.min(Scaler.s(24), root.height * 0.26))
                        color: bRoot.contentTextColor
                        text: root.hasBattery ? (Math.round(root.animCapacity) + "%") : "No battery found"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Math.max(Scaler.s(9), Math.min(Scaler.s(12), root.height * 0.13))
                        color: bRoot.contentTextColor === ThemeBackend.crust ? Qt.alpha(ThemeBackend.crust, 0.85) : (root.isCharging ? ThemeBackend.green : ThemeBackend.subtext0)
                        text: root.hasBattery ? root.timeString : "AC power connected"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        BatteryContent {
            anchors.fill: parent
            contentTextColor: ThemeBackend.text
            iconColor: root.batColorFlat
        }

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: root.hasBattery && root.fillLevel > 0.001

            property real phaseOffset: Math.sin(root.wavePhase) - Math.cos(root.wavePhase)
            property real centerOffset: root.fillLevel > 0.01 && root.fillLevel < 0.99 ? 0.375 * root.waveAmp * phaseOffset : 0

            width: Math.max(0, Math.min(parent.width, (parent.width * root.fillLevel) + centerOffset))
            clip: true

            BatteryContent {
                width: bgContainer.width
                height: bgContainer.height
                contentTextColor: ThemeBackend.crust
                iconColor: ThemeBackend.crust
            }
        }
    }
}
