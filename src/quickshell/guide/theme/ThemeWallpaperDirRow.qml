import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsRow {
    id: row
    required property var tab
    property alias wpDirDropdown: wpDirDropdown

    rootObj: row.tab.rootObj
    settingId: "wallpaper_dir"
    icon: "󰸉"
    title: I18n.t("guide.theme.wallpaper.title") || "Wallpaper Directory"
    description: I18n.t("guide.theme.wallpaper.desc") || "Directory to search for wallpapers"
    searchKeywords: "wallpaper directory folder path pictures wallpapers"

    IconButton {
        Layout.preferredWidth: rootObj.s(32)
        Layout.preferredHeight: rootObj.s(32)
        Layout.alignment: Qt.AlignVCenter
        cornerRadius: rootObj.s(6)
        buttonIcon: "󰉋"
        iconFontSize: rootObj.s(14)
        accentColor: ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
        onClicked: {
            if (row.tab.currentWallpaperDir && row.tab.currentWallpaperDir !== "") {
                let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(row.tab.currentWallpaperDir) + "\" && xdg-open \"" + escapeBash(row.tab.currentWallpaperDir) + "\""]);
            }
        }
    }

    Dropdown {
        id: wpDirDropdown
        Layout.preferredWidth: rootObj.s(260)
        Layout.preferredHeight: rootObj.s(32)
        Layout.alignment: Qt.AlignVCenter
        options: row.tab.availableWallpaperDirs
        isPathSelector: true
        fuzzySearch: true
        currentIndex: options.indexOf(row.tab.currentWallpaperDir) >= 0 ? options.indexOf(row.tab.currentWallpaperDir) : 0
        placeholderText: I18n.t("guide.theme.wallpaper.select_dir") || "Select directory..."
        fontFamily: ThemeBackend.fontFamily
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface0
        hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: rootObj.s(11)
        onValueChanged: function(index, value) {
            row.tab.currentWallpaperDir = value;
            row.tab.updateWallpaperDirSetting();
        }
        onSelected: function(index, value) {
            row.tab.currentWallpaperDir = value;
            row.tab.updateWallpaperDirSetting();
        }
        onClicked: {
            row.tab.wallpaperDirScanner.running = false;
            row.tab.wallpaperDirScanner.running = true;
        }
    }
}
