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

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string circleStyle: {
        if (widget && widget !== root && widget.sysmonStyle !== undefined) return widget.sysmonStyle;
        if (module && module.sysmonStyle !== undefined) return module.sysmonStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.sysmonStyle) return bs.sysmonStyle;
            if (bs.sysmon && bs.sysmon.style) return bs.sysmon.style;
        }
        return "wave";
    }

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

    property bool showLayout: (!barWindow || (root.activeTarget && root.activeTarget.isPreview)) ? true : false
    property int circleSize: barWindow ? barWindow.s(isCompact ? 22 : 28) : (isCompact ? 22 : 28)

    property bool isSysVisible: (!activeTarget || activeTarget.moduleActive) && showLayout
    property color basePrimary: (ThemeBackend.primary !== undefined && ThemeBackend.primary !== "") ? ThemeBackend.primary : ThemeBackend.mauve

    property bool isSubscribed: false

    function updateSubscription() {
        if (isSysVisible && !isSubscribed) {
            isSubscribed = true;
            SysData.subscribe();
        } else if (!isSysVisible && isSubscribed) {
            isSubscribed = false;
            SysData.unsubscribe();
        }
    }

    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            SysData.unsubscribe();
        }
    }
    onIsSysVisibleChanged: updateSubscription()

    property real targetWidth: ((!activeTarget || activeTarget.moduleActive) && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Timer {
        running: (!activeTarget || activeTarget.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady && !root.showLayout
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    component SysMonCircle: Rectangle {
        id: circleRoot
        property real value: 0
        property string textVal: ""
        property string icon: ""
        property color accentColor: root.basePrimary
        property bool showText: textVal !== ""
        property bool useSineWave: root.useSineWave
        property bool initAnimTrigger: (!barWindow || (root.activeTarget && root.activeTarget.isPreview))

        property real animValue: initAnimTrigger ? value : 0
        Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

        property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))

        implicitWidth: root.circleSize
        implicitHeight: root.circleSize
        width: implicitWidth
        height: implicitHeight
        radius: width / 2
        color: "transparent"
        border.width: 0

        Timer {
            running: (!activeTarget || activeTarget.moduleActive) && root.showLayout && !initAnimTrigger
            interval: 150
            onTriggered: initAnimTrigger = true
        }

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            y: initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Canvas {
            id: circleCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Cooperative
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var cy = height / 2;
                var strokeW = barWindow ? barWindow.s(2.2) : 2.2;
                var amp = barWindow ? barWindow.s(0.9) : 0.9;
                var radius = Math.min(cx, cy) - amp - (strokeW / 2) - (barWindow ? barWindow.s(0.4) : 0.4);
                if (radius <= 0) return;

                ctx.save();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2, false);
                ctx.strokeStyle = Qt.rgba(circleRoot.accentColor.r, circleRoot.accentColor.g, circleRoot.accentColor.b, 0.22);
                ctx.lineWidth = strokeW;
                ctx.stroke();

                if (circleRoot.fillRatio > 0.001) {
                    var startAngle = -Math.PI / 2;
                    var sweepAngle = Math.PI * 2 * circleRoot.fillRatio;

                    if (circleRoot.useSineWave) {
                        var totalP = 2 * Math.PI * radius;
                        var cycles = Math.max(5, Math.round(totalP / 8.5));
                        var freq = (Math.PI * 2 * cycles) / totalP;
                        var arcLen = totalP * circleRoot.fillRatio;
                        var steps = Math.max(6, Math.ceil(arcLen / 1.2));

                        ctx.beginPath();
                        for (var i = 0; i <= steps; i++) {
                            var t = i / steps;
                            var a = startAngle + sweepAngle * t;
                            var arcDist = (a - startAngle) * radius;
                            var wOff = amp * Math.sin(freq * arcDist);
                            var px = cx + (radius + wOff) * Math.cos(a);
                            var py = cy + (radius + wOff) * Math.sin(a);

                            if (i === 0) {
                                ctx.moveTo(px, py);
                            } else {
                                ctx.lineTo(px, py);
                            }
                        }

                        if (circleRoot.fillRatio >= 0.999) {
                            ctx.closePath();
                        }

                        ctx.strokeStyle = circleRoot.accentColor;
                        ctx.lineWidth = strokeW;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.stroke();
                    } else {
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, startAngle, startAngle + sweepAngle, false);
                        ctx.strokeStyle = circleRoot.accentColor;
                        ctx.lineWidth = strokeW;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }

                var displayText = circleRoot.showText ? circleRoot.textVal : circleRoot.icon;
                var fontSize = circleRoot.showText
                    ? (barWindow ? barWindow.s(root.isCompact ? 7.5 : 9) : (root.isCompact ? 7.5 : 9))
                    : (barWindow ? barWindow.s(root.isCompact ? 9 : 11) : (root.isCompact ? 9 : 11));

                var fontFam = (ThemeBackend.fontFamily !== undefined && ThemeBackend.fontFamily !== "") ? ThemeBackend.fontFamily : "sans-serif";
                if (circleRoot.showText) {
                    ctx.font = "bold " + Math.round(fontSize) + "px \"" + fontFam + "\", sans-serif";
                } else {
                    ctx.font = "normal " + Math.round(fontSize) + "px \"" + ThemeBackend.iconFont + "\"";
                }

                var baseTextColor = (ThemeBackend.text !== undefined && ThemeBackend.text !== "") ? ThemeBackend.text : "#ffffff";

                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillStyle = baseTextColor;
                ctx.fillText(displayText, cx, cy);

                ctx.restore();
            }

            Component.onCompleted: circleCanvas.requestPaint()
            onWidthChanged: circleCanvas.requestPaint()
            onHeightChanged: circleCanvas.requestPaint()

            Connections {
                target: circleRoot
                enabled: root.isSysVisible
                function onFillRatioChanged() { circleCanvas.requestPaint(); }
                function onAccentColorChanged() { circleCanvas.requestPaint(); }
                function onTextValChanged() { circleCanvas.requestPaint(); }
                function onIconChanged() { circleCanvas.requestPaint(); }
                function onShowTextChanged() { circleCanvas.requestPaint(); }
                function onUseSineWaveChanged() { circleCanvas.requestPaint(); }
            }

            Connections {
                target: root
                enabled: root.isSysVisible
                function onBasePrimaryChanged() { circleCanvas.requestPaint(); }
                function onUseSineWaveChanged() { circleCanvas.requestPaint(); }
            }

            Connections {
                target: ThemeBackend
                enabled: root.isSysVisible
                function onIconFontChanged() { circleCanvas.requestPaint(); }
            }
        }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6)
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
        enabled: !(root.activeTarget && root.activeTarget.isPreview)
        onClicked: {
            FloatingController.showSystemUsage(root.barWindow ? root.barWindow.screen : null);
        }
    }
}
