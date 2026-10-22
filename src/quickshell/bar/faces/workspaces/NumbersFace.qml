import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../reusables"
import "../../../"

Item {
    id: numbersFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false

    property real pillSize: widget ? widget.s(widget.isCompact ? 20 : 24) : 24
    property real pillRadius: widget ? widget.s(widget.isCompact ? 6 : 7) : 7
    property real layoutSpacing: widget ? widget.s(widget.isCompact ? 5 : 6) : 6

    // Special workspace "pill" mode: on a horizontal bar the numbers collapse and the
    // active highlight grows into a pill labelled "special"
    readonly property bool specialOpen: widget ? Boolean(widget.specialActive) : false
    readonly property bool pillMode: !isVertical
    property real specialProgress: (specialOpen && pillMode) ? 1.0 : 0.0
    Behavior on specialProgress { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    TextMetrics {
        id: specialMetrics
        font.family: "JetBrains Mono"
        font.pixelSize: widget ? widget.s(widget.isCompact ? 12 : 14) : 14
        font.weight: Font.Black
        text: "special"
    }
    readonly property real specialPillLength: specialMetrics.advanceWidth + (widget ? widget.s(widget.isCompact ? 16 : 20) : 20)

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
        widget.mangoOccupiedMap;
        if (!widget.isNiri && !widget.isSway && !widget.isMango)
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
        x: numbersFaceRoot.isVertical ? wsLayout.x + (wsLayout.width - width) / 2 : wsLayout.x + (actualStart - wsLayout.x) * (1 - numbersFaceRoot.specialProgress)
        y: numbersFaceRoot.isVertical ? actualStart : wsLayout.y + (wsLayout.height - height) / 2
        width: numbersFaceRoot.isVertical ? numbersFaceRoot.pillSize : (actualEnd - actualStart) + (numbersFaceRoot.specialPillLength - numbersFaceRoot.pillSize) * numbersFaceRoot.specialProgress
        height: numbersFaceRoot.isVertical ? actualEnd - actualStart : numbersFaceRoot.pillSize
        radius: numbersFaceRoot.pillRadius
        color: numbersGlass.active ? "transparent" : ((widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve)

        GlassFill {
            id: numbersGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.mauve
            tintAmount: 0.5
            press: 0.3 + 0.7 * activeHighlight.lift
        }

        property int prevIdx: 0
        property int curIdx: widget ? widget.activeIndex : -1

        onCurIdxChanged: {
            if (curIdx >= 0 && prevIdx >= 0) {
                if (curIdx > prevIdx) {
                    endAnim.duration = 200;
                    startAnim.duration = 350;
                } else if (curIdx < prevIdx) {
                    startAnim.duration = 200;
                    endAnim.duration = 350;
                }
            }
            if (curIdx >= 0) {
                prevIdx = curIdx;
            }
        }

        function getPos(index) {
            if (index < 0)
                return 0;
            let pos = 0;
            const shown = numbersFaceRoot.shownIndices;
            for (let i = 0; i < shown.length; i++) {
                if (shown[i] === index)
                    break;
                pos += numbersFaceRoot.pillSize + numbersFaceRoot.layoutSpacing;
            }
            return (numbersFaceRoot.isVertical ? wsLayout.y : wsLayout.x) + pos;
        }

        property real targetStart: {
            numbersFaceRoot.shownIndices;
            return curIdx >= 0 ? getPos(curIdx) : 0;
        }
        property real targetEnd: (curIdx >= 0) ? (targetStart + numbersFaceRoot.pillSize) : 0

        property real actualStart: targetStart
        property real actualEnd: targetEnd

        Behavior on actualStart { NumberAnimation { id: startAnim; duration: 250; easing.type: Easing.OutExpo } }
        Behavior on actualEnd { NumberAnimation { id: endAnim; duration: 250; easing.type: Easing.OutExpo } }

        readonly property bool isMoving: Math.abs(actualStart - targetStart) > 0.5 || Math.abs(actualEnd - targetEnd) > 0.5
        property real lift: (numbersGlass.active && isMoving) ? 1.0 : 0.0
        Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        property real specialPulse: 0.0
        scale: 1.0 + 0.14 * lift + 0.12 * specialPulse
        transformOrigin: Item.Center

        SequentialAnimation {
            id: specialPulseAnim
            NumberAnimation { target: activeHighlight; property: "specialPulse"; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: activeHighlight; property: "specialPulse"; to: 0.0; duration: 380; easing.type: Easing.OutBack }
        }

        Connections {
            target: numbersFaceRoot.widget
            ignoreUnknownSignals: true
            function onSpecialActiveChanged() { specialPulseAnim.restart(); }
        }

        opacity: (widget && widget.workspaceCount > 0 && widget.activeIndex >= 0) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    AxisFlow {
        id: wsLayout
        vertical: numbersFaceRoot.isVertical
        z: 1
        anchors.centerIn: parent
        spacing: numbersFaceRoot.layoutSpacing * (1 - numbersFaceRoot.specialProgress)

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
                property real specialDim: (numbersFaceRoot.specialOpen && !isActive) ? 0.2 : 1.0
                Behavior on specialDim {
                    enabled: numbersFaceRoot.isVertical
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
                readonly property real fadeOther: numbersFaceRoot.pillMode ? (isActive ? 1.0 : Math.max(0, 1.0 - numbersFaceRoot.specialProgress * 1.6)) : specialDim
                readonly property real numberOpacity: (numbersFaceRoot.pillMode && isActive) ? Math.max(0, 1.0 - numbersFaceRoot.specialProgress * 2.5) : fadeOther

                visible: shown
                width: numbersFaceRoot.isVertical ? numbersFaceRoot.pillSize : (shown ? Math.max(0, isActive ? numbersFaceRoot.pillSize + (numbersFaceRoot.specialPillLength - numbersFaceRoot.pillSize) * numbersFaceRoot.specialProgress : numbersFaceRoot.pillSize * (1 - numbersFaceRoot.specialProgress)) : 0)
                height: numbersFaceRoot.isVertical ? (shown ? numbersFaceRoot.pillSize : 0) : numbersFaceRoot.pillSize

                Rectangle {
                    anchors.fill: parent
                    radius: numbersFaceRoot.pillRadius
                    opacity: wsPill.fadeOther
                    color: numbersHoverGlass.active ? "transparent" : wsPill.isHovered
                        ? Qt.alpha(ThemeBackend.text, 0.1)
                        : (wsPill.isActive ? "transparent" : (wsPill.isOccupied ? Qt.alpha(ThemeBackend.text, 0.15) : "transparent"))

                    Behavior on color { ColorAnimation { duration: 250 } }

                    scale: wsPill.isHovered && !wsPill.isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    GlassFill {
                        id: numbersHoverGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: wsPill.isHovered && !wsPill.isActive
                        tintColor: ThemeBackend.text
                        tintAmount: 0.15
                        press: wsPillMouse.pressed ? 0.8 : 0.25
                    }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: (!numbersFaceRoot.isVertical || wsPill.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    y: (numbersFaceRoot.isVertical || wsPill.initAnimTrigger) ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
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
                    id: wsLabel
                    opacity: wsPill.numberOpacity
                    property bool showS: wsPill.isActive && numbersFaceRoot.specialOpen && !numbersFaceRoot.pillMode
                    onShowSChanged: labelPop.restart()
                    NumberAnimation { id: labelPop; target: wsLabel; property: "scale"; from: 0.3; to: 1.0; duration: 360; easing.type: Easing.OutBack }
                    text: showS ? "S" : (wsPill.index + 1).toString()
                    font.family: "JetBrains Mono"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 12 : 14) : 14
                    font.weight: wsPill.isActive ? Font.Black : (wsPill.isOccupied ? Font.Bold : Font.Medium)

                    color: wsPill.isActive
                        ? (numbersGlass.active ? ThemeBackend.text : ThemeBackend.crust)
                        : (wsPill.isHovered
                            ? ThemeBackend.text
                            : (wsPill.isOccupied
                                ? ThemeBackend.text
                                : (ThemeBackend.overlay0 !== undefined ? ThemeBackend.overlay0 : ThemeBackend.subtext0)))

                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Text {
                    anchors.centerIn: parent
                    visible: wsPill.isActive && numbersFaceRoot.pillMode && numbersFaceRoot.specialProgress > 0.01
                    text: "special"
                    font.family: "JetBrains Mono"
                    font.pixelSize: widget ? widget.s(widget.isCompact ? 12 : 14) : 14
                    font.weight: Font.Black
                    opacity: Math.max(0, Math.min(1, (numbersFaceRoot.specialProgress - 0.55) / 0.4))
                    color: numbersGlass.active ? ThemeBackend.text : ThemeBackend.crust
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
