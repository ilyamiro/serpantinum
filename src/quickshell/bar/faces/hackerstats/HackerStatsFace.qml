import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false

    function s(val) {
        if (barWindow && typeof barWindow.cs === "function") return barWindow.cs(val);
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

    property bool showCpu: {
        if (widget && widget !== root && widget.hackerstatsShowCpu !== undefined) return Boolean(widget.hackerstatsShowCpu);
        if (widget && widget !== root && widget.showCpu !== undefined) return Boolean(widget.showCpu);
        if (module && module.hackerstatsShowCpu !== undefined) return Boolean(module.hackerstatsShowCpu);
        if (module && module.showCpu !== undefined) return Boolean(module.showCpu);
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.hackerstatsShowCpu !== undefined) return Boolean(bs.hackerstatsShowCpu);
            if (bs.hackerstats && bs.hackerstats.showCpu !== undefined) return Boolean(bs.hackerstats.showCpu);
            if (bs.sysmonShowCpu !== undefined) return Boolean(bs.sysmonShowCpu);
        }
        return true;
    }

    property bool showGpu: {
        if (widget && widget !== root && widget.hackerstatsShowGpu !== undefined) return Boolean(widget.hackerstatsShowGpu);
        if (widget && widget !== root && widget.showGpu !== undefined) return Boolean(widget.showGpu);
        if (module && module.hackerstatsShowGpu !== undefined) return Boolean(module.hackerstatsShowGpu);
        if (module && module.showGpu !== undefined) return Boolean(module.showGpu);
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.hackerstatsShowGpu !== undefined) return Boolean(bs.hackerstatsShowGpu);
            if (bs.hackerstats && bs.hackerstats.showGpu !== undefined) return Boolean(bs.hackerstats.showGpu);
            if (bs.sysmonShowGpu !== undefined) return Boolean(bs.sysmonShowGpu);
        }
        return true;
    }

    property int cpu: isPreview ? 24 : 0
    property int gpu: isPreview ? 48 : 0

    readonly property string statsScriptPath: (typeof Caching !== "undefined" && Caching.serpantinumDir ? Caching.serpantinumDir : (Quickshell.env("HOME") + "/.local/share/serpantinum/src")) + "/scripts/stats.sh"

    Process {
        id: statsProc
        command: [root.statsScriptPath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    if (data.cpu !== undefined) root.cpu = parseInt(data.cpu) || 0;
                    if (data.gpu !== undefined) root.gpu = parseInt(data.gpu) || 0;
                } catch (e) {
                }
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 3000
        repeat: true
        running: !root.isPreview && (!module || module.moduleActive) && (root.showCpu || root.showGpu)
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                statsProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        if (!root.isPreview && (!module || module.moduleActive) && (root.showCpu || root.showGpu) && !statsProc.running) {
            statsProc.running = true;
        }
    }

    property bool showLayout: (!barWindow || isPreview) ? true : ((!module || module.moduleActive) && barWindow.isStartupReady && barWindow.isDataReady)

    readonly property real layoutLength: isVertical ? statsLayout.implicitHeight : statsLayout.implicitWidth
    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (!root.showCpu && !root.showGpu) return 0;
        let pad = s(root.isCompact ? (isVertical ? 8 : 10) : (isVertical ? 10 : 14));
        return (layoutLength > 0) ? (layoutLength + pad) : 0;
    }
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

    Timer {
        running: true
        interval: 0
        onTriggered: root.syncImplicitSize()
    }

    Timer {
        running: (!activeTarget || activeTarget.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady && !root.showLayout
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: (root.isVertical || root.showLayout) ? 0 : s(60)
        y: (!root.isVertical || root.showLayout) ? 0 : s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }
    opacity: root.showLayout ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.isPreview
        onClicked: {
            if (!statsProc.running) statsProc.running = true;
            if (typeof FloatingController !== "undefined" && typeof FloatingController.showSystemUsage === "function") {
                FloatingController.showSystemUsage(root.barWindow ? root.barWindow.screen : null);
            }
        }
    }

    Item {
        id: statsLayout
        anchors.centerIn: parent
        implicitWidth: root.isVertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
        implicitHeight: root.isVertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

        Row {
            id: horizontalLayout
            visible: !root.isVertical && (root.showCpu || root.showGpu)
            anchors.centerIn: parent
            spacing: s(root.isCompact ? 6 : 8)

            // CPU Block
            Row {
                id: cpuBlock
                visible: root.showCpu
                anchors.verticalCenter: parent.verticalCenter
                spacing: s(root.isCompact ? 3 : 4)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: s(4)
                    height: s(4)
                    radius: s(2)
                    color: root.cpu > 60 ? ThemeBackend.red : (root.cpu < 40 ? ThemeBackend.green : ThemeBackend.peach)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 9 : 10)
                    font.bold: true
                    color: mouseArea.containsMouse ? Qt.lighter(ThemeBackend.subtext0, 1.15) : ThemeBackend.subtext0
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.cpu < 10 ? "0" : "") + root.cpu + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 10 : 11)
                    font.bold: true
                    color: root.cpu > 60 ? ThemeBackend.red : (root.cpu < 40 ? ThemeBackend.green : ThemeBackend.text)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // Divider
            Rectangle {
                visible: root.showCpu && root.showGpu
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: s(9)
                color: Qt.alpha(ThemeBackend.surface2, 0.45)
            }

            // GPU Block
            Row {
                id: gpuBlock
                visible: root.showGpu
                anchors.verticalCenter: parent.verticalCenter
                spacing: s(root.isCompact ? 3 : 4)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: s(4)
                    height: s(4)
                    radius: s(2)
                    color: root.gpu > 60 ? ThemeBackend.red : (root.gpu < 40 ? ThemeBackend.green : ThemeBackend.peach)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 9 : 10)
                    font.bold: true
                    color: mouseArea.containsMouse ? Qt.lighter(ThemeBackend.subtext0, 1.15) : ThemeBackend.subtext0
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.gpu < 10 ? "0" : "") + root.gpu + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 10 : 11)
                    font.bold: true
                    color: root.gpu > 60 ? ThemeBackend.red : (root.gpu < 40 ? ThemeBackend.green : ThemeBackend.text)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        Column {
            id: verticalLayout
            visible: root.isVertical && (root.showCpu || root.showGpu)
            anchors.centerIn: parent
            spacing: s(root.isCompact ? 2 : 4)

            Row {
                visible: root.showCpu
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: s(2)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: s(3)
                    height: s(3)
                    radius: s(1.5)
                    color: root.cpu > 60 ? ThemeBackend.red : (root.cpu < 40 ? ThemeBackend.green : ThemeBackend.peach)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "C " + root.cpu + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 8 : 9)
                    font.bold: true
                    color: root.cpu > 60 ? ThemeBackend.red : (root.cpu < 40 ? ThemeBackend.green : ThemeBackend.text)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            Row {
                visible: root.showGpu
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: s(2)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: s(3)
                    height: s(3)
                    radius: s(1.5)
                    color: root.gpu > 60 ? ThemeBackend.red : (root.gpu < 40 ? ThemeBackend.green : ThemeBackend.peach)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "G " + root.gpu + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(root.isCompact ? 8 : 9)
                    font.bold: true
                    color: root.gpu > 60 ? ThemeBackend.red : (root.gpu < 40 ? ThemeBackend.green : ThemeBackend.text)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }
}
