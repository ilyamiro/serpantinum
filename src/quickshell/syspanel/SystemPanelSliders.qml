import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Rectangle {
    id: slidersBox
    required property var panel
    property alias volumeSlider: volSlider
    property alias brightnessSlider: briSlider

    Timer {
        id: volSyncDelay
        interval: 800
        repeat: false
        onTriggered: panel.isDraggingVol = false
    }

    Timer {
        id: briSyncDelay
        interval: 800
        repeat: false
        onTriggered: panel.isDraggingBri = false
    }

    Layout.fillWidth: true
    Layout.preferredHeight: slidersCol.implicitHeight + panel.s(20)
    Layout.maximumHeight: slidersCol.implicitHeight + panel.s(20)
    radius: panel.boxRadius
    color: Qt.darker(ThemeBackend.surface0, 1.04)
    opacity: panel.introSliders
    transform: Translate { x: (panel.isLeftAnchored ? -panel.rowSlideDistance : panel.rowSlideDistance) * (1.0 - panel.introSliders) }

    ColumnLayout {
        id: slidersCol
        anchors.fill: parent
        anchors.margins: panel.s(12)
        spacing: panel.s(6)

        RowLayout {
            Layout.fillWidth: true
            spacing: panel.s(10)

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                size: panel.s(26)
                cornerRadius: panel.s(8)
                buttonIcon: panel.sysMuted || panel.sysVolume === 0 ? "󰖁" : (panel.sysVolume > 50 ? "󰕾" : "󰖀")
                iconFontSize: panel.s(15)
                accentColor: ThemeBackend.surface1
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (panel.sysMuted ? ThemeBackend.overlay0 : panel.volColor)
                onClicked: {
                    if (Audio.defaultSink) {
                        Audio.toggleMute(Audio.defaultSink);
                    }
                }
            }

            Timer {
                id: volCmdThrottle
                interval: 50
                property int targetPct: -1
                onTriggered: {
                    if (targetPct >= 0) {
                        if (targetPct > 0 && panel.sysMuted) {
                            if (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) {
                                Audio.toggleMute(Audio.defaultSink);
                            }
                        }
                        if (Audio.defaultSink) {
                            Audio.setVolume(Audio.defaultSink, targetPct);
                        }
                        targetPct = -1;
                    }
                }
            }

            Draggable {
                id: volSlider
                Layout.fillWidth: true
                implicitHeight: panel.s(18)
                from: 0.0
                to: 100.0
                stepSize: 1.0
                showValueBubble: true
                valueFormatter: function(v) { return Math.round(v) }
                value: panel.sysVolume
                backgroundColor: ThemeBackend.surface1
                accentColor: panel.sysMuted ? ThemeBackend.surface2 : panel.volColor
                gradColor1: panel.sysMuted ? ThemeBackend.surface2 : panel.volColor
                gradColor2: panel.sysMuted ? ThemeBackend.surface2 : Qt.lighter(panel.volColor, 1.05)
                gradColor3: panel.sysMuted ? ThemeBackend.surface2 : Qt.lighter(panel.volColor, 1.10)
                cornerRadius: panel.s(6)
                handleSize: panel.s(22)

                handleColor: panel.sysMuted ? ThemeBackend.overlay0 : Qt.lighter(panel.volColor, 1.15)
                handleHoverColor: panel.sysMuted ? ThemeBackend.subtext0 : Qt.lighter(panel.volColor, 1.5)
                handleDragColor: panel.sysMuted ? ThemeBackend.text : Qt.lighter(panel.volColor, 1.45)
                handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

                onDragStarted: {
                    volSyncDelay.stop();
                    panel.isDraggingVol = true;
                }
                onDragFinished: {
                    if (volCmdThrottle.running && volCmdThrottle.targetPct >= 0) {
                        volCmdThrottle.stop();
                        if (volCmdThrottle.targetPct > 0 && panel.sysMuted) {
                            if (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) {
                                Audio.toggleMute(Audio.defaultSink);
                            }
                        }
                        if (Audio.defaultSink) {
                            Audio.setVolume(Audio.defaultSink, volCmdThrottle.targetPct);
                        }
                        volCmdThrottle.targetPct = -1;
                    }
                    volSyncDelay.restart();
                }
                onMoved: (val) => {
                    let pct = Math.max(0, Math.min(100, Math.round(val)));
                    volSlider.value = pct;
                    volCmdThrottle.targetPct = pct;
                    if (!volCmdThrottle.running) volCmdThrottle.start();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: panel.s(10)

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                size: panel.s(26)
                cornerRadius: panel.s(8)
                buttonIcon: panel.sysBrightness > 66 ? "󰃠" : (panel.sysBrightness > 33 ? "󰃟" : "󰃞")
                iconFontSize: panel.s(15)
                accentColor: ThemeBackend.surface1
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : panel.briColor
                onClicked: {
                    briCmdThrottle.stop();
                    briCmdThrottle.targetPct = -1;
                    let target = panel.sysBrightness > 0 ? 0 : 100;
                    panel.sysBrightness = target;
                    Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", target.toString()]);
                }
            }

            Timer {
                id: briCmdThrottle
                interval: 400
                property int targetPct: -1
                onTriggered: {
                    if (targetPct >= 0) {
                        Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", targetPct.toString()]);
                        targetPct = -1;
                    }
                }
            }

            Draggable {
                id: briSlider
                Layout.fillWidth: true
                implicitHeight: panel.s(18)
                from: 0.0
                to: 100.0
                stepSize: 1.0
                showValueBubble: true
                valueFormatter: function(v) { return Math.round(v) }
                value: panel.sysBrightness
                backgroundColor: ThemeBackend.surface1
                accentColor: panel.briColor
                gradColor1: panel.briColor
                gradColor2: Qt.lighter(panel.briColor, 1.05)
                gradColor3: Qt.lighter(panel.briColor, 1.10)
                cornerRadius: panel.s(6)
                handleSize: panel.s(22)

                handleColor: Qt.lighter(panel.briColor, 1.15)
                handleHoverColor: Qt.lighter(panel.briColor, 1.3)
                handleDragColor: Qt.lighter(panel.briColor, 1.45)
                handleBorderColor: Qt.rgba(0, 0, 0, 0.2)

                onDragStarted: {
                    briSyncDelay.stop();
                    panel.isDraggingBri = true;
                }
                onDragFinished: {
                    if (briCmdThrottle.targetPct >= 0) {
                        briCmdThrottle.stop();
                        Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", briCmdThrottle.targetPct.toString()]);
                        briCmdThrottle.targetPct = -1;
                    }
                    briSyncDelay.restart();
                }
                onMoved: (val) => {
                    let pct = Math.max(0, Math.min(100, Math.round(val)));
                    panel.sysBrightness = pct;
                    briSlider.value = pct;
                    briCmdThrottle.targetPct = pct;
                    if (!briSlider.isDragging) briCmdThrottle.restart();
                }
            }
        }
    }
}
