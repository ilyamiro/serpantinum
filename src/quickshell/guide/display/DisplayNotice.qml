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
    color: Qt.alpha(notice.accent, 0.07)
    border.width: 1
    border.color: Qt.alpha(notice.accent, 0.4)
    implicitHeight: shown ? body.implicitHeight + rootObj.s(16) : 0

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    RowLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: rootObj.s(10)
        anchors.rightMargin: rootObj.s(10)
        spacing: rootObj.s(10)

        // Icon badge
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: rootObj.s(30)
            implicitHeight: rootObj.s(30)
            radius: width / 2
            color: Qt.alpha(notice.accent, 0.18)

            Text {
                anchors.centerIn: parent
                text: notice.icon
                font.family: ThemeBackend.iconFont
                font.pixelSize: rootObj.s(15)
                color: notice.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: rootObj.s(1)

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: notice.title
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(13)
                font.bold: true
                color: ThemeBackend.text
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: notice.message
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                color: ThemeBackend.subtext0
                wrapMode: Text.WordWrap
            }

            // Code / command chip
            Rectangle {
                visible: notice.detail !== ""
                Layout.topMargin: rootObj.s(4)
                Layout.maximumWidth: parent.width
                implicitWidth: chipText.implicitWidth + rootObj.s(16)
                implicitHeight: chipText.implicitHeight + rootObj.s(8)
                radius: rootObj.s(6)
                color: Qt.alpha(ThemeBackend.crust, 0.7)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.surface2, 0.5)

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.parent.width - rootObj.s(16))
                    text: notice.detail
                    font.family: "monospace"
                    font.pixelSize: rootObj.s(11)
                    color: notice.accent
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter
            spacing: rootObj.s(8)
        }
    }
}
