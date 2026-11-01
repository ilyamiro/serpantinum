import QtQuick
import QtQuick.Layouts

ThemeTabState {
    id: themeTabRoot

    property alias fontDropdown: appearanceSection.fontDropdown
    property alias wpDirDropdown: wallpaperDirRow.wpDirDropdown
    property alias themeEditorPopup: themeEditorPopup

    property real gridAvailableWidth: Math.max(0, settingsCol.width - rootObj.s(24))
    property real tileWidth: Math.max(rootObj.s(80), (gridAvailableWidth - 2 * rootObj.s(10)) / 3)

    onVisibleChanged: {
        if (!visible) {
            if (fontDropdown.isOpen) fontDropdown.closePopup();
            if (wpDirDropdown.isOpen) wpDirDropdown.closePopup();
            themeEditorPopup.close();
        }
    }

    ThemeEditor {
        id: themeEditorPopup
        rootObj: themeTabRoot.rootObj
        tileWidth: themeTabRoot.tileWidth
        onSaveRequested: function(themeObj) {
            themeTabRoot.saveCustomTheme(themeObj);
            themeTabRoot.applyPreset(themeObj);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            ThemeWallpaperPreview { tab: themeTabRoot }

            ThemeWallpaperDirRow { id: wallpaperDirRow; tab: themeTabRoot }

            ThemeAppearanceSection { id: appearanceSection; tab: themeTabRoot }

            ThemePresetsSection { tab: themeTabRoot }
        }
    }
}
