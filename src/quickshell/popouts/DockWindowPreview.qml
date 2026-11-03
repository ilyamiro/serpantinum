import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

// Hover preview for a dock app (opened by DockPreviewController): one card per window of the app,
// side by side, each with the window's latest snapshot. Click a card to focus it (a minimized window is
// brought back to the current workspace), middle-click or the x to close it.
PanelWindow {
    id: previewWindow

    screen: DockPreviewController.screen

    WlrLayershell.namespace: "dockpreview"
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

    property bool isVisible: DockPreviewController.isVisible
    property real targetX: DockPreviewController.targetX
    property real targetY: DockPreviewController.targetY
    property string dockPosition: DockPreviewController.dockPosition
    // The popup keeps its own copy of the windows: the controller empties its list the moment it hides,
    // which would collapse the panel from the sides during the fade-out. We only follow it while visible.
    property var windowsList: []
    Connections {
        target: DockPreviewController
        function onWindowsChanged() {
            if (DockPreviewController.isVisible) previewWindow.windowsList = DockPreviewController.windows;
        }
    }
    readonly property var dockSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock) ? Config.rawSettings.dock : ({})

    readonly property real cardW: s(232)
    readonly property real thumbH: s(132)
    readonly property real cardH: thumbH + s(48)
    readonly property real pad: s(10)
    readonly property real gap: s(10)
    readonly property real edgeMargin: s(12)
    readonly property real menuOffset: s(16) + (dockSettings.floating ? s(8) : 0)
    readonly property real dockButtonSize: DockPreviewController.buttonSize > 0 ? DockPreviewController.buttonSize : (dockSettings.elementSize ? s(dockSettings.elementSize) : s(44))

    // as many cards as fit on the screen (extra windows are reachable through the right-click menu)
    readonly property int maxCards: Math.max(1, Math.floor((width - 2 * edgeMargin - 2 * pad + gap) / (cardW + gap)))
    readonly property int shownCount: Math.min(maxCards, windowsList ? windowsList.length : 0)
    readonly property real menuWidth: shownCount * cardW + Math.max(0, shownCount - 1) * gap + 2 * pad
    readonly property real menuHeight: cardH + 2 * pad

    readonly property real computedX: {
        let halfBtn = dockButtonSize / 2;
        if (dockPosition === "left") return targetX + halfBtn + menuOffset;
        if (dockPosition === "right") return targetX - halfBtn - menuWidth - menuOffset;
        return targetX - menuWidth / 2;
    }
    readonly property real computedY: {
        let halfBtn = dockButtonSize / 2;
        if (dockPosition === "top") return targetY + halfBtn + menuOffset;
        if (dockPosition === "bottom") return targetY - halfBtn - menuHeight - menuOffset;
        return targetY - menuHeight / 2;
    }
    readonly property real clampedX: Math.max(edgeMargin, Math.min(width - menuWidth - edgeMargin, isNaN(computedX) ? edgeMargin : computedX))
    readonly property real clampedY: Math.max(edgeMargin, Math.min(height - menuHeight - edgeMargin, isNaN(computedY) ? edgeMargin : computedY))

    function iconSource(ic) {
        if (!ic) return "";
        if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
        return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
    }

    visible: isVisible || container.animProgress > 0.001

    onIsVisibleChanged: {
        if (isVisible) {
            windowsList = DockPreviewController.windows;
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Item {
        id: maskTarget
        x: previewWindow.clampedX
        y: previewWindow.clampedY
        width: previewWindow.menuWidth
        height: previewWindow.menuHeight
    }

    mask: Region {
        item: (previewWindow.isVisible || container.animProgress > 0.001) ? maskTarget : null
    }

    Item {
        id: container
        x: previewWindow.clampedX
        y: previewWindow.clampedY
        width: previewWindow.menuWidth
        height: previewWindow.menuHeight

        property real animProgress: 0.0
        opacity: animProgress
        // slide a few pixels toward the dock while fading, instead of scaling (which looked like closing from the sides)
        transform: Translate {
            readonly property real d: (1.0 - container.animProgress) * previewWindow.s(8)
            x: previewWindow.dockPosition === "left" ? -d : (previewWindow.dockPosition === "right" ? d : 0)
            y: previewWindow.dockPosition === "top" ? -d : (previewWindow.dockPosition === "bottom" ? d : 0)
        }

        NumberAnimation { id: openAnim; target: container; property: "animProgress"; to: 1.0; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { id: closeAnim; target: container; property: "animProgress"; to: 0.0; duration: 150; easing.type: Easing.OutCubic }

        // Keep the preview open while the pointer is on it; close shortly after it leaves.
        HoverHandler {
            onHoveredChanged: {
                if (hovered) DockPreviewController.cancelHide();
                else DockPreviewController.scheduleHide();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.94)
            border.color: ThemeBackend.surface1
            border.width: 1
        }

        Row {
            x: previewWindow.pad
            y: previewWindow.pad
            spacing: previewWindow.gap

            Repeater {
                model: previewWindow.shownCount

                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property var win: previewWindow.windowsList[index]
                    readonly property bool minimized: win ? Boolean(win.minimized) : false
                    readonly property bool focused: win ? Boolean(win.focused) : false

                    width: previewWindow.cardW
                    height: previewWindow.cardH
                    radius: Math.max(0, ThemeBackend.borderRadius - previewWindow.s(2))
                    color: cardHover.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0
                    readonly property bool navSelected: DockPreviewController.navMode && index === DockPreviewController.selectedIndex
                    border.width: navSelected ? 3 : ((focused && !DockPreviewController.navMode) ? 2 : 0)
                    border.color: ThemeBackend.mauve
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: cardHover }

                    // thumbnail (clipped to a rounded rectangle)
                    Item {
                        id: thumbArea
                        x: previewWindow.s(6)
                        y: previewWindow.s(6)
                        width: card.width - previewWindow.s(12)
                        height: previewWindow.thumbH

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.max(0, card.radius - previewWindow.s(3))
                            color: ThemeBackend.mantle
                        }

                        Rectangle {
                            id: thumbMask
                            anchors.fill: parent
                            radius: Math.max(0, card.radius - previewWindow.s(3))
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: thumb.status === Image.Ready || liveView.hasContent
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbMask }

                            Image {
                                id: thumb
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: Math.round(previewWindow.cardW * 2)
                                sourceSize.height: Math.round(previewWindow.thumbH * 2)
                                source: (typeof WindowTracker !== "undefined" && card.win)
                                    ? WindowTracker.thumbUrl(card.win) + "?v=" + DockPreviewController.revision : ""
                                // the saved snapshot is only a fallback: once a live frame exists it must not show through
                                // (translucent windows would otherwise blend the old picture into the new one)
                                opacity: (status === Image.Ready && !liveView.hasContent) ? (card.minimized ? 0.8 : 1.0) : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // The window's CURRENT contents (captured once each time the preview opens, never live-streamed,
                            // and without any dock/popup overlay in the picture). The saved snapshot above is only the fallback
                            // for windows that cannot be captured right now.
                            ScreencopyView {
                                id: liveView
                                readonly property real fit: sourceSize.width > 0 && sourceSize.height > 0
                                    ? Math.max(parent.width / sourceSize.width, parent.height / sourceSize.height) : 1
                                anchors.centerIn: parent
                                width: sourceSize.width * fit
                                height: sourceSize.height * fit
                                captureSource: (card.win && card.win.native && card.win.native.wayland) ? card.win.native.wayland : null
                                live: false
                                // keep it "visible" (a hidden view never starts capturing) and fade it in once a frame exists
                                opacity: hasContent ? (card.minimized ? 0.8 : 1.0) : 0.0

                                Component.onCompleted: if (captureSource) captureFrame()
                                Connections {
                                    target: DockPreviewController
                                    function onRevisionChanged() { if (liveView.captureSource) liveView.captureFrame(); }
                                }
                            }
                        }

                        // no snapshot yet: show the app icon instead
                        Image {
                            anchors.centerIn: parent
                            width: previewWindow.s(48)
                            height: width
                            visible: thumb.status !== Image.Ready && !liveView.hasContent
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 96
                            sourceSize.height: 96
                            source: previewWindow.iconSource(DockPreviewController.appIcon)
                            opacity: 0.85
                        }

                        Rectangle {
                            visible: card.minimized
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: previewWindow.s(6)
                            height: previewWindow.s(20)
                            width: badgeText.implicitWidth + previewWindow.s(14)
                            radius: height / 2
                            color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.78)
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: I18n.t("dockpreview.minimized")
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: previewWindow.s(10)
                            }
                        }
                    }

                    // title + close
                    Item {
                        x: previewWindow.s(10)
                        y: thumbArea.y + thumbArea.height + previewWindow.s(2)
                        width: card.width - previewWindow.s(20)
                        height: card.height - y - previewWindow.s(4)

                        Text {
                            anchors.left: parent.left
                            anchors.right: closeBtn.left
                            anchors.rightMargin: previewWindow.s(6)
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.win && card.win.title ? card.win.title : I18n.t("dockpreview.untitled")
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: previewWindow.s(12)
                        }

                        Rectangle {
                            id: closeBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: previewWindow.s(22)
                            height: width
                            radius: width / 2
                            visible: cardHover.hovered
                            color: closeMa.containsMouse ? ThemeBackend.red : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰖭"
                                color: closeMa.containsMouse ? ThemeBackend.crust : ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: previewWindow.s(12)
                            }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { if (card.win && typeof WindowTracker !== "undefined") WindowTracker.close(card.win); }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: function(mouse) {
                            if (!card.win || typeof WindowTracker === "undefined") return;
                            if (mouse.button === Qt.MiddleButton) {
                                WindowTracker.close(card.win);
                            } else {
                                WindowTracker.focusWindow(card.win);
                                DockPreviewController.hide();
                            }
                        }
                    }
                }
            }
        }
    }
}
