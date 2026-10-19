import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Rectangle {
    id: root
    Layout.fillWidth: true

    readonly property bool isSettingsBlob: true

    property real cornerRadius: ThemeBackend.borderRadius
    property color baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)

    default property alias content: blobCol.data

    radius: root.cornerRadius
    color: blobGlass.active ? "transparent" : root.baseColor
    clip: true

    implicitHeight: blobCol.implicitHeight
    Layout.preferredHeight: implicitHeight

    GlassFill {
        id: blobGlass
        anchors.fill: parent
        radius: root.cornerRadius
        tintColor: ThemeBackend.surface0
        tintAmount: 0.26
    }

    ColumnLayout {
        id: blobCol
        readonly property bool isBlobColumn: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0
    }
}
