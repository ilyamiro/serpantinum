import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"

Flickable {
    id: root

    property var rootObj: null

    readonly property var effectiveRootObj: {
        if (rootObj) return rootObj;
        let p = root.parent;
        while (p) {
            if (p.rootObj) return p.rootObj;
            if (p.isGuidePopup) return p;
            p = p.parent;
        }
        return null;
    }

    function s(val) {
        let dummy = effectiveRootObj;
        return (dummy && typeof dummy.s === "function") ? dummy.s(val) : val;
    }

    property real edgeMargin: root.s(8)
    property real bottomEdgeMargin: root.s(4)
    property real spacing: root.s(6)
    property real topPadding: 0
    property real bottomPadding: root.s(16)
    property real leftPadding: 0
    property real rightPadding: 0
    property real scrollbarGap: root.s(6)
    property bool backgroundClickable: false

    readonly property alias contentColumn: contentCol
    default property alias content: contentCol.data

    signal backgroundClicked()

    anchors.fill: parent
    anchors.topMargin: root.edgeMargin
    anchors.leftMargin: root.edgeMargin
    anchors.rightMargin: root.edgeMargin
    anchors.bottomMargin: root.bottomEdgeMargin

    contentWidth: width
    contentHeight: contentCol.implicitHeight + root.topPadding + root.bottomPadding
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    HoverHandler {
        id: scrollHover
    }

    ScrollBar.vertical: ScrollBar {
        active: root.moving || root.movingVertically || scrollHover.hovered
        width: root.s(4)
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: root.s(4)
            radius: root.s(2)
            color: ThemeBackend.surface2
        }
    }

    MouseArea {
        width: Math.max(root.width, root.contentWidth)
        height: Math.max(root.height, root.contentHeight)
        z: -1
        visible: root.backgroundClickable
        enabled: root.backgroundClickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.backgroundClicked()
    }

    ColumnLayout {
        id: contentCol
        x: root.leftPadding
        y: root.topPadding
        width: Math.max(0, root.width - root.leftPadding - root.rightPadding - (root.contentHeight > root.height ? root.scrollbarGap : 0))
        spacing: root.spacing
    }
}
