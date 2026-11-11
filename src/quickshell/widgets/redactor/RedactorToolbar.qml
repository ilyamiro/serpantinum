import QtQuick
import QtQuick.Layouts
import "../../"
import ".."
import "../../reusables"

WidgetPicker {
    id: toolbar

    required property var host
    required property var redactorWindow

    anchors.bottom: parent.bottom
    anchors.bottomMargin: s(24)
    anchors.horizontalCenter: parent.horizontalCenter
    z: 200000
    maxWidth: redactor.width - s(48)

    opacity: (toolbar.panelOpen || !redactor.activeWidgetsModel || redactor.activeWidgetsModel.count === 0 || redactor.selectedId === "" || !redactor.toolbarObscured) ? 1.0 : 0.0
    visible: opacity > 0
    enabled: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

    IconButton {
        size: toolbar.controlHeight
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰕰"
        iconFontSize: s(16)
        accentColor: redactor.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface0
        textColor: redactor.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
        Layout.alignment: Qt.AlignVCenter

        onClicked: {
            let turningOn = !redactor.gridEnabled;
            redactor.gridEnabled = turningOn;
            if (turningOn) {
                redactor.snapAllWidgetsToGrid();
            }
        }
    }

    IconButton {
        size: toolbar.controlHeight
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰑐"
        iconFontSize: s(16)
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.text
        Layout.alignment: Qt.AlignVCenter
        visible: redactor.activeWidgetsModel ? (redactor.activeWidgetsModel.count > 0) : false
        onClicked: redactor.removeAllWidgets()
    }

    ClickButton {
        Layout.alignment: Qt.AlignVCenter
        maxWidth: s(100)
        implicitHeight: toolbar.controlHeight
        horizontalPadding: s(14)
        cornerRadius: ThemeBackend.borderRadius
        buttonText: I18n.t("widgets.redactor.done")
        textFontSize: s(12)
        accentColor: ThemeBackend.mauve
        textColor: ThemeBackend.crust
        onClicked: {
            redactor.selectedId = "";
            host.targetSelectedWidgetId = "";
            redactorWindow.exitRedactor();
        }
    }
}
