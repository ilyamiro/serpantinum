import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../"

Notification {
    id: faceRoot

    fullSummary: model ? (model.summary || I18n.t("notifications.types.default.fallback_summary")) : ""
    fullBody: model ? (model.body || "") : ""

    iconArea: [
        Item {
            anchors.fill: parent

            Image {
                id: notifIcon
                anchors.fill: parent
                source: {
                    let ic = model ? (model.icon || model.iconPath || "") : "";
                    if (!ic) return "";
                    if (typeof AppMatcher !== "undefined" && typeof AppMatcher.resolveIcon === "function") {
                        return AppMatcher.resolveIcon(ic);
                    }
                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                }
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready && source !== ""
            }

            Text {
		anchors.centerIn: parent
		anchors.horizontalCenterOffset: 1
		anchors.verticalCenterOffset: -1
                visible: !notifIcon.visible
                text: "󰋽"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(22)
                color: faceRoot.bodyText
            }
        }
    ]

    headerArea: [
        Text {
            Layout.fillWidth: true
            horizontalAlignment: I18n.textAlignment
            text: model ? (model.displayName || model.appName || "System") : "System"
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: faceRoot.bodyText
            elide: Text.ElideRight
        }
    ]
}
