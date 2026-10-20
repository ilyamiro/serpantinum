import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

ColumnLayout {
    id: root

    property string icon: ""
    property string caption: ""
    property bool highlighted: false
    signal clicked()

    spacing: Scaler.s(6)
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: Scaler.s(56)

    IconButton {
        Layout.alignment: Qt.AlignHCenter
        size: Scaler.s(48)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: root.icon
        iconFontSize: Scaler.s(22)
        accentColor: root.highlighted ? ThemeBackend.mauve : ThemeBackend.surface0
        textColor: root.highlighted ? ThemeBackend.crust : ThemeBackend.text
        onClicked: root.clicked()
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Scaler.s(56)
        horizontalAlignment: Text.AlignHCenter
        text: root.caption
        elide: Text.ElideRight
        maximumLineCount: 1
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(11)
        font.bold: true
        color: ThemeBackend.subtext0
    }
}
