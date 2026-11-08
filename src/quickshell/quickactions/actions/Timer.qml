import QtQuick
import "../../reusables"
import "../../"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(380)
    property real baseL: s(330)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property bool widgetVisible: parent !== null && parent.visible !== undefined ? parent.visible : true

    property int tabMode: 0
    property bool tabTouched: false

    function syncTab() {
        if (!tabTouched) tabMode = FocusTimer.activeMode;
    }

    Component.onCompleted: syncTab()

    Connections {
        target: FocusTimer
        function onStateLoadedChanged() { root.syncTab(); }
    }

    property var interceptedShortcuts: tabMode === 0 ? timerPanel.interceptedShortcuts : ["Return", "Enter"]

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Switch {
            id: tabBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.s(12)
            width: root.s(270)
            height: root.s(36)
            z: 10
            options: [
                I18n.t("quickactions.timer.tabs.timer"),
                I18n.t("quickactions.timer.tabs.stopwatch"),
                I18n.t("quickactions.timer.tabs.pomodoro")
            ]
            Binding { target: tabBar; property: "currentIndex"; value: root.tabMode }
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.mantle
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: Math.round(root.s(12))
            bgOpacity: ThemeBackend.elementOpacity
            onToggled: index => {
                root.tabTouched = true;
                root.tabMode = index;
                FocusTimer.setActiveMode(index);
            }
        }

        FocusTimerPanel {
            id: timerPanel
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.tabMode === 0
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            scaleFn: root.s
            isActiveTab: root.isActiveTab
            widgetVisible: root.widgetVisible
            persistView: true
        }

        FocusStopwatchPanel {
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.tabMode === 1
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            scaleFn: root.s
            isActiveTab: root.isActiveTab
            widgetVisible: root.widgetVisible
        }

        FocusPomodoroPanel {
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.tabMode === 2
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            scaleFn: root.s
            isActiveTab: root.isActiveTab
            widgetVisible: root.widgetVisible
        }
    }
}
