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

    property string kbStyle: {
        if (widget && widget !== root && widget.kbStyle !== undefined) return widget.kbStyle;
        if (module && module.kbStyle !== undefined) return module.kbStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let bs = Config.rawSettings.bar;
            if (bs && bs.kbStyle) return bs.kbStyle;
            if (bs && bs.kb && bs.kb.style) return bs.kb.style;
        }
        return "button";
    }

    property string kbLayout: "US"
    property bool showLayout: (!barWindow || isPreview) ? true : false
    property alias kbPill: kbBtn
    readonly property bool isNiri: NiriState.isNiri
    property bool isSway: false
    readonly property bool isMango: MangoState.isMango
    property bool niriSubscribed: false

    function syncNiriSubscription() {
        let want = isNiri && !root.isPreview && (!module || module.moduleActive);
        if (want === niriSubscribed) return;
        niriSubscribed = want;
        if (want) NiriState.subscribe();
        else NiriState.unsubscribe();
    }

    function applyNiriLayout() {
        if (!NiriState.keyboardReady) return;
        let txt = NiriState.shortKeyboardLayout;
        if (txt !== "" && root.kbLayout !== txt) root.kbLayout = txt;
        if (barWindow) barWindow.fastPollerLoaded = true;
    }

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isSway = de.indexOf("sway") !== -1;
        syncNiriSubscription();
        if (root.isNiri) applyNiriLayout();
    }

    Component.onDestruction: {
        if (niriSubscribed) NiriState.unsubscribe();
    }

    Connections {
        target: NiriState
        enabled: root.isNiri
        function onShortKeyboardLayoutChanged() { root.applyNiriLayout(); }
        function onKeyboardReadyChanged() { root.applyNiriLayout(); }
    }

    Connections {
        target: (!root.isPreview && module) ? module : null
        function onModuleActiveChanged() {
            root.syncNiriSubscription();
            if (root.isNiri) return;
            if (module && !module.moduleActive) {
                kbPoller.running = false;
                kbWaiter.running = false;
            } else {
                kbPoller.running = false;
                kbPoller.running = true;
            }
        }
    }

    Process {
        id: kbPoller
        running: !root.isPreview && (!module || module.moduleActive) && !root.isNiri
        command: [
            "bash",
            "-c",
            root.isMango
                ? "layout=$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : root.isSway
                ? "layout=$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == \"keyboard\" and .xkb_active_layout_name != null)] | .[0].xkb_active_layout_name // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : "layout=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && root.kbLayout !== txt) root.kbLayout = txt;
                if (!root.isPreview && (!module || module.moduleActive) && !kbWaiter.running) kbWaiter.running = true;
                if (barWindow) barWindow.fastPollerLoaded = true;
            }
        }
    }

    Process {
        id: kbWaiter
        command: [
            "bash",
            Caching.qsDir + "/watchers/kb_wait.sh",
            root.isMango ? "mango" : (root.isSway ? "sway" : "hyprland")
        ]
        onExited: {
            kbPoller.running = false;
            if (!root.isPreview && (!module || module.moduleActive) && !root.isNiri) kbPoller.running = true;
        }
    }

    property real targetHeight: {
        if (module && !module.moduleActive) return 0;
        if (root.kbStyle === "text") {
            return (sideText.implicitHeight > 0) ? (sideText.implicitHeight + s(root.isCompact ? 14 : 16)) : 0;
        }
        return (kbBtn.height > 0) ? (kbBtn.height + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    Timer {
        running: !root.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    MouseArea {
        id: sideTextMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.kbStyle === "text" && !root.isPreview
        onClicked: {
            if (root.isNiri) {
                Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
            } else if (root.isSway) {
                Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
            } else if (root.isMango) {
                Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
            } else {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
            }
        }
    }

    Text {
        id: sideText
        visible: root.kbStyle === "text"
        anchors.centerIn: parent
        text: root.kbLayout
        font.family: ThemeBackend.fontFamily
        font.pixelSize: s(root.isCompact ? 11 : 12)
        font.bold: true
        color: sideTextMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.text
        opacity: root.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    ClickButton {
        id: kbBtn
        contentSpacing: s(8)
        visible: root.kbStyle !== "text"
        anchors.centerIn: parent
        width: s(root.isCompact ? 28 : 30)
        height: s(root.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
        horizontalPadding: 0
        buttonText: root.kbLayout
        textFontSize: s(root.isCompact ? 11 : 12)
        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

        onClicked: {
            if (root.isPreview) return;
            if (root.isNiri) {
                Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
            } else if (root.isSway) {
                Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
            } else if (root.isMango) {
                Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
            } else {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
            }
        }
    }
}
