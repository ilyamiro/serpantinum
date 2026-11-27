import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"
import "../../reusables"
import "../../reusables/buttons"

Scope {
    id: overlayScope

    property bool shown: false
    property bool mounted: false
    property string appClass: ""
    property string appName: ""
    property int usedSeconds: 0
    property double lastStamp: -1
    property bool baselineReady: false
    readonly property string eventDir: Caching.getRunDir("focustime")
    property string eventPath: ""

    readonly property var appEntry: appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null
    readonly property string displayName: (appEntry && appEntry.name) ? appEntry.name : (appName || appClass)
    readonly property string iconName: (appEntry && appEntry.icon) ? appEntry.icon : ""

    function s(val) {
        return Scaler.s(val);
    }

    function formatUsed(secs) {
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        if (h > 0) return I18n.t("guide.wellbeing.time_hm", { "h": h, "m": m });
        return I18n.t("guide.wellbeing.time_m", { "m": m });
    }

    function iconSource(ic) {
        return AppMatcher.iconSource(ic);
    }

    FileView {
        id: eventFile
        path: overlayScope.eventPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let ev;
            try { ev = JSON.parse(text()); } catch (e) { return; }
            let stamp = Number(ev.stamp) || 0;
            if (!overlayScope.baselineReady) {
                overlayScope.baselineReady = true;
                overlayScope.lastStamp = stamp;
                return;
            }
            if (stamp === overlayScope.lastStamp) return;
            overlayScope.lastStamp = stamp;
            overlayScope.appClass = ev.class || "";
            overlayScope.appName = ev.name || "";
            overlayScope.usedSeconds = Number(ev.seconds) || 0;
            unmountTimer.stop();
            if (!overlayScope.mounted) {
                overlayScope.mounted = true;
                Qt.callLater(function() { overlayScope.shown = true; });
            } else {
                overlayScope.shown = true;
            }
        }
        onLoadFailed: {
            overlayScope.baselineReady = true;
        }
    }

    onShownChanged: {
        if (!shown && mounted) unmountTimer.restart();
    }

    Timer {
        id: unmountTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (!overlayScope.shown) overlayScope.mounted = false;
        }
    }

    Timer {
        interval: 1000
        repeat: false
        running: true
        onTriggered: overlayScope.eventPath = overlayScope.eventDir + "/limit_event.json"
    }

    Dim {
        active: overlayScope.shown
        opacity: 0.55
        blockInput: true
        duration: 250
        namespace: "serpantinum-wellbeing-dim"
    }

    Variants {
        model: overlayScope.mounted ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: overlayScope.shown || card.opacity > 0.001
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "serpantinum-wellbeing-limit"
            WlrLayershell.keyboardFocus: overlayScope.shown ? Compositor.interactiveKeyboardFocus : WlrKeyboardFocus.None

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: overlayScope.s(360)
                implicitHeight: cardColumn.implicitHeight + overlayScope.s(56)
                height: implicitHeight
                radius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
                color: ThemeBackend.base
                opacity: overlayScope.shown ? 1.0 : 0.0
                scale: overlayScope.shown ? 1.0 : 0.92
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowVerticalOffset: overlayScope.s(6)
                    shadowBlur: 0.6
                }

                ColumnLayout {
                    id: cardColumn
                    anchors.fill: parent
                    anchors.margins: overlayScope.s(28)
                    spacing: overlayScope.s(14)

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: overlayScope.s(72)
                        Layout.preferredHeight: overlayScope.s(72)
                        radius: Math.round(overlayScope.s(72) * 0.28)
                        color: ThemeBackend.surface0

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: overlayScope.s(10)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            mipmap: true
                            sourceSize: Qt.size(Math.ceil(overlayScope.s(52) * (Screen.devicePixelRatio || 1)), Math.ceil(overlayScope.s(52) * (Screen.devicePixelRatio || 1)))
                            visible: status === Image.Ready && !AppMatcher.iconMissing(source)
                            source: overlayScope.iconSource(overlayScope.iconName)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            text: "󰔛"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: overlayScope.s(34)
                            color: ThemeBackend.mauve
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.t("guide.wellbeing.limit_overlay.title", "Daily limit reached")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: overlayScope.s(22)
                        font.bold: true
                        color: ThemeBackend.text
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: overlayScope.displayName + "  ·  " + overlayScope.formatUsed(overlayScope.usedSeconds)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: overlayScope.s(14)
                        color: ThemeBackend.subtext0
                    }

                    FillButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: overlayScope.s(8)
                        Layout.fillWidth: true
                        implicitHeight: overlayScope.s(52)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰁔"
                        buttonText: I18n.t("guide.wellbeing.limit_overlay.hold", "Hold to continue")
                        textFontSize: Math.round(overlayScope.s(14))
                        iconFontSize: Math.round(overlayScope.s(18))
                        fillDuration: 3000
                        accentColor: ThemeBackend.mauve
                        onTriggered: overlayScope.shown = false
                    }
                }
            }
        }
    }
}
