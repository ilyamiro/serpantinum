import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.fillWidth: true
    clip: true

    property bool open: true
    property var row: null

    property real openProgress: open ? 1 : 0
    visible: openProgress > 0.001
    implicitHeight: (row ? row.implicitHeight : 0) * openProgress

    Behavior on openProgress {
        NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
    }
}
