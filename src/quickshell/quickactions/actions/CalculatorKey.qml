import QtQuick
import QtQuick.Layouts
import "../../reusables"
import "../../"

ClickButton {
    id: key

    property string kind: "normal"
    property bool active: false
    property bool alt: false
    property int keyMargin: 3
    property int columnSpan: 1
    property real cellWidth: 0
    property real cellHeight: 0

    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.preferredWidth: Math.max(0, key.cellWidth * key.columnSpan - key.keyMargin * 2)
    Layout.preferredHeight: Math.max(0, key.cellHeight - key.keyMargin * 2)
    Layout.columnSpan: key.columnSpan
    Layout.margins: key.keyMargin

    horizontalPadding: 4
    bgOpacity: ThemeBackend.elementOpacity
    action_highlight: key.active

    accentColor: {
        if (key.kind === "primary") return ThemeBackend.blue;
        if (key.alt) return Qt.tint(ThemeBackend.surface0, Qt.alpha(ThemeBackend.blue, 0.24));
        return key.kind === "operator" ? ThemeBackend.surface1 : ThemeBackend.surface0;
    }
    textColor: {
        if (key.kind === "primary") return ThemeBackend.mantle;
        if (key.kind === "operator" || key.active) return ThemeBackend.blue;
        if (key.kind === "danger") return ThemeBackend.red;
        return ThemeBackend.text;
    }
}
