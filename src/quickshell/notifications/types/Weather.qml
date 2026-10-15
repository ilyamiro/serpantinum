import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../"

Notification {
    id: faceRoot

    fullSummary: model ? (model.summary || I18n.t("notifications.types.weather.fallback_summary")) : ""
    fullBody: model ? (model.body || I18n.t("notifications.types.weather.fallback_body")) : ""
    accentColor: ThemeBackend.peach

    iconArea: [
        Text {
            anchors.centerIn: parent
            text: "󰖕"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: s(24)
            color: faceRoot.accentColor
        }
    ]

    headerArea: [
        Text {
            Layout.fillWidth: true
            horizontalAlignment: I18n.textAlignment
            text: model ? (model.displayName || model.appName || I18n.t("notifications.types.weather.title")) : I18n.t("notifications.types.weather.title")
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: ThemeBackend.subtext0
            elide: Text.ElideRight
        }
    ]
}
