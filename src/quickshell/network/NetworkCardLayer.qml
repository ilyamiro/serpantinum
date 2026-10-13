import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import "../"
import "../reusables"

Item {
    required property var window
    required property Item orbitContainer
    required property var coreRepeater
    property alias repeater: orbitRepeater
    anchors.fill: parent
    opacity: window.currentPower ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    Repeater {
        id: orbitRepeater
        model: window.orbitModel

        delegate: Item {
            id: floatCardDelegateContainer
            width: window.s(150); height: window.s(52)

            property bool isCardHovered: false
            property bool isLoaded: false
            opacity: (isLoaded && window.currentPower) ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

            property real entryAnim: isLoaded ? 1.0 : 0.0
            Behavior on entryAnim { enabled: window.visible; NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

            Connections {
                target: window
                function onVisibleChanged() {
                    if (!window.visible) {
                        floatCardDelegateContainer.isLoaded = false;
                    }
                }
                function onCurrentPowerChanged() {
                    if (!window.currentPower) {
                        floatCardDelegateContainer.isLoaded = false;
                    }
                }
            }

            Timer {
                id: entranceTimer
                running: window.visible && window.currentPower && !floatCardDelegateContainer.isLoaded
                interval: window.activeMode === "eth" ? (400 + (index * 60)) : (40 + (index * 30))
                onTriggered: floatCardDelegateContainer.isLoaded = true
            }

            Component.onCompleted: {
                if (window.visible && window.currentPower) {
                    entranceTimer.restart();
                }
            }

            property int myParentIdx: (typeof model !== "undefined" && model !== null && typeof model.parentIndex !== "undefined") ? model.parentIndex : ((typeof parentIndex !== "undefined" && parentIndex !== null) ? parentIndex : -1)

            property int siblingsCount: {
                let c = 0;
                let m = window.orbitModel;
                if (m && typeof m.count === "number") {
                    for (let i = 0; i < m.count; i++) {
                        let d = m.get(i);
                        if (d && (typeof d.parentIndex !== "undefined" ? d.parentIndex : -1) === myParentIdx) c++;
                    }
                }
                return Math.max(1, c);
            }
            property int localIndex: {
                let idx = 0;
                let m = window.orbitModel;
                if (m && typeof m.count === "number" && typeof index === "number") {
                    for (let i = 0; i < index && i < m.count; i++) {
                        let d = m.get(i);
                        if (d && (typeof d.parentIndex !== "undefined" ? d.parentIndex : -1) === myParentIdx) idx++;
                    }
                }
                return idx;
            }

            property real unifiedRatio: window.activeMode === "wifi" || window.activeMode === "eth" ? 0.0 : window.multiTransitionState

            property real activeCount: (unifiedRatio > 0.5 && myParentIdx !== -1) ? siblingsCount : window.orbitModel.count
            property real dynamicScale: activeCount > 10 ? Math.max(0.6, 12.0 / activeCount) : (unifiedRatio > 0.5 ? (window.activeCoreCount > 2 ? 0.7 : 0.8) : 1.0)

            property real safeMultiShift: window.activeMode === "wifi" || window.activeMode === "eth" ? 0.0 : window.multiTransitionState
            property var pItem: (myParentIdx !== -1 && myParentIdx >= 0 && myParentIdx < coreRepeater.count) ? coreRepeater.itemAt(myParentIdx) : null

            property real safeParentX: (pItem && !isNaN(pItem.x)) ? (orbitContainer.width / 2) + (Math.cos(parentCoreAngle) * (pItem.myOrbitRadiusX || 0) * safeMultiShift * (pItem.activeTransition || 0)) : (orbitContainer.width / 2)
            property real safeParentY: (pItem && !isNaN(pItem.y)) ? (orbitContainer.height / 2) + (Math.sin(parentCoreAngle) * (pItem.myOrbitRadiusY || 0) * safeMultiShift * (pItem.activeTransition || 0)) : (orbitContainer.height / 2)

            property real parentBaseAngle: pItem ? pItem.animatedBaseAngle : 0

            property real targetSingleBaseAngle: (index / Math.max(1, window.orbitModel.count)) * Math.PI * 2
            property real singleBaseAngle: targetSingleBaseAngle
            Behavior on singleBaseAngle { enabled: window.visible; NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }

            property real singleLiveAngle: (window.globalOrbitAngle * 1.5) + singleBaseAngle

            property real arcSpread: Math.PI * 0.8
            property real targetNodeOffset: (siblingsCount > 1) ? ((localIndex / (siblingsCount - 1)) - 0.5) * arcSpread : 0
            property real nodeOffset: targetNodeOffset
            Behavior on nodeOffset { enabled: window.visible; NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }

            property real parentCoreAngle: (window.globalOrbitAngle * 1.5) + parentBaseAngle
            property real multiLiveAngle: myParentIdx === -1 ? singleLiveAngle : (parentCoreAngle + nodeOffset)

            property int ringIndex: (typeof isInfoNode !== "undefined" && isInfoNode) ? 0 : index % 2
            property real targetRingOffset: ringIndex * window.s(32)
            property real ringOffset: targetRingOffset
            Behavior on ringOffset { enabled: window.visible; NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }

            property real singleRadX: (typeof isInfoNode !== "undefined" && isInfoNode) ? window.s(253) : window.s(260) + ringOffset
            property real singleRadY: (typeof isInfoNode !== "undefined" && isInfoNode) ? window.s(154) : window.s(160) + ringOffset

            property real multiRadX: (typeof isInfoNode !== "undefined" && isInfoNode) ? (myParentIdx === -1 ? 0 : (window.activeCoreCount > 2 ? window.s(165) : window.s(149))) : window.s(270) + ringOffset
            property real multiRadY: (typeof isInfoNode !== "undefined" && isInfoNode) ? (myParentIdx === -1 ? 0 : (window.activeCoreCount > 2 ? window.s(165) : window.s(149))) : window.s(190) + ringOffset

            property real currentRadX: window.activeMode === "eth" ? window.s(253) : ((singleRadX * (1 - unifiedRatio)) + (multiRadX * unifiedRatio))
            property real currentRadY: window.activeMode === "eth" ? window.s(154) : ((singleRadY * (1 - unifiedRatio)) + (multiRadY * unifiedRatio))
            property real currentAngle: (singleLiveAngle * (1 - unifiedRatio)) + (multiLiveAngle * unifiedRatio)

            property real pwrDrift: window.currentPower ? 0 : window.s(32)
            Behavior on pwrDrift { enabled: window.visible; NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

            property real animRadX: (currentRadX + pwrDrift) * entryAnim
            property real animRadY: (currentRadY + pwrDrift) * entryAnim

            property real targetX: {
                let tx = myParentIdx === -1
                    ? (orbitContainer.width / 2) - (width / 2) + Math.cos(currentAngle) * animRadX
                    : safeParentX - (width / 2) + Math.cos(currentAngle) * animRadX;
                return isNaN(tx) ? (orbitContainer.width / 2 - width / 2) : tx;
            }

            property real targetY: {
                let ty = myParentIdx === -1
                    ? (orbitContainer.height / 2) - (height / 2) + Math.sin(currentAngle) * animRadY
                    : safeParentY - (height / 2) + Math.sin(currentAngle) * animRadY;
                return isNaN(ty) ? (orbitContainer.height / 2 - height / 2) : ty;
            }

            property real liveBob: myParentIdx === -1 && (typeof isInfoNode !== "undefined" && isInfoNode)
                ? Math.sin(window.globalOrbitAngle * 6) * window.s(10) * (1 - unifiedRatio)
                : 0

            x: targetX
            y: targetY + liveBob

            property bool isHoveredOrHighlighted: isMyActionable ? fillBtn.isHoveredOrHighlighted : clickBtn.isHoveredOrHighlighted
            property real currentPopScale: isMyActionable ? fillBtn.popScale : clickBtn.popScale

            scale: (!isLoaded ? 0.0 : (isHoveredOrHighlighted ? dynamicScale * 1.025 : dynamicScale)) * currentPopScale
            Behavior on scale { enabled: window.visible; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            z: floatCardDelegateContainer.isCardHovered ? 10 : index

            HoverHandler {
                id: cardHoverHandler
                enabled: window.visible
                onHoveredChanged: {
                    if (floatCardDelegateContainer.isCardHovered !== hovered) {
                        floatCardDelegateContainer.isCardHovered = hovered;
                        if (hovered) window.hoveredCardCount++;
                        else window.hoveredCardCount = Math.max(0, window.hoveredCardCount - 1);
                    }
                }
            }

            Component.onDestruction: {
                if (floatCardDelegateContainer.isCardHovered) {
                    floatCardDelegateContainer.isCardHovered = false;
                    window.hoveredCardCount = Math.max(0, window.hoveredCardCount - 1);
                }
            }

            property string itemId: typeof model !== "undefined" && model !== null && model.id !== undefined ? model.id : (typeof id !== "undefined" && id !== null ? id : "")
            property bool isFailed: window.failedId === itemId
            property bool isMyBusy: window.connectingId === itemId || !!window.busyTasks[itemId]

            property bool isPairedBT: window.activeMode === "bt" && (typeof action !== "undefined" && action === "Connect")
            property bool isTargetWifi: window.activeMode === "wifi" && !window.isWifiConn && itemId === window.targetWifiSsid
            property bool isSpecialAction: itemId === "action_scan" || itemId === "action_settings" || itemId === "ip_0" || itemId === "action_portal" || itemId.indexOf("forget_") === 0
            property bool isHighlighted: isPairedBT || isTargetWifi || isSpecialAction

            property bool isCurrentlyConnected: {
                if (window.activeMode === "eth") return (window.ethConnected && window.ethConnected.id === itemId);
                if (window.activeMode === "wifi") return (window.wifiConnected && window.wifiConnected.ssid === itemId);
                for (let i = 0; i < window.btConnected.length; i++) {
                    if (window.btConnected[i] && window.btConnected[i].mac === itemId) return true;
                }
                return false;
            }

            property real myFillLevel: isCurrentlyConnected ? 1.0 : 0.0

            property string myButtonText: {
                let n = typeof model !== "undefined" && model !== null && model.name !== undefined ? model.name : (typeof name !== "undefined" && name !== null ? name : "");
                return n !== "" ? n : (typeof ssid !== "undefined" ? ssid : "");
            }

            property string myButtonIcon: typeof icon !== "undefined" ? icon : ""
            property bool isMyActionable: typeof isActionable !== "undefined" ? isActionable : true

            property color dynamicTextColor: {
                if (isFailed) return ThemeBackend.red;
                if (isHighlighted) return window.activeColor;
                return ThemeBackend.text;
            }

            function handleTrigger() {
                let currentCmd = typeof cmdStr !== "undefined" ? cmdStr : "";
                let currentAction = typeof action !== "undefined" ? action : "";
                let currentSsid = typeof ssid !== "undefined" ? ssid : "";
                let currentMac = typeof mac !== "undefined" ? mac : "";
                let currentIsInfoNode = typeof isInfoNode !== "undefined" ? isInfoNode : false;

                if (currentCmd === "TOGGLE_VIEW") {
                    floatCardDelegateContainer.isCardHovered = false;
                    window.hoveredCardCount = 0;
                    window.showInfoView = !window.showInfoView;
                } else if (currentIsInfoNode && currentAction === "IP Address") {
                    let itemName = myButtonText;
                    if (itemName && itemName !== "No IP" && itemName !== "Unknown") {
                        Sounds.playSfx("network/switch.wav");
                        Quickshell.execDetached(["bash", "-c", currentCmd]);
                    }
                } else if (currentIsInfoNode && currentCmd) {
                    if (currentCmd.indexOf("BT_FORGET_") === 0) {
                        let macToForget = currentCmd.substring(10);
                        window.withBtOpLock(macToForget, function() {
                            let devList = window.getBtDevicesList();
                            let devToForget = null;
                            for (let i = 0; i < devList.length; i++) {
                                if (devList[i] && devList[i].address === macToForget) { devToForget = devList[i]; break; }
                            }
                            if (!devToForget) return;

                            let map = Object.assign({}, window.btDeviceMap);
                            delete map[macToForget];
                            window.btDeviceMap = map;

                            let bt = window.busyTasks; delete bt[macToForget]; window.busyTasks = Object.assign({}, bt);
                            let dd = window.disconnectingDevices; delete dd[macToForget]; window.disconnectingDevices = Object.assign({}, dd);
                            if (window.connectingId === macToForget) window.connectingId = "";
                            if (window.failedId === macToForget) window.failedId = "";

                            devToForget.forget();
                            window.requestBtRebuild();
                        });
                    } else {
                        Quickshell.execDetached(["sh", "-c", currentCmd]);
                    }
                } else {
                    let sec = typeof security !== "undefined" && security ? security.trim().toLowerCase() : "";
                    let isSecure = sec !== "" && sec !== "open" && sec !== "--" && sec !== "none";
                    let isSaved = false;
                    if (window.wifiDevice && window.wifiDevice.networks) {
                        let nets = window.wifiDevice.networks.values;
                        for (let i = 0; i < nets.length; i++) {
                            let n = nets[i];
                            if (n && n.name === currentSsid && n.known) { isSaved = true; break; }
                        }
                    }

                    if (window.activeMode === "wifi" && isSecure && !isSaved) {
                        window.pendingWifiSsid = currentSsid;
                        window.pendingWifiId = itemId;
                    } else {
                        window.connectDevice(window.activeMode, itemId, window.activeMode === "wifi" ? currentSsid : (window.activeMode === "eth" ? itemId : currentMac), "");
                    }
                }
            }

            FillButton {
                id: fillBtn
                visible: isMyActionable
                enabled: !isMyBusy && !window.isBtOpBusy(itemId)
                anchors.fill: parent
                cornerRadius: ThemeBackend.borderRadius
                fillDuration: 600
                buttonText: ""
                buttonIcon: ""
                accentColor: window.activeColor
                baseColor: ThemeBackend.base
                hoverColor: ThemeBackend.surface0
                textColor: dynamicTextColor
                filledTextColor: ThemeBackend.crust
                action_highlight: isHighlighted
                contentAlignment: Qt.AlignLeft
                horizontalPadding: window.s(10)
                textFontSize: window.s(12)
                iconFontSize: window.s(18)
                fillLevel: myFillLevel
                onTriggered: floatCardDelegateContainer.handleTrigger()
            }

            ClickButton {
                id: clickBtn
                visible: !isMyActionable
                enabled: !isMyBusy && !window.isBtOpBusy(itemId)
                anchors.fill: parent
                cornerRadius: ThemeBackend.borderRadius
                accentColor: ThemeBackend.surface0
                textColor: dynamicTextColor
                action_highlight: isHighlighted
                buttonText: ""
                buttonIcon: ""
                onTriggered: floatCardDelegateContainer.handleTrigger()
            }

            Item {
                id: cardContentOverlay
                anchors.fill: parent

                Item {
                    id: baseContent
                    anchors.fill: parent
                    anchors.leftMargin: window.s(10)
                    anchors.rightMargin: window.s(10)

                    Row {
                        id: baseRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: window.s(6)
                        height: parent.height

                        Text {
                            id: overlayIcon
                            visible: myButtonIcon !== ""
                            text: myButtonIcon
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(18)
                            color: dynamicTextColor
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                        }

                        MarqueeText {
                            id: marqueeClip
                            width: floatCardDelegateContainer.width - window.s(20) - (overlayIcon.visible ? overlayIcon.implicitWidth + window.s(6) : 0)
                            height: parent.height
                            text: myButtonText
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: window.s(12)
                            color: dynamicTextColor
                            marqueeSpacing: window.s(30)
                            active: window.visible

                            Behavior on color { enabled: window.visible; ColorAnimation { duration: 200 } }
                        }
                    }
                }

                Item {
                    id: filledClipItem
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (isMyActionable ? fillBtn.fillLevel : 0.0)
                    clip: true
                    visible: width > 0

                    Item {
                        width: cardContentOverlay.width
                        height: cardContentOverlay.height
                        anchors.left: parent.left
                        anchors.top: parent.top

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(10)
                            anchors.rightMargin: window.s(10)

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: window.s(6)
                                height: parent.height

                                Text {
                                    visible: myButtonIcon !== ""
                                    text: myButtonIcon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(18)
                                    color: ThemeBackend.crust
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: marqueeClip.width
                                    height: parent.height
                                    clip: true

                                    Item {
                                        height: parent.height
                                        width: marqueeClip.textWidth + marqueeClip.marqueeSpacing
                                        x: marqueeClip.scrollX

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: marqueeClip.marqueeSpacing

                                            Text {
                                                text: myButtonText
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: Font.Bold
                                                font.pixelSize: window.s(12)
                                                color: ThemeBackend.crust
                                            }

                                            Text {
                                                text: myButtonText
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: Font.Bold
                                                font.pixelSize: window.s(12)
                                                color: ThemeBackend.crust
                                                visible: marqueeClip.canMarquee
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
