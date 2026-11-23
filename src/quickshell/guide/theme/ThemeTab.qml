import QtQuick
import QtQuick.Layouts
import "../../reusables"

ThemeTabState {
    id: themeTabRoot

    property alias fontDropdown: appearanceSection.fontDropdown

    property real gridAvailableWidth: Math.max(0, scrollView.contentColumn.width - rootObj.s(24))
    property real tileWidth: Math.max(rootObj.s(80), (gridAvailableWidth - 2 * rootObj.s(10)) / 3)

    onVisibleChanged: {
        if (!visible) {
            if (fontDropdown.isOpen) fontDropdown.closePopup();
            if (themeEditorLoader.item) themeEditorLoader.item.close();
        }
    }

    function openThemeEditorForNew() {
        themeEditorLoader.active = true;
        themeEditorLoader.item.openForNew();
    }

    Loader {
        id: themeEditorLoader
        active: false
        sourceComponent: ThemeEditor {
            rootObj: themeTabRoot.rootObj
            tileWidth: themeTabRoot.tileWidth
            onSaveRequested: function(themeObj) {
                themeTabRoot.saveCustomTheme(themeObj);
                themeTabRoot.applyPreset(themeObj);
            }
        }
    }

    GuideScrollView {
        id: scrollView
        rootObj: themeTabRoot.rootObj

        ThemeAppearanceSection { id: appearanceSection; tab: themeTabRoot }

        ThemePresetsSection { tab: themeTabRoot }
    }
}
