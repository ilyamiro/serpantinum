import QtQuick

Item {
    id: slotRoot

    required property int index
    property var widget: null
    property bool isVertical: false
    property int cascadeBaseDelay: 100
    property int cascadeStepDelay: 50
    property int slideDuration: 600
    property int slideEasing: Easing.OutQuint
    property int opacityDuration: 400

    readonly property bool isOccupied: widget ? widget.isOccupied(index) : false
    readonly property bool isActive: widget ? (index === Number(widget.activeIndex)) : false
    readonly property bool shown: widget && typeof widget.isShown === "function" ? widget.isShown(index) : true
    readonly property bool isHovered: slotMouse.containsMouse
    readonly property bool pressed: slotMouse.pressed

    property bool initAnimTrigger: !(widget && widget.barWindow && !widget.barWindow.startupCascadeFinished)

    visible: shown
    opacity: initAnimTrigger ? 1.0 : 0.0

    transform: Translate {
        x: (!slotRoot.isVertical || slotRoot.initAnimTrigger) ? 0 : (slotRoot.widget ? slotRoot.widget.s(15) : 15)
        y: (slotRoot.isVertical || slotRoot.initAnimTrigger) ? 0 : (slotRoot.widget ? slotRoot.widget.s(15) : 15)
        Behavior on x { NumberAnimation { duration: slotRoot.slideDuration; easing.type: slotRoot.slideEasing } }
        Behavior on y { NumberAnimation { duration: slotRoot.slideDuration; easing.type: slotRoot.slideEasing } }
    }

    Behavior on opacity { NumberAnimation { duration: slotRoot.opacityDuration; easing.type: Easing.OutCubic } }

    Component.onCompleted: {
        if (!initAnimTrigger) {
            cascadeTimer.interval = index * cascadeStepDelay + cascadeBaseDelay;
            if (widget.moduleActive) cascadeTimer.start();
        }
    }

    Timer {
        id: cascadeTimer
        running: false
        repeat: false
        onTriggered: slotRoot.initAnimTrigger = true
    }

    MouseArea {
        id: slotMouse
        anchors.fill: parent
        z: 10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (slotRoot.widget) slotRoot.widget.focusWorkspace(slotRoot.index);
        }
    }
}
