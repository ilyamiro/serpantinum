import QtQuick

Item {
    id: guideTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: -1

    readonly property bool isCurrent: rootObj.currentTab === tabIndex && (subTabIndex < 0 || rootObj.currentSubTab === subTabIndex)

    property bool revealed: visible
    property real slideY: revealed ? 0 : rootObj.s(10)

    anchors.fill: parent
    visible: isCurrent
    opacity: revealed ? 1.0 : 0.0

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 250 } }
    transform: Translate { y: guideTabRoot.slideY }
}
