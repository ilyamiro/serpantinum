import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (activeTarget && typeof activeTarget.s === "function") return activeTarget.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string wifiStyle: {
        if (widget && widget !== root && widget.wifiStyle !== undefined) return widget.wifiStyle;
        if (module && module.wifiStyle !== undefined) return module.wifiStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.wifiStyle) return bs.wifiStyle;
            if (bs.wifi && bs.wifi.style) return bs.wifi.style;
        }
        return "button";
    }

    property bool showIcon: {
        if (widget && widget !== root && widget.wifiShowIcon !== undefined) return widget.wifiShowIcon;
        if (widget && widget !== root && widget.showIcon !== undefined) return widget.showIcon;
        if (module && module.wifiShowIcon !== undefined) return module.wifiShowIcon;
        if (module && module.showIcon !== undefined) return module.showIcon;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.wifiShowIcon !== undefined) return Boolean(bs.wifiShowIcon);
            if (bs.wifi && bs.wifi.showIcon !== undefined) return Boolean(bs.wifi.showIcon);
        }
        return true;
    }

    property bool showName: {
        if (widget && widget !== root && widget.wifiShowName !== undefined) return widget.wifiShowName;
        if (widget && widget !== root && widget.showName !== undefined) return widget.showName;
        if (module && module.wifiShowName !== undefined) return module.wifiShowName;
        if (module && module.showName !== undefined) return module.showName;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.wifiShowName !== undefined) return Boolean(bs.wifiShowName);
            if (bs.wifi && bs.wifi.showName !== undefined) return Boolean(bs.wifi.showName);
        }
        return true;
    }

    property bool isDesktop: false
    property string ethStatus: "Ethernet"
    property string wifiStatus: isPreview ? "Enabled" : "Off"
    property string wifiIcon: isPreview ? "󰤨" : "󰤮"
    property string wifiSsid: isPreview ? "Home-WiFi" : ""
    property bool isWifiOn: isPreview ? true : Networking.wifiEnabled
    property bool showEthernet: !isPreview && (ethStatus === "Connected" || (isDesktop && !isWifiOn))
    property bool showLayout: (!barWindow || isPreview) ? true : ((!module || module.moduleActive) && barWindow.isStartupReady && barWindow.isDataReady)
    property alias wifiPill: wifiPill

    property var ethDevice: null
    property var wifiDevice: null

    Component.onCompleted: {
        findDevices();
        updateNetworkData();
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                chassisDetector.running = false;
            } else {
                chassisDetector.running = true;
                root.findDevices();
                root.updateNetworkData();
            }
        }
    }

    Process {
        id: chassisDetector
        running: !module || module.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    function isEthDevice(dev) {
        return !!dev && dev.type === DeviceType.Wired;
    }

    function isWifiDevice(dev) {
        return !!dev && dev.type === DeviceType.Wifi;
    }

    function findDevices() {
        if (!Networking || !Networking.devices) return;
        let devs = Networking.devices.values || Networking.devices;
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (!d) continue;
            if (!root.ethDevice && isEthDevice(d)) {
                root.ethDevice = d;
            } else if (!root.wifiDevice && isWifiDevice(d)) {
                root.wifiDevice = d;
            }
        }
    }

    function getWifiNetworksList() {
        if (!wifiDevice || !wifiDevice.networks) return [];
        let nets = wifiDevice.networks.values || wifiDevice.networks;
        let list = [];
        let count = nets.length !== undefined ? nets.length : (nets.count !== undefined ? nets.count : 0);
        for (let i = 0; i < count; i++) {
            let n = nets[i] !== undefined ? nets[i] : (nets.get ? nets.get(i) : null);
            if (n) list.push(n);
        }
        return list;
    }

    function updateNetworkData() {
        findDevices();

        let isWifiEnabled = Networking.wifiEnabled;
        wifiStatus = isWifiEnabled ? "Enabled" : "Off";

        if (ethDevice) {
            if (ethDevice.connected) {
                ethStatus = "Connected";
            } else if (ethDevice.hasLink) {
                ethStatus = "Disconnected";
            } else {
                ethStatus = "Ethernet";
            }
        } else {
            ethStatus = "Ethernet";
        }

        if (!isWifiEnabled) {
            wifiSsid = "";
            wifiIcon = "󰤮";
            return;
        }

        let connectedNet = null;
        let netList = getWifiNetworksList();
        for (let i = 0; i < netList.length; i++) {
            let n = netList[i];
            if (n && n.connected) {
                connectedNet = n;
                break;
            }
        }

        if (connectedNet) {
            wifiSsid = connectedNet.name || connectedNet.ssid || "";
            let sig = connectedNet.signalStrength !== undefined ? Math.round(connectedNet.signalStrength * (connectedNet.signalStrength <= 1 ? 100 : 1)) : 100;
            if (sig >= 80) wifiIcon = "󰤨";
            else if (sig >= 60) wifiIcon = "󰤥";
            else if (sig >= 40) wifiIcon = "󰤢";
            else if (sig >= 20) wifiIcon = "󰤟";
            else wifiIcon = "󰤯";
        } else {
            wifiSsid = "";
            wifiIcon = "󰤯";
        }
    }

    Item {
        visible: false

        Connections {
            target: Networking
            ignoreUnknownSignals: true
            function onWifiEnabledChanged() { root.updateNetworkData(); }
            function onDevicesChanged() {
                root.findDevices();
                root.updateNetworkData();
            }
        }

        Connections {
            target: Networking.devices || null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) {
                root.findDevices();
                root.updateNetworkData();
            }
            function onObjectRemovedPost(object, index) {
                root.findDevices();
                root.updateNetworkData();
            }
            function onCountChanged() {
                root.findDevices();
                root.updateNetworkData();
            }
        }

        Connections {
            target: root.ethDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { root.updateNetworkData(); }
            function onStateChanged() { root.updateNetworkData(); }
            function onHasLinkChanged() { root.updateNetworkData(); }
        }

        Connections {
            target: root.wifiDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { root.updateNetworkData(); }
            function onStateChanged() { root.updateNetworkData(); }
            function onNetworksChanged() { root.updateNetworkData(); }
        }

        Connections {
            target: (root.wifiDevice && root.wifiDevice.networks) ? root.wifiDevice.networks : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { root.updateNetworkData(); }
            function onObjectRemovedPost(object, index) { root.updateNetworkData(); }
            function onCountChanged() { root.updateNetworkData(); }
        }

        Repeater {
            id: netDeviceRepeater
            model: Networking.devices
            Item {
                property var device: modelData
                Component.onCompleted: {
                    if (device && device.type === DeviceType.Wired) {
                        root.ethDevice = device;
                    } else if (device && device.type === DeviceType.Wifi) {
                        root.wifiDevice = device;
                    }
                    root.updateNetworkData();
                }
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onStateChanged() { root.updateNetworkData(); }
                    function onConnectedChanged() { root.updateNetworkData(); }
                    function onHasLinkChanged() { root.updateNetworkData(); }
                }
            }
        }

        Repeater {
            id: wifiNetworkRepeater
            model: root.wifiDevice ? root.wifiDevice.networks : null
            Item {
                property var network: modelData
                Component.onCompleted: root.updateNetworkData()
                Connections {
                    target: network || null
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { root.updateNetworkData(); }
                    function onStateChanged() { root.updateNetworkData(); }
                    function onConnectedChanged() { root.updateNetworkData(); }
                    function onNameChanged() { root.updateNetworkData(); }
                    function onSsidChanged() { root.updateNetworkData(); }
                }
            }
        }
    }

    property string effectiveIcon: root.showEthernet ? "󰈀" : root.wifiIcon
    property string effectiveName: root.showEthernet ? root.ethStatus : ((root.isWifiOn ? (root.wifiSsid !== "" ? root.wifiSsid : "On") : "Off"))
    readonly property bool isActive: root.showEthernet ? (root.ethStatus === "Connected") : root.isWifiOn

    property real targetWidth: {
        if (module && !module.moduleActive) return 0;
        if (root.wifiStyle === "text") {
            return (textRow.implicitWidth > 0) ? (textRow.implicitWidth + s(root.isCompact ? 12 : 16)) : 0;
        }
        return (sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    transform: Translate {
        x: root.showLayout ? 0 : s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: textMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.wifiStyle === "text" && !root.isPreview
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"])
    }

    Row {
        id: textRow
        visible: root.wifiStyle === "text"
        anchors.centerIn: parent
        spacing: s(root.isCompact ? 5 : 6)
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Item {
            visible: root.showIcon
            width: s(root.isCompact ? 18 : 20)
            height: width
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.effectiveIcon
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(root.isCompact ? 14 : 15)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.blue, 1.15) : (root.isActive ? ThemeBackend.blue : ThemeBackend.subtext0)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        Text {
            visible: root.showName
            text: root.effectiveName
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(root.isCompact ? 11 : 12)
            font.bold: true
            color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Row {
        id: sysLayout
        visible: root.wifiStyle !== "text"
        anchors.centerIn: parent
        property int pillHeight: s(root.isCompact ? 28 : 30)

        ClickButton {
            id: wifiPill
            contentSpacing: s(8)
            property bool initAnimTrigger: root.showLayout
            property bool isActive: root.isActive

            height: sysLayout.pillHeight
            maxWidth: s(root.isCompact ? 156 : 160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
            horizontalPadding: s(root.isCompact ? 10 : 12)
            buttonIcon: root.showIcon ? root.effectiveIcon : ""
            iconFontSize: s(root.isCompact ? 14 : 15)
            buttonText: root.showName ? root.effectiveName : ""
            textFontSize: s(root.isCompact ? 11 : 12)
            accentColor: isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: (root.showIcon || root.showName) ? implicitWidth : 0
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"])
        }
    }
}
