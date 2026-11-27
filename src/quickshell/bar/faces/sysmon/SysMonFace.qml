import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    property string circleStyle: String(readSetting("sysmonStyle", "sysmon.style", "wave"))
    readonly property bool useSineWave: circleStyle !== "circle"

    property var activeStats: {
        if (widget && widget !== root && widget.sysmonStats !== undefined) return widget.sysmonStats;
        if (module && module.sysmonStats !== undefined) return module.sysmonStats;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (Array.isArray(bs.sysmonStats)) return bs.sysmonStats;
            if (bs.sysmon && Array.isArray(bs.sysmon.stats)) return bs.sysmon.stats;
            if (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined) {
                let stats = [];
                if (bs.sysmonShowCpu !== false) stats.push("cpu");
                if (bs.sysmonShowRam !== false) stats.push("ram");
                if (bs.sysmonShowTemp !== false) stats.push("temp");
                if (bs.sysmonShowDisk === true) stats.push("disk");
                return stats;
            }
        }
        return ["cpu", "ram", "temp"];
    }

    property bool showLayout: (!barWindow || isPreview) ? true : false
    property int circleSize: s(isCompact ? 22 : 28)

    property bool isSysVisible: moduleActive && showLayout
    property color basePrimary: (ThemeBackend.primary !== undefined && ThemeBackend.primary !== "") ? ThemeBackend.primary : ThemeBackend.mauve

    SubscriptionGate {
        target: SysData
        wanted: root.isSysVisible
    }

    readonly property real layoutLength: isVertical ? sysLayout.implicitHeight : sysLayout.implicitWidth
    property real targetLength: (moduleActive && layoutLength > 0) ? (layoutLength + s(isCompact ? 8 : 10)) : 0
    property bool isFaceVisible: showLayout && targetLength > 0

    function syncImplicitSize() {
        let cross = module ? module.thickness : (parent ? (isVertical ? parent.width : parent.height) : 0);
        implicitWidth = isVertical ? cross : targetLength;
        implicitHeight = isVertical ? targetLength : cross;
    }

    onTargetLengthChanged: syncImplicitSize()
    onIsVerticalChanged: syncImplicitSize()
    onModuleChanged: syncImplicitSize()
    onParentChanged: syncImplicitSize()

    Component.onCompleted: Qt.callLater(root.syncImplicitSize)

    Timer {
        running: root.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady && !root.showLayout
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: (root.isVertical || root.showLayout) ? 0 : root.s(60)
        y: (!root.isVertical || root.showLayout) ? 0 : root.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    component SysMonCircle: Rectangle {
        id: circleRoot
        property real value: 0
        property string textVal: ""
        property string icon: ""
        property color accentColor: root.basePrimary
        property bool showText: textVal !== ""
        property bool useSineWave: root.useSineWave
        property bool initAnimTrigger: (!barWindow || root.isPreview)

        property real animValue: initAnimTrigger ? value : 0
        Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

        property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))

        implicitWidth: root.circleSize
        implicitHeight: root.circleSize
        width: implicitWidth
        height: implicitHeight
        radius: width / 2
        color: "transparent"

        Timer {
            running: root.moduleActive && root.showLayout && !initAnimTrigger
            interval: 150
            onTriggered: initAnimTrigger = true
        }

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            x: (!root.isVertical || initAnimTrigger) ? 0 : root.s(15)
            y: (root.isVertical || initAnimTrigger) ? 0 : root.s(15)
            Behavior on x { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        ShaderEffect {
            id: circleGauge
            anchors.fill: parent

            property vector2d itemSize: Qt.vector2d(width, height)
            property real fillRatio: circleRoot.fillRatio
            property real strokeWidth: root.s(2.2)
            property real useSineWave: circleRoot.useSineWave ? 1.0 : 0.0
            property color accentColor: circleRoot.accentColor
            property vector4d params: Qt.vector4d(root.s(0.9), 0.0, 0.0, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/gauges/circular_wave_gauge.frag.qsb"
        }

        Text {
            anchors.centerIn: parent
            text: circleRoot.showText ? circleRoot.textVal : circleRoot.icon
            font.pixelSize: Math.round(circleRoot.showText
                ? root.s(root.isCompact ? 7.5 : 9)
                : root.s(root.isCompact ? 9 : 11))
            font.bold: circleRoot.showText
            font.family: circleRoot.showText
                ? ((ThemeBackend.fontFamily !== undefined && ThemeBackend.fontFamily !== "") ? ThemeBackend.fontFamily : "sans-serif")
                : ThemeBackend.iconFont
            color: (ThemeBackend.text !== undefined && ThemeBackend.text !== "") ? ThemeBackend.text : "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    AxisFlow {
        id: sysLayout
        vertical: root.isVertical
        anchors.centerIn: parent
        spacing: root.s(root.isCompact ? 5 : 6)
        property int circleSize: root.circleSize

        Repeater {
            model: root.activeStats

            SysMonCircle {
                readonly property string statType: modelData
                value: {
                    if (statType === "cpu") return isNaN(SysData.cpu) ? 0 : SysData.cpu / 100.0;
                    if (statType === "ram") return isNaN(SysData.ramPercent) ? 0 : SysData.ramPercent / 100.0;
                    if (statType === "temp") return isNaN(SysData.temp) ? 0 : Math.max(0, Math.min(1, SysData.temp / 100.0));
                    if (statType === "disk") return isNaN(SysData.diskPercent) ? 0 : SysData.diskPercent / 100.0;
                    return 0;
                }
                textVal: {
                    if (statType === "temp") return isNaN(SysData.temp) ? "0" : Math.round(SysData.temp).toString();
                    return "";
                }
                icon: {
                    if (statType === "cpu") return String.fromCodePoint(0xF035B);
                    if (statType === "ram") return String.fromCodePoint(0xF035C);
                    if (statType === "temp") return String.fromCodePoint(0xF050F);
                    if (statType === "disk") return String.fromCodePoint(0xF0A0);
                    return "";
                }
                accentColor: {
                    if (statType === "cpu") return Qt.tint(root.basePrimary, Qt.rgba(1.0, 0.22, 0.22, 0.25));
                    if (statType === "ram") return Qt.lighter(root.basePrimary, 1.15);
                    if (statType === "temp") return Qt.darker(root.basePrimary, 1.15);
                    if (statType === "disk") return Qt.darker(root.basePrimary, 1.35);
                    return root.basePrimary;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: !root.isPreview
        onClicked: {
            FloatingController.showSystemUsage(root.barWindow ? root.barWindow.screen : null);
        }
    }
}
