import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Services.UPower
import "../../reusables"
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 110
    property real minHeight: 110
    property real maxWidth: 460
    property real maxHeight: 460
    property real minAspect: 1.0
    property real maxAspect: 1.0

    readonly property bool hasBattery: UPower.displayDevice.ready ? UPower.displayDevice.isLaptopBattery : !SystemInfo.isDesktop
    readonly property int batCapacity: (UPower.displayDevice.ready && hasBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: hasBattery && UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    readonly property color ringColor: {
        if (!hasBattery) return ThemeBackend.subtext0;
        if (isCharging) return ThemeBackend.green;
        if (batCapacity <= 20) return ThemeBackend.red;
        return ThemeBackend.blue;
    }

    property real level: 0

    Behavior on level {
        enabled: root.visible
        NumberAnimation {
            duration: 1100
            easing.type: Easing.OutQuint
        }
    }

    onBatCapacityChanged: {
        if (root.visible && hasBattery) level = batCapacity / 100;
    }

    Component.onCompleted: {
        if (hasBattery) level = batCapacity / 100;
    }

    readonly property string statusText: {
        if (!hasBattery) return "AC power";
        if (UPower.displayDevice.ready && UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return "Full";
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        if (!secs || secs <= 0 || isNaN(secs)) return isCharging ? "Charging" : "On battery";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return (h > 0 ? h + "h " : "") + m + "m";
    }

    readonly property real ringSize: Math.min(root.width, root.height * 0.78)

    Shape {
        id: ring
        width: root.ringSize
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.height * 0.06
        preferredRendererType: Shape.CurveRenderer
        opacity: root.hasBattery ? 1.0 : 0.45

        readonly property real thickness: Math.max(3, width * 0.075)
        readonly property real inset: thickness / 2

        ShapePath {
            strokeColor: ThemeBackend.surface1
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: ring.width / 2 + ring.inset
            startY: ring.inset
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.inset
                radiusY: ring.height / 2 - ring.inset
                startAngle: 90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: ring.width / 2 + ring.inset
            startY: ring.inset
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.inset
                radiusY: ring.height / 2 - ring.inset
                startAngle: 90
                sweepAngle: -Math.max(0, Math.min(1, root.level)) * 360
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: ring
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hasBattery ? Math.round(root.level * 100) + "%" : "--"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(14, ring.width * 0.24)
            font.weight: Font.Black
            color: ThemeBackend.text
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: ring.width * 0.82
            text: root.statusText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(9, ring.width * 0.105)
            font.weight: Font.DemiBold
            color: root.isCharging ? ThemeBackend.green : ThemeBackend.subtext0
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
