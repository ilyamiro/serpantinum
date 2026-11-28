import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PopoutMenuWindow {
    id: desktopMenuWindow

    screen: DesktopMenuController.screen
    WlrLayershell.namespace: "desktopmenu"
    WlrLayershell.layer: WlrLayer.Bottom
    focusable: desktopMenuWindow.isVisible

    menuOpen: DesktopMenuController.isVisible
    anchorX: DesktopMenuController.targetX
    anchorY: DesktopMenuController.targetY
    menuX: clampedX
    menuY: clampedY
    menuWidth: s(170)
    menuHeight: contentCol.implicitHeight
    closeDuration: 75

    readonly property bool isVisible: DesktopMenuController.isVisible
    readonly property bool isWidgetMode: DesktopMenuController.mode === "widget"
    readonly property real targetX: DesktopMenuController.targetX
    readonly property real targetY: DesktopMenuController.targetY
    readonly property bool isNightLightActive: Gamma.anyEnabled

    onMenuOpenChanged: {
        if (menuOpen) {
            rootContainerItem.forceActiveFocus();
        }
    }

    Connections {
        target: DesktopMenuController
        function onMenuTriggered() {
            rootContainerItem.forceActiveFocus();
            desktopMenuWindow.restartOpenAnim();
        }
    }

    Connections {
        target: desktopMenuWindow.rootContainerItem
        function onActiveFocusChanged() {
            if (!desktopMenuWindow.rootContainerItem.activeFocus && desktopMenuWindow.isVisible && desktopMenuWindow.animProgress > 0.5) {
                DesktopMenuController.hide();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: desktopMenuWindow.isVisible
        onActivated: DesktopMenuController.hide()
    }

    readonly property real cornerRadius: (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
        ? ThemeBackend.borderRadius
        : s(12)

    readonly property color menuBackgroundColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.base) ? ThemeBackend.base : "#1e1e2e"
    readonly property color buttonColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? ThemeBackend.surface0 : "#313244"
    readonly property color primaryButtonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.primary) return ThemeBackend.primary;
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.blue) return ThemeBackend.blue;
        return "#89b4fa";
    }
    readonly property color primaryTextColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.base) ? ThemeBackend.base : "#1e1e2e"

    property real menuOffset: s(3)

    readonly property var dockInfo: SurfaceRegistry.dockAvoidance(desktopMenuWindow.screen)

    readonly property real clampedX: {
        let w = menuWidth;
        let margin = s(8);
        let dockLeft = SurfaceRegistry.dockMarginFor(desktopMenuWindow.screen, "left");
        let dockRight = SurfaceRegistry.dockMarginFor(desktopMenuWindow.screen, "right");
        let maxRight = desktopMenuWindow.width - margin - dockRight;
        let minLeft = margin + dockLeft;
        let off = (targetX + w > maxRight) ? -menuOffset : menuOffset;
        if (targetX + w > maxRight) {
            return Math.max(minLeft, targetX - w + off);
        }
        return Math.max(minLeft, Math.min(maxRight - w, targetX + off));
    }

    readonly property real clampedY: {
        let h = menuHeight;
        let margin = s(8);
        let dockTop = SurfaceRegistry.dockMarginFor(desktopMenuWindow.screen, "top");
        let dockBottom = SurfaceRegistry.dockMarginFor(desktopMenuWindow.screen, "bottom");
        let maxBottom = desktopMenuWindow.height - margin - dockBottom;
        let minTop = margin + dockTop;
        let off = (targetY + h > maxBottom) ? -menuOffset : menuOffset;
        if (targetY + h > maxBottom) {
            return Math.max(minTop, targetY - h + off);
        }
        return Math.max(minTop, Math.min(maxBottom - h, targetY + off));
    }

    readonly property bool alignRight: (targetX + menuWidth > desktopMenuWindow.width - s(8))

    Timer {
        id: reloadTimer
        interval: 50
        repeat: false
        onTriggered: ShellRouter.reload()
    }

    function toggleNightLight() {
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("system/quick_click.wav");
        }
        Gamma.toggleAll();
    }

    function shuffleWallpaper() {
        let scr = desktopMenuWindow.screen || DesktopMenuController.screen;
        let scrName = (scr && scr.name) ? scr.name : "all";

        let scrW = desktopMenuWindow.width > 0 ? desktopMenuWindow.width : ((scr && scr.geometry && scr.geometry.width) ? scr.geometry.width : 1920);
        let scrH = desktopMenuWindow.height > 0 ? desktopMenuWindow.height : ((scr && scr.geometry && scr.geometry.height) ? scr.geometry.height : 1080);
        let posX = Math.max(desktopMenuWindow.clampedX, Math.min(desktopMenuWindow.clampedX + desktopMenuWindow.menuWidth, desktopMenuWindow.targetX));
        let posY = Math.max(desktopMenuWindow.clampedY, Math.min(desktopMenuWindow.clampedY + desktopMenuWindow.menuHeight, desktopMenuWindow.targetY));
        let normX = scrW > 0 ? Math.max(0.0, Math.min(1.0, posX / scrW)) : 0.5;
        let normY = scrH > 0 ? Math.max(0.0, Math.min(1.0, posY / scrH)) : 0.5;

        DesktopMenuController.menuOriginX = normX;
        DesktopMenuController.menuOriginY = normY;
        DesktopMenuController.isMenuShuffle = true;

        Wallpaper.shuffle(scrName, "circle:" + normX + ":" + normY);
    }

    function lockScreen() {
        DesktopMenuController.hide();
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/lock.sh") : "lock.sh";
        Quickshell.execDetached(["bash", scriptPath]);
    }

    function openRedactor(selectedWidgetId) {
        DesktopMenuController.hide();
        let targetId = selectedWidgetId !== undefined ? String(selectedWidgetId) : "";
        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/redactor.sh") : "redactor.sh";
        Quickshell.execDetached(["bash", scriptPath, mon, targetId]);
    }

    function openGuide(tab) {
        DesktopMenuController.hide();
        let targetTab = tab !== undefined ? String(tab).trim() : "";
        ShellRouter.toggle("settings", targetTab, desktopMenuWindow.screen);
    }

    Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: desktopMenuWindow.s(2)

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Item {
                visible: desktopMenuWindow.alignRight
                Layout.fillWidth: true
            }

            Rectangle {
                id: iconButtonsBox
                Layout.preferredWidth: iconRow.implicitWidth + desktopMenuWindow.s(8)
                Layout.preferredHeight: iconRow.implicitHeight + desktopMenuWindow.s(8)
                color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
                radius: desktopMenuWindow.cornerRadius
                clip: true

                WallpaperBlur {
                    z: -1
                    anchors.fill: parent
                    radius: parent.radius
                }

                Row {
                    id: iconRow
                    anchors.centerIn: parent
                    spacing: desktopMenuWindow.s(3)

                    IconButton {
                        visible: desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: desktopMenuWindow.primaryButtonColor
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: desktopMenuWindow.primaryTextColor
                        buttonIcon: "󰏫"
                        iconFontSize: desktopMenuWindow.s(16)
                        onClicked: desktopMenuWindow.openRedactor(DesktopMenuController.targetWidgetId)
                    }

                    IconButton {
                        visible: !desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: desktopMenuWindow.primaryButtonColor
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: desktopMenuWindow.primaryTextColor
                        buttonIcon: "󰒝"
                        iconFontSize: desktopMenuWindow.s(16)
                        onClicked: {
                            desktopMenuWindow.shuffleWallpaper();
                            DesktopMenuController.hide();
                        }
                    }

                    IconButton {
                        id: nightLightBtn
                        visible: !desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.peach) ? ThemeBackend.peach : "#fab387") : desktopMenuWindow.buttonColor
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.crust) ? ThemeBackend.crust : ((typeof ThemeBackend !== "undefined" && ThemeBackend.base) ? ThemeBackend.base : "#1e1e2e")) : ((typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4")
                        buttonIcon: "󰖔"
                        iconOffsetY: -1
                        iconFontSize: desktopMenuWindow.s(16)
                        onClicked: desktopMenuWindow.toggleNightLight()
                    }

                    IconButton {
                        id: reloadBtn
                        visible: !desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: desktopMenuWindow.buttonColor
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        buttonIcon: "󰑐"
                        iconFontSize: desktopMenuWindow.s(16)
                        onClicked: {
                            DesktopMenuController.hide();
                            reloadTimer.restart();
                        }
                    }

                    IconButton {
                        id: lockBtn
                        visible: !desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: desktopMenuWindow.buttonColor
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text
                        buttonIcon: ""
                        iconFontSize: desktopMenuWindow.s(16)
                        onClicked: desktopMenuWindow.lockScreen()
                    }

                    DeleteButton {
                        visible: desktopMenuWindow.isWidgetMode
                        width: desktopMenuWindow.s(36)
                        height: desktopMenuWindow.s(36)
                        size: height
                        cornerRadius: desktopMenuWindow.s(8)
                        accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.22) : "#452026"
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? ThemeBackend.red : "#f38ba8"
                        onClicked: {
                            let wId = DesktopMenuController.targetWidgetId;
                            if (wId) {
                                let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
                                if (typeof WidgetSync !== "undefined") {
                                    WidgetSync.removeWidget(mon, wId);
                                }
                            }
                            DesktopMenuController.hide();
                        }
                    }
                }
            }

            Item {
                visible: !desktopMenuWindow.alignRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            id: clickButtonsBox
            width: parent.width
            height: clickButtonsCol.implicitHeight + desktopMenuWindow.s(8)
            color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
            radius: desktopMenuWindow.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            Column {
                id: clickButtonsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: desktopMenuWindow.s(4)
                spacing: desktopMenuWindow.s(2)

                ClickButton {
                    visible: desktopMenuWindow.isWidgetMode
                    width: parent.width
                    height: desktopMenuWindow.s(29)
                    cornerRadius: desktopMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: desktopMenuWindow.s(10)
                    buttonIcon: "󰕰"
                    iconFontSize: desktopMenuWindow.s(15)
                    textFontSize: desktopMenuWindow.s(12)
                    buttonText: I18n.t("guide.display.widgets.open", "Open redactor")
                    accentColor: desktopMenuWindow.primaryButtonColor
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: desktopMenuWindow.primaryTextColor
                    onClicked: desktopMenuWindow.openRedactor("")
                }

                ClickButton {
                    visible: !desktopMenuWindow.isWidgetMode
                    width: parent.width
                    height: desktopMenuWindow.s(29)
                    cornerRadius: desktopMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: desktopMenuWindow.s(10)
                    buttonIcon: "󰸉"
                    iconFontSize: desktopMenuWindow.s(15)
                    textFontSize: desktopMenuWindow.s(12)
                    buttonText: I18n.t("guide.theme.wallpaper.select_wallpaper", "Select wallpaper")
                    accentColor: desktopMenuWindow.buttonColor
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: {
                        DesktopMenuController.hide();
                        ShellRouter.toggle("wallpaper", "", desktopMenuWindow.screen);
                    }
                }

                ClickButton {
                    visible: !desktopMenuWindow.isWidgetMode
                    width: parent.width
                    height: desktopMenuWindow.s(29)
                    cornerRadius: desktopMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: desktopMenuWindow.s(10)
                    buttonIcon: "󰕰"
                    iconFontSize: desktopMenuWindow.s(15)
                    textFontSize: desktopMenuWindow.s(12)
                    buttonText: I18n.t("guide.display.widgets.open", "Widget redactor")
                    accentColor: desktopMenuWindow.buttonColor
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: desktopMenuWindow.openRedactor("")
                }

                ClickButton {
                    visible: !desktopMenuWindow.isWidgetMode
                    width: parent.width
                    height: desktopMenuWindow.s(29)
                    cornerRadius: desktopMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: desktopMenuWindow.s(10)
                    buttonIcon: "󰏘"
                    iconFontSize: desktopMenuWindow.s(15)
                    textFontSize: desktopMenuWindow.s(12)
                    buttonText: I18n.t("guide.tabs.theme", "Theme")
                    accentColor: desktopMenuWindow.buttonColor
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: desktopMenuWindow.openGuide("theme")
                }
            }
        }

        Rectangle {
            id: settingsBox
            width: parent.width
            height: settingsCol.implicitHeight + desktopMenuWindow.s(8)
            color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
            radius: desktopMenuWindow.cornerRadius
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            Column {
                id: settingsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: desktopMenuWindow.s(4)

                ClickButton {
                    width: parent.width
                    height: desktopMenuWindow.s(29)
                    cornerRadius: desktopMenuWindow.s(8)
                    contentAlignment: Qt.AlignLeft
                    horizontalPadding: desktopMenuWindow.s(10)
                    buttonIcon: "󰒓"
                    iconFontSize: desktopMenuWindow.s(15)
                    textFontSize: desktopMenuWindow.s(12)
                    buttonText: I18n.t("widgets.guide.name", "Settings")
                    accentColor: desktopMenuWindow.buttonColor
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: ThemeBackend.text
                    onClicked: {
                        if (desktopMenuWindow.isWidgetMode) {
                            desktopMenuWindow.openGuide("display_widgets");
                        } else {
                            desktopMenuWindow.openGuide("");
                        }
                    }
                }
            }
        }
    }
}
