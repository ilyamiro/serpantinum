import QtQuick
import QtQuick.Layouts
import "../../../../reusables"
import "../../../../"

Item {
    id: sidePillsFaceRoot
    property var widget: null

    implicitWidth: wsLayout.implicitWidth
    implicitHeight: wsLayout.implicitHeight

    Rectangle {
        id: activeHighlight
        z: 3
        radius: widget ? widget.s(widget.isCompact ? 7 : 8) : 8
        color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve

        property int prevIdx: 0
        property int curIdx: widget ? widget.activeIndex : -1

        onCurIdxChanged: {
            if (curIdx >= 0 && prevIdx >= 0) {
                if (curIdx > prevIdx) {
                    topAnim.duration = 400;
                    bottomAnim.duration = 300;
                } else if (curIdx < prevIdx) {
                    topAnim.duration = 300;
                    bottomAnim.duration = 400;
                }
            }
            if (curIdx >= 0) {
                prevIdx = curIdx;
            }
        }

        function getY(index, activeIndex) {
            if (index < 0 || !widget) return 0;
            let yPos = 0;
            let spacing = widget.s(widget.isCompact ? 7 : 8);
            let activeH = widget.s(widget.isCompact ? 34 : 36);
            let inactiveH = widget.s(widget.isCompact ? 16 : 18);
            for (let i = 0; i < index; i++) {
                if (typeof widget.isShown === "function" && !widget.isShown(i))
                    continue;
                yPos += (i === activeIndex ? activeH : inactiveH) + spacing;
            }
            return yPos;
        }

        property real targetTop: {
            if (widget) {
                widget.hideEmptyWorkspaces;
                widget.activeIndex;
                widget.niriOccupiedMap;
                widget.swayOccupiedMap;
            }
            return (curIdx >= 0 && widget) ? getY(curIdx, curIdx) : 0;
        }
        property real targetBottom: (curIdx >= 0 && widget) ? targetTop + widget.s(widget.isCompact ? 34 : 36) : 0
        property real actualTop: targetTop
        property real actualBottom: targetBottom

        Behavior on actualTop { NumberAnimation { id: topAnim; duration: 380; easing.type: Easing.OutQuint } }
        Behavior on actualBottom { NumberAnimation { id: bottomAnim; duration: 380; easing.type: Easing.OutQuint } }

        x: wsLayout.x + (wsLayout.width - width) / 2
        y: wsLayout.y + actualTop
        width: widget ? widget.s(widget.isCompact ? 16 : 18) : 18
        height: actualBottom - actualTop
        opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Column {
        id: wsLayout
        z: 2
        anchors.centerIn: parent
        spacing: widget ? widget.s(widget.isCompact ? 7 : 8) : 8

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: wsPill
                required property int index

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool initAnimTrigger: false
                property bool shown: widget && typeof widget.isShown === "function" ? widget.isShown(index) : true

                visible: shown
                width: widget ? widget.s(widget.isCompact ? 16 : 18) : 18
                height: shown
                    ? (isActive ? (widget ? widget.s(widget.isCompact ? 34 : 36) : 36) : (widget ? widget.s(widget.isCompact ? 16 : 18) : 18))
                    : 0
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                Rectangle {
                    id: wsVisualShape
                    anchors.fill: parent
                    radius: widget ? widget.s(widget.isCompact ? 8 : 10) : 10
                    color: wsPill.isActive ? "transparent" : (wsPill.isOccupied ? ThemeBackend.surface2 : ((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0))
                    border.width: 0

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPillMouse.pressed ? 0.88 : (wsPillMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: wsPill.initAnimTrigger ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
                }

                Component.onCompleted: {
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 50 + 100;
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

                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: wsPillMouse
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        if (widget) widget.focusWorkspace(wsPill.index);
                    }
                }
            }
        }
    }
}
