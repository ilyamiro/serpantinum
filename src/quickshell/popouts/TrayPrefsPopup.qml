import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PanelWindow {
    id: trayPrefsWindow

    screen: TrayPrefsController.screen

    WlrLayershell.namespace: "trayprefspopup"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: TrayPrefsController.isVisible
    property real targetX: TrayPrefsController.targetX
    property real targetY: TrayPrefsController.targetY
    property bool alignRight: TrayPrefsController.alignRight
    property bool alignBottom: TrayPrefsController.alignBottom

    readonly property var trayItems: SystemTray.items ? SystemTray.items.values : []

    onIsVisibleChanged: {
        if (isVisible) {
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Item {
        id: maskTarget
        x: trayPrefsWindow.clampedX
        y: trayPrefsWindow.clampedY
        width: trayPrefsWindow.menuWidth
        height: trayPrefsWindow.menuHeight
    }

    mask: Region {
        item: (trayPrefsWindow.isVisible || menuContainer.animProgress > 0.001) ? maskTarget : null
    }

    property real cornerRadius: ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null
        ? ThemeBackend.borderRadius
        : s(12)

    property real contentMargin: s(10)
    property real menuWidth: s(240)
    property real menuHeight: contentCol.implicitHeight + contentMargin * 2
    property real menuOffset: s(10)
    property real edgeMargin: s(12)

    property real computedTargetX: alignRight ? (targetX - menuWidth) : targetX
    property real computedTargetY: alignBottom ? (targetY - menuHeight - menuOffset) : (targetY + menuOffset)

    property real clampedX: {
        let maxX = trayPrefsWindow.width - menuWidth - edgeMargin;
        let x = isNaN(computedTargetX) ? edgeMargin : computedTargetX;
        return Math.max(edgeMargin, Math.min(maxX, x));
    }

    property real clampedY: {
        let maxY = trayPrefsWindow.height - menuHeight - edgeMargin;
        let y = isNaN(computedTargetY) ? edgeMargin : computedTargetY;
        return Math.max(edgeMargin, Math.min(maxY, y));
    }

    visible: isVisible || menuContainer.animProgress > 0.001

    Item {
        id: menuContainer
        property real animProgress: 0.0

        NumberAnimation {
            id: openAnim
            target: menuContainer
            property: "animProgress"
            from: menuContainer.animProgress > 0.8 ? 0.2 : 0.0
            to: 1.0
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        }

        NumberAnimation {
            id: closeAnim
            target: menuContainer
            property: "animProgress"
            to: 0.0
            duration: 90
            easing.type: Easing.InCubic
            onFinished: {
                if (!trayPrefsWindow.isVisible) menuContainer.animProgress = 0.0;
            }
        }

        HoverHandler {
            id: menuHover
            onHoveredChanged: {
                if (hovered) {
                    autoCloseTimer.stop();
                } else if (trayPrefsWindow.isVisible) {
                    autoCloseTimer.interval = 1200;
                    autoCloseTimer.restart();
                }
            }
        }

        Timer {
            id: autoCloseTimer
            interval: 3000
            repeat: false
            onTriggered: {
                if (!menuHover.hovered) TrayPrefsController.hide();
            }
        }

        Connections {
            target: trayPrefsWindow
            function onIsVisibleChanged() {
                if (trayPrefsWindow.isVisible) {
                    autoCloseTimer.interval = 3000;
                    autoCloseTimer.restart();
                } else {
                    autoCloseTimer.stop();
                }
            }
        }

        x: trayPrefsWindow.clampedX
        y: trayPrefsWindow.clampedY
        width: trayPrefsWindow.menuWidth
        height: trayPrefsWindow.menuHeight

        opacity: Math.max(0.0, Math.min(1.0, animProgress * 2.5))

        transform: Scale {
            origin.x: trayPrefsWindow.targetX - trayPrefsWindow.clampedX
            origin.y: trayPrefsWindow.targetY - trayPrefsWindow.clampedY
            xScale: Math.max(0.0, menuContainer.animProgress)
            yScale: Math.max(0.0, menuContainer.animProgress)
        }

        Rectangle {
            anchors.fill: parent
            radius: trayPrefsWindow.cornerRadius
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            ColumnLayout {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: trayPrefsWindow.contentMargin
                spacing: trayPrefsWindow.s(6)

                Text {
                    Layout.fillWidth: true
                    text: "Tray Icons"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: trayPrefsWindow.s(12)
                    color: ThemeBackend.text
                }

                Text {
                    Layout.fillWidth: true
                    visible: trayPrefsWindow.trayItems.length === 0
                    text: "No tray icons running"
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: trayPrefsWindow.s(11)
                    color: ThemeBackend.subtext0
                }

                Repeater {
                    model: trayPrefsWindow.trayItems

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: trayPrefsWindow.s(8)

                        Image {
                            Layout.preferredWidth: trayPrefsWindow.s(16)
                            Layout.preferredHeight: trayPrefsWindow.s(16)
                            Layout.alignment: Qt.AlignVCenter
                            source: modelData.icon || ""
                            sourceSize: Qt.size(trayPrefsWindow.s(16), trayPrefsWindow.s(16))
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.title || modelData.id || ""
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: trayPrefsWindow.s(11)
                            color: ThemeBackend.text
                        }

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: !TrayPrefs.isHidden(modelData)
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) { TrayPrefs.setHidden(modelData, !c); }
                        }
                    }
                }
            }
        }
    }
}
