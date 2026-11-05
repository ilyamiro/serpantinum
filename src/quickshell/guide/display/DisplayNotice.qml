import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// Banner used by the display page: pending-change confirmation, results and hints.
Rectangle {
    id: notice
    required property var rootObj

    property string icon: "󰋼"
    property string title: ""
    property string message: ""
    property string detail: ""
    property color accent: ThemeBackend.mauve
    property bool shown: true
    default property alias actions: actionRow.data

    Layout.fillWidth: true
    visible: opacity > 0.01
    opacity: shown ? 1.0 : 0.0
    clip: true
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, 0.55)
    border.width: 1
    border.color: Qt.alpha(notice.accent, 0.55)
    implicitHeight: shown ? body.implicitHeight + rootObj.s(24) : 0

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    RowLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(12)

        Text {
            Layout.alignment: Qt.AlignTop
            text: notice.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: rootObj.s(22)
            color: notice.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: rootObj.s(2)

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: notice.title
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(14)
                font.bold: true
                color: ThemeBackend.text
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: notice.message
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                color: ThemeBackend.subtext0
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: notice.detail
                font.family: "monospace"
                font.pixelSize: rootObj.s(11)
                color: ThemeBackend.text
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
        }

        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter
            spacing: rootObj.s(8)
        }
    }
}
