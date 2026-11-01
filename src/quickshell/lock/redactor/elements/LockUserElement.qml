import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "filled"
    property var ctx: null

    readonly property bool plain: el.variant === "plain"
    readonly property string userName: el.ctx ? el.ctx.currentUser : (SystemInfo.username !== "" ? SystemInfo.username : I18n.t("lock.default_user"))

    ClickButton {
        anchors.fill: parent
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: Scaler.s(16)
        buttonIcon: "󰀉"
        iconFontSize: Scaler.s(15)
        buttonText: el.userName
        textFontSize: Scaler.s(13)
        accentColor: el.plain ? "transparent" : Qt.lighter(ThemeBackend.surface0, 1.28)
        textColor: ThemeBackend.text
        onClicked: if (el.ctx) el.ctx.restoreFocus()
    }
}
