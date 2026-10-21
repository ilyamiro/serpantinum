import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
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

    property string btStyle: {
        if (widget && widget !== root && widget.btStyle !== undefined) return widget.btStyle;
        if (module && module.btStyle !== undefined) return module.btStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.btStyle) return bs.btStyle;
            if (bs.bt && bs.bt.style) return bs.bt.style;
        }
        return "button";
    }

    property bool showIcon: {
        if (widget && widget !== root && widget.btShowIcon !== undefined) return widget.btShowIcon;
        if (widget && widget !== root && widget.showIcon !== undefined) return widget.showIcon;
        if (module && module.btShowIcon !== undefined) return module.btShowIcon;
        if (module && module.showIcon !== undefined) return module.showIcon;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.btShowIcon !== undefined) return Boolean(bs.btShowIcon);
            if (bs.bt && bs.bt.showIcon !== undefined) return Boolean(bs.bt.showIcon);
        }
        return true;
    }

    property bool showName: {
        if (widget && widget !== root && widget.btShowName !== undefined) return widget.btShowName;
        if (widget && widget !== root && widget.showName !== undefined) return widget.showName;
        if (module && module.btShowName !== undefined) return module.btShowName;
        if (module && module.showName !== undefined) return module.showName;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.btShowName !== undefined) return Boolean(bs.btShowName);
            if (bs.bt && bs.bt.showName !== undefined) return Boolean(bs.bt.showName);
        }
        return true;
    }

    property bool isDesktop: false
    property bool showLayout: (!barWindow || isPreview) ? true : ((!module || module.moduleActive) && barWindow.isStartupReady && barWindow.isDataReady)
    property alias btPill: btBtn
    property string btStatus: isPreview ? "On" : "Off"
    property string btIcon: isPreview ? "🎧" : "󰂲"
    property string btDevice: isPreview ? "Headphones" : "Off"
    property bool isBtOn: isPreview ? true : (btStatus.toLowerCase() === "enabled" || btStatus.toLowerCase() === "on")
    property bool isConnected: isPreview ? true : false

    Component.onCompleted: {
        updateBtData();
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && module.moduleActive) {
                root.updateBtData();
            }
        }
    }

    function getBtDevicesList() {
        let adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.devices) return [];
        let devs = adapter.devices.values || adapter.devices;
        let list = [];
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (d) list.push(d);
        }
        return list;
    }

    function updateBtData() {
        let adapter = Bluetooth.defaultAdapter;
        let enabled = adapter ? adapter.enabled : false;

        if (!enabled) {
            btStatus = "Off";
            btIcon = "󰂲";
            btDevice = "Off";
            isConnected = false;
            return;
        }

        btStatus = "On";

        let connectedDev = null;
        let devList = getBtDevicesList();

        for (let i = 0; i < devList.length; i++) {
            let d = devList[i];
            if (d && d.connected) {
                connectedDev = d;
                break;
            }
        }

        if (connectedDev) {
            let name = connectedDev.name || connectedDev.deviceName || connectedDev.address || "";
            let iconType = connectedDev.icon || "";
            let typeLower = iconType.toLowerCase();
            let nameLower = name.toLowerCase();

            let icon = "󰂯";
            if (typeLower.indexOf("headset") !== -1 || typeLower.indexOf("headphone") !== -1 || nameLower.indexOf("headphone") !== -1 || nameLower.indexOf("buds") !== -1 || nameLower.indexOf("pods") !== -1) icon = "🎧";
            else if (typeLower.indexOf("audio") !== -1 || typeLower.indexOf("speaker") !== -1 || typeLower.indexOf("card") !== -1 || nameLower.indexOf("speaker") !== -1) icon = "📻";
            else if (typeLower.indexOf("phone") !== -1 || nameLower.indexOf("phone") !== -1 || nameLower.indexOf("iphone") !== -1 || nameLower.indexOf("android") !== -1) icon = "📱";
            else if (typeLower.indexOf("mouse") !== -1 || nameLower.indexOf("mouse") !== -1) icon = "󰍽";
            else if (typeLower.indexOf("keyboard") !== -1 || nameLower.indexOf("keyboard") !== -1) icon = "⌨️";
            else if (typeLower.indexOf("controller") !== -1 || nameLower.indexOf("controller") !== -1) icon = "🎮";

            btIcon = icon;
            btDevice = name;
            isConnected = true;
        } else {
            btIcon = "󰂯";
            btDevice = "On";
            isConnected = false;
        }
    }

    Item {
        visible: false
        Connections {
            target: Bluetooth
            ignoreUnknownSignals: true
            function onDefaultAdapterChanged() { root.updateBtData(); }
        }
        Connections {
            target: Bluetooth.defaultAdapter || null
            ignoreUnknownSignals: true
            function onEnabledChanged() { root.updateBtData(); }
            function onDiscoveringChanged() { root.updateBtData(); }
            function onDevicesChanged() { root.updateBtData(); }
        }
        Connections {
            target: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.devices) ? Bluetooth.defaultAdapter.devices : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { root.updateBtData(); }
            function onObjectRemovedPost(object, index) { root.updateBtData(); }
            function onCountChanged() { root.updateBtData(); }
        }
        Repeater {
            id: btDeviceRepeater
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
            Item {
                property var device: modelData
                Component.onCompleted: root.updateBtData()
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onConnectedChanged() { root.updateBtData(); }
                    function onStateChanged() { root.updateBtData(); }
                    function onPairedChanged() { root.updateBtData(); }
                    function onNameChanged() { root.updateBtData(); }
                    function onDeviceNameChanged() { root.updateBtData(); }
                    function onIconChanged() { root.updateBtData(); }
                }
            }
        }
    }

    property real targetHeight: {
        if (module && !module.moduleActive) return 0;
        if (root.isDesktop) return 0;
        if (root.btStyle === "text") {
            return (sideTextCol.implicitHeight > 0) ? (sideTextCol.implicitHeight + s(root.isCompact ? 14 : 16)) : 0;
        }
        return (btBtn.height > 0) ? (btBtn.height + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && !isDesktop && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    MouseArea {
        id: sideTextMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.btStyle === "text" && !root.isPreview
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network bt"])
    }

    Column {
        id: sideTextCol
        visible: root.btStyle === "text"
        anchors.centerIn: parent
        spacing: s(root.isCompact ? 2 : 3)
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
            visible: root.showIcon
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.btIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(root.isCompact ? 14 : 15)
            color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.15) : (root.isBtOn ? ThemeBackend.mauve : ThemeBackend.subtext0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: root.showName
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.btDevice.length > 6 ? (root.btDevice.substring(0, 5) + "…") : root.btDevice
            font.family: "Monocraft"
            font.pixelSize: s(root.isCompact ? 9 : 10)
            font.bold: true
            color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    ClickButton {
        mcStyle: true
        id: btBtn
        visible: root.btStyle !== "text"
        anchors.centerIn: parent
        width: s(root.isCompact ? 28 : 30)
        height: (root.showIcon || root.showName) ? s(root.isCompact ? 28 : 30) : 0
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
        horizontalPadding: 0
        buttonIcon: root.showIcon ? root.btIcon : ""
        iconFontSize: s(root.isCompact ? 14 : 15)
        buttonText: (!root.showIcon && root.showName) ? (root.btDevice.length > 3 ? root.btDevice.substring(0, 3) : root.btDevice) : ""
        textFontSize: s(root.isCompact ? 9 : 10)
        accentColor: root.isBtOn ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: root.isBtOn ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network bt"])
    }
}
