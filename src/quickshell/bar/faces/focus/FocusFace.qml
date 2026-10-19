import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool moduleActive: module ? module.moduleActive : true
    readonly property bool isSolid: module ? module.isSolid : false
    readonly property bool distinctPills: module ? module.distinctPills : false
    readonly property real barOpacity: ThemeBackend.elementOpacity

    readonly property string displayText: CurrentFocus.displayText
    readonly property bool isFocused: CurrentFocus.isFocused
    readonly property bool isFaceVisible: isFocused

    property real startPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.cs(6) : 6)
    property real endPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.cs(12) : 12)
    property real maxLength: barWindow ? barWindow.cs(300) : 300
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
        spacing: (root.isVertical && isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.cs(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6))

        IconButton {
            id: focusIconButton
            width: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
            buttonIcon: "✦"
            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ((root.isVertical && isSolid && !distinctPills) ? "transparent" : ThemeBackend.surface0)
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: {
                if (Caching.serpantinumDir) {
                    Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle applauncher"])
                }
            }
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
                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
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
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle applauncher"])
            }
        }
    }
}
