import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PopoutMenuWindow {
    id: dockAppMenuWindow

    screen: DockAppMenuController.screen
    WlrLayershell.namespace: "dockappmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false

    menuOpen: DockAppMenuController.isVisible
    anchorX: DockAppMenuController.targetX
    anchorY: DockAppMenuController.targetY
    menuX: clampedX
    menuY: clampedY
    menuWidth: s(248)
    menuHeight: contentCol.implicitHeight
    closeDuration: 90

    readonly property bool isVisible: DockAppMenuController.isVisible
    readonly property real targetX: DockAppMenuController.targetX
    readonly property real targetY: DockAppMenuController.targetY
    readonly property string dockPosition: DockAppMenuController.dockPosition
    property var windowsList: []
    readonly property bool hasWindows: windowsList && windowsList.length > 0

    onMenuOpenChanged: {
        if (menuOpen) {
            autoCloseTimer.interval = 2400;
            autoCloseTimer.restart();
        } else {
            autoCloseTimer.stop();
        }
    }

    Connections {
        target: DockAppMenuController
        function onMenuTriggered() {
            dockAppMenuWindow.windowsList = DockAppMenuController.windows;
            dockAppMenuWindow.restartOpenAnim();
            autoCloseTimer.interval = 2400;
            autoCloseTimer.restart();
        }
        function onWindowsChanged() {
            if (DockAppMenuController.isVisible) {
                dockAppMenuWindow.windowsList = DockAppMenuController.windows;
            }
        }
    }

    readonly property var dockSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock) ? Config.rawSettings.dock : ({})

    readonly property real cornerRadius: ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null
        ? ThemeBackend.borderRadius
        : s(12)

    readonly property real menuOffset: s(16) + (dockSettings.floating ? s(8) : 0)
    readonly property real dockButtonSize: DockAppMenuController.buttonSize > 0 ? DockAppMenuController.buttonSize : (dockSettings.elementSize ? s(dockSettings.elementSize) : s(44))

    readonly property real computedTargetX: {
        let w = menuWidth;
        let halfBtn = dockButtonSize / 2;
        if (dockPosition === "left") {
            return targetX + halfBtn + menuOffset;
        } else if (dockPosition === "right") {
            return targetX - halfBtn - w - menuOffset;
        } else {
            return targetX - (w / 2);
        }
    }

    readonly property real computedTargetY: {
        let h = menuHeight;
        let halfBtn = dockButtonSize / 2;
        if (dockPosition === "top") {
            return targetY + halfBtn + menuOffset;
        } else if (dockPosition === "bottom") {
            return targetY - halfBtn - h - menuOffset;
        } else {
            return targetY - (h / 2);
        }
    }

    readonly property real edgeMargin: s(12)

    readonly property real clampedX: {
        let maxX = dockAppMenuWindow.width - menuWidth - edgeMargin;
        let x = isNaN(computedTargetX) ? edgeMargin : computedTargetX;
        return Math.max(edgeMargin, Math.min(maxX, x));
    }

    readonly property real clampedY: {
        let maxY = dockAppMenuWindow.height - menuHeight - edgeMargin;
        let y = isNaN(computedTargetY) ? edgeMargin : computedTargetY;
        return Math.max(edgeMargin, Math.min(maxY, y));
    }

    HoverHandler {
        id: menuHover
        onHoveredChanged: {
            if (hovered) {
                autoCloseTimer.stop();
            } else if (dockAppMenuWindow.isVisible) {
                autoCloseTimer.interval = 800;
                autoCloseTimer.restart();
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 2400
        repeat: false
        onTriggered: {
            if (!menuHover.hovered) DockAppMenuController.hide();
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: dockAppMenuWindow.s(4)

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: dockAppMenuWindow.s(32) + dockAppMenuWindow.s(8)
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: dockAppMenuWindow.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            Item {
                anchors.fill: parent
                anchors.margins: dockAppMenuWindow.s(4)

                ClickButton {
                    anchors.fill: parent
                    cornerRadius: dockAppMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: dockAppMenuWindow.s(40)
                    textFontSize: dockAppMenuWindow.s(12)
                    buttonText: DockAppMenuController.appName || DockAppMenuController.desktopId
                    accentColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: {
                        if (dockAppMenuWindow.hasWindows) {
                            if (typeof WindowTracker !== "undefined") {
                                WindowTracker.focusWindow(dockAppMenuWindow.windowsList[0]);
                            }
                        } else if (typeof DesktopEntries !== "undefined" && DockAppMenuController.desktopId) {
                            let entry = DesktopEntries.byId(DockAppMenuController.desktopId) || DesktopEntries.byId(String(DockAppMenuController.desktopId).replace(/\.desktop$/, ""));
                            if (entry) AppMatcher.launch(entry);
                        }
                        DockAppMenuController.hide();
                    }
                }

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: dockAppMenuWindow.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: dockAppMenuWindow.s(20)
                    height: dockAppMenuWindow.s(20)
                    source: AppMatcher.iconSource(DockAppMenuController.appIcon)
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready && !AppMatcher.iconMissing(source)
                }

                Rectangle {
                    visible: dockAppMenuWindow.hasWindows
                    anchors.right: parent.right
                    anchors.rightMargin: dockAppMenuWindow.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(height, badgeText.implicitWidth + dockAppMenuWindow.s(10))
                    height: dockAppMenuWindow.s(18)
                    radius: height / 2
                    color: Qt.alpha(ThemeBackend.base, 0.6)

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: String(dockAppMenuWindow.windowsList ? dockAppMenuWindow.windowsList.length : 0)
                        color: ThemeBackend.subtext0
                        font.pixelSize: dockAppMenuWindow.s(10)
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Rectangle {
            visible: dockAppMenuWindow.hasWindows
            Layout.fillWidth: true
            Layout.preferredHeight: windowsCol.implicitHeight + dockAppMenuWindow.s(8)
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: dockAppMenuWindow.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            ColumnLayout {
                id: windowsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: dockAppMenuWindow.s(4)
                spacing: dockAppMenuWindow.s(2)

                Repeater {
                    model: dockAppMenuWindow.windowsList

                    delegate: RowLayout {
                        id: windowRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: dockAppMenuWindow.s(30)
                        spacing: 0

                        HoverHandler { id: rowHover }

                        ClickButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            cornerRadius: dockAppMenuWindow.s(7)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: dockAppMenuWindow.s(8)
                            buttonIcon: "󰖲"
                            iconFontSize: dockAppMenuWindow.s(13)
                            textFontSize: dockAppMenuWindow.s(11)
                            buttonText: {
                                let t = modelData.title || I18n.t("guide.dock.window_menu.untitled", "Untitled");
                                let ws = (modelData.workspaceLabel !== undefined && modelData.workspaceLabel !== "") ? (" [" + modelData.workspaceLabel + "]") : "";
                                return t + ws;
                            }
                            accentColor: modelData.focused ? ThemeBackend.mauve : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: modelData.focused ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: {
                                if (typeof WindowTracker !== "undefined") {
                                    WindowTracker.focusWindow(modelData);
                                }
                                DockAppMenuController.hide();
                            }
                        }

                        Item {
                            Layout.preferredWidth: rowHover.hovered ? dockAppMenuWindow.s(30) + dockAppMenuWindow.s(2) : 0
                            Layout.fillHeight: true
                            clip: true
                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            CloseButton {
                                x: parent.width - width
                                width: dockAppMenuWindow.s(30)
                                height: dockAppMenuWindow.s(30)
                                size: dockAppMenuWindow.s(30)
                                cornerRadius: dockAppMenuWindow.s(7)
                                accentColor: ThemeBackend.surface0
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.red
                                iconFontSize: dockAppMenuWindow.s(13)
                                opacity: rowHover.hovered ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                }
                                onClicked: {
                                    if (typeof WindowTracker !== "undefined") {
                                        WindowTracker.close(modelData);
                                    }
                                    DockAppMenuController.hide();
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: actionsCol.implicitHeight + dockAppMenuWindow.s(8)
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: dockAppMenuWindow.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            ColumnLayout {
                id: actionsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: dockAppMenuWindow.s(4)
                spacing: dockAppMenuWindow.s(2)

                ClickButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: dockAppMenuWindow.s(29)
                    cornerRadius: dockAppMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: dockAppMenuWindow.s(8)
                    buttonIcon: "󰐕"
                    iconFontSize: dockAppMenuWindow.s(14)
                    textFontSize: dockAppMenuWindow.s(11)
                    buttonText: I18n.t("guide.dock.window_menu.new_window", "New window")
                    accentColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: {
                        if (typeof DesktopEntries !== "undefined" && DockAppMenuController.desktopId) {
                            let entry = DesktopEntries.byId(DockAppMenuController.desktopId) || DesktopEntries.byId(String(DockAppMenuController.desktopId).replace(/\.desktop$/, ""));
                            if (entry) AppMatcher.launch(entry);
                        }
                        DockAppMenuController.hide();
                    }
                }

                ClickButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: dockAppMenuWindow.s(29)
                    cornerRadius: dockAppMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: dockAppMenuWindow.s(8)
                    buttonIcon: DockAppMenuController.isPinned ? "󰤰" : "󰤱"
                    iconFontSize: dockAppMenuWindow.s(14)
                    textFontSize: dockAppMenuWindow.s(11)
                    buttonText: DockAppMenuController.isPinned ? I18n.t("guide.dock.window_menu.unpin", "Unpin from dock") : I18n.t("guide.dock.window_menu.pin", "Pin to dock")
                    accentColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: {
                        if (DockAppMenuController.isPinned) {
                            DockAppMenuController.unpinApp(DockAppMenuController.desktopId);
                        } else {
                            DockAppMenuController.pinApp(DockAppMenuController.desktopId, DockAppMenuController.appName, DockAppMenuController.appIcon);
                        }
                        DockAppMenuController.hide();
                    }
                }
            }
        }
    }
}
