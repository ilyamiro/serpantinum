import QtQuick
import "../../"
import "../../../"

Item {
    id: el

    property string variant: "classic"
    property bool showText: true
    property var ctx: null

    visible: !el.ctx || el.ctx.root.fingerprintAvailable
    implicitWidth: Scaler.s(200)
    implicitHeight: Scaler.s(72)

    FingerprintIndicator {
        anchors.centerIn: parent
        status: el.ctx ? el.ctx.lockUI.fpState : "ready"
        label: el.ctx ? el.ctx.lockUI.fpLabel : I18n.t("lock.fingerprint.ready")
        attempts: el.ctx ? el.ctx.lockUI.fpFailures : 0
        maxAttempts: el.ctx ? el.ctx.root.fingerprintMaxAttempts : 5
        look: el.variant
        showLabel: el.showText
        glyphSize: Math.max(Scaler.s(24), Math.min(el.width, el.height - (el.showText ? Scaler.s(24) : 0)) * 0.9)
        labelPixelSize: Scaler.s(12)
    }
}
