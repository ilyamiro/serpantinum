import QtQuick
import Quickshell
import "../../"
import "../../reusables"

FilePicker {
    id: fontPickerRoot

    titleText: typeof I18n !== "undefined" ? I18n.t("guide.font_picker.title") : "Select a font"
    nameFilters: ["*.ttf", "*.otf", "*.ttc", "*.woff", "*.woff2"]
    showPreview: false
    preferredWidth: s(840)
    preferredHeight: s(540)

    places: [
        { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.home") : "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
        { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.downloads") : "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
        { name: typeof I18n !== "undefined" ? I18n.t("guide.font_picker.places.user_fonts") : "User Fonts", icon: "󰆉", path: "file://" + (Quickshell.env("HOME") || "") + "/.local/share/fonts" },
    ]

    signal fontSelected(string filePath, string fileName)

    onFileSelected: function(filePath, fileName) {
        fontPickerRoot.fontSelected(filePath, fileName);
    }

    function openPicker() {
        openWithOptionalPath("");
    }
}
