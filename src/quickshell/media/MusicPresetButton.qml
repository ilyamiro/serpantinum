import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

ClickButton {
    required property var root
    property string name: ""
    bgOpacity: ThemeBackend.elementOpacity
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: root.s(28)
    cornerRadius: ThemeBackend.borderRadius
    buttonText: I18n.t("music.presets." + name.toLowerCase())
    textFontSize: root.s(11.5)
    horizontalPadding: 0
    property bool isActivePreset: root.eqData && root.eqData.preset === name
    accentColor: isActivePreset ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface0 || "#313244")
    textColor: isActivePreset ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.subtext0 || "#a6adc8")
    onClicked: root.applyPresetOptimistically(name)
}
