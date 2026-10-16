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
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.kbStyle) return bs.kbStyle;
            if (bs.kb && bs.kb.style) return bs.kb.style;
        }
        return "button";
    }

    property bool showIcon: {
        if (widget && widget !== root && widget.kbShowIcon !== undefined) return widget.kbShowIcon;
        if (widget && widget !== root && widget.showIcon !== undefined) return widget.showIcon;
        if (module && module.kbShowIcon !== undefined) return module.kbShowIcon;
        if (module && module.showIcon !== undefined) return module.showIcon;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.kbShowIcon !== undefined) return Boolean(bs.kbShowIcon);
            if (bs.kb && bs.kb.showIcon !== undefined) return Boolean(bs.kb.showIcon);
        }
        return true;
    }

    property string kbLayout: "US"
    property bool showLayout: (!barWindow || isPreview) ? true : false
    property alias kbPill: kbPill
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

    property real targetWidth: {
        if (module && !module.moduleActive) return 0;
        if (root.kbStyle === "text") {
            return (textRow.implicitWidth > 0) ? (textRow.implicitWidth + s(root.isCompact ? 12 : 16)) : 0;
        }
        return (sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + s(root.isCompact ? 8 : 10)) : 0;
    }
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Timer {
        running: !root.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: textMouseArea
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

    Row {
        id: textRow
        visible: root.kbStyle === "text"
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
                text: "󰌌"
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(root.isCompact ? 14 : 15)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: textMouseArea.containsMouse ? Qt.lighter(ThemeBackend.text, 1.15) : ThemeBackend.subtext0
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        Text {
            text: root.kbLayout
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
        visible: root.kbStyle !== "text"
        anchors.centerIn: parent
        property int pillHeight: s(root.isCompact ? 28 : 30)

        ClickButton {
            id: kbPill
            contentSpacing: s(8)
            property bool initAnimTrigger: root.isPreview
            height: sysLayout.pillHeight
            maxWidth: s(root.isCompact ? 96 : 100)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - s(2))
            horizontalPadding: s(root.isCompact ? 10 : 12)
            buttonIcon: root.showIcon ? "󰌌" : ""
            iconFontSize: s(root.isCompact ? 14 : 15)
            buttonText: root.kbLayout
            textFontSize: s(root.isCompact ? 11 : 12)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: Math.max(s(root.isCompact ? (root.showIcon ? 48 : 32) : (root.showIcon ? 52 : 36)), implicitWidth)
            width: targetWidth

            Behavior on width {
                enabled: barWindow && barWindow.startupCascadeFinished
                NumberAnimation { duration: 480; easing.type: Easing.OutQuint }
            }

            Timer { running: !root.isPreview && (!module || module.moduleActive) && root.showLayout && !kbPill.initAnimTrigger; interval: 70; onTriggered: kbPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: kbPill.initAnimTrigger ? 0 : s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

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
}
