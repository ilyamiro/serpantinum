import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    readonly property bool isSolid: module ? module.isSolid : false
    readonly property bool distinctPills: module ? module.distinctPills : false

    SubscriptionGate {
        target: CurrentFocus
        wanted: root.moduleActive
    }

    readonly property string displayText: CurrentFocus.displayText
    readonly property bool isFocused: CurrentFocus.isFocused
    readonly property bool isFaceVisible: isFocused

    property real startPadding: (isSolid && !distinctPills) ? 0 : s(6)
    property real endPadding: (isSolid && !distinctPills) ? 0 : s(12)
    property real maxLength: s(300)
    property real maxTextLength: Math.max(0, maxLength - (startPadding + (isVertical ? focusIconButton.height : focusIconButton.width) + innerLayout.spacing + endPadding))
    property real targetLength: (moduleActive && isFocused) ? Math.min(maxLength, startPadding + (isVertical ? focusIconButton.height : focusIconButton.width) + innerLayout.spacing + (isVertical ? titleClipRect.height : titleTextMain.width) + endPadding) : 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    AxisFlow {
        id: innerLayout
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        anchors.left: root.isVertical ? undefined : parent.left
        anchors.leftMargin: root.isVertical ? 0 : root.startPadding
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.top: root.isVertical ? parent.top : undefined
        anchors.topMargin: root.isVertical ? root.startPadding : 0
        anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
        spacing: (root.isVertical && isSolid && !distinctPills) ? 0 : root.s(root.isCompact ? 5 : 6)

        IconButton {
            id: focusIconButton
            width: root.s(root.isCompact ? 28 : 30)
            height: root.s(root.isCompact ? 28 : 30)
            cornerRadius: root.s(root.isCompact ? 9 : 10)
            buttonIcon: "✦"
            iconFontSize: root.s(root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ((root.isVertical && isSolid && !distinctPills) ? "transparent" : ThemeBackend.surface0)
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: root.togglePanel("applauncher")
        }

        Item {
            id: titleClipRect
            width: root.isVertical ? focusIconButton.width : Math.min(root.maxTextLength, titleTextMain.width)
            height: root.isVertical ? Math.min(titleTextMain.implicitWidth, root.maxTextLength) : titleTextMain.height
            clip: true

            Behavior on width {
                enabled: !root.isVertical && (barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging) : true)
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Item {
                id: rotator
                anchors.centerIn: parent
                width: root.isVertical ? titleClipRect.height : titleClipRect.width
                height: root.isVertical ? titleClipRect.width : titleClipRect.height
                rotation: root.isVertical ? 90 : 0

                Text {
                    id: titleTextMain
                    text: root.displayText
                    font.family: root.isVertical ? Qt.application.font.family : ThemeBackend.fontFamily
                    font.pixelSize: root.s(root.isCompact ? 11 : 12)
                    font.weight: root.isVertical ? Font.Normal : Font.DemiBold
                    color: (root.isVertical || root.isCompact) ? ThemeBackend.text : ThemeBackend.subtext1
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: root.isVertical ? rotator.width : Math.min(implicitWidth, root.maxTextLength)

                    property string targetText: root.displayText
                    onTargetTextChanged: {
                        if (root.isVertical) return;
                        if (titleTextMain.text === "" || targetText === "") {
                            titleTextMain.text = targetText;
                            return;
                        }
                        if (titleFadeAnim.running) titleFadeAnim.stop();
                        titleFadeAnim.start();
                    }

                    SequentialAnimation {
                        id: titleFadeAnim
                        NumberAnimation { target: titleTextMain; property: "opacity"; to: 0.0; duration: 80; easing.type: Easing.OutQuad }
                        ScriptAction { script: titleTextMain.text = titleTextMain.targetText; }
                        NumberAnimation { target: titleTextMain; property: "opacity"; to: 1.0; duration: 120; easing.type: Easing.InQuad }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isVertical
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: root.togglePanel("applauncher")
    }
}
