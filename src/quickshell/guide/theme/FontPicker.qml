import QtQuick
import Quickshell
import "../../"
import "../../reusables"

FilePicker {
    id: fontPickerRoot

    titleText: typeof I18n !== "undefined" ? I18n.t("guide.font_picker.title", "Select a font") : "Select a font"
    nameFilters: ["*.ttf", "*.otf", "*.ttc", "*.woff", "*.woff2"]
    showPreview: false
    preferredWidth: Scaler.s(840)
    preferredHeight: Scaler.s(540)

    extraPlaces: [
        { name: typeof I18n !== "undefined" ? I18n.t("guide.font_picker.places.user_fonts", "User fonts") : "User fonts", icon: "󰆉", path: "file://" + Caching.xdgDataHome + "/fonts" }
    ]

    signal fontSelected(string filePath, string fileName)

    onFileSelected: function(filePath, fileName) {
        fontPickerRoot.fontSelected(filePath, fileName);
    }

    function openPicker() {
        openWithOptionalPath("");
    }
}
