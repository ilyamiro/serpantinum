import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../"
import "../battery"

Notification {
    id: faceRoot

    function iconValue() {
        var n = delegateWrapper ? delegateWrapper.realNotif : null;
        var parts = [];
        if (model) {
            parts.push(model.image, model.imagePath, model.iconPath, model.icon);
        }
        if (n) {
            parts.push(n.image, n.imagePath, n.appIcon);
        }
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i];
            if (p === undefined || p === null) continue;
            var m = /battery-kind-([a-z_]+)/.exec(p.toString());
            if (m) return m[1];
        }
        return "";
    }

    readonly property string kind: iconValue()
    readonly property bool hasKind: kind !== ""

    function kindAccent() {
        switch (kind) {
        case "critical": return ThemeBackend.red;
        case "full": return ThemeBackend.green;
        }
        return ThemeBackend.peach;
    }

    fullSummary: model ? (model.summary || I18n.t("notifications.types.battery.title", "Battery")) : ""
    fullBody: model ? model.body : ""
    accentColor: kindAccent()
    iconFullBleed: hasKind

    bgContent: [
        BatteryCardBackground {
            anchors.fill: parent
            visible: faceRoot.hasKind
            kind: faceRoot.kind
            radius: ThemeBackend.borderRadius
            surface: ThemeBackend.surface1
            mirror: I18n.rtl
        }
    ]

    iconArea: [
        Item {
            anchors.fill: parent

            BatteryIllustration {
                anchors.fill: parent
                visible: faceRoot.hasKind
                kind: faceRoot.kind
                radius: Math.max(0, parent.parent.radius)
            }

            Text {
                anchors.centerIn: parent
                visible: !faceRoot.hasKind
                text: "󰁹"
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(24)
                color: faceRoot.accentColor
            }
        }
    ]

    headerArea: [
        Text {
            Layout.fillWidth: true
            horizontalAlignment: I18n.textAlignment
            text: I18n.t("notifications.types.battery.title", "Battery")
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: faceRoot.bodyText
            elide: Text.ElideRight
        }
    ]
}
