import QtQuick
import QtQuick.Layouts
import "../../"

ColumnLayout {
    id: metric
    required property var tab
    readonly property var rootObj: tab.rootObj
    property string caption: ""
    property string value: ""
    property string detail: ""
    property string iconSource: ""
    property real valueSize: rootObj.s(22)

    spacing: rootObj.s(2)

    Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        font.family: ThemeBackend.fontFamily
        font.weight: Font.DemiBold
        font.pixelSize: rootObj.s(12)
        color: metric.tab.textSub
        text: metric.caption
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: rootObj.s(8)

        Image {
            visible: metric.iconSource !== ""
            Layout.preferredWidth: rootObj.s(26)
            Layout.preferredHeight: rootObj.s(26)
            Layout.alignment: Qt.AlignVCenter
            source: metric.iconSource
            sourceSize: Qt.size(rootObj.s(26), rootObj.s(26))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: metric.valueSize
            color: metric.tab.textMain
            text: metric.value
        }
    }

    Text {
        Layout.fillWidth: true
        visible: metric.detail !== ""
        elide: Text.ElideRight
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Medium
        font.pixelSize: rootObj.s(11)
        color: metric.tab.textDim
        text: metric.detail
    }
}
