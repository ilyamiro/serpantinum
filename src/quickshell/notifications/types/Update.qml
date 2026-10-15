import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../"

Notification {
    id: faceRoot

    fullSummary: model ? (model.summary || "Update Available") : "Update Available"
    fullBody: model && model.body !== "" ? model.body : "A new version of Serpantinum is available."
    accentColor: ThemeBackend.green
    overrideClick: true

    onCardClicked: {
        var n = delegateWrapper ? delegateWrapper.realNotif : null;
        if (n && n.actions) {
            for (var i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === "default") {
                    n.actions[i].invoke();
                    break;
                }
            }
        }
        Quickshell.execDetached(["bash", "-c", "echo 'about' > '" + Caching.getCacheDir("guide") + "/last_tab.txt'"]);
        Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "guide"]);
        doClose();
    }

    iconArea: [
        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(ThemeBackend.green, 0.15)
            }

            Text {
                anchors.centerIn: parent
                text: "󰚰"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(22)
                color: ThemeBackend.green
            }
        }
    ]

    headerArea: [
        Text {
            Layout.fillWidth: true
            horizontalAlignment: I18n.textAlignment
            text: model ? (model.displayName || model.appName || "Serpantinum Updater") : "Serpantinum Updater"
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: ThemeBackend.subtext0
            elide: Text.ElideRight
        }
    ]
}
