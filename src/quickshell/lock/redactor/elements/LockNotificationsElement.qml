import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "card"
    property var ctx: null

    readonly property bool plain: el.variant === "plain"

    NotificationBox {
        anchors.fill: parent
        hasShadow: !el.plain
        shadowColor: Qt.rgba(0, 0, 0, 0.14)
        baseColor: el.plain ? "transparent" : ThemeBackend.faded(Qt.lighter(ThemeBackend.surface0, 1.28))
        standaloneBlur: el.ctx !== null && !el.plain
        blurScreen: el.ctx ? el.ctx.surface.screen : null
        borderWidth: el.plain ? 0 : 1
        borderColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)
        cornerRadius: Scaler.s(16)
        cardRadius: Scaler.s(14)
        emptyGraphicSize: Math.min(Scaler.s(110), el.height * 0.4)
        rootContext: el.ctx
    }
}
