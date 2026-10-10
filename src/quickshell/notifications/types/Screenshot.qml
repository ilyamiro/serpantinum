import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"
import "../"

Notification {
    id: faceRoot

    fullSummary: model ? (model.summary || I18n.t("notifications.types.screenshot.fallback_summary")) : ""
    fullBody: model && model.body !== "" ? model.body : I18n.t("notifications.types.screenshot.click_to_open")
    accentColor: ThemeBackend.mauve
    overrideClick: true

    function getImagePath() {
        var n = (model && model.notif) ? model.notif : (delegateWrapper ? delegateWrapper.realNotif : null);
        var p = "";
        if (n) {
            if (n.image) p = n.image.toString();
            else if (n.imagePath) p = n.imagePath;
            else if (n.appIcon) p = n.appIcon;
        }
        if (!p && model) {
            p = model.imagePath || model.image || model.iconPath || model.icon || "";
            if (typeof p === "object" && p && p.toString) p = p.toString();
        }
        return p ? p.toString() : "";
    }

    onCardClicked: {
        let p = getImagePath();
        if (p !== "" && (p.startsWith("/") || p.startsWith("file://"))) {
            let filePath = p.startsWith("file://") ? p.replace("file://", "") : p;
            let folderPath = filePath.substring(0, filePath.lastIndexOf('/'));
            Quickshell.execDetached(["xdg-open", folderPath]);
        } else {
            var n = delegateWrapper ? delegateWrapper.realNotif : null;
            if (n && n.actions) {
                for (var i = 0; i < n.actions.length; i++) {
                    if (n.actions[i].identifier === "default") {
                        n.actions[i].invoke();
                        break;
                    }
                }
            }
        }
        doClose();
    }

    bgContent: [
        Item {
            anchors.fill: parent

            Rectangle {
                id: bgMask
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "black"
                visible: false
            }

            Image {
                id: rawBgImg
                anchors.fill: parent
                source: {
                    let p = faceRoot.getImagePath();
                    if (!p || p === "") return "";
                    if (p.startsWith("file://") || p.startsWith("http://") || p.startsWith("https://") || p.startsWith("image://")) return p;
                    if (p.startsWith("/")) return "file://" + p;
                    return "image://icon/" + p;
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: rawBgImg
                maskSource: bgMask
                maskEnabled: true
                opacity: 0.22
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.surface0, 0.45) }
                    GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.surface0, 0.65) }
                }
            }
        }
    ]

    iconArea: [
        Text {
            anchors.centerIn: parent
            text: "󰄀"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: s(24)
            color: faceRoot.accentColor
        }
    ]

    headerArea: [
        Text {
            Layout.fillWidth: true
            horizontalAlignment: I18n.textAlignment
            text: model ? (model.displayName || model.appName || I18n.t("notifications.types.screenshot.badge")) : I18n.t("notifications.types.screenshot.badge")
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: ThemeBackend.subtext0
            elide: Text.ElideRight
        }
    ]
}
