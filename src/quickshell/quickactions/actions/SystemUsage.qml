import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: root

    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property var requestedLayoutTemplate: [
        { x: 0.0, y: 0.0, w: 0.333, h: 0.5 },
        { x: 0.333, y: 0.0, w: 0.334, h: 0.5 },
        { x: 0.667, y: 0.0, w: 0.333, h: 0.5 },
        { x: 0.0, y: 0.5, w: 0.5, h: 0.5 },
        { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }
    ]

    property real baseW: s(360)
    property real baseL: s(250)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 80 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property real sp: s(10)
    function cellX(mx) { return (mx * orientedRoot.width) + (mx > 0 ? sp / 2 : 0); }
    function cellY(my) { return (my * orientedRoot.height) + (my > 0 ? sp / 2 : 0); }
    function cellW(mx, mw) { return (mw * orientedRoot.width) - ((mx > 0 ? sp / 2 : 0) + ((mx + mw) < 0.99 ? sp / 2 : 0)); }
    function cellH(my, mh) { return (mh * orientedRoot.height) - ((my > 0 ? sp / 2 : 0) + ((my + mh) < 0.99 ? sp / 2 : 0)); }

    property color cBase: ThemeBackend.base
    property color cCrust: ThemeBackend.crust
    property color cSurface0: ThemeBackend.surface0
    property color cSurface1: ThemeBackend.surface1
    property color cText: ThemeBackend.text
    property color cSubtext0: ThemeBackend.subtext0
    property color cMauve: ThemeBackend.mauve
    property color cSapphire: ThemeBackend.sapphire
    property color cGreen: ThemeBackend.green
    property color cPeach: ThemeBackend.peach
    property color cYellow: ThemeBackend.yellow
    property color cRed: ThemeBackend.red

    property color accent: cMauve
    property color textPrimary: cText
    property color textSecondary: cSubtext0
    property color bgSurface: cSurface0
    property string iconFont: "Iosevka Nerd Font"

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    property bool widgetVisible: parent !== null && parent.visible !== undefined ? parent.visible : true
    property bool isSubscribed: false

    function updateSubscription() {
        if (root.widgetVisible && !root.isSubscribed) {
            SysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.widgetVisible && root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onWidgetVisibleChanged: {
        updateSubscription();
        if (root.widgetVisible) {
            Sounds.playSfx("quickactions/usage.wav", 0.25);
        }
    }
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real globalWavePhase: 0.0
    NumberAnimation on globalWavePhase {
        from: 0; to: Math.PI * 2; duration: 1800; loops: Animation.Infinite; running: root.widgetVisible
    }

    property real rawCpu: isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: root.widgetVisible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawTemp: isNaN(SysData.temp) ? 0.0 : SysData.temp
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.widgetVisible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRam: isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.widgetVisible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.widgetVisible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real netRx: isNaN(SysData.netRx) ? 0 : SysData.netRx
    property real netTx: isNaN(SysData.netTx) ? 0 : SysData.netTx

    property string rxSpeedStr: root.formatBytes(netRx)
    property string txSpeedStr: root.formatBytes(netTx)

    property real rawDisk: isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.widgetVisible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property string diskUsedText: SysData.diskGb > 0 ? (SysData.diskGb.toFixed(1) + "G") : "..."
    property string diskTotalText: SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : ""

    function formatBytes(bytes) {
        if (bytes <= 0 || isNaN(bytes)) return "0 B/s";
        let k = 1024, sizes = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: false

        SystemUsageCard {
            x: root.cellX(0.0)
            y: root.cellY(0.0)
            width: root.cellW(0.0, 0.333)
            height: root.cellH(0.0, 0.5)

            value: root.cpuUsage
            colorFill: Qt.lighter(root.cMauve, 1.35)
            icon: "\uF2DB"
            title: I18n.t("quickactions.systemusage.cpu")
            valueText: Math.round(root.cpuUsage * 100) + "%"
            wavePhase: root.globalWavePhase
            isLive: root.widgetVisible
            scaleFunc: root.s
        }

        SystemUsageCard {
            x: root.cellX(0.333)
            y: root.cellY(0.0)
            width: root.cellW(0.333, 0.334)
            height: root.cellH(0.0, 0.5)

            value: root.ramUsage
            colorFill: Qt.lighter(root.cMauve, 1.15)
            icon: "\uF538"
            title: I18n.t("quickactions.systemusage.ram")
            valueText: root.ramUsedGb.toFixed(1) + "G"
            wavePhase: root.globalWavePhase
            isLive: root.widgetVisible
            scaleFunc: root.s
        }

        SystemUsageCard {
            x: root.cellX(0.667)
            y: root.cellY(0.0)
            width: root.cellW(0.667, 0.333)
            height: root.cellH(0.0, 0.5)

            value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
            colorFill: root.cMauve
            icon: "\uF2C9"
            title: I18n.t("quickactions.systemusage.temp")
            valueText: Math.round(root.tempC) + "°"
            wavePhase: root.globalWavePhase
            isLive: root.widgetVisible
            scaleFunc: root.s
        }

        SystemUsageCard {
            x: root.cellX(0.0)
            y: root.cellY(0.5)
            width: root.cellW(0.0, 0.5)
            height: root.cellH(0.5, 0.5)

            value: root.diskUsagePercent
            colorFill: Qt.darker(root.cMauve, 1.15)
            icon: "\uF0A0"
            title: root.diskTotalText
            midText: ""
            subText: root.diskUsedText
            valueText: Math.round(root.diskUsagePercent * 100) + "%"
            wavePhase: root.globalWavePhase
            isLive: root.widgetVisible
            scaleFunc: root.s
        }

        SystemUsageCard {
            x: root.cellX(0.5)
            y: root.cellY(0.5)
            width: root.cellW(0.5, 0.5)
            height: root.cellH(0.5, 0.5)

            value: 0.12
            colorFill: Qt.darker(root.cMauve, 1.35)
            icon: "󰤨"
            title: I18n.t("quickactions.systemusage.net")
            valueText: ""
            wavePhase: root.globalWavePhase
            isLive: root.widgetVisible
            scaleFunc: root.s

            ColumnLayout {
                anchors.centerIn: parent
                spacing: root.s(6)

                ClickButton {
                    Layout.alignment: Qt.AlignHCenter
                    buttonText: SysData.isScanningNet ? "Scanning..." : "Scan"
                    buttonIcon: SysData.isScanningNet ? "\uF110" : "\uF021"
                    iconFontSize: Math.round(root.s(14))
                    textFontSize: Math.round(root.s(12))
                    accentColor: root.alpha(root.cSurface1, 0.7)
                    textColor: root.cText
                    cornerRadius: Math.round(root.s(8))
                    horizontalPadding: Math.round(root.s(10))
                    enabled: !SysData.isScanningNet
                    onClicked: SysData.scanNetwork()
                }

                Rectangle {
                    Layout.preferredHeight: root.s(28)
                    Layout.preferredWidth: root.s(125)
                    radius: root.s(14)
                    color: root.alpha(root.cSurface1, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(3)
                        spacing: root.s(6)

                        IconButton {
                            size: Math.round(root.s(22))
                            cornerRadius: Math.round(root.s(11))
                            buttonIcon: "\uF063"
                            iconFontSize: Math.round(root.s(12))
                            accentColor: root.alpha(root.cGreen, 0.2)
                            textColor: root.cGreen
                            enabled: false
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.rxSpeedStr
                            color: root.textPrimary
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: root.s(28)
                    Layout.preferredWidth: root.s(125)
                    radius: root.s(14)
                    color: root.alpha(root.cSurface1, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(3)
                        spacing: root.s(6)

                        IconButton {
                            size: Math.round(root.s(22))
                            cornerRadius: Math.round(root.s(11))
                            buttonIcon: "\uF062"
                            iconFontSize: Math.round(root.s(12))
                            accentColor: root.alpha(root.cPeach, 0.2)
                            textColor: root.cPeach
                            enabled: false
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.txSpeedStr
                            color: root.textPrimary
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
