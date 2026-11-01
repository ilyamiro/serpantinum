import QtQuick

Item {
    id: guideTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: -1

    readonly property bool isCurrent: rootObj.currentTab === tabIndex && (subTabIndex < 0 || rootObj.currentSubTab === subTabIndex)

    property bool revealed: visible

    anchors.fill: parent
    visible: isCurrent
    opacity: revealed ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: 150 } }
}
