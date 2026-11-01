import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.5
    property real maxAspect: 2.0
    property bool isRound: false

    property bool sineWave: true
    property real lineThickness: 8

    property bool compactMode: Math.min(root.height, root.width) < Scaler.s(110)

    readonly property bool hasBattery: UPower.displayDevice.ready ? UPower.displayDevice.isLaptopBattery : !SystemInfo.isDesktop
    readonly property int batCapacity: (UPower.displayDevice.ready && hasBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: hasBattery && UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    readonly property color batColor: {
        if (!hasBattery) return ThemeBackend.subtext0;
        if (isCharging) return ThemeBackend.green;
        if (batCapacity <= 20) return ThemeBackend.red;
        return ThemeBackend.blue;
    }

    readonly property string batIcon: {
        if (!hasBattery) return "󰂎";
        if (isCharging) return "󰂄";
        if (batCapacity > 80) return "󰁹";
        if (batCapacity > 60) return "󰂀";
        if (batCapacity > 40) return "󰁾";
        if (batCapacity > 20) return "󰁼";
        return "󰂃";
    }

    property real animCapacity: 0
    Behavior on animCapacity {
        enabled: root.visible
        NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
    }

    onBatCapacityChanged: animCapacity = hasBattery ? batCapacity : 0
    onHasBatteryChanged: animCapacity = hasBattery ? batCapacity : 0
    Component.onCompleted: animCapacity = hasBattery ? batCapacity : 0

    SystemUsageCircle {
        anchors.fill: parent
        value: root.animCapacity / 100
        accentColor: root.batColor
        icon: root.batIcon
        title: root.isCharging ? I18n.t("syspanel.battery.charging") : ""
        valueText: root.hasBattery ? Math.round(root.animCapacity) + "%" : "--"
        iconColor: root.batColor
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
