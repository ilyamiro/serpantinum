import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../../reusables"
import "../../../../"

Item {
    id: numbersFaceRoot
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
        y: wsLayout.y + (wsLayout.height - height) / 2
        height: numbersFaceRoot.pillSize
        radius: numbersFaceRoot.pillRadius
        color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve

        property int prevIdx: 0
        property int curIdx: widget ? widget.activeIndex : -1

        onCurIdxChanged: {
            if (curIdx >= 0 && prevIdx >= 0) {
                if (curIdx > prevIdx) {
                    rightAnim.duration = 200;
                    leftAnim.duration = 350;
                } else if (curIdx < prevIdx) {
                    leftAnim.duration = 200;
                    rightAnim.duration = 350;
                }
            }
            if (curIdx >= 0) {
                prevIdx = curIdx;
            }
        }

        function getX(index) {
            if (index < 0)
                return 0;
            let xPos = 0;
            const shown = numbersFaceRoot.shownIndices;
            for (let i = 0; i < shown.length; i++) {
                if (shown[i] === index)
                    break;
                xPos += numbersFaceRoot.pillSize + numbersFaceRoot.layoutSpacing;
            }
            return wsLayout.x + xPos;
        }

        property real targetLeft: {
            numbersFaceRoot.shownIndices;
            return curIdx >= 0 ? getX(curIdx) : 0;
        }
        property real targetRight: (curIdx >= 0) ? (targetLeft + numbersFaceRoot.pillSize) : 0

        property real actualLeft: targetLeft
        property real actualRight: targetRight

        Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
        Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

        x: actualLeft
        width: actualRight - actualLeft
        opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Row {
        id: wsLayout
        z: 1
        anchors.centerIn: parent
        spacing: numbersFaceRoot.layoutSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: wsPill
                required property int index

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool isHovered: wsPillMouse.containsMouse
                property bool initAnimTrigger: false
                property bool shown: numbersFaceRoot.isShown(index)

                visible: shown
                width: shown ? numbersFaceRoot.pillSize : 0
                height: numbersFaceRoot.pillSize

                Rectangle {
                    anchors.fill: parent
                    radius: numbersFaceRoot.pillRadius
                    color: wsPill.isHovered
                        ? Qt.alpha(ThemeBackend.text, 0.1)
                        : (wsPill.isActive ? "transparent" : (wsPill.isOccupied ? Qt.alpha(ThemeBackend.text, 0.15) : "transparent"))

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.isHovered && !wsPill.isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    y: wsPill.initAnimTrigger ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
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
