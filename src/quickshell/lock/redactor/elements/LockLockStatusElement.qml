import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "filled"
    property var ctx: null

    readonly property bool plain: el.variant === "plain"
    readonly property string statusText: el.ctx ? el.ctx.lockUI.statusText : I18n.t("lock.status.locked")

    ClickButton {
        anchors.fill: parent
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: Scaler.s(16)
        buttonIcon: "󰌾"
        iconFontSize: Scaler.s(15)
        buttonText: el.statusText
        textFontSize: Scaler.s(13)
        accentColor: el.plain ? "transparent" : Qt.lighter(ThemeBackend.surface0, 1.28)
        textColor: el.ctx && el.ctx.lockUI.failed ? ThemeBackend.red : ThemeBackend.text
        onClicked: if (el.ctx) el.ctx.restoreFocus()
    }
}
