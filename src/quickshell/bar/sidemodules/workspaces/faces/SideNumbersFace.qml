import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../../reusables"
import "../../../../"

Item {
    id: sideNumbersFaceRoot
    property var widget: null

    property real pillSize: widget ? widget.s(widget.isCompact ? 20 : 24) : 24
    property real pillRadius: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
    property real layoutSpacing: widget ? widget.s(widget.isCompact ? 5 : 6) : 6

    function isShown(index) {
        if (!widget)
            return false;
        if (typeof widget.isShown === "function")
            return widget.isShown(index);
        return true;
    }

    readonly property var shownIndices: {
        if (!widget)
            return [];
        widget.activeIndex;
        widget.workspaceCount;
        widget.hideEmptyWorkspaces;
        widget.niriOccupiedMap;
        widget.swayOccupiedMap;
        if (!widget.isNiri && !widget.isSway)
            Hyprland.workspaces.values;
        let ids = [];
        for (let i = 0; i < widget.workspaceCount; i++) {
            if (isShown(i))
                ids.push(i);
        }
        return ids;
    }

    implicitWidth: wsLayout.implicitWidth
    implicitHeight: wsLayout.implicitHeight

    Rectangle {
        id: activeHighlight
        z: 0
        x: wsLayout.x + (wsLayout.width - width) / 2
        width: sideNumbersFaceRoot.pillSize
        radius: sideNumbersFaceRoot.pillRadius
        color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve

        property int prevIdx: 0
        property int curIdx: widget ? widget.activeIndex : -1

        onCurIdxChanged: {
            if (curIdx >= 0 && prevIdx >= 0) {
                if (curIdx > prevIdx) {
                    bottomAnim.duration = 200;
                    topAnim.duration = 350;
                } else if (curIdx < prevIdx) {
                    topAnim.duration = 200;
                    bottomAnim.duration = 350;
                }
            }
            if (curIdx >= 0) {
                prevIdx = curIdx;
            }
        }

        function getY(index) {
            if (index < 0)
                return 0;
            let yPos = 0;
            const shown = sideNumbersFaceRoot.shownIndices;
            for (let i = 0; i < shown.length; i++) {
                if (shown[i] === index)
                    break;
                yPos += sideNumbersFaceRoot.pillSize + sideNumbersFaceRoot.layoutSpacing;
            }
            return wsLayout.y + yPos;
        }

        property real targetTop: {
            sideNumbersFaceRoot.shownIndices;
            return curIdx >= 0 ? getY(curIdx) : 0;
        }
        property real targetBottom: (curIdx >= 0) ? (targetTop + sideNumbersFaceRoot.pillSize) : 0

        property real actualTop: targetTop
        property real actualBottom: targetBottom

        Behavior on actualTop { NumberAnimation { id: topAnim; duration: 250; easing.type: Easing.OutExpo } }
        Behavior on actualBottom { NumberAnimation { id: bottomAnim; duration: 250; easing.type: Easing.OutExpo } }

        y: actualTop
        height: actualBottom - actualTop
        opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Column {
        id: wsLayout
        z: 1
        anchors.centerIn: parent
        spacing: sideNumbersFaceRoot.layoutSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: wsPill
                required property int index

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool isHovered: wsPillMouse.containsMouse
                property bool initAnimTrigger: false
                property bool shown: sideNumbersFaceRoot.isShown(index)

                visible: shown
                width: sideNumbersFaceRoot.pillSize
                height: shown ? sideNumbersFaceRoot.pillSize : 0

                Rectangle {
                    anchors.fill: parent
                    radius: sideNumbersFaceRoot.pillRadius
                    color: wsPill.isHovered
                        ? Qt.alpha(ThemeBackend.text, 0.1)
                        : (wsPill.isActive ? "transparent" : (wsPill.isOccupied ? Qt.alpha(ThemeBackend.text, 0.15) : "transparent"))

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.isHovered && !wsPill.isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: wsPill.initAnimTrigger ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                }

                Component.onCompleted: {
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 60;
                        if (widget.moduleActive) animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Timer {
                    id: animTimer
                    running: false
                    repeat: false
                    onTriggered: wsPill.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: (wsPill.index + 1).toString()
                    font.family: "JetBrains Mono"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 12 : 14) : 14
                    font.weight: wsPill.isActive ? Font.Black : (wsPill.isOccupied ? Font.Bold : Font.Medium)

                    color: wsPill.isActive
                        ? ThemeBackend.crust
                        : (wsPill.isHovered
                            ? ThemeBackend.text
                            : (wsPill.isOccupied
                                ? ThemeBackend.text
                                : (ThemeBackend.overlay0 !== undefined ? ThemeBackend.overlay0 : ThemeBackend.subtext0)))

                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                MouseArea {
                    id: wsPillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widget) widget.focusWorkspace(wsPill.index);
                    }
                }
            }
        }
    }
}
