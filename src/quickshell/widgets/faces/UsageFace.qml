import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../reusables"
import "../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 260
    property real minHeight: 180
    property real maxWidth: 800
    property real maxHeight: 500
    property real minAspect: 1.15
    property real maxAspect: 2.5
    property bool isRound: false

    property bool isSubscribed: false
    property bool compactMode: root.height < Scaler.s(190) || root.width < Scaler.s(300)
    property real sp: Scaler.s(4)

    function cellX(mx) { return (mx * root.width) + (mx > 0 ? sp / 2 : 0); }
    function cellY(my) { return (my * root.height) + (my > 0 ? sp / 2 : 0); }
    function cellW(mx, mw) { return (mw * root.width) - ((mx > 0 ? sp / 2 : 0) + ((mx + mw) < 0.99 ? sp / 2 : 0)); }
    function cellH(my, mh) { return (mh * root.height) - ((my > 0 ? sp / 2 : 0) + ((my + mh) < 0.99 ? sp / 2 : 0)); }

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            SysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            SysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real globalWavePhase: 0.0
    NumberAnimation on globalWavePhase {
        from: 0
        to: Math.PI * 2
        duration: 1800
        loops: Animation.Infinite
        running: root.visible
    }

    property real rawCpu: isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawTemp: isNaN(SysData.temp) ? 0.0 : SysData.temp
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRam: isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real netRx: isNaN(SysData.netRx) ? 0 : SysData.netRx
    property real netTx: isNaN(SysData.netTx) ? 0 : SysData.netTx
    property string rxSpeedStr: root.formatBytes(netRx)
    property string txSpeedStr: root.formatBytes(netTx)

    property real rawDisk: isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property string diskUsedText: SysData.diskGb > 0 ? (SysData.diskGb.toFixed(1) + "G") : "..."
    property string diskTotalText: SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : ""

    function formatBytes(bytes) {
        if (bytes <= 0 || isNaN(bytes)) return "0 B/s";
        let k = 1024, sizes = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
    }

    SystemUsageCard {
        x: root.cellX(0.0)
        y: root.cellY(0.0)
        width: root.cellW(0.0, 0.333)
        height: root.cellH(0.0, 0.5)
        value: root.cpuUsage
        colorBase: ThemeBackend.surface0
        colorFill: Qt.lighter(ThemeBackend.mauve, 1.35)
        icon: "\uF2DB"
        title: I18n.t("quickactions.systemusage.cpu")
        valueText: Math.round(root.cpuUsage * 100) + "%"
        wavePhase: root.globalWavePhase
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }

    SystemUsageCard {
        x: root.cellX(0.333)
        y: root.cellY(0.0)
        width: root.cellW(0.333, 0.334)
        height: root.cellH(0.0, 0.5)
        value: root.ramUsage
        colorBase: ThemeBackend.surface0
        colorFill: Qt.lighter(ThemeBackend.mauve, 1.15)
        icon: "\uF538"
        title: I18n.t("quickactions.systemusage.ram")
        valueText: root.ramUsedGb.toFixed(1) + "G"
        wavePhase: root.globalWavePhase
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }

    SystemUsageCard {
        x: root.cellX(0.667)
        y: root.cellY(0.0)
        width: root.cellW(0.667, 0.333)
        height: root.cellH(0.0, 0.5)
        value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
        colorBase: ThemeBackend.surface0
        colorFill: ThemeBackend.mauve
        icon: "\uF2C9"
        title: I18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        wavePhase: root.globalWavePhase
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }

    SystemUsageCard {
        x: root.cellX(0.0)
        y: root.cellY(0.5)
        width: root.cellW(0.0, 0.5)
        height: root.cellH(0.5, 0.5)
        value: root.diskUsagePercent
        colorBase: ThemeBackend.surface0
        colorFill: Qt.darker(ThemeBackend.mauve, 1.15)
        icon: "\uF0A0"
        title: root.diskTotalText
        subText: root.diskUsedText
        valueText: Math.round(root.diskUsagePercent * 100) + "%"
        wavePhase: root.globalWavePhase
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }

    SystemUsageCard {
        id: netCard
        x: root.cellX(0.5)
        y: root.cellY(0.5)
        width: root.cellW(0.5, 0.5)
        height: root.cellH(0.5, 0.5)
        value: Math.min(1.0, (root.netRx + root.netTx) / (10 * 1024 * 1024))
        colorBase: ThemeBackend.surface0
        colorFill: Qt.darker(ThemeBackend.mauve, 1.35)
        icon: "󰤨"
        title: I18n.t("quickactions.systemusage.net")
        valueText: ""
        wavePhase: root.globalWavePhase
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s

        ColumnLayout {
            id: netCol
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.compactMode ? Scaler.s(2) : Scaler.s(4)
            spacing: Math.max(Scaler.s(2), Math.min(Scaler.s(6), netCard.height * 0.035))

            property real pillWidth: Math.min(netCard.width - Scaler.s(16), Math.max(Scaler.s(85), netCard.width * 0.74))
            property real pillHeight: Math.min(Scaler.s(28), Math.max(Scaler.s(18), netCard.height * 0.21))
            property real btnFontSize: Math.min(Scaler.s(12), Math.max(Scaler.s(8.5), netCard.height * 0.095))
            property real iconSize: Math.round(Math.max(Scaler.s(14), netCol.pillHeight - Scaler.s(4)))
            property real speedFontSize: Math.min(Scaler.s(11.5), Math.max(Scaler.s(8.5), netCard.height * 0.09))

            ClickButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Math.round(netCol.pillHeight)
                buttonText: SysData.isScanningNet ? "Scanning..." : "Scan"
                buttonIcon: SysData.isScanningNet ? "\uF110" : "\uF021"
                iconFontSize: Math.round(netCol.btnFontSize * 1.15)
                textFontSize: Math.round(netCol.btnFontSize)
                accentColor: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.7)
                textColor: ThemeBackend.text
                cornerRadius: Math.round(netCol.pillHeight / 2)
                horizontalPadding: Math.round(Math.max(Scaler.s(6), netCol.pillWidth * 0.08))
                enabled: !SysData.isScanningNet
                onClicked: SysData.scanNetwork()
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Math.round(netCol.pillHeight)
                Layout.preferredWidth: Math.round(netCol.pillWidth)
                radius: Math.round(netCol.pillHeight / 2)
                color: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.5)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(Scaler.s(3))
                    anchors.rightMargin: Math.round(Scaler.s(6))
                    spacing: Math.round(Scaler.s(4))

                    IconButton {
                        size: netCol.iconSize
                        cornerRadius: Math.round(netCol.iconSize / 2)
                        buttonIcon: "\uF063"
                        iconFontSize: Math.round(netCol.iconSize * 0.55)
                        accentColor: Qt.rgba(ThemeBackend.green.r, ThemeBackend.green.g, ThemeBackend.green.b, 0.2)
                        textColor: ThemeBackend.green
                        enabled: false
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.rxSpeedStr
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.round(netCol.speedFontSize)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Math.round(netCol.pillHeight)
                Layout.preferredWidth: Math.round(netCol.pillWidth)
                radius: Math.round(netCol.pillHeight / 2)
                color: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.5)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(Scaler.s(3))
                    anchors.rightMargin: Math.round(Scaler.s(6))
                    spacing: Math.round(Scaler.s(4))

                    IconButton {
                        size: netCol.iconSize
                        cornerRadius: Math.round(netCol.iconSize / 2)
                        buttonIcon: "\uF062"
                        iconFontSize: Math.round(netCol.iconSize * 0.55)
                        accentColor: Qt.rgba(ThemeBackend.peach.r, ThemeBackend.peach.g, ThemeBackend.peach.b, 0.2)
                        textColor: ThemeBackend.peach
                        enabled: false
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.txSpeedStr
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.round(netCol.speedFontSize)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
