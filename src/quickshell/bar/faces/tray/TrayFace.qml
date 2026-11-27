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
import "../../"

BarFaceBase {
    id: root

    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false
    readonly property bool isRightAligned: module ? module.isRightAligned : true
    property bool isBottomAligned: true
    readonly property bool isEndAligned: isVertical ? isBottomAligned : isRightAligned

    property bool showLayout: false

    readonly property real iconSize: s(isCompact ? 15 : 16)
    readonly property real itemSpacing: s(isCompact ? 8 : 10)
    readonly property real iconPadding: s(isCompact ? 10 : 12)
    readonly property real totalPadding: iconPadding * 2
    readonly property int itemCount: (moduleActive && trayRepeater.count > 0) ? trayRepeater.count : 0

    property real targetLength: itemCount > 0 ? (itemCount * iconSize + (itemCount - 1) * itemSpacing + totalPadding) : 0
    property bool isFaceVisible: showLayout && targetLength > 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    Component.onDestruction: {
        TrayMenuController.hide();
    }

    onVisibleChanged: {
        if (!visible) {
            TrayMenuController.hide();
        }
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                TrayMenuController.hide();
            }
        }
    }

    Connections {
        target: barWindow || null
        function onPositionChangingChanged() {
            if (barWindow && barWindow.positionChanging) {
                TrayMenuController.hide();
            }
        }
        function onBarPositionChanged() {
            TrayMenuController.hide();
        }
        function onIsRevealedChanged() {
            if (barWindow && !barWindow.isRevealed && !TrayMenuController.menuHovered) {
                TrayMenuController.hide();
            }
        }
    }

    Timer {
        running: root.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: (root.isVertical || root.showLayout) ? 0 : root.s(60)
        y: (!root.isVertical || root.showLayout) ? 0 : root.s(60)
        Behavior on x {
            enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging && (!module || !module.suppressAnimation)
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging && (!module || !module.suppressAnimation)
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    AxisFlow {
        id: trayLayout
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.left: (root.isVertical || root.isEndAligned) ? undefined : parent.left
        anchors.leftMargin: (root.isVertical || root.isEndAligned) ? 0 : root.iconPadding
        anchors.right: (root.isVertical || !root.isEndAligned) ? undefined : parent.right
        anchors.rightMargin: (root.isVertical || !root.isEndAligned) ? 0 : root.iconPadding
        anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
        anchors.top: (!root.isVertical || root.isEndAligned) ? undefined : parent.top
        anchors.topMargin: (!root.isVertical || root.isEndAligned) ? 0 : root.iconPadding
        anchors.bottom: (!root.isVertical || !root.isEndAligned) ? undefined : parent.bottom
        anchors.bottomMargin: (!root.isVertical || !root.isEndAligned) ? 0 : root.iconPadding
        spacing: root.itemSpacing

        Repeater {
            id: trayRepeater
            model: root.moduleActive ? SystemTray.items : null

            onCountChanged: {
                if (count === 0) {
                    TrayMenuController.hide();
                }
            }

            delegate: Image {
                id: trayIcon
                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit

                sourceSize: Qt.size(root.iconSize, root.iconSize)
                width: root.iconSize
                height: root.iconSize

                layer.enabled: true
                layer.smooth: true
                layer.effect: ShaderEffect {
                    property color accentColor: ThemeBackend.mauve
                    fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/icon_recolor.frag.qsb"
                }

                property bool isHovered: trayMouse.containsMouse
                property bool initAnimTrigger: false
                opacity: initAnimTrigger ? (isHovered ? 1.0 : (root.isCompact ? 0.9 : 0.8)) : 0.0
                scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                Component.onCompleted: {
                    if (barWindow && !barWindow.startupCascadeFinished) {
                        trayAnimTimer.interval = index * 45 + 180;
                        if (root.moduleActive) trayAnimTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Component.onDestruction: {
                    if (trayMouse.containsMouse) {
                        TrayMenuController.itemExited();
                    }
                    let idStr = (modelData && modelData.id !== undefined && modelData.id !== null && String(modelData.id).length > 0) ? String(modelData.id) : String(index);
                    if (TrayMenuController.activeItemId === idStr) {
                        TrayMenuController.hide();
                    }
                }

                Timer {
                    id: trayAnimTimer
                    running: false
                    repeat: false
                    onTriggered: trayIcon.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                function openMenu(action) {
                    TrayMenuController.cancelHide();
                    let pt = root.anchorPointFor(trayIcon);
                    let scr = (barWindow && barWindow.screen) ? barWindow.screen : null;
                    let idStr = (modelData && modelData.id !== undefined && modelData.id !== null && String(modelData.id).length > 0) ? String(modelData.id) : String(index);
                    let spanStart = barWindow ? (root.isVertical ? barWindow.currentBarMinY : barWindow.currentBarMinX) : 0;
                    let spanEnd = barWindow ? (root.isVertical ? barWindow.currentBarMaxY : barWindow.currentBarMaxX) : 0;

                    if (action === "toggle") {
                        TrayMenuController.toggle(idStr, scr, pt.x, pt.y, root.isVertical && root.isRightBar, !root.isVertical && root.isBottomBar, root.isVertical, spanStart, spanEnd);
                    } else {
                        TrayMenuController.itemEntered(idStr, scr, pt.x, pt.y, root.isVertical && root.isRightBar, !root.isVertical && root.isBottomBar, root.isVertical, spanStart, spanEnd);
                    }
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    anchors.margins: -root.s(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onEntered: {
                        trayIcon.openMenu("show");
                    }

                    onExited: {
                        TrayMenuController.itemExited();
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.isMenuOnly || modelData.onlyMenu) {
                                trayIcon.openMenu("toggle");
                            } else if (typeof modelData.activate === "function") {
                                modelData.activate();
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            if (typeof modelData.secondaryActivate === "function") {
                                modelData.secondaryActivate();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.menu) {
                                trayIcon.openMenu("toggle");
                            } else if (typeof modelData.contextMenu === "function") {
                                modelData.contextMenu(mouse.x, mouse.y);
                            } else if (typeof modelData.activate === "function") {
                                modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
