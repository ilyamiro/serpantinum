import QtQuick
import QtQuick.Layouts
import "../../"
import ".."

Item {
    function s(val) { return Scaler.s(val); }

    width: s(400)
    height: s(100)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: s(8)

        Text {
            text: I18n.t("widgets.redactor.no_widgets_active")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(20)
            font.bold: true
            color: ThemeBackend.text
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: I18n.t("widgets.redactor.click_to_add")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(14)
            color: ThemeBackend.subtext0
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
