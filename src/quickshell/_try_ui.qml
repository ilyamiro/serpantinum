import QtQuick
import Quickshell

// Temporary test window (removed on exit): hosts the Display page.
FloatingWindow {
    implicitWidth: 900
    implicitHeight: 1000
    Item {
        id: fakeRoot
        anchors.fill: parent
        property int currentTab: 0
        property int currentSubTab: 0
        function s(v) { return v }
        Loader {
            anchors.fill: parent
            Component.onCompleted: setSource("guide/display/DisplayMainTab.qml", { "rootObj": fakeRoot, "tabIndex": 0 })
        }
    }
}
