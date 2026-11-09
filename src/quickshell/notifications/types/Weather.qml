import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../"
import "../weather"

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
            var str = p.toString();
            var m = /weather-kind-([a-z_]+)/.exec(str);
            if (m) return m[1];
        }
        return "";
    }

    readonly property string kind: iconValue()
    readonly property bool hasKind: kind !== ""
    readonly property bool isGov: kind === "gov" || kind.indexOf("gov_") === 0
    readonly property string severity: kind.indexOf("gov_extreme") === 0 ? "extreme" : kind.indexOf("gov_severe") === 0 ? "severe" : "moderate"

    function kindAccent() {
        if (!hasKind) return ThemeBackend.peach;
        if (isGov) return severity === "extreme" ? ThemeBackend.red : severity === "severe" ? ThemeBackend.peach : ThemeBackend.yellow;
        switch (kind) {
        case "rain_soon": case "heavy_rain": case "daily_rain": return ThemeBackend.blue;
        case "thunderstorm": case "daily_storm": case "uv": case "daily_clear": return ThemeBackend.yellow;
        case "snow_soon": case "heavy_snow": case "daily_snow": case "ice": case "cold": case "temp_drop": return ThemeBackend.sapphire;
        case "fog": case "daily_fog": case "wind": case "daily_cloudy": return ThemeBackend.teal;
        case "hot": case "temp_rise": return ThemeBackend.peach;
        case "air_quality": return ThemeBackend.mauve;
        }
        return ThemeBackend.peach;
    }

    fullSummary: model ? (model.summary || I18n.t("notifications.types.weather.fallback_summary")) : ""
    fullBody: model ? (model.body || I18n.t("notifications.types.weather.fallback_body")) : ""
    accentColor: kindAccent()
    iconFullBleed: hasKind

    bgContent: [
        WeatherCardBackground {
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

            WeatherIllustration {
                anchors.fill: parent
                visible: faceRoot.hasKind
                kind: faceRoot.kind
                radius: Math.max(0, parent.parent.radius)
            }

            Text {
                anchors.centerIn: parent
                visible: !faceRoot.hasKind
                text: "󰖕"
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
            text: I18n.t("notifications.types.weather.title", "Weather")
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: s(11)
            color: faceRoot.bodyText
            elide: Text.ElideRight
        }
    ]
}
